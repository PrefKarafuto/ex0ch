#!/usr/bin/perl
#============================================================================================================
#
#	書き込み用CGI
#
#============================================================================================================

use lib './perllib';

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
no warnings 'once';
use CGI::Cookie;
use Digest::MD5;
use JSON;
use LWP::UserAgent;
use Storable qw(lock_store lock_retrieve);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);

# 実行時間の計測開始 (デバッグ用)
# sys.top.plのSetMenuList関数でコメントアウトを解除すると管理画面からログが閲覧できます
use Time::HiRes qw(gettimeofday tv_interval);
my ($exit, $debug_log, $debug_bbs);

# BBSCGI実行
eval 'require FCGI;'; 
if (! $@) {
	# FastCGIモード
	my $request = FCGI::Request();
	my $count = 0;
	while($request->Accept() >= 0){
		my $start_time = [gettimeofday];
		($exit, $debug_log, $debug_bbs) = BBSCGI();
		# ログに保存 (デバッグ用)
		CGIExecutionTime($start_time, $debug_log, $debug_bbs.":$count", 100);
		$count++;
		$request->Finish();
	}
} else {
	# 通常
	my $start_time = [gettimeofday];
	($exit, $debug_log, $debug_bbs) = BBSCGI();
	# ログに保存 (デバッグ用)
	CGIExecutionTime($start_time, $debug_log, $debug_bbs, 100);
}

