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
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);


# CGIの実行結果を終了コードとする
exit(BBSCGI());

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
			PrintBBSError($CGI, $Page, $err);
		}
	}
	else {
		# スレッド作成画面表示
		if ($err == $ZP::E_PAGE_THREAD) {
			PrintBBSThreadCreate($CGI, $Page);
			$err = $ZP::E_SUCCESS;
		}
		# cookie確認画面表示
		elsif ($err == $ZP::E_PAGE_COOKIE) {
			PrintBBSCookieConfirm($CGI, $Page);
			$err = $ZP::E_SUCCESS;
		}
		# エラー画面表示
		else {
			PrintBBSError($CGI, $Page, $err);
		}
	}
	
	# 結果の表示
	$Page->Flush('', 0, 0);
	
	return $err;
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
	if ($Form->IsExist('key'))	{ $Sys->Set('MODE', 2); }
	else						{ $Sys->Set('MODE', 1); }
	
	# スレッド作成モードでMESSAGEが無い：スレッド作成画面
	if ($Sys->Equal('MODE', 1)) {
		if (!$Form->IsExist('MESSAGE')) {
			return $ZP::E_PAGE_THREAD;
		}
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
			# メール欄cookie
			if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked') && !$Cookie->IsExist('MAIL')) {
				return $ZP::E_PAGE_COOKIE;
			}
		}
	}

	#cookieからセッションID取得
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
	if($sid && $sec){
		my $ctx = Digest::MD5->new;
		$ctx->add($Sys->Get('SECURITY_KEY'));
		$ctx->add(':', $sid);
		
		if ($ctx->b64digest eq $sec){
			$Sys->Set('SID',$sid);
		}else{
			#一致しなかったら改竄されている
			return $ZP::E_PAGE_COOKIE;
		}
	}else{
		$Sys->Set('SID',undef);
	}

	# subjectの読み込み
	$Threads->Load($Sys);
	
	return $ZP::E_SUCCESS;
}

