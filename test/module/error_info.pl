#============================================================================================================
#
#	エラー情報管理モジュール
#
#============================================================================================================
package	ERROR_INFO;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use Digest::MD5;

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	
	my $obj = {
		'SUBJECT'	=> undef,
		'MESSAGE'	=> undef,
		'ERR'		=> undef,
	};
	bless $obj, $this;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	エラー情報読み込み - Load
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Load {
    my $this = shift;

    $this->{'ERR'} = undef;

    my $messages = {
		'100' => { SUBJECT => 'サブジェクト長すぎ', MESSAGE => 'サブジェクトが長すぎます！' },
		'101' => { SUBJECT => '名前長すぎ', MESSAGE => '名前が長すぎます！' },
		'102' => { SUBJECT => 'メール長すぎ', MESSAGE => 'メールアドレスが長すぎます！' },
		'103' => { SUBJECT => '本文長すぎ', MESSAGE => '本文が長すぎます！' },
		'104' => { SUBJECT => '1行長すぎ', MESSAGE => '長すぎる行があります！' },
		'105' => { SUBJECT => '改行多すぎ', MESSAGE => '改行が多すぎます！' },
		'106' => { SUBJECT => 'アンカー多すぎ', MESSAGE => 'レスアンカーリンクが多すぎます！' },
		'150' => { SUBJECT => 'タイトルが無い', MESSAGE => 'サブジェクトが存在しません！' },
		'151' => { SUBJECT => '本文が無い', MESSAGE => '本文がありません！' },
		'152' => { SUBJECT => '名前が無い', MESSAGE => '名前いれてちょ。' },
		'153' => { SUBJECT => '認証されてない', MESSAGE => 'Captcha認証をしてください。<br>専ブラからの場合は、通常ブラウザで書き込みしてください。' },
		'154' => { SUBJECT => '認証失敗', MESSAGE => 'Captcha認証に失敗しました。' },
		'200' => { SUBJECT => 'スレッド停止', MESSAGE => 'このスレッドは停止されてます。もう書けない。。。' },
		'201' => { SUBJECT => '書き込み限界', MESSAGE => '{!RESMAX!}を超えてます。このスレッドにはもう書けない。。。' },
		'202' => { SUBJECT => 'スレッド移転', MESSAGE => 'このスレッドは移転されたようです。詳しくは（略' },
		'203' => { SUBJECT => '読取専用', MESSAGE => '現在この掲示板は読取専用です。ここは待つしかない。。。' },
		'204' => { SUBJECT => 'スレッド規制', MESSAGE => '携帯からのスレッド作成はキャップのみ可能です。<br>PCから試してみてください。' },
		'205' => { SUBJECT => 'CGI禁止', MESSAGE => '現在この掲示板ではCGIの使用が禁止されてます<br>indexだけでお楽しみください。' },
		'206' => { SUBJECT => 'サイズオーバー', MESSAGE => 'datファイルのサイズが限界を超えました。新しいスレッドを作成してください。' },
		'207' => { SUBJECT => '海外串', MESSAGE => 'JPドメイン以外からのスレッド作成を規制しています。' },
		'208' => { SUBJECT => '逆引き不可', MESSAGE => '逆引き出来ないIPからの投稿を規制しています。' },
		'500' => { SUBJECT => 'スレッド立てすぎ', MESSAGE => 'スレッド立てすぎです。もうちょいもちついてください。' },
		'501' => { SUBJECT => '連続投稿', MESSAGE => '連続投稿ですか？？' },
		'502' => { SUBJECT => '二重かきこ', MESSAGE => '二重かきこですか？？' },
		'503' => { SUBJECT => 'もまいらもちつけ。', MESSAGE => 'もうちょっと落ち着いて書きこみしてください。{!WAIT!}秒ぐらい。' },
		'504' => { SUBJECT => 'スレッド規制', MESSAGE => '現在この板のスレッド作成はキャップのみ可能です。<br>管理人に相談してください。。。' },
		'505' => { SUBJECT => 'Samba規制1', MESSAGE => '{!SAMBATIME!} sec たたないと書けません。({!SAMBA!}回目、{!WAIT!} sec しかたってない)<br>\n<br>\n今のところ、キャップ以外に回避する方法はありません。\n' },
		'506' => { SUBJECT => 'Samba規制2', MESSAGE => '連打しないでください。もうそろそろ規制リストに入れますよ。。(￣ー￣)ニヤリッ<br>\n<br>\n\n' },
		'507' => { SUBJECT => 'Samba規制3', MESSAGE => 'もうずっと書けませんよ。<br>\n<br>\nあなたは、規制リストに追加されました。<br><br>\n【解除する方法】<br>\n{!WAIT!}分以上初心者の方々を優しく導いてあげてください。<br>\nこれ以外に解除の方法はありません。<br>\n' },
		'508' => { SUBJECT => 'Samba規制中', MESSAGE => 'まだ書けませんよ。<br><br>　　　　あなたは、規制リストに追加されています。 <br><br>　　　　【解除する方法】<br>　　　　{!WAIT!}分以上初心者の方々を優しく導いてあげてください。<br>　　　　これ以外に解除の方法はありません。<br>----------' },
		'600' => { SUBJECT => 'NGワード', MESSAGE => 'NGワードが含まれてます。抜かないと書き込みできません。' },
		'601' => { SUBJECT => '規制ユーザ', MESSAGE => 'アクセス規制中です！！({!HITS!})' },
		'602' => { SUBJECT => 'SPAMブロック', MESSAGE => 'スパム行為は禁止！！' },
		'603' => { SUBJECT => 'スレタイ重複', MESSAGE => 'スレタイ被ってますよ。' },
		'700' => { SUBJECT => 'BAN', MESSAGE => 'あなたはBANされています。' },
		'701' => { SUBJECT => 'レベル制限', MESSAGE => 'あなたの忍法帖レベルでは書き込めません。' },
		'890' => { SUBJECT => '情報取得失敗', MESSAGE => 'BEユーザー情報の取得に失敗しました。' },
		'891' => { SUBJECT => '接続失敗', MESSAGE => 'be.2ch.netに接続できませんでした。({!CODE!})' },
		'892' => { SUBJECT => 'BEログイン失敗', MESSAGE => 'BEログインに失敗しました。({!CHK!})' },
		'893' => { SUBJECT => 'BEログイン必須', MESSAGE => '<a href="http://be.2ch.net/">be.2ch.net</a>でログインしてないと書けません。' },
		'894' => { SUBJECT => 'BE_TYPE2規制', MESSAGE => 'Beログインしてください(t)。<a href="http://be.2ch.net/">be.2ch.net</a>' },
		'900' => { SUBJECT => 'スレッド指定が変です', MESSAGE => 'スレッドキーに数字以外がありそうです。<br>もう一度よく確かめてちょ。' },
		'901' => { SUBJECT => 'スレッド指定が変です', MESSAGE => 'スレッドキーの数がおかしいですよん。<br>もう一度よく確かめてちょ。' },
		'902' => { SUBJECT => 'スレッド指定が変です', MESSAGE => '書き込もうとしているスレッドは存在しないか、削除されています。。。' },
		'950' => { SUBJECT => '端末固有情報不明', MESSAGE => '端末固有情報を送信してください。' },
		'997' => { SUBJECT => 'ＰＲＯＸＹ規制', MESSAGE => '公開ＰＲＯＸＹからの投稿は受け付けていません！！' },
		'998' => { SUBJECT => 'ブラウザ変ですよん', MESSAGE => 'アクセス不正です。このCGIは外部からのアクセスは認めてないです。。' },
		'999' => { SUBJECT => 'ブラウザ変ですよん', MESSAGE => 'フォーム情報が正しく読めないです。' },
		'990' => { SUBJECT => 'システムエラー', MESSAGE => 'システムが変です。サポートで聞いたほうがいいかも。。' },
		'991' => { SUBJECT => 'システムエラー', MESSAGE => 'Captchaの設定が変です。管理者に連絡してくらはい。。' }
    };

    # メッセージデータをオブジェクトに格納
    foreach my $id (keys %{$messages}) {
		$this->{'SUBJECT'}->{$id} = $messages->{$id}->{SUBJECT};
		$this->{'MESSAGE'}->{$id} = $messages->{$id}->{MESSAGE};
    }
}