# CGIの実行結果を終了コードとする
exit($exit);

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgiメイン
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	エラー番号
#
#------------------------------------------------------------------------------------------------------------
sub BBSCGI
{
	require './module/constant.pl';
	
	require './module/buffer_output.pl';
	my $Page = BUFFER_OUTPUT->new;
	
	my $CGI = {};
	my $err = $ZP::E_SUCCESS;
	my $log = $ZP::E_SUCCESS;
	
	$err = Initialize($CGI, $Page);
	# 初期化に成功したら書き込み処理を開始
	if ($err == $ZP::E_SUCCESS) {
		my $Sys = $CGI->{'SYS'};
		my $Form = $CGI->{'FORM'};
		my $Set = $CGI->{'SET'};
		my $Conv = $CGI->{'CONV'};
		my $Threads = $CGI->{'THREADS'};
		
		require './module/post_service.pl';
		my $WriteAid = POST_SERVICE->new;
		$WriteAid->Init($Sys, $Form, $Set, $Threads, $Conv);
		
		$err = $WriteAid->Write();
		# 書き込みに成功したら掲示板構成要素を更新する
		if ($err == $ZP::E_SUCCESS) {
			if (1){		#(!$Sys->Equal('FASTMODE', 1)) {
				require './module/bbs_service.pl';
				my $BBSAid = BBS_SERVICE->new;
				
				$BBSAid->Init($Sys, $Set);
				$BBSAid->CreateIndex();
				$BBSAid->CreateSubback();
			}
			PrintBBSJump($CGI, $Page);
		}
		else {
			$Threads->Close();
			# Captcha認証画面表示
			if ($err == $ZP::E_PAGE_CAPTCHA) {
				PrintBBSCaptcha($CGI, $Page);
				$log = $err;
				$err = $ZP::E_SUCCESS;
			}else{
				#SaveErrorInfo($Sys, $Set, $err);
				PrintBBSError($CGI, $Page, $err);
				$log = $err;
			}
		}
	}
	else {
		# cookie確認画面表示
		if ($err == $ZP::E_PAGE_COOKIE) {
			PrintBBSCookieConfirm($CGI, $Page);
			$log = $err;
			$err = $ZP::E_SUCCESS;
		}
		# エラー画面表示
		else {
			PrintBBSError($CGI, $Page, $err);
			$log = $err;
		}
	}
	
	# 結果の表示
	$Page->Flush('', 0, 0);
	
	return $err,$log,$CGI->{'SYS'}->Get('BBS');
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgi初期化
#	-------------------------------------------------------------------------------------
#	@param	$CGI
#	@param	$Page
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Initialize
{
	my ($CGI, $Page) = @_;
	
	# 使用モジュールの初期化
	require './module/system.pl';
	require './module/setting.pl';
	require './module/cookie.pl';
	require './module/data_utils.pl';
	require './module/form.pl';
	require './module/thread.pl';
	
	my $Sys = SYSTEM->new;
	my $Conv = DATA_UTILS->new;
	my $Set = SETTING->new;
	my $Cookie = COOKIE->new;
	my $Threads = THREAD->new;
	
	# システム情報設定
	return $ZP::E_SYSTEM_ERROR if ($Sys->Init());
	
	my $Form = FORM->new($Sys->Get('BBSGET'));
	
	%$CGI = (
		'SYS'		=> $Sys,
		'SET'		=> $Set,
		'COOKIE'	=> $Cookie,
		'CONV'		=> $Conv,
		'PAGE'		=> $Page,
		'FORM'		=> $Form,
		'THREADS'	=> $Threads,
	);
	
	# 夢が広がりんぐ
	$Sys->Set('MainCGI', $CGI);
	
	# form情報設定
	$Form->DecodeForm(1);
	
	# ホスト情報設定(DNS逆引き)
	#変数初期化チェックを挿入。
	#IPアドレスの設定とリモホ逆引き用
	$ENV{'REMOTE_ADDR'} = $ENV{'HTTP_CF_CONNECTING_IP'} if $ENV{'HTTP_CF_CONNECTING_IP'};
	if(!defined $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_HOST'} eq '') {
		$ENV{'REMOTE_HOST'} = $Conv->reverse_lookup($ENV{'REMOTE_ADDR'});
	}
	if($ENV{'REMOTE_ADDR'} =~ /:/){
		$ENV{'REMOTE_ADDR'} = $Conv->expand_ipv6($ENV{'REMOTE_ADDR'});
	}
	$Form->Set('HOST', $ENV{'REMOTE_HOST'});
	
	my $client = $Conv->GetClient();
	
	$Sys->Set('ENCODE', 'Shift_JIS');
	$Sys->Set('BBS', $Form->Get('bbs', ''));
	$Sys->Set('KEY', $Form->Get('key', ''));
	$Sys->Set('CLIENT', $client);
	$Sys->Set('AGENT', $Conv->GetAgentMode($client));
	$Sys->Set('KOYUU', $ENV{'REMOTE_HOST'});
	$Sys->Set('BBSPATH_ABS', $Conv->MakePath($Sys->Get('CGIPATH'), $Sys->Get('BBSPATH')));
	$Sys->Set('BBS_ABS', $Conv->MakePath($Sys->Get('BBSPATH_ABS'), $Sys->Get('BBS')));
	$Sys->Set('BBS_REL', $Conv->MakePath($Sys->Get('BBSPATH'), $Sys->Get('BBS')));
	
	# 携帯の場合は機種情報を設定
	if ($client & $ZP::C_MOBILE_IDGET) {
		my $product = $Conv->GetProductInfo($client);
		
		if (!defined $product) {
			return $ZP::E_POST_NOPRODUCT;
		}
		
		$Sys->Set('KOYUU', $product);
	}
	
	# SETTING.TXTの読み込み
	if (!$Set->Load($Sys)) {
		return $ZP::E_POST_NOTEXISTBBS;
	}
	
	my $submax = $Set->Get('BBS_SUBJECT_MAX') || $Sys->Get('SUBMAX');
	$Sys->Set('SUBMAX', $submax);
	my $resmax = $Set->Get('BBS_RES_MAX') || $Sys->Get('RESMAX');
	$Sys->Set('RESMAX', $resmax);
	
	# form情報にkeyが存在したらレス書き込み
	if ($Form->IsExist('key'))	{ $Sys->Set('MODE', 2);}
	else						{ $Sys->Set('MODE', 1);}
	
	# スレッド作成モードでMESSAGEが無い：スレッド作成画面
	# 廃止
	if ($Sys->Equal('MODE', 1)) {
		$Form->Set('key', int(time));
		$Sys->Set('KEY', $Form->Get('key'));
	}

	# cookieの存在チェック(PCのみ)
	if ($client & $ZP::C_PC) {
		if ($Set->Equal('SUBBBS_CGI_ON', 1)) {
			# 環境変数取得失敗
			if (!$Cookie->Init()) {
				return $ZP::E_PAGE_COOKIE;
			}
			
			# 名前欄cookie
			if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked') && !$Cookie->IsExist('NAME')) {
				return $ZP::E_PAGE_COOKIE;
			}
			# メール欄（コマンド欄）cookie
			if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked') && !$Cookie->IsExist('MAIL')) {
				return $ZP::E_PAGE_COOKIE;
			}
		}
	}

	#セッションID設定
	$Sys->Set('SID', undef);
	my $err = LoadSessionID($Sys, $Cookie, $Conv);
	return $err if $err;

	# subjectの読み込み
	$Threads->Load($Sys);
	
	return $ZP::E_SUCCESS;
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgiクッキー確認ページ表示
#	-------------------------------------------------------------------------------------
#	@param	$CGI	
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSCookieConfirm
{
	my ($CGI, $Page) = @_;
	
	my $Sys = $CGI->{'SYS'};
	my $Form = $CGI->{'FORM'};
	my $Set = $CGI->{'SET'};
	my $Cookie = $CGI->{'COOKIE'};
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;
		return $_;
	};
	my $code = $Sys->Get('ENCODE');
	my $bbs = &$sanitize($Form->Get('bbs'));
	my $tm = int(time);
	my $name = &$sanitize($Form->Get('FROM'));
	my $mail = &$sanitize($Form->Get('mail'));
	my $msg = &$sanitize($Form->Get('MESSAGE'));
	my $subject = &$sanitize($Form->Get('subject'));
	my $key = &$sanitize($Form->Get('key'));
	
	
	# cookie情報の出力
	$Cookie->Set('countsession', $Sys->Get('SID'));
	$Cookie->Set('securitykey', $Sys->Get('SEC'));
	$Cookie->Set('NAME', $name, 'utf8')	if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked'));
	$Cookie->Set('MAIL', $mail, 'utf8')	if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked'));
	$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
	
	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<!-- 2ch_X:cookie -->
