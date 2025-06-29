#!/usr/bin/perl
#============================================================================================================
#
#	規制一覧表示用CGI
#	madakana.cgi
#	---------------------------------------------------------------------------
#	2011.03.18 start
#	2011.03.31 remake
#
#============================================================================================================

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
no warnings 'once';

BEGIN { use lib './perllib'; }

# CGIの実行結果を終了コードとする
exit(MADAKANA());

#------------------------------------------------------------------------------------------------------------
#
#	madakana.cgiメイン
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub MADAKANA
{
	
	my ( %SYS, $Page, $err );
	
	require './module/buffer_output.pl';
	$Page = new BUFFER_OUTPUT;
	
	# 初期化に成功したら内容を表示
	if (($err = Initialize(\%SYS, $Page)) == 0) {
		
		# ヘッダ表示
		PrintMadaHead(\%SYS, $Page);
		
		# 内容表示
		PrintMadaCont(\%SYS, $Page);
		
		# フッタ表示
		PrintMadaFoot(\%SYS, $Page);
		
	}
	else {
		PrintMadaError(\%SYS, $Page, $err);
	}
	
	$Page->Flush(0, 0, '');
	
	return $err;
	
}

#------------------------------------------------------------------------------------------------------------
#
#	madakana.cgi初期化・前準備
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Initialize
{
	my ($pSYS, $Page) = @_;
	my (@elem, @regs, $path);
	my ($oSYS, $oCONV);
	
	require './module/system.pl';
	require './module/data_utils.pl';
	require './module/form.pl';
	
	$oSYS	= new SYSTEM;
	$oCONV	= new DATA_UTILS;
	
	%$pSYS = (
		'SYS'	=> $oSYS,
		'CONV'	=> $oCONV,
		'PAGE'	=> $Page,
		'CODE'	=> 'Shift_JIS',
	);
	
	$pSYS->{'FORM'} = FORM->new;
	
	# システム初期化
	$oSYS->Init();

	# 規制非公開
	return "Hidden data" if $oSYS->Get('HIDE_HITS');
	
	# 夢が広がりんぐ
	$oSYS->{'MainCGI'} = $pSYS;
	
	# ホスト情報設定(DNS逆引き)
	my $client_ip = $oCONV->is_cdn_ip($ENV{'REMOTE_ADDR'}) ;
	if ($client_ip) {
		# 信用できるプロキシ経由と判断
		$ENV{'REMOTE_ADDR'} = $client_ip;
	}
	$ENV{'REMOTE_HOST'} = $oCONV->reverse_lookup($ENV{'REMOTE_ADDR'}) unless ($ENV{'REMOTE_HOST'});
	$pSYS->{'FORM'}->Set('HOST', $ENV{'REMOTE_HOST'});
	
	return 0;
	
}