#------------------------------------------------------------------------------------------------------------
#
#	エラー情報取得 - Get
#	-------------------------------------------
#	引　数：$err  : エラー番号
#			$kind : 種類
#	戻り値：エラー情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($err, $kind) = @_;
	
	my $val = $this->{$kind}->{$err};
	
	return $val;
}

#------------------------------------------------------------------------------------------------------------
#
#	エラーページ出力 - PrintBBS
#	-------------------------------------------
#	引　数：$CGI  : 
#			$Page : BUFFER_OUTPUT
#			$err  : エラー番号
#			$mode : エージェント
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Print
{
	my $this = shift;
	my ($CGI, $Page, $err, $mode) = @_;
	
	my $Form = $CGI->{'FORM'};
	my $Sys = $CGI->{'SYS'};
	my $Set = $CGI->{'SET'};
	my $version = $Sys->Get('VERSION');
	my $bbsPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	my $message = $this->{'MESSAGE'}->{$err};
	
	# エラーメッセージの置換
	my $sanitize = sub {
		#$_[0] =~ s/&/&amp;/g;
		$_[0] =~ s/</&lt;/g;
		$_[0] =~ s/>/&gt;/g;
		return $_[0];
	};
	$message =~ s/\\n/\n/g;
	$message =~ s/{!(.*?)!}/&$sanitize($Sys->Get($1, ''))/ge;
	
	# リモートホストの取得
	my $koyuu = $Sys->Get('KOYUU');
	$mode = '0' if (! defined $mode);
	$mode = 'O' if ($Form->Equal('mb', 'on'));
	
	# エラーログを保存
	require './module/manager_log.pl';
	my $Log = MANAGER_LOG->new;
	$Log->Load($Sys, 'ERR', '');
	$Log->Set('', $err, $version, $koyuu, $mode);
	$Log->Save($Sys);
    
    my $name = &$sanitize($Form->Get('NAME'));
	my $mail = &$sanitize($Form->Get('MAIL'));
    my $key = $Form->Get('key');
    my $t = &$sanitize($Form->Get('subject',''));
	my $msg = $Form->Get('MESSAGE');

	#超過対策
	if($Set->Get('BBS_MESSAGE_COUNT') < length($msg)){
		$msg = substr($msg,0,$Set->Get('BBS_MESSAGE_COUNT'));
		$msg .= ' ...(長すぎたので省略)';
	}
	if($Set->Get('BBS_NAME_COUNT') < length($name)){
		$name = substr($name,0,$Set->Get('BBS_NAME_COUNT'));
		$name .= ' ...(長すぎたので省略)';
	}
	if($Set->Get('BBS_MAIL_COUNT') < length($mail)){
		$mail = substr($mail,0,$Set->Get('BBS_MAIL_COUNT'));
		$mail .= ' ...(長すぎたので省略)';
	}
	if($Set->Get('BBS_SUBJECT_COUNT') < length($t) && $t){
		$t = substr($t,0,$Set->Get('BBS_SUBJECT_COUNT'));
		$t .= ' ...(長すぎたので省略)';
	}
	my $title = $t?"(New)$t":"$key";
	
	$Log->Load($Sys, 'FLR', '');
	$Log->Set('', $err,"$title<>$name<>$mail<>$msg", $koyuu, $mode);
	$Log->Save($Sys);
	
	#$Page->Print("Status: 412 Precondition Failed\n");
	
	if ($mode eq 'O') {
		my $subject = $this->{'SUBJECT'}->{$err};
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ＥＲＲＯＲ！</title></head><!--nobanner-->\n");
		$Page->Print("<body><font color=red>ERROR:$subject</font><hr>");
		$Page->Print("$message<hr><a href=\"$bbsPath/i/\">こちら</a>");
		$Page->Print("から戻ってください</body></html>");
	}
	else {
		my $Cookie = $CGI->{'COOKIE'};
		my $Set = $CGI->{'SET'};
		
		my $name = &$sanitize($Form->Get('NAME'));
		my $mail = &$sanitize($Form->Get('MAIL'));
		my $msg = $Form->Get('MESSAGE');
		
		# cookie情報の出力
		if ($Set->Equal('BBS_NAMECOOKIE_CHECK', 'checked')) {
			$Cookie->Set('NAME', $name, 'utf8');
		}
		if ($Set->Equal('BBS_MAILCOOKIE_CHECK', 'checked')) {
			$Cookie->Set('MAIL', $mail, 'utf8');
		}
		# セキュリティキー生成
		my $ctx = Digest::MD5->new;
		$ctx->add($Sys->Get('SECURITY_KEY'));
		$ctx->add(':', $Sys->Get('SID'));
		my $sec = $Sys->Get('SID') ? $ctx->b64digest : "";
		$Cookie->Set('countsession', $Sys->Get('SID'));
		$Cookie->Set('securitykey', $sec);
		$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * $Sys->Get('COOKIE_EXPIRY'));
		
		$Page->Print("Content-type: text/html\n\n");
		
		if ($err < $ZP::E_REG_SAMBA_CAUTION || $err > $ZP::E_REG_SAMBA_STILL) {
			$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>
 
 <meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
 <meta name="viewport" content="width=device-width,initial-scale=1.0">
 
 <title>ＥＲＲＯＲ！</title>
 
</head>
<!--nobanner-->
<body>
<!-- 2ch_X:error -->
<div style="margin-bottom:2em;">
<font size="+1" color="#FF0000"><b>ＥＲＲＯＲ：$message</b></font>
</div>

<blockquote><br><br>
ホスト<b>$koyuu</b><br>
<br>
名前： <b>$name</b><br>
E-mail： $mail<br>
内容：<br>
$msg
<br>
<br>
</blockquote>
<hr>
<div class="reload">こちらでリロードしてください。<a href="$bbsPath/">&nbsp;GO!</a></div>
<div align="right">$version</div>
</body>
</html>
HTML
		}
		else {
			my $sambaerr = {
				$ZP::E_REG_SAMBA_CAUTION	=> $ZP::E_REG_SAMBA_2CH1,
				$ZP::E_REG_SAMBA_WARNING	=> $ZP::E_REG_SAMBA_2CH2,
				$ZP::E_REG_SAMBA_LISTED		=> $ZP::E_REG_SAMBA_2CH3,
				$ZP::E_REG_SAMBA_STILL		=> $ZP::E_REG_SAMBA_2CH3,
			}->{$err};
			
			$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

	<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">

	<title>ＥＲＲＯＲ！</title>

</head>
<!--nobanner-->
<body>
<!-- 2ch_X:error -->

<div>
ＥＲＲＯＲ - $sambaerr $message
<br>
</div>

<hr>

<div>(Samba24-2.13互換)</div>

<div align="right">$version</div>

</body>
</html>
HTML
		}
		
	}
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
