#============================================================================================================
#
#	エラー情報管理モジュール
#
#============================================================================================================
package	ERROR_INFO;

use strict;
#use warnings;

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
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'ERR'} = undef;
	
	my $path = '.' . $Sys->Get('INFO') . '/errmsg.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '' || $_ =~ /^#/);
			
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 3) {
				warn "invalid line in $path";
				next;
			}
			
			my $id = $elem[0];
			$this->{'SUBJECT'}->{$id} = $elem[1];
			$this->{'MESSAGE'}->{$id} = $elem[2];
		}
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
#			$Page : BUFFER
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
		$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * 30);
		
		$Page->Print("Content-type: text/html\n\n");
		
		if ($err < $ZP::E_REG_SAMBA_CAUTION || $err > $ZP::E_REG_SAMBA_STILL) {
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
<div style="margin-bottom:2em;">
<font size="+1" color="#FF0000"><b>ＥＲＲＯＲ：$message</b></font>
</div>

<blockquote>
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
