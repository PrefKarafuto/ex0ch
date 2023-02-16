#!/usr/bin/perl
#============================================================================================================
#
#	検索用CGI(まちがえてすみません)
#	search.cgi
#	-----------------------------------------------------
#	2003.11.22 star
#	2004.09.16 システム改変に伴う変更
#	2009.06.19 HTML部分の大幅な書き直し
#
#============================================================================================================

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
##use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
no warnings 'once';

BEGIN { use lib './perllib'; }

# CGIの実行結果を終了コードとする
exit(SearchCGI());

#------------------------------------------------------------------------------------------------------------
#
#	CGIメイン処理 - SearchCGI
#	------------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub SearchCGI
{
	my ($Sys, $Page, $Form, $BBS);
	
	require './module/system.pl';
	require './module/buffer_output.pl';
	require './module/form.pl';
	require './module/bbs_info.pl';
	$Sys	= new SYSTEM;
	$Page	= new BUFFER_OUTPUT;
	$Form	= FORM->new(1);
	$BBS	= new BBS_INFO;
	
	$Form->DecodeForm(1);
	$Sys->Init();
	$BBS->Load($Sys);
	PrintHead($Sys, $Page, $BBS, $Form);
	
	# 検索ワードがある場合は検索を実行する
	if ($Form->Get('WORD', '') ne '') {
		Search($Sys, $Form, $Page, $BBS);
	}
	PrintFoot($Sys, $Page);
	$Page->Flush(0, 0, '');
}

#------------------------------------------------------------------------------------------------------------
#
#	ヘッダ出力 - PrintHead
#	------------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintHead
{
	my ($Sys, $Page, $BBS, $Form) = @_;
	my ($pBBS, $bbs, $name, $dir, $Banner);
	my ($sMODE, $sBBS, $sKEY, $sWORD, @sTYPE, @cTYPE, $types, $BBSpath, @bbsSet, $id);
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;#"
		return $_;
	};
	
	$sMODE	= &$sanitize($Form->Get('MODE', ''));
	$sBBS	= &$sanitize($Form->Get('BBS', ''));
	$sKEY	= &$sanitize($Form->Get('KEY', ''));
	$sWORD	= &$sanitize($Form->Get('WORD'));
	@sTYPE	= $Form->GetAtArray('TYPE', 0);
	
	$types = ($sTYPE[0] || 0) | ($sTYPE[1] || 0) | ($sTYPE[2] || 0);
	$cTYPE[0] = ($types & 1 ? 'checked' : '');
	$cTYPE[1] = ($types & 2 ? 'checked' : '');
	$cTYPE[2] = ($types & 4 ? 'checked' : '');
	
	$BBSpath = $Sys->Get('BBSPATH');
	
	# バナーの読み込み
	require './module/banner.pl';
	$Banner = new BANNER;
	$Banner->Load($Sys);

	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv=Content-Type content="text/html;charset=Shift_JIS">
 <meta http-equiv="Content-Script-Type" content="text/css">

 <title>検索＠0chPlus</title>

 <link rel="stylesheet" type="text/css" href="./datas/search.css">

</head>
<!--nobanner-->
<body>

<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="#ccffcc" style="margin-bottom:1.2em;" align="center">
 <tr>
  <td>
  <font size="+1"><b>検索＠0chPlus</b></font>
  
  <div align="center" style="margin:1.2em 0;">
  <form action="./search.cgi" method="POST">
  <table border="0">
   <tr>
    <td>検索モード</td>
    <td>
    <select name="MODE">
