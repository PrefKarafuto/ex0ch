#============================================================================================================
#
#	管理CGIベースモジュール
#	admin_cgi_base.pl
#	---------------------------------------------------------------------------
#	2003.10.12 start
#
#============================================================================================================
package	ADMIN_CGI_BASE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

require './module/buffer_output.pl';

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($obj, @MnuStr, @MnuUrl);
	
	$obj = {
		'SYS'		=> undef,														# SYSTEM保持
		'FORM'		=> undef,														# FORM保持
		'INN'		=> undef,														# BUFFER_OUTPUT保持
		'MNUSTR'	=> \@MnuStr,													# 機能リスト文字列
		'MNUURL'	=> \@MnuUrl,													# 機能リストURL
		'MNUNUM'	=> 0															# 機能リスト数
	};
	bless $obj, $this;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	オブジェクト生成 - Create
#	-------------------------------------------------------------------------------------
#	引　数：$M : SYSTEMモジュール
#			$S : FORMモジュール
#	戻り値：BUFFER_OUTPUTモジュール
#
#------------------------------------------------------------------------------------------------------------
sub Create
{
	my $this = shift;
	my ($Sys, $Form) = @_;
	
	$this->{'SYS'}		= $Sys;
	$this->{'FORM'}		= $Form;
	$this->{'INN'}		= BUFFER_OUTPUT->new;
	$this->{'MNUNUM'}	= 0;
	
	return $this->{'INN'};
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューの設定 - SetMenu
#	-------------------------------------------------------------------------------------
#	引　数：$str : 表示文字列
#			$url : ジャンプURL
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenu
{
	my $this = shift;
	my ($str, $url) = @_;
	
	push @{$this->{'MNUSTR'}}, $str;
	push @{$this->{'MNUURL'}}, $url;
	
	$this->{'MNUNUM'} ++;
}

#------------------------------------------------------------------------------------------------------------
#
#	ページ出力 - Print
#	-------------------------------------------------------------------------------------
#	引　数：$ttl : ページタイトル
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Print
{
	my $this = shift;
	my ($ttl, $mode) = @_;
	my ($Tad, $Tin, $TPlus);
	
	$Tad	= BUFFER_OUTPUT->new;
	$Tin	= $this->{'INN'};
	
	PrintHTML($Tad, $ttl);																# HTMLヘッダ出力
	PrintCSS($Tad, $this->{'SYS'});														# CSS出力
	PrintHead($Tad, $ttl, $mode);														# ヘッダ出力
	PrintList($Tad, $this->{'MNUNUM'}, $this->{'MNUSTR'}, $this->{'MNUURL'});			# 機能リスト出力
	PrintInner($Tad, $Tin, $ttl);														# 機能内容出力
	PrintCommonInfo($Tad, $this->{'FORM'});
	PrintFoot($Tad, $this->{'FORM'}->Get('UserName'), $this->{'SYS'}->Get('VERSION'),
						$this->{'SYS'}->Get('ADMIN')->{'UPDATE_NOTICE'}->Get('Update'));	# フッタ出力
	
	$Tad->Flush(0, 0, '');																# 画面出力
}

#------------------------------------------------------------------------------------------------------------
#
#	ページ出力(メニューリストなし) - PrintNoList
#	-------------------------------------------------------------------------------------
#	引　数：$ttl : ページタイトル
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNoList
{
	my $this = shift;
	my ($ttl, $mode) = @_;
	my ($Tad, $Tin);
	
	$Tad = BUFFER_OUTPUT->new;
	$Tin = $this->{'INN'};
	
	PrintHTML($Tad, $ttl);															# HTMLヘッダ出力
	PrintCSS($Tad, $this->{'SYS'}, $ttl);											# CSS出力
	PrintHead($Tad, $ttl, $mode);													# ヘッダ出力
	PrintInner($Tad, $Tin, $ttl);													# 機能内容出力
	PrintFoot($Tad, 'NONE', $this->{'SYS'}->Get('VERSION'));						# フッタ出力
	
	$Tad->Flush(0, 0, '');															# 画面出力
}

#------------------------------------------------------------------------------------------------------------
#
#	HTMLヘッダ出力 - PrintHTML
#	-------------------------------------------
#	引　数：$T   : BUFFER_OUTPUTモジュール
#			$ttl : ページタイトル
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintHTML
{
	my ($Page, $ttl) = @_;
	
	$Page->Print("Content-type: text/html\n\n");
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>
 
 <title>ぜろちゃんねるプラス管理 - [ $ttl ]</title>
 
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	スタイルシート出力 - PrintCSS
#	-------------------------------------------
#	引　数：$Page   : BUFFER_OUTPUTモジュール
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCSS
{
	my ($Page, $Sys, $ttl) = @_;
	my ($data);
	
	$data = $Sys->Get('DATA');
	
$Page->Print(<<HTML);
 <meta http-equiv=Content-Type content="text/html;charset=Shift_JIS">
 
 <meta http-equiv="Content-Script-Type" content="text/javascript">
 <meta http-equiv="Content-Style-Type" content="text/css">
 
 <meta name="robots" content="noindex,nofollow">
 
 <link rel="stylesheet" href=".$data/admin.css" type="text/css">
 <script language="javascript" src=".$data/admin.js"></script>
 
</head>
<!--nobanner-->
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	ページヘッダ出力 - PrintHead
#	-------------------------------------------
#	引　数：$Page   : BUFFER_OUTPUTモジュール
#			$ttl : ページタイトル
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintHead
{
	my ($Page, $ttl, $mode) = @_;
	my ($common);
	
	$common = '<a href="javascript:DoSubmit';
	
$Page->Print(<<HTML);
<body>

<form name="ADMIN" action="./admin.cgi" method="POST"@{[$mode ? ' onsubmit="return Submitted();"' : '']}>

<div class="MainMenu" align="right">
HTML
	
	# システム管理メニュー
	if ($mode == 1) {
		
$Page->Print(<<HTML);
 <a href="javascript:DoSubmit('sys.top','DISP','NOTICE');">トップ</a> |
 <a href="javascript:DoSubmit('sys.bbs','DISP','LIST');">掲示板</a> |
 <a href="javascript:DoSubmit('sys.user','DISP','LIST');">ユーザー</a> |
 <a href="javascript:DoSubmit('sys.cap','DISP','LIST');">キャップ</a> |
 <a href="javascript:DoSubmit('sys.capg','DISP','LIST');">共通キャップグループ</a> |
 <a href="javascript:DoSubmit('sys.setting','DISP','INFO');">システム設定</a> |
 <a href="javascript:DoSubmit('sys.union','DISP','INFO');">掲示板サーバー連合設定</a> |
 <a href="javascript:DoSubmit('sys.edit','DISP','BANNER_PC');">共通告知欄の編集</a> |
HTML
		
	}
	# 掲示板管理メニュー
	elsif ($mode == 2) {
		
$Page->Print(<<HTML);
 <a href="javascript:DoSubmit('bbs.thread','DISP','LIST');">スレッド</a> |
 <a href="javascript:DoSubmit('bbs.pool','DISP','LIST');">プール</a> |
 <a href="javascript:DoSubmit('bbs.kako','DISP','LIST');">過去ログ</a> |
 <a href="javascript:DoSubmit('bbs.setting','DISP','SETINFO');">掲示板設定</a> |
 <a href="javascript:DoSubmit('bbs.ninja','DISP','SETINFO');">忍法帖</a> |
 <a href="javascript:DoSubmit('bbs.command','DISP','SETINFO');">各種コマンド設定</a> |
 <a href="javascript:DoSubmit('bbs.edit','DISP','HEAD');">各種編集</a> |
 <a href="javascript:DoSubmit('bbs.user','DISP','LIST');">管理グループ</a> |
 <a href="javascript:DoSubmit('bbs.cap','DISP','LIST');">キャップグループ</a> |
 <a href="javascript:DoSubmit('bbs.log','DISP','INFO');">ログ閲覧</a> |
HTML
		
	}
	# スレッド管理メニュー
	elsif ($mode == 3) {
		
$Page->Print(<<HTML);
 <a href="javascript:DoSubmit('thread.res','DISP','LIST');">レス一覧</a> |
 <a href="javascript:DoSubmit('thread.del','DISP','LIST');">削除レス一覧</a> |
HTML
		
	}
	
$Page->Print(<<HTML);
 <a href="javascript:DoSubmit('login','','');">ログオフ</a>
</div>
 
<div class="MainHead" align="right">New 0ch+ BBS System Manager</div>

<table cellspacing="0" width="100%" height="400">
 <tr>
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	機能リスト出力 - PrintList
#	-------------------------------------------
#	引　数：$Page   : BUFFER_OUTPUTモジュール
#			$str : 機能タイトル配列
#			$url : 機能URL配列
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintList
{
	my ($Page, $n, $str, $url) = @_;
	my ($i, $strURL, $strTXT);
	
$Page->Print(<<HTML);
  <td valign="top" class="Content">
  <table width="95%" cellspacing="0">
   <tr>
    <td class="FunctionList">
HTML
	
	for ($i = 0 ; $i < $n ; $i++) {
		$strURL = $$url[$i];
		$strTXT = $$str[$i];
		if ($strURL eq '') {
			$Page->Print("    <font color=\"gray\">$strTXT</font>\n");
			if ($strTXT ne '<hr>') {
				$Page->Print('    <br>'."\n");
			}
		}
		else {
			$Page->Print("    <a href=\"javascript:DoSubmit($$url[$i]);\">");
			$Page->Print("$$str[$i]</a><br>\n");
		}
	}
	
$Page->Print(<<HTML);
    </td>
   </tr>
  </table>
  </td>
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	機能内容出力 - PrintInner
#	-------------------------------------------
#	引　数：$Page1 : BUFFER_OUTPUTモジュール(MAIN)
#			$Page2 : BUFFER_OUTPUTモジュール(内容)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintInner
{
	my ($Page1, $Page2, $ttl) = @_;
	
$Page1->Print(<<HTML);
  <td width="80%" valign="top" class="Function">
  <div class="FuncTitle">$ttl</div>
HTML
	
	$Page1->Merge($Page2);
	
	$Page1->Print("  </td>\n");
	
}

#------------------------------------------------------------------------------------------------------------
#
#	共通情報出力 - PrintCommonInfo
#	-------------------------------------------
#	引　数：$Sys   : 
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCommonInfo
{
	my ($Page, $Form) = @_;
	
	my $user = $Form->Get('UserName', '');
	my $sid = $Form->Get('SessionID', '');
	
$Page->Print(<<HTML);
  <!-- ▼こんなところに地下要塞(ry -->
   <input type="hidden" name="MODULE" value="">
   <input type="hidden" name="MODE" value="">
   <input type="hidden" name="MODE_SUB" value="">
   <input type="hidden" name="UserName" value="$user">
   <input type="hidden" name="SessionID" value="$sid">
  <!-- △こんなところに地下要塞(ry -->
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	フッタ出力 - PrintFoot
#	-------------------------------------------
#	引　数：$Page   : BUFFER_OUTPUTモジュール
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintFoot
{
	my ($Page, $user, $ver, $nverflag) = @_;
	
$Page->Print(<<HTML);
 </tr>
</table>

<div class="MainFoot">
 Copyright 2001 - 2023 New 0ch+ BBS : Loggin User - <b>$user</b><br>
 Build Version:<b>$ver</b>@{[$nverflag ? " (New Version is Available.)" : '']}
</div>

</form>

</body>
</html>
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	完了画面の出力
#	-------------------------------------------------------------------------------------
#	@param	$processName	処理名
#	@param	$pLog	処理ログ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintComplete
{
	my $this = shift;
	my ($processName, $pLog) = @_;
	my ($Page, $text);
	
	$Page = $this->{'INN'};
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="0" cellpadding="0" width="100%" align="center">
   <tr>
    <td>
    
    <div class="oExcuted">
     $processName\を正常に完了しました。
    </div>
   
    <div class="LogExport">処理ログ</div>
    <hr>
    <blockquote class="LogExport">
HTML
	
	# ログの表示
	foreach $text (@$pLog) {
		$Page->Print("     $text<br>\n");
	}
	
$Page->Print(<<HTML);
    </blockquote>
    <hr>
    </td>
   </tr>
  </table>
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	エラーの表示
#	-------------------------------------------------------------------------------------
#	@param	$pLog	ログ用
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintError
{
	my $this = shift;
	my ($pLog) = @_;
	my ($Page, $ecode);
	
	$Page = $this->{'INN'};
	
	# エラーコードの抽出
	$ecode = pop @$pLog;
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="0" cellpadding="0" width="100%" align="center">
   <tr>
    <td>
    
    <div class="xExcuted">
HTML
	
	if ($ecode == 1000) {
		$Page->Print("     ERROR:$ecode - 本機能\の処理を実行する権限がありません。\n");
	}
	elsif ($ecode == 1001) {
		$Page->Print("     ERROR:$ecode - 入力必須項目が空欄になっています。\n");
	}
	elsif ($ecode == 1002) {
		$Page->Print("     ERROR:$ecode - 設定項目に規定外の文字が使用されています。\n");
	}
	elsif ($ecode == 2000) {
		$Page->Print("     ERROR:$ecode - 掲示板ディレクトリの作成に失敗しました。<br>\n");
		$Page->Print("     パーミッション、または既に同名の掲示板が作成されていないかを確認してください。\n");
	}
	elsif ($ecode == 2001) {
		$Page->Print("     ERROR:$ecode - SETTING.TXTの生成に失敗しました。\n");
	}
	elsif ($ecode == 2002) {
		$Page->Print("     ERROR:$ecode - 掲示板構\成要素の生成に失敗しました。\n");
	}
	elsif ($ecode == 2003) {
		$Page->Print("     ERROR:$ecode - 過去ログ初期情報の生成に失敗しました。\n");
	}
	elsif ($ecode == 2004) {
		$Page->Print("     ERROR:$ecode - 掲示板情報の更新に失敗しました。\n");
	}
	else {
		$Page->Print("     ERROR:$ecode - 不明なエラーが発生しました。\n");
	}
	
$Page->Print(<<HTML);
    </div>
    
HTML

	# エラーログがあれば出力する
	if (@$pLog) {
		$Page->Print('<hr>');
		$Page->Print("    <blockquote>");
		foreach (@$pLog) {
			$Page->Print("    $_<br>\n");
		}
		$Page->Print("    </blockquote>");
		$Page->Print('<hr>');
	}
	
$Page->Print(<<HTML);
    </td>
   </tr>
  </table>
HTML
	
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