#------------------------------------------------------------------------------------------------------------
#
#	bbs.cgiスレッド作成ページ表示
#	-------------------------------------------------------------------------------------
#	@param	$CGI
#	@param	$Page
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSThreadCreate
{
	my ($CGI, $Page) = @_;
	
	my $Sys = $CGI->{'SYS'};
	my $Set = $CGI->{'SET'};
	my $Form = $CGI->{'FORM'};
	my $Cookie = $CGI->{'COOKIE'};
	
	require './module/header_footer_meta.pl';
	my $Caption = HEADER_FOOTER_META->new;
	$Caption->Load($Sys, 'META');
	
	my $title = $Set->Get('BBS_TITLE');
	my $link = $Set->Get('BBS_TITLE_LINK');
	my $image = $Set->Get('BBS_TITLE_PICTURE');
	my $code = $Sys->Get('ENCODE');
	my $cgipath = $Sys->Get('CGIPATH');
	
	# HTMLヘッダの出力
	$Page->Print("Content-type: text/html\n\n");
	$Page->Print("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n");
	$Page->Print("<html lang=\"ja\">\n");
	$Page->Print("<head>\n");
	$Page->Print(' <meta http-equiv="Content-Type" content="text/html;charset=Shift_JIS">'."\n\n");
	$Page->Print("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">"."\n");
	$Page->Print('<script type="text/javascript" src="https://code.jquery.com/jquery-2.1.4.min.js"></script>'."\n");
	$Caption->Print($Page, undef);
	$Page->Print(" <title>$title</title>\n\n");
	$Page->Print("<link rel=\"stylesheet\" type=\"text/css\" href=\"./datas/design.css\">\n");
	if($Set->Get('BBS_CAPTCHA')){
		$Page->Print('<script src="https://js.hcaptcha.com/1/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'h-captcha');
		$Page->Print('<script src="https://www.google.com/recaptcha/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'g-recaptcha');
		$Page->Print('<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'cf-turnstile');
	}
	$Page->Print("</head>\n<!--nobanner-->\n");
	
	# <body>タグ出力
	{
		my @work;
		$work[0] = $Set->Get('BBS_BG_COLOR');
		$work[1] = $Set->Get('BBS_TEXT_COLOR');
		$work[2] = $Set->Get('BBS_LINK_COLOR');
		$work[3] = $Set->Get('BBS_ALINK_COLOR');
		$work[4] = $Set->Get('BBS_VLINK_COLOR');
		$work[5] = $Set->Get('BBS_BG_PICTURE');
		
		$Page->Print("<body bgcolor=\"$work[0]\" text=\"$work[1]\" link=\"$work[2]\" ");
		$Page->Print("alink=\"$work[3]\" vlink=\"$work[4]\" ");
		$Page->Print("background=\"$work[5]\">\n");
	}

	$Page->Print("<div align=\"center\">");
	# 看板画像表示あり
	if ($image ne '') {
		# 看板画像からのリンクあり
		if ($link ne '') {
			$Page->Print("<a href=\"$link\"><img src=\"$image\" border=\"0\" alt=\"$image\"></a><br>");
		}
		# 看板画像にリンクはなし
		else {
			$Page->Print("<img src=\"$image\" border=\"0\"><br>");
		}
	}
	$Page->Print("</div>");

	# ヘッダテーブルの表示
	$Caption->Load($Sys, 'HEAD');
	$Caption->Print($Page, $Set);
	
	# スレッド作成フォームの表示
	{
		my $tblCol = $Set->Get('BBS_MAKETHREAD_COLOR');
		my $name = $Cookie->Get('NAME', '', 'utf8');
		my $mail = $Cookie->Get('MAIL', '', 'utf8');
		my $bbs = $Form->Get('bbs');
		my $tm = int(time);
		my $ver = $Sys->Get('VERSION');
		my $sitekey = $Sys->Get('CAPTCHA_SITEKEY');
		my $classname = $Sys->Get('CAPTCHA');
		my $Captcha = $Set->Get('BBS_CAPTCHA') ? "<div class=\"$classname\" data-sitekey=\"$sitekey\"></div>" : '';

		$Page->Print(<<HTML);
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$tblCol" align="center">
 <tr>
  <td>
  <b>スレッド新規作成</b><br>
  <center>
  <form method="POST" action="./bbs.cgi">
  <input type="hidden" name="bbs" value="$bbs"><input type="hidden" name="time" value="$tm">
  <table border="0">
   <tr>
    <td align="left">
    <div class ="reverse_order">
    <span class = "order2">タイトル：<input type="text" name="subject" size="25"></span>
    <span class = "order1"><input type="submit" value="新規スレッド作成">$Captcha</span>
    </div>
    名前：<input type="text" name="FROM" size="19" value="$name"><br class="smartphone">
    E-mail<font size="1">（省略可）</font>：<input type="text" name="mail" size="19" value="$mail"><br>
    <textarea rows="5" cols="64" name="MESSAGE" placeholder="投稿したい内容を入力してください（必須）"></textarea>
    </td>
   </tr>
  </table>
  </form>
  </center>
  </td>
 </tr>
</table>

<p>
$ver
</p>
HTML
	}


# CSS
$Page->Print(<<HTML);
<style>
/* スマホ用レイアウト */
img {
    max-width: 100%;
    height:auto;
}

textarea {
width:95%;
margin:0;
}
</style>
HTML

	$Page->Print("\n</body>\n</html>\n");
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
	$Cookie->Set('NAME', $name, 'utf8')	if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked'));
	$Cookie->Set('MAIL', $mail, 'utf8')	if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked'));
	$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
	
	$Page->Print("Content-type: text/html\n\n");
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
	
	# レス書き込みモードの場合はkeyを設定する
	if ($Sys->Equal('MODE', 2)) {
		$Page->HTMLInput('hidden', 'key', $key);
	}
	
	$Page->Print(<<HTML);
<input type="submit" value="上記全てを承諾して書き込む"><br>
</form>

<p>
変更する場合は戻るボタンで戻って書き直して下さい。
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
	
	my $bbsPath = $Conv->MakePath($Sys->Get('BBS_REL'));
	my $name = $Form->Get('NAME', '');
	my $mail = $Form->Get('MAIL', '');
		
	$Cookie->Set('NAME', $name, 'utf8')	if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked'));
	$Cookie->Set('MAIL', $mail, 'utf8')	if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked'));
	$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
		
	$Page->Print("Content-type: text/html\n\n");
	$Page->Print(<<HTML);
<html>
<head>
	<title>書きこみました。</title>
<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
<meta http-equiv="Refresh" content="5;URL=$bbsPath/">
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

