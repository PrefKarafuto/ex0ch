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
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
no warnings 'once';
use JSON;
use LWP::UserAgent;
use Time::Local;

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
	my ($Sys, $Page, $Form, $BBS, $capt);
	
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
	$capt = $Sys->Get('SEARCHCAP') ? Certification_Captcha($Sys,$Form) : 1;
	PrintHead($Sys, $Page, $BBS, $Form);
	
	# 検索ワードがある場合は検索を実行する
	if ($Form->Get('WORD', '') ne '' && $capt) {
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
	my ($pBBS, $bbs, $name, $catname, $dir, $Banner);
	my ($sMODE, $sBBS, $sCAT, $sWORD, @sTYPE, @cTYPE, $types, $BBSpath, @bbsSet, $id, $isSelC, $isSelB);
	my ($dFROM, $dTO);
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;#"
		return $_;
	};
	
	$sBBS	= &$sanitize($Form->Get('BBS', ''));
	$sCAT	= &$sanitize($Form->Get('CATEGORY', ''));
	$sWORD	= &$sanitize($Form->Get('WORD'));
	$dFROM	= $Form->Get('FROM');
	$dTO	= $Form->Get('TO');
	@sTYPE	= $Form->GetAtArray('TYPE', 0);
	
	$types = ($sTYPE[0] || 0) | ($sTYPE[1] || 0) | ($sTYPE[2] || 0) | ($sTYPE[3] || 0);
	$cTYPE[0] = ($types & 0x1 ? 'checked' : '');
	$cTYPE[1] = ($types & 0x2 ? 'checked' : '');
	$cTYPE[2] = ($types & 0x4 ? 'checked' : '');
	$cTYPE[3] = ($types & 0x8 ? 'checked' : '');
	
	$BBSpath = $Sys->Get('BBSPATH');
	
	# バナーの読み込み
	require './module/banner.pl';
	$Banner = new BANNER;
	$Banner->Load($Sys);

	my $data_url = $Sys->Get('SERVER').$Sys->Get('CGIPATH').$Sys->Get('DATA');
	$data_url =~ s/^https?://;

	$Page->Print("Content-type: text/html;charset=Shift_JIS\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv=Content-Type content="text/html;charset=Shift_JIS">
 <meta http-equiv="Content-Script-Type" content="text/css">
 <meta name="viewport" content="width=device-width, initial-scale=1.0">

 <title>検索＠Ex0ch</title>

 <link rel="stylesheet" type="text/css" href="$data_url/search.css">
 <link rel="stylesheet" type="text/css" href="$data_url/design.css">
 <script language="javascript" src="$data_url/script.js"></script>

HTML

	if($Sys->Get('SEARCHCAP')){
		$Page->Print('<script src="https://js.hcaptcha.com/1/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'h-captcha');
		$Page->Print('<script src="https://www.google.com/recaptcha/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'g-recaptcha');
		$Page->Print('<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>') if ($Sys->Get('CAPTCHA') eq 'cf-turnstile');
	}
	my $sitekey = $Sys->Get('CAPTCHA_SITEKEY');
	my $classname = $Sys->Get('CAPTCHA');
	my $Captcha = $sitekey && $classname && $Sys->Get('SEARCHCAP') ? "<div class=\"$classname\" data-sitekey=\"$sitekey\"></div><br>" : '';

	$Page->Print("</head>\n<!--nobanner-->\n<body>\n");

	# サイドメニュー
	require './module/bbs_info.pl';
	my $Category = CATEGORY_INFO->new;
	$Category->Load($Sys);
	$BBS->Load($Sys);
	my @catSet;
	$Category->GetKeySet(\@catSet);
	$BBS->GetKeySet('ALL', '', \@bbsSet);

	my $sitename = $Sys->Get('SITENAME') || 'EXぜろちゃんねる';

	# PC用メニューバー
	$Page->Print("<nav class=\"sidebar\" id=\"pc-sidebar\"><ul>\n");
	$Page->Print("<li class=\"menu-title\">$sitename</li>\n");
	$Page->Print("<li><a class=\"active\" href=\"../test/search.cgi\">検索</a></li>\n");
	$Page->Print("<li><a href=\"../bbsmenu.html\">BBS MENU</a></li>\n") if -e '../bbsmenu.html';
	$Page->Print("<hr>");
	$Page->Print("<li class=\"menu-title\">掲示板一覧</li>\n");
	foreach my $catid (sort @catSet) {
		my $catname = $Category->Get('NAME', $catid);
		$Page->Print("<li class=\"category-title\">$catname</li>\n");
		foreach my $id (sort @bbsSet) {
			my $name = $BBS->Get('NAME', $id);
			my $dir = $BBS->Get('DIR', $id);
			$Page->Print("<li><a href=\"../$dir/\">$name</a></li>\n") if $catid eq $BBS->Get('CATEGORY', $id);
		}
	}
	
	$Page->Print("</ul></nav>\n");

	# スマホ用メニューバー
	$Page->Print("<nav class=\"dropdown\" id=\"mobile-dropdown\">\n");
	$Page->Print("<button class=\"dropbtn\" onclick=\"toggleDropdown()\"><span class=\"sitename\">$sitename</span>\n");
	$Page->Print("<div class=\"hamburger-icon\"><span></span><span></span><span></span></div></button>");
	$Page->Print("<div class=\"dropdown-content\" id=\"dropdown-content\">\n");
	$Page->Print("<a class=\"active\" href=\"../test/search.cgi\">検索</a>\n");
	$Page->Print("<a href=\"../bbsmenu.html\">BBS MENU</a>\n") if -e '../bbsmenu.html';
	$Page->Print("<hr>");
	$Page->Print("<li class=\"menu-title\">掲示板一覧</li>\n");
	foreach my $catid (sort @catSet) {
		my $catname = $Category->Get('NAME', $catid);
		$Page->Print("<span class=\"category-title\">$catname</span>\n");
		foreach my $id (sort @bbsSet) {
			my $name = $BBS->Get('NAME', $id);
			my $dir = $BBS->Get('DIR', $id);
			$Page->Print("<a href=\"../$dir/\">$name</a>\n") if $catid eq $BBS->Get('CATEGORY', $id);
		}
	}
	$Page->Print("</div></nav>\n");

	$Page->Print("<main class=\"content\">\n");
	$Page->Print(<<HTML);

<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="#ccffcc" style="margin-bottom:1.2em; word-break:break-all;" align="center">
 <tr>
  <td>
  <font size="+1"><b>検索＠Ex0ch</b></font>
  
  <div align="center" style="margin:1.2em 0;">
  <form action="./search.cgi" method="POST">
  <table border="0">
   <tr>
	<td>対象カテゴリー<br>
	<select name="CATEGORY">
	<option value="">指定しない</option>

HTML

	
	foreach my $catid (sort @catSet) {
		$catname = $Category->Get('NAME', $catid);
		my $count = 0;
		foreach my $id(sort @bbsSet){
			$count++ if $catid eq $BBS->Get('CATEGORY', $id);
		}
		next if !$count;
		$catname .= " ($count)";
		$isSelC = $sCAT eq $catid ? "selected" : "";

		$Page->Print("<option value=\"$catid\" $isSelC>$catname</option>\n");
	}
	$Page->Print(<<HTML);
	</select>
	</td>
   </tr>
   <tr>
	<td>対象BBS<br>
	<select name="BBS">
HTML

	$Page->Print("<option value=\"\">すべて</option>\n");
	foreach my $catid (sort @catSet) {
		$catname = $Category->Get('NAME', $catid);
		$Page->Print("<optgroup label=\"$catname\">");
		foreach $id (sort @bbsSet) {
			$name = $BBS->Get('NAME', $id);
			$dir = $BBS->Get('DIR', $id);
			
			# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
			next if ( -e "$BBSpath/$dir/.0ch_hidden" && $sBBS ne $dir );

			# 選択肢
			$isSelC = $sBBS eq $dir ? "selected" : "";
			$Page->Print("<option value=\"$dir\" $isSelB>$name</option>\n") if $catid eq $BBS->Get('CATEGORY', $id);
		}
		$Page->Print("</optgroup>");
	}

	$Page->Print(<<HTML);
	</select>
	</td>
   </tr>
   <tr>
	<td>検索ワード<br><input type="text" size="35" name="WORD" value="$sWORD"></td>
   </tr>
   <tr>
	<td>検索範囲<br>
	<input type="date" name="FROM" value="$dFROM"><small>から</small>
	<input type="date" name="TO" value="$dTO"><small>まで</small><br>
	</td>
   </tr>
   <tr>
	<td>検索種別<br>
	<input type="checkbox" name="TYPE" value="1" $cTYPE[0]><small>名前検索</small><br>
	<input type="checkbox" name="TYPE" value="2" $cTYPE[1]><small>本文検索</small><br>
	<input type="checkbox" name="TYPE" value="4" $cTYPE[2]><small>ID検索</small><br>
	<input type="checkbox" name="TYPE" value="8" $cTYPE[3]><small>スレタイ検索</small><br>
	</td>
   </tr>
   <tr>
	<td colspan="2" align="right">
	<hr>
	$Captcha
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
<a href="https://github.com/PrefKarafuto/ex0ch">EXぜろちゃんねる</a>
SEARCH.CGI - $ver
</div>
</main>
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
	my ($Sys, $Form, $Page, $BBS) = @_;
	my ($Search, $Mode, $Result, @elem, $n, $base, $word);
	my (@types, $Type);
	
	require './module/search.pl';
	$Search = new SEARCH;
	my $bbs = $Form->Get('BBS', '');
	my $cat = $Form->Get('CATEGORY', '');
	my @dFROM	= split(/-/,$Form->Get('FROM', ''));
	my $FROM = $Form->Get('FROM', '') ? timelocal(0,0,0,$dFROM[2],$dFROM[1]-1,$dFROM[0]) : 0;
	my @dTO	= split(/-/,$Form->Get('TO', ''));
	my $TO = $Form->Get('TO', '') ? timelocal(0,0,0,$dTO[2]+1,$dTO[1]-1,$dTO[0]) - 1 : 0;
	
	$Mode = 2 if ($cat);
	$Mode = 1 if ($bbs);
	$Mode = 0 if (!$bbs && !$cat);

	@types = $Form->GetAtArray('TYPE', 0);
	$Type = ($types[0] || 0) | ($types[1] || 0) | ($types[2] || 0) | ($types[3] || 0);
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	
	# 検索オブジェクトの設定と検索の実行
	$Search->Create($Sys, $Mode, $Type, $bbs, $cat, $FROM, $TO);
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
			PrintResult($Sys, $Page, $BBS, $Conv, $n, $base, \@elem);
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
<br>
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
	my ($Sys, $Page, $BBS, $Conv, $n, $base, $pResult) = @_;
	my ($name, @bbsSet);
	
	$BBS->GetKeySet('DIR', $$pResult[0], \@bbsSet);
	require './module/thread.pl';
	my $Threads = THREAD->new;

	if (@bbsSet > 0) {
		$name = $BBS->Get('NAME', $bbsSet[0]);

		$Page->Print("   <dt>$n 名前：<b>");
		if ($$pResult[4] eq '') {
			$Page->Print("<font color=\"green\">$$pResult[3]</font>");
		}
		else {
			$Page->Print("<font color=\"blue\"><b>$$pResult[3]</b></font>");
		}
		
		$Sys->Set('BBS',$$pResult[0]);
		$Threads->Load($Sys);
		my $threadName = $Threads->Get('SUBJECT',$$pResult[1]);

		$Page->Print(<<HTML);
 </b>：$$pResult[5]</dt>
	<dd>
	$$pResult[6]
	<br>
	<hr>
	<a target="_blank" href="$base/$$pResult[0]/">【$name】</a>
	<a target="_blank" href="./read.cgi/$$pResult[0]/$$pResult[1]/">【$threadName】</a>
	<a target="_blank" href="./read.cgi/$$pResult[0]/$$pResult[1]/$$pResult[2]">【&gt;&gt;$$pResult[2]】</a>
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
 0 名前：<font color="forestgreen"><b>検索エンジン＠EXぜろちゃんねる</b></font>：No Hit
</dt>
<dd>
 <br>
 <br>
 ＿|￣|○　一件もヒットしませんでした。。<br>
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
   <dt>0 名前：<font color="forestgreen"><b>検索エンジン＠EXぜろちゃんねる</b></font>：System Error</dt>
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

#------------------------------------------------------------------------------------------------------------
#
#	改造版で追加
#	Captchaの認証
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	規制通過なら0を返す
#			規制チェックにかかったらエラーコードを返す
#
#------------------------------------------------------------------------------------------------------------
sub Certification_Captcha {
	my ($Sys,$Form) = @_;
	my ($captcha_response,$url);

	my $captcha_kind = $Sys->Get('CAPTCHA');
	my $captcha_leniency = $Sys->Get('CAPTCHA_LENIENCY');
	my $secretkey = $Sys->Get('CAPTCHA_SECRETKEY');
	if($captcha_kind eq 'h-captcha'){
		$captcha_response = $Form->Get('h-captcha-response');
		$url = 'https://api.hcaptcha.com/siteverify';
	}elsif($captcha_kind eq 'g-recaptcha'){
		$captcha_response = $Form->Get('g-recaptcha-response');
		$url = 'https://www.google.com/recaptcha/api/siteverify';
	}elsif($captcha_kind eq 'cf-turnstile'){
		$captcha_response = $Form->Get('cf-turnstile-response');
		$url = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
	}else{
		return 1;
	}

	if($captcha_response){
		my $ua = LWP::UserAgent->new();
		my $response = $ua->post($url,{
			secret => $secretkey,
			response => $captcha_response,
			remoteip => $ENV{'REMOTE_ADDR'},
			remoteip_leniency => $captcha_leniency,
		});
		if ($response->is_success()) {
			my $json_text = $response->decoded_content();
			
			# JSON::decode_json関数でJSONテキストをPerlデータ構造に変換
			my $out = decode_json($json_text);
			
			if ($out->{success}) {
				# パス
				return 1;
			}else{
				# 失敗
				return 0;
			}
		} else {
			# Captchaを素通りする場合、HTTPS関連のエラーの疑いあり
			# LWP::Protocol::httpsおよびNet::SSLeayが入っているか確認
			# このエラーの場合、検索は実行されない
			return 0;
		}
	}else{
		return 1;
	}
}