<head>

 <meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
 <meta name="viewport" content="width=device-width,initial-scale=1.0">

 <title>■ 書き込み確認 ■</title>

</head>
<!--nobanner-->
HTML
	
	# <body>タグ出力
	{
		my @work;
		$work[0] = $Set->Get('BBS_THREAD_COLOR');
		$work[1] = $Set->Get('BBS_TEXT_COLOR');
		$work[2] = $Set->Get('BBS_LINK_COLOR');
		$work[3] = $Set->Get('BBS_ALINK_COLOR');
		$work[4] = $Set->Get('BBS_VLINK_COLOR');
		
		$Page->Print("<body bgcolor=\"$work[0]\" text=\"$work[1]\" link=\"$work[2]\" ");
		$Page->Print("alink=\"$work[3]\" vlink=\"$work[4]\">\n");
	}
	
	$Page->Print(<<HTML);
<font size="4" color="#FF0000"><b>書きこみ＆クッキー確認</b></font>
<blockquote style="margin-top:4em;">
 名前： $name<br>
 E-mail： $mail<br>
 内容：<br>
 $msg<br>
</blockquote>

<div style="font-weight:bold;">
投稿確認<br>
・投稿者は、投稿に関して発生する責任が全て投稿者に帰すことを承諾します。<br>
・投稿者は、話題と無関係な広告の投稿に関して、相応の費用を支払うことを承諾します<br>
・投稿者は、投稿された内容について、掲示板運営者がコピー、保存、引用、転載等の利用することを許諾します。<br>
　また、掲示板運営者に対して、著作者人格権を一切行使しないことを承諾します。<br>
・投稿者は、掲示板運営者が指定する第三者に対して、著作物の利用許諾を一切しないことを承諾します。<br>
</div>

<form method="POST" action="./bbs.cgi">
HTML
	
	$msg =~ s/<br>/\n/g;
	
	$Page->HTMLInput('hidden', 'subject', $subject);
	$Page->HTMLInput('hidden', 'FROM', $name);
	$Page->HTMLInput('hidden', 'mail', $mail);
	$Page->HTMLInput('hidden', 'MESSAGE', $msg);
	$Page->HTMLInput('hidden', 'bbs', $bbs);
	$Page->HTMLInput('hidden', 'time', $tm);

	if($Sys->Get('CAPTCHA')){
		my $capkind = $Sys->Get('CAPTCHA').'-response';
		my $captcha = $Form->Get($capkind);
		$Page->HTMLInput('hidden', $capkind, $captcha);
	}
	
	# レス書き込みモードの場合はkeyを設定する
	if ($Sys->Equal('MODE', 2)) {
		$Page->HTMLInput('hidden', 'key', $key);
	}
	
	$Page->Print(<<HTML);
