#!/usr/bin/perl
#============================================================================================================
#
#	読み出し専用CGI
#	r.cgi
#	-------------------------------------------------------------------------------------
#	2004.04.08 システム改変に伴う新規作成
#
#============================================================================================================

use lib './perllib';

use strict;
#use warnings;
##use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
no warnings 'once';
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);


# CGIの実行結果を終了コードとする
exit(ReadCGI());

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiメイン
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub ReadCGI
{
	my (%SYS, $Page, $err);
	
	require './module/constant.pl';
	
	require './module/buffer_output.pl';
	$Page = new BUFFER_OUTPUT;
	
	# 初期化・準備に成功したら内容表示
	if (($err = Initialize(\%SYS, $Page)) == $ZP::E_SUCCESS) {
		# ヘッダ表示
		PrintReadHead(\%SYS, $Page);
		
		# メニュー表示
		PrintReadMenu(\%SYS, $Page);
		
		# 内容表示
		PrintReadContents(\%SYS, $Page);
		
		# フッタ表示
		PrintReadFoot(\%SYS, $Page);
	}
	# 初期化に失敗したらエラー表示
	else {
		# 対象スレッドが見つからなかった場合は探索画面を表示する
		if ($err == $ZP::E_PAGE_FINDTHREAD) {
			PrintReadSearch(\%SYS, $Page, $err);
		}
		# それ以外は通常エラー
		else {
			PrintReadError(\%SYS, $Page, $err);
		}
	}
	
	# 表示結果を出力
	$Page->Flush(0, 0, '');
	
	return $err;
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgi初期化・前準備
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Initialize
{
	my ($pSYS, $Page) = @_;
	my (@elem, @regs, $path);
	my ($oSYS, $oSET, $oCONV, $oDAT);
	
	# 各使用モジュールの生成と初期化
	require './module/system.pl';
	require './module/setting.pl';
	require './module/dat.pl';
	require './module/data_utils.pl';
	
	$oSYS	= new SYSTEM;
	$oSET	= new SETTING;
	$oCONV	= new DATA_UTILS;
	$oDAT	= new DAT;
	
	%$pSYS = (
		'SYS'	=> $oSYS,
		'SET'	=> $oSET,
		'CONV'	=> $oCONV,
		'DAT'	=> $oDAT,
		'PAGE'	=> $Page,
		'CODE'	=> 'sjis'
	);
	
	# システム初期化
	$oSYS->Init();
	
	# 夢が広がりんぐ
	$oSYS->{'MainCGI'} = $pSYS;
	
	# 起動パラメータの解析
	@elem = $oCONV->GetArgument(\%ENV);
	
	# BBS指定がおかしい
	if (! defined $elem[0] || $elem[0] eq '') {
		return $ZP::E_READ_R_INVALIDBBS;
	}
	# スレッドキー指定がおかしい
	elsif (! defined $elem[1] || $elem[1] eq '' || ($elem[1] =~ /[^0-9]/) ||
			(length($elem[1]) != 10 && length($elem[1]) != 9)) {
		return $ZP::E_READ_R_INVALIDKEY;
	}
	
	# システム変数設定
	$oSYS->Set('MODE', 0);
	$oSYS->Set('BBS', $elem[0]);
	$oSYS->Set('KEY', $elem[1]);
	$oSYS->Set('CLIENT', $oCONV->GetClient());
	$oSYS->Set('AGENT', $oCONV->GetAgentMode($oSYS->Get('CLIENT')));
	$oSYS->Set('BBSPATH_ABS', $oCONV->MakePath($oSYS->Get('CGIPATH'), $oSYS->Get('BBSPATH')));
	$oSYS->Set('BBS_ABS', $oCONV->MakePath($oSYS->Get('BBSPATH_ABS'), $oSYS->Get('BBS')));
	$oSYS->Set('BBS_REL', $oCONV->MakePath($oSYS->Get('BBSPATH'), $oSYS->Get('BBS')));
	
	$path = $oCONV->MakePath($oSYS->Get('BBSPATH')."/$elem[0]/dat/$elem[1].dat");
	
	# datファイルの読み込みに失敗
	if ($oDAT->Load($oSYS, $path, 1) == 0) {
		return $ZP::E_READ_FAILEDLOADDAT;
	}
	$oDAT->Close();
	
	# 設定ファイルの読み込みに失敗
	if ($oSET->Load($oSYS) == 0) {
		return $ZP::E_READ_FAILEDLOADSET;
	}
	
	my $submax = $oSET->Get('BBS_SUBJECT_MAX') || $oSYS->Get('SUBMAX');
	$oSYS->Set('SUBMAX', $submax);
	my $resmax = $oSET->Get('BBS_RES_MAX') || $oSYS->Get('RESMAX');
	$oSYS->Set('RESMAX', $resmax);
	
	# 表示開始終了位置の設定
	@regs = $oCONV->RegularDispNum(
				$oSYS, $oDAT, $elem[2], $elem[3], $elem[4]);
	$oSYS->SetOption($elem[2], $regs[0], $regs[1], $elem[5], $elem[6]);
	
	return $ZP::E_SUCCESS;
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiヘッダ出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadHead
{
	my ($Sys, $Page) = @_;
	my ($Caption, $Banner, $code, $title);
	
	require './module/banner.pl';
	$Banner = new BANNER;
	$Banner->Load($Sys->{'SYS'});
	
	require './module/header_footer_meta.pl';
	$Caption = new HEADER_FOOTER_META;
	$Caption->Load($Sys->{'SYS'}, 'META');
	
	$code	= $Sys->{'CODE'};
	$title	= $Sys->{'DAT'}->GetSubject();
	
	# HTMLヘッダの出力
	$Page->Print("Content-type: text/html\n\n");
$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="ja">
<head>
<meta http-equiv=Content-Type content="text/html;charset=Shift_JIS">
<meta http-equiv="Cache-Control" content="no-cache">

<script src='https://js.hcaptcha.com/1/api.js' async defer></script>
<script type="text/javascript" src="https://code.jquery.com/jquery-2.1.4.min.js"></script>
HTML
	
	$Caption->Print($Page, undef);
	
$Page->Print(<<HTML);
<title>$title</title>
</head>
<!--nobanner-->
HTML
	
	# <body>タグ出力
	{
		$Page->Print('<body>'."\n");
	}
	
	# バナー出力
	$Banner->Print($Page, 100, 2, 1);
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiメニュー出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadMenu
{
	my ($Sys, $Page) = @_;
	my ($oSYS, $bbs, $key, $baseBBS, $resNum);
#	my ($pathBBS, $pathAll, $pathLast, $pathMenu, $pathNext, $pathPrev);
	
	# 前準備
	$oSYS		= $Sys->{'SYS'};
	$bbs		= $oSYS->Get('BBS');
	$key		= $oSYS->Get('KEY');
	
$Page->Print(<<HTML);
前4)<a href="#down" accesskey="8">下</a>8)次6) 初1)新3)<a href="#res" accesskey="7">書</a>7) 板5)
HTML

	# スレッドタイトル表示
	{
		my $title	= $Sys->{'DAT'}->GetSubject();
		my $ttlCol	= $Sys->{'SET'}->Get('BBS_SUBJECT_COLOR');
		$Page->Print("<hr>\n");
		$Page->Print("<font color=\"$ttlCol\" size=\"+1\">$title</font>\n");
		$Page->Print("<a name=\"top\"></a>\n");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgi内容出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadContents
{
	my ($Sys, $Page) = @_;
	my ($work, @elem, $i);
	
	$work = $Sys->{'SYS'}->Get('OPTION');
	@elem = split(/\,/, $work);
	
	# 1表示フラグがTRUEで開始が1でなければ1を表示する
	if ($elem[3] == 0 && $elem[1] != 1) {
		PrintResponse($Sys, $Page, 1, 0);
	}
	# 残りのレスを表示する
	for ($i = $elem[1] ; $i <= $elem[2] ; $i++) {
		PrintResponse($Sys, $Page, $i, $elem[2]);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiフッタ出力
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadFoot
{
	my ($Sys, $Page) = @_;
	my ($oSYS, $Conv, $bbs, $key, $ver, $rmax, $pathNext, $pathPrev);
	my ($baseBBS, $pathBBS, $pathAll, $pathLast, $resNum, $cgipath);
	
	# 前準備
	$oSYS		= $Sys->{'SYS'};
	$Conv		= $Sys->{'CONV'};
	$bbs		= $oSYS->Get('BBS');
	$key		= $oSYS->Get('KEY');
	$ver		= $oSYS->Get('VERSION');
	$rmax		= $oSYS->Get('RESMAX');
	
	$cgipath	= $oSYS->Get('CGIPATH');
	$baseBBS	= $oSYS->Get('BBS_ABS');
	$pathBBS	= $Conv->MakePath("$baseBBS/i/index.html");
	$pathAll	= $Sys->{'CONV'}->CreatePath($oSYS, 1, $bbs, $key, '1-10n');
	$pathLast	= $Sys->{'CONV'}->CreatePath($oSYS, 1, $bbs, $key, 'l10');
	$resNum		= $Sys->{'DAT'}->Size();
	
	# 前、次番号の取得
	{
		my ($st, $ed, $b1, $b2, $f1, $f2);
		
		$st = $oSYS->GetOption(2);
		$ed = $oSYS->GetOption(3);
		$b1 = ($st - 11 > 0) ? ($st - 11) : 1;
		$b2 = ($b1 == 1) ? 10 : ($b1 + 10);
		$f1 = ($ed + 1 < $rmax) ? ($ed + 1) : $rmax;
		$f2 = ($ed + 10 < $rmax) ? ($ed + 10) : $rmax;
		
		$pathNext = $Conv->CreatePath($oSYS, 1, $bbs, $key, "${f1}-${f2}n");
		$pathPrev = $Conv->CreatePath($oSYS, 1, $bbs, $key, "${b1}-${b2}n");
	}
	$Page->Print('<hr>');
	
	# メニューの表示
	$Page->Print("<a href=\"#top\" accesskey=\"2\">上</a>");
	$Page->Print("<a href=\"$pathPrev\" accesskey=\"4\">前</a>");
	$Page->Print("<a href=\"$pathNext\" accesskey=\"6\">次</a>");
	$Page->Print("<a href=\"$pathLast?guid=ON\" accesskey=\"3\">新</a>");
	$Page->Print("<a href=\"$pathAll\" accesskey=\"1\">1-</a>");
	$Page->Print("<a href=\"$pathBBS\" accesskey=\"5\">板</a>");
	
	# 投稿フォームの表示
	# レス最大数を超えている場合はフォーム表示しない
	if ($rmax > $Sys->{'DAT'}->Size()) {

$Page->Print(<<HTML);
<hr>
<a name=res></a>
<form method="POST" action="$cgipath/bbs.cgi?guid=ON">
<input type="hidden" name="bbs" value="$bbs">
<input type="hidden" name="key" value="$key">
<input type="hidden" name="mb" value="on">
名前<br><input type="text" name="FROM"><br>
E-mail<br><input type="text" name="mail"><br>
<textarea rows="3" wrap="off" name="MESSAGE"></textarea>
HTML


	# hCaptchaなしの場合
	my $hCaptcha_check = $Set->Get('BBS_HCAPTCHA_ONOFF');
	my $sitekey = $Set->Get('BBS_HCAPTCHA_SITEKEY');
	if ($hCaptcha_check eq '') {
$Page->Print(<<HTML);
<br><input type="submit" value="書き込む"><br>
HTML
	}else{
$Page->Print("<div class=\"h-captcha\" data-sitekey=\"$sitekey\"></div>　\n");
$Page->Print(<<HTML);
<br><input type="submit" value="書き込む"><br>
HTML
}



	}
	$Page->Print("<small>$ver</small></form></body></html>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiレス表示
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResponse
{
	my ($Sys, $Page, $n, $last) = @_;
	my ($oSYS, $oConv, $pDat, @elem, $maxLen, $len, $resNum);
	
	$oSYS	= $Sys->{'SYS'};
	$oConv	= $Sys->{'CONV'};
	$pDat	= $Sys->{'DAT'}->Get($n -1);
	@elem	= split(/<>/, $$pDat);
	$len	= length $elem[3];
	$maxLen	= $Sys->{'SET'}->Get('BBS_LINE_NUMBER');
	$maxLen	= int($maxLen * 5);
	$resNum	= $Sys->{'DAT'}->Size();
	
	# 表示範囲内か指定表示ならすべて表示する
	if ($oSYS->GetOption(5) == 1 || $len <= $maxLen) {
		$oConv->ConvertURL($oSYS, $Sys->{'SET'}, 1, \$elem[3]);
		$oConv->ConvertQuotation($oSYS, \$elem[3], 1);
	}
	# 表示範囲を超えていたら省略表示をする
	else {
		my ($bbs, $key, $path);
		
		$bbs		= $oSYS->Get('BBS');
		$key		= $oSYS->Get('KEY');
		$elem[3]	= $oConv->DeleteText(\$elem[3], $maxLen);
		$maxLen		= (($_ = $len - length($elem[3])) + 20 - ($_ % 20 || 20)) / 20;
		$path		= $oConv->CreatePath($oSYS, 1, $bbs, $key, "${n}n");
		
		$oConv->ConvertURL($oSYS, $Sys->{'SET'}, 1, \$elem[3]);
		$oConv->ConvertQuotation($oSYS, \$elem[3], 1);
		
		#if ($maxLen) {
			$elem[3] .= " <a href=\"$path\">省$maxLen</a>";
		#}
	}
	
	# AASリンク取得
	my ( $server, $path, $obama );
	
	$server	= $oSYS->Get('SERVER') || $ENV{'SERVER_NAME'};
	$server	=~ s|http://||i;
	$path	= $oConv->MakePath($server.$oSYS->Get('BBSPATH_ABS'));
	$path	=~ s|/|+|gi;
	$path	= $oConv->MakePath($path, $oSYS->Get('BBS'));
	$obama	= 'http://example.ddo.jp' . $oConv->MakePath("/aas/a.i/$path/".$oSYS->Get('KEY')."/$n?guid=ON");
		
	$Page->Print("<a name=\"down\"></a>") if ( $n == $last );
	$Page->Print("<hr>[$n]$elem[0]</b>：$elem[2]<br><a href=\"$obama\">AAS</a><br>$elem[3]<br>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgi探索画面表示
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadSearch
{
	my ($Sys, $Page, $err) = @_;
	
	# 存在しないので404を返す。
	$Page->Print("Status: 404 Not Found\n");
	
	# 仮エラーページ
	PrintReadError($Sys, $Page, $err);
}

#------------------------------------------------------------------------------------------------------------
#
#	r.cgiエラー表示
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintReadError
{
	my ($Sys, $Page, $err) = @_;
	my $code;
	
	$code = 'Shift_JIS';
	
	# HTMLヘッダの出力
	$Page->Print("Content-type: text/html\n\n");
	$Page->Print('<html><head><title>ＥＲＲＯＲ！！</title>');
	$Page->Print("<meta http-equiv=Content-Type content=\"text/html;charset=$code\">");
	$Page->Print('</head><!--nobanner-->');
	$Page->Print('<html><body>');
	$Page->Print("<b>$err</b>");
	$Page->Print('</body></html>');
}