HTML

	if ($sMODE eq 'ALL') {
		$Page->Print(<<HTML);
     <option value="ALL" selected>鯖内全検索</option>
     <option value="BBS">BBS指定全検索</option>
     <option value="THREAD">スレッド指定全検索</option>
HTML
	}
	elsif ($sMODE eq 'BBS' || $sMODE eq '') {
		$Page->Print(<<HTML);
     <option value="ALL">鯖内全検索</option>
     <option value="BBS" selected>BBS指定全検索</option>
     <option value="THREAD">スレッド指定全検索</option>
HTML
	}
	elsif ($sMODE eq 'THREAD') {
		$Page->Print(<<HTML);
     <option value="ALL">鯖内全検索</option>
     <option value="BBS">BBS指定全検索</option>
     <option value="THREAD" selected>スレッド指定全検索</option>
HTML
	}
	$Page->Print(<<HTML);
    </select>
    </td>
   </tr>
   <tr>
    <td>指定BBS</td>
    <td>
    <select name="BBS">
HTML

	# BBSセットの取得
	$BBS->GetKeySet('ALL', '', \@bbsSet);
	
	foreach $id (@bbsSet) {
		$name = $BBS->Get('NAME', $id);
		$dir = $BBS->Get('DIR', $id);
		
		# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
		next if ( -e "$BBSpath/$dir/.0ch_hidden" && $sBBS ne $dir );
		
		if ($sBBS eq $dir) {
			$Page->Print("     <option value=\"$dir\" selected>$name</option>\n");
		}
		else {
			$Page->Print("     <option value=\"$dir\">$name</option>\n");
		}
	}
	$Page->Print(<<HTML);
    </select>
    </td>
   </tr>
   <tr>
    <td>指定スレッドキー</td>
    <td>
    <input type="text" size="20" name="KEY" value="$sKEY">
    </td>
   </tr>
   <tr>
    <td>検索ワード</td>
    <td><input type="text" size="40" name="WORD" value="$sWORD"></td>
   </tr>
   <tr>
    <td>検索種別</td>
    <td>
    <input type="checkbox" name="TYPE" value="1" $cTYPE[0]>名前検索<br>
    <input type="checkbox" name="TYPE" value="4" $cTYPE[2]>ID・日付検索<br>
    <input type="checkbox" name="TYPE" value="2" $cTYPE[1]>本文検索<br>
    </td>
   </tr>
   <tr>
    <td colspan="2" align="right">
    <hr>
    <input type="submit" value="検索" style="width:150px;">
    </td>
   </tr>
  </table>
  </form>
  </div>
  </td>
 </tr>
</table>

HTML

	$Banner->Print($Page, 95, 0, 0) if($Sys->Get('BANNER'));
}

#------------------------------------------------------------------------------------------------------------
#
#	フッタ出力 - PrintHead
#	------------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintFoot
{
	my ($Sys, $Page) = @_;
	my ($ver, $cgipath);
	
	$ver = $Sys->Get('VERSION');
	$cgipath	= $Sys->Get('CGIPATH');
	
	$Page->Print(<<HTML);

<div class="foot">
<a href="http://zerochplus.sourceforge.jp/">ぜろちゃんねるプラス</a>
SEARCH.CGI - $ver
</div>

HTML
}

#------------------------------------------------------------------------------------------------------------
#
#	検索結果出力 - Search
#	------------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Search
{
	my ($Sys, $Form, $Page, $BBS) = @_;;
	my ($Search, $Mode, $Result, @elem, $n, $base, $word);
	my (@types, $Type);
	
	require './module/search.pl';
	$Search = new SEARCH;
	
	$Mode = 0 if ($Form->Equal('MODE', 'ALL'));
	$Mode = 1 if ($Form->Equal('MODE', 'BBS'));
	$Mode = 2 if ($Form->Equal('MODE', 'THREAD'));
	
	@types = $Form->GetAtArray('TYPE', 0);
	$Type = ($types[0] || 0) | ($types[1] || 0) | ($types[2] || 0);
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	
	# 検索オブジェクトの設定と検索の実行
	$Search->Create($Sys, $Mode, $Type, $Form->Get('BBS', ''), $Form->Get('KEY', ''));
	$Search->Run(&$sanitize($Form->Get('WORD')));
	
	if ($@ ne '') {
		PrintSystemError($Page, $@);
		return;
	}
	
	# 検索結果セット取得
	$Result = $Search->GetResultSet();
	$n		= $Result ? @$Result : 0;
	$base	= $Sys->Get('BBSPATH');
	$word	= $Form->Get('WORD');
	
	PrintResultHead($Page, $n);
	
	# 検索ヒットが1件以上あり
	if ($n > 0) {
		require './module/data_utils.pl';
		my $Conv = new DATA_UTILS;
		$n = 1;
		foreach (@$Result) {
			@elem = split(/<>/);
			PrintResult($Page, $BBS, $Conv, $n, $base, \@elem);
			$n++;
		}
	}
	# 検索ヒット無し
	else {
		PrintNoHit($Page);
	}
	
	PrintResultFoot($Page);
}