<input type="submit" value="上記全てを承諾して書き込む"><br>
</form>

<p>
変更する場合は戻るボタンで戻って書き直して下さい。<br>
この画面が繰り返し表示される場合、一度ブラウザのCookieを削除してから再度投稿してください。
</p>

<p>
現在、荒らし対策でクッキーを設定していないと書きこみできないようにしています。<br>
<font size="2">(cookieを設定するとこの画面はでなくなります。)</font><br>
</p>

</body>
</html>
HTML
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgi Captcha認証ページ表示
#	-------------------------------------------------------------------------------------
#	@param	$CGI	
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSCaptcha
{
	my ($CGI, $Page) = @_;
	
	my $Sys = $CGI->{'SYS'};
	my $Form = $CGI->{'FORM'};
	my $Set = $CGI->{'SET'};
	my $Cookie = $CGI->{'COOKIE'};
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;
		return $_;
	};
	my $code = $Sys->Get('ENCODE');
	my $bbs = &$sanitize($Form->Get('bbs'));
	my $tm = int(time);
	my $name = &$sanitize($Form->Get('FROM'));
	my $mail = &$sanitize($Form->Get('mail'));
	my $msg = &$sanitize($Form->Get('MESSAGE'));
	my $subject = &$sanitize($Form->Get('subject'));
	my $key = &$sanitize($Form->Get('key'));
	
	# cookie情報の出力
	$Cookie->Set('countsession', $Sys->Get('SID'));
	$Cookie->Set('securitykey', $Sys->Get('SEC'));
	$Cookie->Set('NAME', $name, 'utf8')	if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked'));
	$Cookie->Set('MAIL', $mail, 'utf8')	if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked'));
	$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
	
	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<!-- 2ch_X:cookie -->
<head>

 <meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
 <meta name="viewport" content="width=device-width,initial-scale=1.0">

 <title>■ Captcha認証 ■</title>
HTML
	my $sitekey = $Sys->Get('CAPTCHA_SITEKEY');
	my $classname = $Sys->Get('CAPTCHA');

	$Page->Print('<script src="https://js.hcaptcha.com/1/api.js" async defer></script>') if ($classname eq 'h-captcha');
	$Page->Print('<script src="https://www.google.com/recaptcha/api.js" async defer></script>') if ($classname eq 'g-recaptcha');
	$Page->Print('<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>') if ($classname eq 'cf-turnstile');
	
	$Page->Print("</head>\n<!--nobanner-->\n");
	
	# <body>タグ出力
	{
		my @work;
		$work[0] = $Set->Get('BBS_THREAD_COLOR');
		$work[1] = $Set->Get('BBS_TEXT_COLOR');
		$work[2] = $Set->Get('BBS_LINK_COLOR');
		$work[3] = $Set->Get('BBS_ALINK_COLOR');
		$work[4] = $Set->Get('BBS_VLINK_COLOR');
		
		$Page->Print("<body bgcolor=\"$work[0]\" text=\"$work[1]\" link=\"$work[2]\" ");
		$Page->Print("alink=\"$work[3]\" vlink=\"$work[4]\">\n");
	}
	
	$Page->Print(<<HTML);
<font size="4" color="#FF0000"><b>Captcha認証</b></font>
<br>

<p>書き込むにはキャプチャを解いてください。</p>
<form method="POST" action="./bbs.cgi">
HTML
	
	$Page->HTMLInput('hidden', 'subject', $subject);
	$Page->HTMLInput('hidden', 'FROM', $name);
	$Page->HTMLInput('hidden', 'mail', $mail);
	$Page->HTMLInput('hidden', 'MESSAGE', $msg);
	$Page->HTMLInput('hidden', 'bbs', $bbs);
	$Page->HTMLInput('hidden', 'time', $tm);
	$Page->HTMLInput('hidden', 'page', 'captcha');
	$Page->HTMLInput('hidden', $classname.'-response', $Form->Get($classname.'-response'));

	if ($Sys->Equal('MODE', 2)) {
		$Page->HTMLInput('hidden', 'key', $key);
	}

	$Page->Print(<<HTML);