#------------------------------------------------------------------------------------------------------------
#
#	madakana.cgiヘッダ出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintMadaHead
{
	my ($Sys, $Page) = @_;
	my ($Caption, $Banner, $code, $HOST, $ADDR);
	
	require './module/header_footer_meta.pl';
	require './module/banner.pl';
	$Caption = new HEADER_FOOTER_META;
	$Banner = new BANNER;
	
	$Caption->Load($Sys->{'SYS'}, 'META');
	$Banner->Load($Sys->{'SYS'});
	
	$code	= $Sys->{'CODE'};
	$HOST	= $Sys->{'FORM'}->Get('HOST');
	$ADDR	= ($ENV{'REMOTE_ADDR'});
	
	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv="Content-Type" content="text/html;charset=$code">
 <meta http-equiv="Content-Style-Type" content="text/css">
 <meta http-equiv="imagetoolbar" content="no">

HTML
	
	$Caption->Print($Page, undef);
	
	$Page->Print(" <title>まだかな、まだかな</title>\n\n");
	$Page->Print("</head>\n<!--nobanner-->\n<body>\n");
	
	# バナー出力
	$Banner->Print($Page, 100, 2, 0) if ($Sys->{'SYS'}->Get('BANNER'));
	
	$Page->Print(<<HTML);
<div style="color:navy;">
<h1 style="font-size:1em;font-weight:normal;margin:0;">まだかな、まだかな、まなかな(規制一覧表)</h1>
<p style="margin:0;">
あなたのリモホ[<span style="color:red;font-weight:bold;">$HOST</span>]
</p>
<p>
by <font color="green">EXぜろちゃんねる ★</font>
</p>
<p>
##############################################################################<br>
# ここから<br>
</p>
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	madakana.cgi内容出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintMadaCont
{
	my ($Sys, $Page) = @_;
	my ($BBS, $vUser, $HOST, $ADDR, $BBSpath, @BBSkey, %BBSs, $path, $check, $line, $color );
	
	require './module/bbs_info.pl';
	$BBS	= new BBS_INFO;
	$BBS->Load($Sys->{'SYS'});
	
	require './module/user.pl';
	$vUser = USER->new;
	
	$HOST	= $Sys->{'FORM'}->Get('HOST');
	$ADDR	= ($ENV{'REMOTE_ADDR'});
	$BBSpath	= $Sys->{'SYS'}->Get('BBSPATH');
	
	#$sys->Set('HITS', $line);
	# BBSセットの取得
	$BBS->GetKeySet('ALL', '', \@BBSkey);
	
	# ハッシュに詰め込む
	foreach my $id (@BBSkey) {
		$BBSs{$BBS->Get('DIR', $id)} = $BBS->Get('NAME', $id);
	}
	
	foreach my $dir ( keys %BBSs ) {
		
		# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
		next if ( -e "$BBSpath/$dir/.0ch_hidden" );
		
		$Sys->{'SYS'}->Set('BBS', $dir);
		$vUser->Load($Sys->{'SYS'});
		$check = $vUser->Check($HOST, $ADDR);
		
		$color = "red";
		
		$Page->Print('<p>'."\n");
		$Page->Print('#-----------------------------------------------------------------------------<br>'."\n");
		$Page->Print("# <a href=\"$BBSpath/$dir/\">$BBSs{$dir}</a> [ $dir ]<br>\n");
		$Page->Print('#-----------------------------------------------------------------------------<br>'."\n");
		
		$path = "$BBSpath/$dir/info/access.cgi";
		
		if ( -e $path && open(SEC, '<', $path) ) {
			flock(FILE, 1);
			
			$line = <SEC>;
			chomp $line;
			my ( $type, $method ) = split(/<>/, $line, 2);
			
			if ( $type eq 'enable' ) {
				$Page->Print('<font color="red">※この板は以下のユーザーのみ書き込みを行うことができます。</font><br>'."\n");
				$color = "blue";
			}
			
			while ( <SEC> ) {
				next if( $_ =~ /(?:disable|enable)<>(?:disable|host)\n/ );
				chomp;
				if ( $Sys->{'SYS'}->Get('HITS') eq $_ ) {
					$_ = '<font color="'.$color.'"><b>'.$_.'</b></font>';
				}
				$_ .= "\n";
				s/\n/<br>/g;
				s/(http:\/\/.*)<br>/<a href="$1" target="_blank">$1<\/a><br>/g;
				$Page->Print($_."\n");
			}
			close(SEC);
		}
		else {
			$Page->Print('<span style="color:#AAA">Cannot open access.cgi.</span><br>'."\n");
		}
		
		$Page->Print('</p>'."\n");
		
	}
	

	
}

sub PrintMadaFoot
{
	my ($Sys, $Page) = @_;
	my ($ver, $cgipath);
	
	$ver		= $Sys->{'SYS'}->Get('VERSION');
	$cgipath	= $Sys->{'SYS'}->Get('CGIPATH');
	
	$Page->Print(<<HTML);
<p>
# ここまで<br>
##############################################################################<br>
</p>
</div>

<hr>

<div>
<a href="https://github.com/PrefKarafuto/ex0ch">EXぜろちゃんねる</a>
MADAKANA.CGI - $ver
</div>

</body>
</html>
HTML

}

#------------------------------------------------------------------------------------------------------------
#
#	madakana.cgiエラー表示
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintMadaError
{
	my ($Sys, $Page, $err) = @_;
	my ($code);
	
	$code = 'Shift_JIS';
	
	# HTMLヘッダの出力
	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print('<html><head><title>ＥＲＲＯＲ！！</title>');
	$Page->Print("<meta http-equiv=Content-Type content=\"text/html;charset=$code\">");
	$Page->Print('</head><!--nobanner-->');
	$Page->Print('<html><body>');
	$Page->Print("<b>$err</b>");
	$Page->Print('</body></html>');
}