#------------------------------------------------------------------------------------------------------------
#
#	検索結果ヘッダ出力 - PrintResultHead
#	------------------------------------------------
#	引　数：Page : 出力モジュール
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResultHead
{
	my ($Page, $n) = @_;
	
	$Page->Print(<<HTML);
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="#efefef" style="margin-bottom:1.2em;" align="center">
 <tr>
  <td>
  <div class="hit" style="margin-top:1.2em;">
   <b>
   【ヒット数：$n】
   <font size="+2" color="red">検索結果</font>
   </b>
  </div>
  <dl>
HTML
}

#------------------------------------------------------------------------------------------------------------
#
#	検索結果内容出力
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResult
{
	my ($Page, $BBS, $Conv, $n, $base, $pResult) = @_;
	my ($name, @bbsSet);
	
	$BBS->GetKeySet('DIR', $$pResult[0], \@bbsSet);
	
	if (@bbsSet > 0) {
		$name = $BBS->Get('NAME', $bbsSet[0]);
		
		$Page->Print("   <dt>$n 名前：<b>");
		if ($$pResult[4] eq '') {
			$Page->Print("<font color=\"green\">$$pResult[3]</font>");
		}
		else {
			$Page->Print("<a href=\"mailto:$$pResult[4]\">$$pResult[3]</a>");
		}
		
	$Page->Print(<<HTML);
 </b>：$$pResult[5]</dt>
    <dd>
    $$pResult[6]
    <br>
    <hr>
    <a target="_blank" href="$base/$$pResult[0]/">【$name】</a>
    <a target="_blank" href="./read.cgi/$$pResult[0]/$$pResult[1]/">【スレッド】</a>
    <a target="_blank" href="./read.cgi/$$pResult[0]/$$pResult[1]/$$pResult[2]">【レス】</a>
    <br>
    <br>
    </dd>
    
HTML
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	検索結果フッタ出力
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResultFoot
{
	my ($Page) = @_;
	
	$Page->Print("  </dl>\n  </td>\n </tr>\n</table>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	NoHit出力
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNoHit
{
	my ($Page) = @_;
	
	$Page->Print(<<HTML);
<dt>
 0 名前：<font color="forestgreen"><b>検索エンジソ\＠ぜろちゃんねるプラス</b></font>：No Hit
</dt>
<dd>
 <br>
 <br>
 ＿|‾|○　一件もヒットしませんでした。。<br>
 <br>
</dd>
HTML
}

#------------------------------------------------------------------------------------------------------------
#
#	システムエラー出力
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@param	$msg	エラーメッセージ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintSystemError
{
	my ($Page, $msg) = @_;
	
	$Page->Print(<<HTML);
<br>
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="#efefef" align="center">
 <tr>
  <td>
  <dl>
  <div class="title">
  <small><b>【ヒット数：0】</b></small><font size="+2" color="red">システムエラー</font>
  </div>
   <dt>0 名前：<font color="forestgreen"><b>検索エンジソ\＠ぜろちゃんねるプラス</b></font>：System Error</dt>
    <dd>
    <br>
    <br>
    $msg<br>
    <br>
    <br>
    </dd>
  </dl>
  </td>
 </tr>
</table>
HTML
}