<div class="$classname" data-sitekey="$sitekey"></div><br>
<input type="submit" value="　認証する　"><br>
</form>
<br>
HTML
	if($Set->Get('BBS_CAPTCHA') eq 'checked'){
	$Page->Print(<<HTML);
<div style="font-weight:bold;">
専用ブラウザから投稿する場合</div><br>
・ユーザー認証が必要です。<br>
・一度通常ブラウザから、コマンド欄に<br>
!auth<br>
と入れて書込みをし、Captcha認証をしてください。ワンタイムパスワードを発行します。<br>

HTML
	}elsif($Set->Get('BBS_CAPTCHA') eq 'force'){
	$Page->Print(<<HTML);
<div style="font-weight:bold;">
専用ブラウザからは投稿出来ません。<br>
通常のブラウザを使ってください。<br>
</div>
HTML
	}
	$Page->Print("<p>現在、荒らし対策でCaptchaをクリアしないと書きこみできないようにしています。</p>");
	$Page->Print("<p><font size=\"2\">(ユーザー認証をすればこの画面は出なくなります。)</font></p>") if $Set->Get('BBS_CAPTCHA') ne 'force';

	$Page->Print("</body></html>");
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgiジャンプページ表示
#	-------------------------------------------------------------------------------------
#	@param	$CGI
#	@param	$Page
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSJump
{
	my ($CGI, $Page) = @_;
	
	my $Sys = $CGI->{'SYS'};
	my $Form = $CGI->{'FORM'};
	my $Set = $CGI->{'SET'};
	my $Conv = $CGI->{'CONV'};
	my $Cookie = $CGI->{'COOKIE'};
	
	my $bbsPath = $Conv->MakePath($Sys->Get('CGIPATH').'/read.cgi/'.$Form->Get('bbs').'/'.$Form->Get('key').'/l10');
	my $name = $Form->Get('NAME', '');
	my $mail = $Form->Get('MAIL', '');
	my $sid = $Sys->Get('SID');
		
	# セキュリティキー生成
	my $ctx = Digest::MD5->new;
	$ctx->add($Sys->Get('SECURITY_KEY'));
	$ctx->add(':', $sid);
	my $sec = $ctx->b64digest;
	$Cookie->Set('countsession', $sid);
	$Cookie->Set('securitykey', $sec);
	$Cookie->Set('NAME', $name, 'utf8')	if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked'));
	$Cookie->Set('MAIL', $mail, 'utf8')	if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked') && $mail !~ /((!auth)|(^success$))/);
	$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
		
	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<html>
<head>
	<title>書きこみました。</title>
<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
<meta http-equiv="Refresh" content="5;URL=$bbsPath#bottom">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
</head>
<!--nobanner-->
<body>
書きこみが終わりました。<br>
<br>
画面を切り替えるまでしばらくお待ち下さい。<br>
<br>
<br>
<br>
<br>
<hr>
HTML
	

	# 告知欄表示(表示させたくない場合はコメントアウトか条件を0に)
	if ($Sys->Get('BANNER')) {
		require './module/banner.pl';
		my $Banner = BANNER->new;
		$Banner->Load($Sys);
		$Banner->Print($Page, 100, 0, $Sys->Get('AGENT'));
	}
	$Page->Print("\n</body>\n</html>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgiエラーページ表示
#	-------------------------------------------------------------------------------------
#	@param	$CGI
#	@param	$Page
#	@param	$err
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSError
{
	my ($CGI, $Page, $err) = @_;
	
	require './module/error_info.pl';
	my $Error = ERROR_INFO->new;
	$Error->Load($CGI->{'SYS'});
	
	$Error->Print($CGI, $Page, $err, $CGI->{'SYS'}->Get('AGENT'));
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgi実行時間ログ	(デバッグ用)
#	-------------------------------------------------------------------------------------
#	@param	$start_time		計測開始時間
#	@param	$logMax			最大ログ数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub CGIExecutionTime
{
	my ($start_time, $log, $bbs, $logMax) = @_;

	# 実行時間の計測終了
	my $elapsed = tv_interval($start_time);
	my $time = time;

	# ログファイルに追記
	my $log_file = './info/execution_time.cgi';
	open my $fh, '>>', $log_file or die "Cannot open log file: $!";
	print $fh "$time<>$elapsed<>$bbs<>$log\n";
	close $fh;

	# ファイルパーミッションの設定
	chmod 0600, $log_file;

	# ログファイルを読み込んで行数を確認
	open $fh, '<', $log_file or die "Cannot open log file: $!";
	my @lines = <$fh>;
	close $fh;

	# 行数が100行を超えている場合、超過分を削除
	if (scalar @lines > $logMax) {
		@lines = @lines[-$logMax..-1];  # 最後の100行だけを保持
	}

	# ファイルに内容を書き戻す
	open my $fh_out, '>', $log_file or die "Cannot open file: $!";
	print $fh_out @lines;
	close $fh_out;

}

# エラー情報を忍法帖に保存
sub SaveErrorInfo{
	my ($Sys, $Set, $err) = @_;
	return unless $Set->Get('BBS_NINJA');

	require './module/ninja.pl';
	my $Ninja = NINPOCHO->new;
	$Ninja->LoadOnly($Sys,$Sys->Get('SID'));

	# 短時間に特定のエラーが集中した場合
	my $last_etime = $Ninja->Get('last_err_time') || time;
	my $err_count = $Ninja->Get('error_count') || 0;
	my $limit_count = $Set->Get('NINJA_ERR_COUNT');
	my $limit_time = $Set->Get('NINJA_ERR_TIME') * 60;
	my $ban_period = $Set->Get('NINJA_BAN_PERIOD') * 60;

	if($err = $ZP::E_FORM_NOCAPTCHA||$ZP::E_FORM_FAILEDCAPTCHA||$ZP::E_FORM_FAILEDAUTH
	||$ZP::E_REG_NGWORD||$ZP::E_REG_NGUSER||$ZP::E_REG_SPAMKILL||$ZP::E_REG_BAN||$ZP::E_REG_NINLVLIMIT){
		if (int(time / $limit_time) == int($last_etime / $limit_time)) {
			$err_count++;
		} else {
			$err_count = 1;
		}
	}
	if($err_count >= $limit_count){
		$Ninja->Set('time_ban',$ban_period);
	}

}

# SessionIDの取得
sub LoadSessionID
{
	my ($Sys, $Cookie, $Conv) = @_;
	require './module/ninpocho.pl';

	my $sid = $Cookie->Get('countsession');
	my $sec = $Cookie->Get('securitykey');
	my %cookies = fetch CGI::Cookie;
	if (!$sid && exists $cookies{'countsession'}) {
		$sid = $cookies{'countsession'}->value;
		$sid =~ s/"//g;
	}
	if (!$sec && exists $cookies{'securitykey'}) {
		$sec = $cookies{'securitykey'}->value;
		$sec =~ s/"//g;
	}

	#改竄をチェック
	my $ctx = Digest::MD5->new;
	$ctx->add(':', $Sys->Get('SERVER'));
	$ctx->add(':', $ENV{'REMOTE_ADDR'});
	my $infoDir = $Sys->Get('INFO');
	my $ipHash = $ctx->hexdigest;
	my $ipFile = ".$infoDir/.ninpocho/hash/ip-$ipHash.cgi";

	my $fileExpiry = 60 * 60 * 24;
	
	if($sid =~ /^[0-9a-fA-F]{32}$/ && $sec){
		my $ctx = Digest::MD5->new;
		$ctx->add($Sys->Get('SECURITY_KEY'));
		$ctx->add(':', $sid);
		
		if ($ctx->b64digest ne $sec){
			#一致しなかったら改竄されている
			return $ZP::E_PAGE_COOKIE;
		}
	}
	
	if($Conv->IsJPIP($Sys)){
		# JPIPに紐付けられているかチェック
		if(-e $ipFile && time - (stat($ipFile))[9] < $fileExpiry){
			my $sid_loaded = lock_retrieve($ipFile);
			my $crtime = $sid_loaded->{'crtime'};
			$sid = $sid_loaded->{'sid'} unless $sid;
			lock_store({'sid'=> $sid,'crtime'=> $crtime},$ipFile);
			chmod 0600,$ipFile;
		}elsif($sid){
			lock_store({'sid'=> $sid,'crtime'=> time},$ipFile);
			chmod 0600,$ipFile;
		}
	}
	if(!$sid){
		# 新規ID発行
		$sid = Digest::MD5->new()->add($$,time(),rand(time))->hexdigest();
	}

	my $ctx_sec = Digest::MD5->new;
	$ctx_sec->add($Sys->Get('SECURITY_KEY'));
	$ctx_sec->add(':', $sid);
	$Sys->Set('SEC',$ctx_sec->b64digest);
	$Sys->Set('SID',$sid);

	return $ZP::E_SUCCESS;

}
