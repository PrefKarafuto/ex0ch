#============================================================================================================
#
#	掲示板管理 - 掲示板設定 モジュール
#	bbs.setting.pl
#	---------------------------------------------------------------------------
#	2004.06.01 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($obj, @LOG);
	
	$obj = {
		'LOG'	=> \@LOG
	};
	bless $obj, $this;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	表示メソッド
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Form	FORM
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoPrint
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $BASE, $BBS, $Page);
	
	require './admin/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	$BBS = $pSys->{'AD_BBS'};
	
	# 掲示板情報の読み込みとグループ設定
	if (! defined $BBS) {
		require './module/bbs_info.pl';
		$BBS = BBS_INFO->new;
		
		$BBS->Load($Sys);
		$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
		$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	}
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys, $Sys->Get('BBS'));
	
	if ($subMode eq 'SETINFO') {													# 設定情報画面
		PrintSettingInfo($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SETBASE') {													# 基本設定画面
		PrintBaseSetting($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SETCOLOR') {												# カラー設定画面
		PrintColorSetting($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'SETCOLORC') {												# カラー設定確認画面
		PrintColorSetting($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'SETLIMIT') {												# 制限設定画面
		PrintLimitSetting($Page, $Sys, $Form);
	}
 	elsif ($subMode eq 'SETCOMMAND') {												# ユーザーコマンド設定画面
		PrintCommandSetting($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SETNINPOCHO') {												# 忍法帖設定画面
		PrintNinpochoSetting($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SETOTHER') {												# その他設定画面
		PrintOtherSetting($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SETIMPORT') {												# インポート画面
		PrintSettingImport($Page, $Sys, $Form, $BBS);
	}
	elsif ($subMode eq 'COMPLETE') {												# 設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('掲示板設定処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 設定失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
	# 掲示板情報を設定
	$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	
	$BASE->Print($Sys->Get('_TITLE') . ' - ' . $BBS->Get('NAME', $Form->Get('TARGET_BBS')), 2);
}

#------------------------------------------------------------------------------------------------------------
#
#	機能メソッド
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Form	FORM
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoFunction
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $err, $BBS);
	
	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	
	# 管理情報を登録
	$BBS->Load($Sys);
	$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	$Sys->Set('ADMIN', $pSys);
	$pSys->{'SECINFO'}->SetGroupInfo($Sys->Get('BBS'));
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 9999;
	
	if ($subMode eq 'SETBASE') {													# 基本設定
		$err = FunctionBaseSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETCOLOR') {												# カラー設定
		$err = FunctionColorSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETLIMIT') {												# 制限設定
		$err = FunctionLimitSetting($Sys, $Form, $this->{'LOG'});
	}
 	elsif ($subMode eq 'SETCOMMAND') {												# ユーザーコマンド設定
		$err = FunctionCommandSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETNINPOCHO') {												# 忍法帖設定
		$err = FunctionNinpochoSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETOTHER') {												# その他設定
		$err = FunctionOtherSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETORIGIN') {												# オリジナル設定
		$err = FunctionOriginalSetting($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SETIMPORT') {												# インポート
		$err = FunctionSettingImport($Sys, $Form, $this->{'LOG'}, $BBS);
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"THREAD($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"THREAD($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$pSys->{'AD_BBS'} = $BBS;
	$this->DoPrint($Sys, $Form, $pSys);
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューリスト設定
#	-------------------------------------------------------------------------------------
#	@param	$Base	ADMIN_CGI_BASE
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys, $bbs) = @_;
	
	$Base->SetMenu('設定情報', "'bbs.setting','DISP','SETINFO'");
	
	# 管理グループ設定権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_BBSSETTING, $bbs)){
		$Base->SetMenu('<hr>', '');
		$Base->SetMenu('基本設定', "'bbs.setting','DISP','SETBASE'");
		$Base->SetMenu('カラー設定', "'bbs.setting','DISP','SETCOLOR'");
		$Base->SetMenu('制限・規制設定', "'bbs.setting','DISP','SETLIMIT'");
  		$Base->SetMenu('ユーザーコマンド設定', "'bbs.setting','DISP','SETCOMMAND'");
		$Base->SetMenu('忍法帖設定', "'bbs.setting','DISP','SETNINPOCHO'");
		$Base->SetMenu('その他設定', "'bbs.setting','DISP','SETOTHER'");
		$Base->SetMenu('<hr>', '');
		$Base->SetMenu('設定インポート', "'bbs.setting','DISP','SETIMPORT'");
	}
	$Base->SetMenu('<hr>', '');
	$Base->SetMenu('システム管理へ戻る', "'sys.bbs','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	設定情報画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintSettingInfo
{
	my ($Page, $SYS, $Form) = @_;
	my ($Setting, @settingKeys, $key, $val, $keyNum, $i);
	
	$SYS->Set('_TITLE', 'BBS Setting Information');
	
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($SYS);
	
	$Setting->GetKeySet(\@settingKeys);
	@settingKeys = sort @settingKeys;
	$keyNum = @settingKeys;
	push @settingKeys, '';
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	
	for ($i = 0 ; $i < ($keyNum / 2) ; $i++) {
		$key = $settingKeys[$i * 2];
		$val = $Setting->Get($key, '');
		$Page->Print("<tr><td class=\"DetailTitle\">$key</td><td>$val</td>");
		$key = $settingKeys[$i * 2 + 1];
		$val = $Setting->Get($key, '');
		$Page->Print("<td class=\"DetailTitle\">$key</td><td>$val</td></tr>\n");
	}
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	基本設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBaseSetting
{
	my ($Page, $Sys, $Form) = @_;
	my (@threadList, $id);
	my ($BBS, $Category, @bbsSet, @catSet, $name, $category);
	my ($sCat, @belongBBS, $belongID);
	
	$Sys->Set('_TITLE', 'BBS Base Setting');
	
	require './module/setting.pl';
	my $Setting = SETTING->new;
	$Setting->Load($Sys);

	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	$Category = CATEGORY_INFO->new;
	$BBS->Load($Sys);
	$Category->Load($Sys);

	# ユーザ所属のBBS一覧を取得
	$Sys->Get('ADMIN')->{'SECINFO'}->GetBelongBBSList($Sys->Get('ADMIN')->{'USER'}, $BBS, \@belongBBS);
	
	# 掲示板情報を取得
	if ($sCat eq '' || $sCat eq 'ALL') {
		$BBS->GetKeySet('ALL', '', \@bbsSet);
	}
	else {
		$BBS->GetKeySet('CATEGORY', $sCat, \@bbsSet);
	}
	$Category->GetKeySet(\@catSet);
	
	my $setSubTitle		= $Setting->Get('BBS_SUBTITLE');
	my $setKanban		= $Setting->Get('BBS_TITLE_PICTURE');
	my $setKnabanLink	= $Setting->Get('BBS_TITLE_LINK');
	my $setBackPict		= $Setting->Get('BBS_BG_PICTURE');
	my $setBackMascot	= $Setting->Get('BBS_MASCOT');
	my $setNoName		= $Setting->Get('BBS_NONAME_NAME');
	my $setAbone		= $Setting->Get('BBS_DELETE_NAME');
	my $setCookiePath	= $Setting->Get('BBS_COOKIEPATH');
	my $setRefCushion	= $Setting->Get('BBS_REFERER_CUSHION');
	my $setFavicon  	= $Setting->Get('BBS_FAVICON');
<<<<<<< HEAD
=======
	my $setKako		  	= $Setting->Get('BBS_KAKO');
>>>>>>> main
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=2>各設定値を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">サブタイトル</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_SUBTITLE value=\"$setSubTitle\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">index看板画像(フルパス推奨)</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_TITLE_PICTURE value=\"$setKanban\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">index看板リンク</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_TITLE_LINK value=\"$setKnabanLink\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">index背景画像</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_BG_PICTURE value=\"$setBackPict\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">ファビコン画像</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_FAVICON value=\"$setFavicon\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">read.cgi背景マスコット</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_MASCOT value=\"$setBackMascot\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名無しさん</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_NONAME_NAME value=\"$setNoName\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">削除文言</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_DELETE_NAME value=\"$setAbone\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">cookie保存パス</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_COOKIEPATH value=\"$setCookiePath\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">リファラクッション</td><td>");
	$Page->Print("<input type=text size=80 name=BBS_REFERER_CUSHION value=\"$setRefCushion\"></td></tr>");

	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">DAT落ちスレッド保存先</td><td>");
	$Page->Print("<select name=BBS_KAKO required>");
	$Page->Print("<option value=\"\">プール(外部からのアクセス不可)");
	foreach my $listid (@bbsSet) {
		next if ($BBS->Get('DIR', $listid) eq $Sys->Get('BBS'));
		$category	= $Category->Get('NAME', $BBS->Get('CATEGORY', $listid));
		$Page->Print("<optgroup label=\"$category\">");
		foreach $belongID (@belongBBS) {
			if ($listid eq $belongID) {
				my $selKako = $setKako eq $BBS->Get('DIR', $listid) ?  "selected" : "";
				$name		= $BBS->Get('NAME', $listid);
				$Page->Print("<option value=".$BBS->Get('DIR', $listid)." $selKako>$name</option>");
			}
		}
	}
	$Page->Print("</select></td></tr>");

	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left><input type=button value=\"　設定　\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETBASE');\"></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	カラー設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$flg	モード(0:表示 1:確認)
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintColorSetting
{
	my ($Page, $SYS, $Form, $flg) = @_;
	my ($Setting);
	my ($setIndexTitle, $setThreadTitle, $setIndexBG, $setThreadBG, $setCreateBG);
	my ($setMenuBG, $setText, $setLink, $setLinkA, $setLinkV, $setName, $setCap, $setPost, $setType, $selectType,$setHighlight);
	my ($selOri,$sel5ch);
	$SYS->Set('_TITLE', 'BBS Color Setting');
	
	# SETTING.TXTから値を取得
	if ($flg == 0) {
		require './module/setting.pl';
		$Setting = SETTING->new;
		$Setting->Load($SYS);
	}
	# フォーム情報から値を取得
	else {
		$Setting = $Form;
	}
	
	# 設定値を取得
	$setIndexTitle	= $Setting->Get('BBS_TITLE_COLOR');
	$setThreadTitle	= $Setting->Get('BBS_SUBJECT_COLOR');
	$setIndexBG		= $Setting->Get('BBS_BG_COLOR');
	$setThreadBG	= $Setting->Get('BBS_THREAD_COLOR');
	$setCreateBG	= $Setting->Get('BBS_MAKETHREAD_COLOR');
	$setMenuBG		= $Setting->Get('BBS_MENU_COLOR');
	$setText		= $Setting->Get('BBS_TEXT_COLOR');
	$setLink		= $Setting->Get('BBS_LINK_COLOR');
	$setLinkA		= $Setting->Get('BBS_ALINK_COLOR');
	$setLinkV		= $Setting->Get('BBS_VLINK_COLOR');
	$setName		= $Setting->Get('BBS_NAME_COLOR');
	$setCap			= $Setting->Get('BBS_CAP_COLOR');
	$setPost		= $Setting->Get('BBS_POSTCOLOR');
	$setType		= $Setting->Get('BBS_READTYPE');
 	$setHighlight   = $Setting->Get('BBS_HIGHLIGHT');
	
	$selOri			= ($setType eq 'original' ? 'selected' : '');
	$sel5ch			= ($setType eq '5ch' ? 'selected' : '');
	$selectType     ="text";	#"color"でカラーピッカに
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=6>各設定色を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=6><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">index背景色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_BG_COLOR value=\"$setIndexBG\">");
	$Page->Print("</td><td bgcolor=$setIndexBG></td>");
	$Page->Print("<td class=\"DetailTitle\">テキスト色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_TEXT_COLOR value=\"$setText\">");
	$Page->Print("</td><td><font color=$setText>テキスト</font></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">indexメニュー背景色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_MENU_COLOR value=\"$setMenuBG\">");
	$Page->Print("</td><td bgcolor=$setMenuBG></td>");
	$Page->Print("<td class=\"DetailTitle\">名前色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_NAME_COLOR value=\"$setName\">");
	$Page->Print("</td><td><font color=$setName>名前</font></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッド作成背景色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_MAKETHREAD_COLOR value=\"$setCreateBG\">");
	$Page->Print("</td><td bgcolor=$setCreateBG></td>");
	$Page->Print("<td class=\"DetailTitle\">リンク色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_LINK_COLOR value=\"$setLink\">");
	$Page->Print("</td><td><font color=$setLink>リンク</font></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッド背景色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_THREAD_COLOR value=\"$setThreadBG\">");
	$Page->Print("</td><td bgcolor=$setThreadBG></td>");
	$Page->Print("<td class=\"DetailTitle\">リンク色(アンカー時)</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_ALINK_COLOR value=\"$setLinkA\">");
	$Page->Print("</td><td><font color=$setLinkA>リンク(アンカー)</font></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">indexタイトル色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_TITLE_COLOR value=\"$setIndexTitle\">");
	$Page->Print("</td><td><font color=$setIndexTitle>indexタイトル</font></td>");
	$Page->Print("<td class=\"DetailTitle\">リンク色(訪問済み)</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_VLINK_COLOR value=\"$setLinkV\">");
	$Page->Print("</td><td><font color=$setLinkV>リンク(訪問済み)</font></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッドタイトル色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_SUBJECT_COLOR value=\"$setThreadTitle\">");
	$Page->Print("</td><td><font color=$setThreadTitle>スレッドタイトル</font></td>");
	$Page->Print("<td class=\"DetailTitle\">キャップ色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_CAP_COLOR value=\"$setCap\">");
	$Page->Print("</td><td><font color=$setName><font color=$setCap>名前</font></font></td></tr>\n");
	$Page->Print("<tr><td colspan=6><hr></td></tr>");
	$Page->Print("<td class=\"DetailTitle\">レスの表示形式</td><td>");
	$Page->Print("<select name=\"BBS_READTYPE\"><option value=\"original\" $selOri>オリジナル</option><option value=\"5ch\" $sel5ch>5ch風</option></select>");
	$Page->Print("<td class=\"DetailTitle\">レス背景色</td><td>");
	$Page->Print("<input type=$selectType size=10 name=BBS_POSTCOLOR value=\"$setPost\">");
    $Page->Print("<td class=\"DetailTitle\">#と＞を強調</td><td>");
	$Page->Print("<input type=checkbox name=BBS_HIGHLIGHT value=on $setHighlight>有効</td>");
	$Page->Print("<tr><td colspan=6><hr></td></tr>");
	
	# スレッドプレビューの表示
	if ($setType eq "original") {
		$Page->Print("<tr><td class=\"DetailTitle\" colspan=3>indexプレビュー</td>");
		$Page->Print("<td class=\"DetailTitle\" colspan=3>スレッドプレビュー</td></tr>");
		$Page->Print("<tr><td colspan=3 bgcolor=$setIndexBG>");
		$Page->Print("<center><font color=$setIndexTitle>indexタイトル</font><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setMenuBG border><td>ヘッダ</td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setMenuBG border><td>メニュー</td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setThreadBG border><td>");
		$Page->Print("<font color=$setThreadTitle>スレッドタイトル</font><br><br>");
		$Page->Print("<font color=$setText>テキスト</font><br></td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setCreateBG border><td>スレッド作成</td>");
		$Page->Print("</table><br></center></td>");
		$Page->Print("<td colspan=3 bgcolor=$setThreadBG valign=top><font color=$setThreadTitle>");
		$Page->Print("スレッドタイトル</font><br><br>1 <font color=$setName>名前＠<font color=$setCap>キャップ ★</font></font><br>");
		$Page->Print("　<font color=$setText>本文テキスト</font><br>");
		$Page->Print("　<font color=$setLink><u>http://---</u></font><br>");
		$Page->Print("　<font color=$setLinkV><u>http://---</u></font><br><br>");
        if($setHighlight eq 'checked'){
		    $Page->Print("　<font color=green>#ハッシュタグ</font><br>");
		    $Page->Print("　<font color=gray>＞引用</font><br>");
        }
        else{
            $Page->Print("  <font color=$setText>#ハッシュタグ</font><br>");
            $Page->Print("  <font color=$setText>＞引用</font><br>");
        }
		$Page->Print("</td></tr>");
		$Page->Print("<tr><td colspan=6><hr></td></tr>");
	}
	else{
		$Page->Print("<tr><td class=\"DetailTitle\" colspan=3>indexプレビュー</td>");
		$Page->Print("<td class=\"DetailTitle\" colspan=3>スレッドプレビュー</td></tr>");
		$Page->Print("<tr><td colspan=3 bgcolor=$setIndexBG>");
		$Page->Print("<center><font color=$setIndexTitle>indexタイトル</font><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setMenuBG border><td>ヘッダ</td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setMenuBG border><td>メニュー</td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setThreadBG border><td>");
		$Page->Print("<font color=$setThreadTitle>スレッドタイトル</font><br><br>");
		$Page->Print("<font color=$setText>テキスト</font><br></td></table><br>");
		$Page->Print("<table width=100% cellspacing=7 bgcolor=$setCreateBG border><td>スレッド作成</td>");
		$Page->Print("</table><br></center></td>");
		$Page->Print("<td colspan=3 bgcolor=$setThreadBG valign=top><font color=$setThreadTitle>");
		$Page->Print("スレッドタイトル</font><br><br><div class=\"post\" style=\"background-color:$setPost;border-width: 1px;display: inline-block; padding: 8px;border-style: none solid solid none;border-color:#ddd;margin-bottom: 8px;\">1 <font color=$setName>名前＠<font color=$setCap>キャップ ★</font></font><br>");
		$Page->Print("　<font color=$setText>本文テキスト</font><br>");
		$Page->Print("　<font color=$setLink><u>http://---</u></font><br>");
		$Page->Print("　<font color=$setLinkV><u>http://---</u></font><br><br>");
		if($setHighlight eq 'checked'){
		    $Page->Print("　<font color=green>#ハッシュタグ</font><br>");
		    $Page->Print("　<font color=gray>＞引用</font><br>");
        }
        else{
            $Page->Print("  <font color=$setText>#ハッシュタグ</font><br>");
            $Page->Print("  <font color=$setText>＞引用</font><br>");
        }
		$Page->Print("</td></tr>");
		$Page->Print("<tr><td colspan=6><hr></td></tr>");
	}
	$Page->Print("<tr><td colspan=6 align=left>");
	$Page->Print("<input type=button value=\"　設定　\" onclick=\"DoSubmit");
	$Page->Print("('bbs.setting','FUNC','SETCOLOR');\"> ");
	$Page->Print("<input type=button value=\"　確認　\" onclick=\"DoSubmit");
	$Page->Print("('bbs.setting','DISP','SETCOLORC');\">");
	$Page->Print("</td></tr></table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	制限設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintLimitSetting
{
	my ($Page, $Sys, $Form) = @_;
	
	$Sys->Set('_TITLE', 'BBS Limitter Setting');
	
	require './module/setting.pl';
	my $Setting = SETTING->new;
	$Setting->Load($Sys);
	my $DNSBL = $Sys->Get('DNSBL_TOREXIT');
	$DNSBL += $Sys->Get('DNSBL_S5H');
	$DNSBL += $Sys->Get('DNSBL_DRONEBL');
	my $isDNSBL = ($DNSBL?'':'disabled');
	my $setInfo = ($DNSBL == 0 ? 'システム設定でDNSBLが選択されていません' : '有効');
	my $isProxyApi = $Sys->Get('PROXYCHECK_APIKEY') ? '':'disabled';
	my $setInfo2 = $isProxyApi eq 'disabled' ? 'システム設定でAPIキーが設定されていません' : '有効';
	# 設定値を取得
	my $setResMax		= $Setting->Get('BBS_RES_MAX');
	my $setSubMax		= $Setting->Get('BBS_SUBJECT_MAX');		# 最大スレッド数
	my $setSubjectMax	= $Setting->Get('BBS_SUBJECT_COUNT');	# タイトル最大バイト数
	my $setNameMax		= $Setting->Get('BBS_NAME_COUNT');
	my $setMailMax		= $Setting->Get('BBS_MAIL_COUNT');
	my $setContMax		= $Setting->Get('BBS_MESSAGE_COUNT');
	my $setLineMax		= $Setting->Get('BBS_LINE_NUMBER') *2;
	my $setWriteMax		= $Setting->Get('timeclose')||0;
	my $setContinueMax	= $Setting->Get('timecount')||0;
	my $setNoName		= $Setting->Get('NANASHI_CHECK');
	my $setProxy		= $Setting->Get('BBS_PROXY_CHECK');
	my $setDNSBL		= $Setting->Get('BBS_DNSBL_CHECK');
	my $setOverSea		= $Setting->Get('BBS_JP_CHECK');
	my $setTomato		= $Setting->Get('BBS_RAWIP_CHECK');
	
	my $setDatMax		= $Setting->Get('BBS_DATMAX');
	my $setLineLength	= $Setting->Get('BBS_COLUMN_NUMBER');
	my $setReadOnly		= $Setting->Get('BBS_READONLY');
	my $setCapOnly		= $Setting->Get('BBS_THREADCAPONLY');
	my $setThreadMb		= $Setting->Get('BBS_THREADMOBILE');
	my $setSambaTime	= $Setting->Get('BBS_SAMBATIME');
	my $setHoushiTime	= $Setting->Get('BBS_HOUSHITIME');
	my $setTateClose	= $Setting->Get('BBS_THREAD_TATESUGI');
	my $setTateCount2	= $Setting->Get('BBS_TATESUGI_COUNT2');
	my $setTateHour		= $Setting->Get('BBS_TATESUGI_HOUR');
	my $setTateCount	= $Setting->Get('BBS_TATESUGI_COUNT');
	
	my $setAskiiPoint	= $Setting->Get('BBS_SPAMKILLI_ASCII');
	my $setMailPoint	= $Setting->Get('BBS_SPAMKILLI_MAIL');
	my $setHostPoint	= $Setting->Get('BBS_SPAMKILLI_HOST');
	my $setURLPoint		= $Setting->Get('BBS_SPAMKILLI_URL');
	my $setAskiiMessage	= $Setting->Get('BBS_SPAMKILLI_MESSAGE');
	my $setSpamLink		= $Setting->Get('BBS_SPAMKILLI_LINK');
	my $setMesPoint		= $Setting->Get('BBS_SPAMKILLI_MESPOINT');
	my $setDomain		= $Setting->Get('BBS_SPAMKILLI_DOMAIN');
	my $setSpamPoint	= $Setting->Get('BBS_SPAMKILLI_POINT');

	# 改造版で追加
	my $Captcha		= $Setting->Get('BBS_CAPTCHA');
	my $setCapInfo 		= (($Sys->Get('CAPTCHA_SITEKEY') eq undef || $Sys->Get('CAPTCHA_SECRETKEY') eq undef) ? 'Captchaのキーが設定されていません':'有効');
	my $setCap		= ($setCapInfo eq '有効' ? '' : 'style="opacity:0.5"');
	my $selROnone		= ($setReadOnly eq 'none' ? 'selected' : '');
	my $selROcaps		= ($setReadOnly eq 'caps' ? 'selected' : '');
	my $selROon			= ($setReadOnly eq 'on' ? 'selected' : '');
	my $setSameTitle	= $Setting->Get('BBS_SAMETHREAD');
<<<<<<< HEAD
=======
	my $setReverse		= $Setting->Get('BBS_REVERSE_CHECK');
>>>>>>> main
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=4>各設定値を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\">タイトル文字数</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_SUBJECT_COUNT value=\"$setSubjectMax\"></td>");
	$Page->Print("<td class=\"DetailTitle\">メール文字数</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_MAIL_COUNT value=\"$setMailMax\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名前文字数</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_NAME_COUNT value=\"$setNameMax\"></td>");
	$Page->Print("<td class=\"DetailTitle\">本文文字数</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_MESSAGE_COUNT value=\"$setContMax\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">レス1行最大文字数</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_COLUMN_NUMBER value=\"$setLineLength\"></td>");
	$Page->Print("<td class=\"DetailTitle\">datファイル最大サイズ（KB）</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_DATMAX value=\"$setDatMax\"></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">書き込み可能\行数(偶数行)</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_LINE_NUMBER value=\"$setLineMax\"></td>");
	$Page->Print("<td class=\"DetailTitle\">最大スレッド数(無記入=".$Sys->Get('SUBMAX').")</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_SUBJECT_MAX value=\"$setSubMax\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名無しチェック</td><td>");
	$Page->Print("<input type=checkbox name=NANASHI_CHECK $setNoName value=on>有効</td>");
	$Page->Print("<td class=\"DetailTitle\">最大レス数(無記入=".$Sys->Get('RESMAX').")</td><td>");
	$Page->Print("<input type=text size=10 name=BBS_RES_MAX value=\"$setResMax\"></td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\">掲示板書き込み制限</td><td><select name=BBS_READONLY>");
	$Page->Print("<option value=on $selROon>読取専用");
	$Page->Print("<option value=caps $selROcaps>キャップのみ可能");
	$Page->Print("<option value=none $selROnone>書き込み可能");
	$Page->Print("</select></td>");
	$Page->Print("<td class=\"DetailTitle\">DNSBLチェック</td><td>");
	$Page->Print("<input type=checkbox name=BBS_DNSBL_CHECK $setDNSBL value=on $isDNSBL>$setInfo</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッド作成制限(キャップ)</td><td>");
	$Page->Print("<input type=checkbox name=BBS_THREADCAPONLY $setCapOnly value=on>キャップのみ可能\</td>");
	$Page->Print("<td class=\"DetailTitle\">海外ホスト規制</td><td>");
	$Page->Print("<input type=checkbox name=BBS_JP_CHECK $setOverSea value=on>有効</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッド作成制限(携帯)</td><td>");
	$Page->Print("<input type=checkbox name=BBS_THREADMOBILE $setThreadMb value=on>携帯から許可</td>");
<<<<<<< HEAD
	$Page->Print("<td class=\"DetailTitle\">hCaptcha</td><td>");
	$Page->Print("<input type=checkbox name=BBS_HCAPTCHA $hCaptcha value=on $setCap>$setCapInfo</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">同一スレッド名を禁止</td><td>");
	$Page->Print("<input type=checkbox name=BBS_SAMETHREAD value=on $setSameTitle>有効</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"opacity:0.5\">マルチポスト制限</td><td>");
	$Page->Print("<input type=checkbox name=BBS_MULTIPOST value=on disabled></td></tr>");
=======
	$Page->Print("<td class=\"DetailTitle\">Captcha</td><td>");
	$Page->Print("<input type=checkbox name=BBS_CAPTCHA $Captcha value=on $setCap>$setCapInfo</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">同一スレッド名を禁止</td><td>");
	$Page->Print("<input type=checkbox name=BBS_SAMETHREAD value=on $setSameTitle>有効</td>");
	$Page->Print("<td class=\"DetailTitle\">逆引き不可のIPからの投稿を制限</td><td>");
	$Page->Print("<input type=checkbox name=BBS_REVERSE_CHECK value=on $setReverse></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">プロキシ規制</td><td>");
	$Page->Print("<input type=checkbox name=BBS_PROXY_CHECK value=on $setProxy>$setInfo2</td>");
	$Page->Print("<td class=\"DetailTitle\">???</td><td>");
	$Page->Print("<input type=checkbox name= value=on disabled></td></tr>");
>>>>>>> main
	$Page->Print("</tr>");
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=4>連続書き込み規制</td></tr>");
	$Page->Print("<tr><td colspan=4>");
	$Page->Print("直近<input type=text size=5 name=timecount value=\"$setContinueMax\" style=\"text-align: right\">書き込みのうち、");
	$Page->Print("一人が<input type=text size=5 name=timeclose value=\"$setWriteMax\" style=\"text-align: right\">回まで書き込み可");
	$Page->Print("</td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=4>Samba規制</td></tr>");
	$Page->Print("<tr><td colspan=4>");
	$Page->Print("一度書き込んだ人は<input type=text size=5 name=BBS_SAMBATIME value=\"$setSambaTime\" style=\"text-align: right\">秒(0で無効)経たないと書き込めません。(無記入=".$Sys->Get('DEFSAMBA').")<br>");
	$Page->Print("指定秒数を待たず何度も書き込もうとした場合は<input type=text size=5 name=BBS_HOUSHITIME value=\"$setHoushiTime\" style=\"text-align: right\">分間書き込みを禁止します。(無記入=".$Sys->Get('DEFHOUSHI').")");
	$Page->Print("</td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=4>スレッド立てすぎ規制 (時間非依存)</td></tr>");
	$Page->Print("<tr><td colspan=4>");
	$Page->Print("直近<input type=text size=5 name=BBS_THREAD_TATESUGI value=\"$setTateClose\" style=\"text-align: right\">スレッド(0で無効)のうち、");
	$Page->Print("一人が<input type=text size=5 name=BBS_TATESUGI_COUNT2 value=\"$setTateCount2\" style=\"text-align: right\">スレッドまで立てられる");
	$Page->Print("</td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=4>スレッド立てすぎ規制 (時間依存)</td></tr>");
	$Page->Print("<tr><td colspan=4>");
	$Page->Print("<input type=text size=5 name=BBS_TATESUGI_HOUR value=\"$setTateHour\" style=\"text-align: right\">時間(0で無効)に");
	$Page->Print("全体で<input type=text size=5 name=BBS_TATESUGI_COUNT value=\"$setTateCount\" style=\"text-align: right\">スレッドまで立てられる");
	$Page->Print("</td></tr>");
    
    	$Page->Print("<tr><td class=\"DetailTitle\" colspan=4>スパムブロック</td></tr>");
	$Page->Print("<tr><td colspan=4>");
	$Page->Print("名前欄がASCIIのみで<input type=text size=3 name=BBS_SPAMKILL_ASCII value=\"$setAskiiPoint\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("本文のASCIIの割合が<input type=text size=3 name=BBS_SPAMKILL_MESSAGE value=\"$setAskiiMessage\" style=\"text-align: right\" maxlength=\"3\">％以上で");
	$Page->Print("<input type=text size=3 name=BBS_SPAMKILL_MESPOINT value=\"$setMesPoint\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("メール欄に半角＠を含むと<input type=text size=3 name=BBS_SPAMKILL_MAIL value=\"$setMailPoint\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("ホスト名が逆引き不可だと&#009;<input type=text size=3 name=BBS_SPAMKILL_HOST value=\"$setHostPoint\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("本文に<;a href=か[url=を含むと<input type=text size=3 name=BBS_SPAMKILL_URL value=\"$setURLPoint\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("本文にリンクを含むと<input type=text size=3 name=BBS_SPAMKILL_LINK value=\"$setSpamLink\" style=\"text-align: right\" maxlength=\"2\">ポイント加点<br>");
	$Page->Print("（↑が0の時のみ）本文中リンクのTLドメインの種類<input type=text size=30 name=BBS_SPAMKILL_DOMAIN value=\"$setDomain\" style=\"text-align: right\">でポイント加点<br>");
	$Page->Print("合計<input type=text size=3 name=BBS_SPAMKILL_POINT value=\"$setSpamPoint\" style=\"text-align: right\" maxlength=\"3\">ポイントでスパムと判定");
	$Page->Print("</td></tr>");
    
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td colspan=4 align=left><input type=button value=\"　設定　\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETLIMIT');\"></td></tr></table>");
}
#------------------------------------------------------------------------------------------------------------
#
#	コマンド設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCommandSetting
{
	my ($Page, $Sys, $Form) = @_;
	
	$Sys->Set('_TITLE', 'BBS User Command Setting');
	
	require './module/setting.pl';
	my $Setting = SETTING->new;
	$Setting->Load($Sys);
	
	my $setBitMask = $Setting->Get('BBS_COMMAND');
	
	my $setpass = $setBitMask & 1 ? 'checked' : '';
	my $setmaxres = $setBitMask & 2 ? 'checked' : '';
	my $setsage = $setBitMask & 4 ? 'checked' : '';
	my $setnoid = $setBitMask & 8 ? 'checked' : '';
	my $setchangeid = $setBitMask & 16 ? 'checked' : '';
	my $setforce774 = $setBitMask & 32 ? 'checked' : '';
	my $setchange774 = $setBitMask & 64 ? 'checked' : '';
	my $setstop = $setBitMask & 128 ? 'checked' : '';
	my $setdelcmd = $setBitMask & 256 ? 'checked' : '';
	my $setpool = $setBitMask & 512 ? 'checked' : '';
	my $setlive = $setBitMask & 1024 ? 'checked' : '';
	my $setslip = $setBitMask & 2048 ? 'checked' : '';
	my $setban = $setBitMask & 4096 ? 'checked' : '';
	my $setninLv = $setBitMask & 8192 ? 'checked' : '';
	my $setchtt = $setBitMask & 16384 ? 'checked' : '';
	my $sethidenusi = $setBitMask & 32768 ? 'checked' : '';
	my $setadd = $setBitMask & 65536 ? 'checked' : '';
	my $setfloat = $setBitMask & 131072 ? 'checked' : '';
	my $setnopool = $setBitMask & 262144 ? 'checked' : '';
	my $setdelete = $setBitMask & 524288 ? 'checked' : '';
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=4>有効にしたいコマンドにチェックを入れ、[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	
	$Page->Print("<td class=\"DetailTitle\">スレッドパスワード（メール欄!pass:[password]）</td><td>");
	$Page->Print("<input type=checkbox name=PASS value=1 $setpass>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">スレッド最大レス（!maxres:[100-2000]）</td><td>");
	$Page->Print("<input type=checkbox name=MAXRES value=2 $setmaxres>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">強制sage（!sage）</td><td>");
	$Page->Print("<input type=checkbox name=SAGE value=4 $setsage>有効</tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">BBS_SLIP（!slip:[vvv/vvvv/vvvvv/vvvvvv]）</td><td>");
	$Page->Print("<input type=checkbox name=SLIP value=2048 $setslip>有効</tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">ID無し（!noid）</td><td>");
	$Page->Print("<input type=checkbox name=NOID value=8 $setnoid>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">ID変更（!changeid）</td><td>");
	$Page->Print("<input type=checkbox name=CHID value=16 $setchangeid>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">名無し強制（!force774）</td><td>");
	$Page->Print("<input type=checkbox name=FC774 value=32 $setforce774>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">名無し変更（!change774:[名無し]）</td><td>");
	$Page->Print("<input type=checkbox name=CH774 value=64 $setchange774>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">書き込みが一時間なければ過去ログ送り（!live）</td><td>");
	$Page->Print("<input type=checkbox name=LIVE value=1024 $setlive>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">スレ主表示無し（!hidenusi）</td><td>");
	$Page->Print("<input type=checkbox name=NONUSI value=32768 $sethidenusi>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">強制age（!float）</td><td>");
	$Page->Print("<input type=checkbox name=AGE value=131072 $setfloat>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">不落（!nopool）</td><td>");
	$Page->Print("<input type=checkbox name=NOPOOL value=262144 $setnopool>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">忍法帖レベル制限 ※要忍法帖（!ninLv:[レベル]）</td><td>");
	$Page->Print("<input type=checkbox name=NINLV value=8192 $setninLv>有効</td></tr>");

	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td colspan=4>スレッド中のみ</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">スレッドストップ（!stop）</td><td>");
	$Page->Print("<input type=checkbox name=STOP value=128 $setstop>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">過去ログ送り（!pool）</td><td>");
	$Page->Print("<input type=checkbox name=POOL value=512 $setpool>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\"w>コマンド取り消し（!delcmd:[command]）</td><td>");
	$Page->Print("<input type=checkbox name=DELCMD value=256 $setdelcmd>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">アクセス禁止（!ban:[>>レス番]）</td><td>");
	$Page->Print("<input type=checkbox name=BAN value=4096 $setban>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">スレタイ変更（!changetitle:[新スレタイ]）</td><td>");
	$Page->Print("<input type=checkbox name=CHTT value=16384 $setchtt>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">追記（!add:[>>レス番]:[追記内容]）</td><td>");
	$Page->Print("<input type=checkbox name=ADD value=65536 $setadd>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">レス削除（!delete:[>>レス番] </td><td>");
	$Page->Print("<input type=checkbox name=DELETE value=524288 $setdelete>有効</td></tr>");
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td colspan=4 align=left><input type=button value=\"　設定　\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETCOMMAND');\"></td></tr></table>");
}
#------------------------------------------------------------------------------------------------------------
#
#	忍法帖設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinpochoSetting
{
	my ($Page, $Sys, $Form) = @_;
	
	$Sys->Set('_TITLE', 'BBS Ninpocho Setting');
	
	require './module/setting.pl';
	my $Setting = SETTING->new;
	$Setting->Load($Sys);

	my $ninlstat = $Setting->Get('BBS_NINJA') ? '最大Lv：'.$Sys->Get('NINLVMAX') : '無効';
	
	my $setWrite		= $Setting->Get('NINJA_WRITE_MESSAGE');
	my $setSage			= $Setting->Get('NINJA_FORCE_SAGE');

	my ($setThread,$thcost)		= split(/-/,$Setting->Get('NINJA_MAKE_THREAD'));
	my ($setCommand,$comcost)		= split(/-/,$Setting->Get('NINJA_USE_COMMAND'));
	my ($setStop,$stopcost)			= split(/-/,$Setting->Get('NINJA_THREAD_STOP'));
	my ($setBan,$bancost)			= split(/-/,$Setting->Get('NINJA_USER_BAN'));
	my ($setDelete,$delcost)		= split(/-/,$Setting->Get('NINJA_RES_DELETE'));

	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=4>各設定値を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=4><hr><font size=4>忍法帖 $ninlstat</font><hr></td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\">書き込み可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_WRITE_MESSAGE value=\"$setWrite\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\">sageを強制するレベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_FORCE_SAGE value=\"$setSage\">まで</td>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">スレ立て可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_MAKE_THREAD value=\"$setThread\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\">消費レベル</td><td>");
	$Page->Print("<input type=text size=8 name=COST_TH value=\"$thcost\"></td>");
	$Page->Print("<tr><td class=\"DetailTitle\">各種コマンド使用可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_USE_COMMAND value=\"$setCommand\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"opacity: 0.5;\">消費レベル</td><td>");
	$Page->Print("<input type=text size=8 name=COST_COM value=\"$comcost\" disabled></td>");
	$Page->Print("<tr><td class=\"DetailTitle\">スレスト可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_THREAD_STOP value=\"$setStop\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\">消費レベル</td><td>");
	$Page->Print("<input type=text size=8 name=COST_STOP value=\"$stopcost\"></td>");
	$Page->Print("<tr><td class=\"DetailTitle\">BAN可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_USER_BAN value=\"$setBan\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\">消費レベル</td><td>");
	$Page->Print("<input type=text size=8 name=COST_BAN value=\"$bancost\"></td>");
	$Page->Print("<tr><td class=\"DetailTitle\">レス削除可能レベル</td><td>");
	$Page->Print("<input type=text size=8 name=NINJA_RES_DELETE value=\"$setDelete\">以上</td>");
	$Page->Print("<td class=\"DetailTitle\">消費レベル</td><td>");
	$Page->Print("<input type=text size=8 name=COST_DEL value=\"$delcost\"></td>");
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td colspan=4 align=left><input type=button value=\"　設定　\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETNINPOCHO');\"></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	その他設定画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintOtherSetting
{
	my ($Page, $Sys, $Form) = @_;
	
	$Sys->Set('_TITLE', 'BBS Other Setting');
	
	require './module/setting.pl';
	my $Setting = SETTING->new;
	$Setting->Load($Sys);
	
	my $setIPSave		= $Setting->Get('BBS_SLIP');
	my $setIDForce		= $Setting->Get('BBS_FORCE_ID');
	my $setIDNone		= $Setting->Get('BBS_NO_ID');
	my $setIDHost		= $Setting->Get('BBS_DISP_IP');
	my $setIDDisp		= ($setIDForce eq '' && $setIDNone eq '' ? 'checked' : '');
	my $selIDforce		= ($setIDForce eq 'checked' ? 'selected' : '');
	my $selIDnone		= ($setIDNone eq 'checked' ? 'selected' : '');
	my $selIDdisp		= ($setIDDisp eq 'checked' ? 'selected' : '');
	my $selIDhost		= ($setIDHost eq 'checked' ? 'selected' : '');
	my $selIDkarafuto	= ($setIDHost eq 'karafuto' ? 'selected' : '');
	my $selIDsiberia	= ($setIDHost eq 'siberia' ? 'selected' : '');

	my $selSlipNone		= ($setIPSave eq '' ? 'selected' : '');
	my $selSlipChecked	= ($setIPSave eq 'checked' ? 'selected' : '');
	my $selSlipFeature	= ($setIPSave eq 'feature' ? 'selected' : '');
	#my $selSlipVerbose	= ($setIPSave eq 'verbose' ? 'selected' : '');
	my $selSlipVVV		= ($setIPSave eq 'vvv' ? 'selected' : '');
	my $selSlipVVVV		= ($setIPSave eq 'vvvv' ? 'selected' : '');
	my $selSlipVVVVV	= ($setIPSave eq 'vvvvv' ? 'selected' : '');
	my $selSlipVVVVVV	= ($setIPSave eq 'vvvvvv' ? 'selected' : '');
	
	my $setThreadNum	= $Setting->Get('BBS_THREAD_NUMBER');
	my $setContentNum	= $Setting->Get('BBS_CONTENTS_NUMBER');
	my $setContentLine	= $Setting->Get('BBS_INDEX_LINE_NUMBER');
	my $setThreadMenu	= $Setting->Get('BBS_MAX_MENU_THREAD');
	my $setUnicode		= $Setting->Get('BBS_UNICODE');
	my $setCookie		= $Setting->Get('SUBBBS_CGI_ON');
	my $setNameCookie	= $Setting->Get('BBS_NAMECOOKIE_CHECK');
	my $setMailCookie	= $Setting->Get('BBS_MAILCOOKIE_CHECK');
	my $setNewThread	= $Setting->Get('BBS_PASSWORD_CHECK');
	my $setConfirm		= $Setting->Get('BBS_NEWSUBJECT');
	my $setWeek			= $Setting->Get('BBS_YMD_WEEKS');
	my $setTripColumn	= $Setting->Get('BBS_TRIPCOLUMN');
	my $setImgur    	= $Setting->Get('BBS_IMGUR');
	my $setTwitter    	= $Setting->Get('BBS_TWITTER');
	my $setMovie    	= $Setting->Get('BBS_MOVIE');
	my $setURLtoTitle   = $Setting->Get('BBS_URL_TITLE');
	my $setImage    	= $Sys->Get('IMGTAG');
	my $setNinja		= $Setting->Get('BBS_NINJA');
	my $setHideNusi		= $Setting->Get('BBS_HIDENUSI');
	my $setTitleID		= $Setting->Get('BBS_TITLEID');
	
	$setUnicode			= ($setUnicode eq 'pass' ? 'checked' : '');
	$setCookie			= ($setCookie eq '1' ? 'checked' : '');
	$setConfirm			= ($setConfirm eq '1' ? 'checked' : '');
	$setImage			= ($setImage eq '1' ? 'checked' : '');
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=4>各設定値を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	
	$Page->Print("<tr><td class=\"DetailTitle\">ID表示</td><td><select name=ID_DISP>");
	$Page->Print("<option value=BBS_FORCE_ID $selIDforce>強制ID</option>");
	$Page->Print("<option value=BBS_ID_DISP $selIDdisp>任意ID</option>");
	$Page->Print("<option value=BBS_NO_ID $selIDnone>ID表示無し</option>");
	$Page->Print("<option value=BBS_DISP_IP1 $selIDhost>ホスト表\示</option>");
	$Page->Print("<option value=BBS_DISP_IP2 $selIDkarafuto>発信元表示(樺太)</option>");
	$Page->Print("<option value=BBS_DISP_IP3 $selIDsiberia>発信元表示(シベリア)</option>");
	$Page->Print("</select></td>");
	$Page->Print("<td class=\"DetailTitle\">忍法帖</td><td>");
	$Page->Print("<input type=checkbox name=BBS_NINJA value=on $setNinja>有効</td>");
	$Page->Print("<tr><td class=\"DetailTitle\">機種識別子(BBS_SLIP)</td><td><select name=BBS_SLIP>");
	$Page->Print("<option value=\"\" $selSlipNone>なし</option>");
	$Page->Print("<option value=checked $selSlipChecked>ID末尾簡易表示</option>");
	$Page->Print("<option value=feature $selSlipFeature>ID末尾標準表示</option>");
	#$Page->Print("<option value=verbose $selSlipVerbose>ID末尾詳細表示</option>");
	$Page->Print("<option value=vvv $selSlipVVV>ﾜｯﾁｮｲ</option>");
	$Page->Print("<option value=vvvv $selSlipVVVV>ﾜｯﾁｮｲ+IP</option>");
	$Page->Print("<option value=vvvvv $selSlipVVVVV>ﾜｯﾁｮｲ+KOROKORO</option>");
	$Page->Print("<option value=vvvvvv $selSlipVVVVVV>ﾜｯﾁｮｲ+KOROKORO+IP</option>");
	$Page->Print("</select></td>");
	$Page->Print("<td class=\"DetailTitle\">スレ主表示を隠す</td><td>");
	$Page->Print("<input type=checkbox name=BBS_HIDENUSI value=on $setHideNusi>有効</td>");

	$Page->Print("<tr><td class=\"DetailTitle\">曜日文字</td><td>");
	$Page->Print("<input type=text size=20 name=BBS_YMD_WEEKS value=\"$setWeek\"></td>");
	$Page->Print("<td class=\"DetailTitle\"><s>文字参照</s></td><td>");
	$Page->Print("<input type=checkbox name=BBS_UNICODE $setUnicode value=on>使用可能\</td>");
	
	$Page->Print("<tr><td class=\"DetailTitle\">トリップ桁数</td><td>");
	$Page->Print("<input type=text size=8 name=BBS_TRIPCOLUMN value=\"$setTripColumn\"></td>");
	$Page->Print("<td class=\"DetailTitle\">cookie確認</td><td>");
	$Page->Print("<input type=checkbox name=SUBBBS_CGI_ON $setCookie value=on>確認あり</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">indexスレッドプレビュー数</td><td>");
	$Page->Print("<input type=text size=8 name=BBS_THREAD_NUMBER value=\"$setThreadNum\"></td>");
	$Page->Print("<td class=\"DetailTitle\">　　名前cookie保存</td><td>");
	$Page->Print("<input type=checkbox name=BBS_NAMECOOKIE_CHECK $setNameCookie value=on>保存</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">indexプレビューレス数</td><td>");
	$Page->Print("<input type=text size=8 name=BBS_CONTENTS_NUMBER value=\"$setContentNum\"></td>");
	$Page->Print("<td class=\"DetailTitle\">　　メールcookie保存</td><td>");
	$Page->Print("<input type=checkbox name=BBS_MAILCOOKIE_CHECK $setMailCookie value=on>保存</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">indexレス内容表\示行数(注)</td><td>");
	$Page->Print("<input type=text size=8 name=BBS_INDEX_LINE_NUMBER value=\"$setContentLine\"></td>");
	$Page->Print("<td class=\"DetailTitle\">スレッド作成画面</td><td>");
	$Page->Print("<input type=checkbox name=BBS_PASSWORD_CHECK $setNewThread value=on>別画面</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">indexメニュー数</td><td>");
	$Page->Print("<input type=text size=8 name=BBS_MAX_MENU_THREAD value=\"$setThreadMenu\"></td>");
	$Page->Print("<td class=\"DetailTitle\">スレッド作成確認画面</td><td>");
	$Page->Print("<input type=checkbox name=BBS_NEWSUBJECT $setConfirm value=on>確認あり</td></tr>");
    
    $Page->Print("<tr><td rowspan=6 class=\"DetailTitle\"></td><td rowspan=6>");
	$Page->Print("</td>");
	$Page->Print("<td class=\"DetailTitle\">一般画像埋め込み表示</td><td>");
	$Page->Print("<input type=checkbox name=IMGTAG value=on disabled $setImage>システム設定に依存</tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">Imgur 埋め込み表示</td><td>");
	$Page->Print("<input type=checkbox name=BBS_IMGUR value=on $setImgur>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">X(旧Twitter) 埋め込み表示</td><td>");
	$Page->Print("<input type=checkbox name=BBS_TWITTER value=on $setTwitter>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">Youtube/niconico 埋め込み表示</td><td>");
	$Page->Print("<input type=checkbox name=BBS_MOVIE value=on $setMovie>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">本文中スレURLをスレタイに変換</td><td>");
	$Page->Print("<input type=checkbox name=BBS_URL_TITLE value=on $setURLtoTitle>有効</td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\">スレタイにIDを付加</td><td>");
	$Page->Print("<input type=checkbox name=BBS_TITLEID value=on $setTitleID>有効</td></tr>");
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>");
	$Page->Print("<tr><td colspan=4 align=left><input type=button value=\"　設定　\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETOTHER');\"></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	インポート画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$BBS	BBS情報
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintSettingImport
{
	my ($Page, $SYS, $Form, $BBS) = @_;
	my (@bbsSet, $id, $name);
	
	$SYS->Set('_TITLE', 'BBS Setting Import');
	
	# 所属BBSを取得
	$SYS->Get('ADMIN')->{'SECINFO'}->GetBelongBBSList($SYS->Get('ADMIN')->{'USER'}, $BBS, \@bbsSet);
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\"><input type=radio name=IMPORT_KIND value=FROM_BBS");
	$Page->Print(" checked>既存BBSからインポート</td>");
	$Page->Print("<td><select name=IMPORT_BBS><option value=\"\">--掲示板を選択--</option>");
	
	# 掲示板一覧の出力
	foreach $id (@bbsSet) {
		$name = $BBS->Get('NAME', $id);
		$Page->Print("<option value=$id>$name</option>\n");
	}
	
	$Page->Print("</select></td></tr>");
	$Page->Print("<tr><td valign=top class=\"DetailTitle\">");
	$Page->Print("<input type=radio name=IMPORT_KIND value=FROM_DIRECT>直接インポート</td>");
	$Page->Print("<td><textarea rows=10 cols=60 wrap=off name=IMPORT_DIRECT></textarea></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left><input type=button value=\"インポート\"");
	$Page->Print("onclick=\"DoSubmit('bbs.setting','FUNC','SETIMPORT');\"></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	基本設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionBaseSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = qw(BBS_SUBTITLE BBS_NONAME_NAME BBS_DELETE_NAME BBS_COOKIEPATH);
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		foreach (@inList) {
			push @$pLog, "「$_」を「" . $Form->Get($_) . '」に設定';
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	$Setting->Set('BBS_SUBTITLE', $Form->Get('BBS_SUBTITLE'));
	$Setting->Set('BBS_TITLE_PICTURE', $Form->Get('BBS_TITLE_PICTURE'));
	$Setting->Set('BBS_TITLE_LINK', $Form->Get('BBS_TITLE_LINK'));
	$Setting->Set('BBS_BG_PICTURE', $Form->Get('BBS_BG_PICTURE'));
	$Setting->Set('BBS_FAVICON', $Form->Get('BBS_FAVICON'));
	$Setting->Set('BBS_MASCOT', $Form->Get('BBS_MASCOT'));
	$Setting->Set('BBS_NONAME_NAME', $Form->Get('BBS_NONAME_NAME'));
	$Setting->Set('BBS_DELETE_NAME', $Form->Get('BBS_DELETE_NAME'));
	$Setting->Set('BBS_COOKIEPATH', $Form->Get('BBS_COOKIEPATH'));
	$Setting->Set('BBS_REFERER_CUSHION', $Form->Get('BBS_REFERER_CUSHION'));
	$Setting->Set('BBS_KAKO', $Form->Get('BBS_KAKO'));
	
	$Setting->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	カラー設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionColorSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting, $capColor);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('BBS_TITLE_COLOR', 'BBS_SUBJECT_COLOR', 'BBS_BG_COLOR', 'BBS_THREAD_COLOR',
						'BBS_MAKETHREAD_COLOR', 'BBS_MENU_COLOR', 'BBS_TEXT_COLOR', 'BBS_LINK_COLOR',
						'BBS_ALINK_COLOR', 'BBS_VLINK_COLOR', 'BBS_NAME_COLOR','BBS_READTYPE','BBS_POSTCOLOR');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		foreach (@inList, 'BBS_CAP_COLOR') {
			push @$pLog, "「$_」を「" . $Form->Get($_) . '」に設定';
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	$Setting->Set('BBS_TITLE_COLOR', $Form->Get('BBS_TITLE_COLOR'));
	$Setting->Set('BBS_SUBJECT_COLOR', $Form->Get('BBS_SUBJECT_COLOR'));
	$Setting->Set('BBS_BG_COLOR', $Form->Get('BBS_BG_COLOR'));
	$Setting->Set('BBS_THREAD_COLOR', $Form->Get('BBS_THREAD_COLOR'));
	$Setting->Set('BBS_MAKETHREAD_COLOR', $Form->Get('BBS_MAKETHREAD_COLOR'));
	$Setting->Set('BBS_MENU_COLOR', $Form->Get('BBS_MENU_COLOR'));
	$Setting->Set('BBS_TEXT_COLOR', $Form->Get('BBS_TEXT_COLOR'));
	$Setting->Set('BBS_LINK_COLOR', $Form->Get('BBS_LINK_COLOR'));
	$Setting->Set('BBS_ALINK_COLOR', $Form->Get('BBS_ALINK_COLOR'));
	$Setting->Set('BBS_VLINK_COLOR', $Form->Get('BBS_VLINK_COLOR'));
	$Setting->Set('BBS_NAME_COLOR', $Form->Get('BBS_NAME_COLOR'));
	$capColor = $Form->Get('BBS_CAP_COLOR');
	$capColor =~ s/[^\w\d\#]//ig;
	$Setting->Set('BBS_CAP_COLOR', $capColor);
	$Setting->Set('BBS_READTYPE', $Form->Get('BBS_READTYPE'));
	$Setting->Set('BBS_POSTCOLOR', $Form->Get('BBS_POSTCOLOR'));
    $Setting->Set('BBS_HIGHLIGHT', ($Form->Equal('BBS_HIGHLIGHT', 'on') ? 'checked' : ''));
	
	$Setting->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	制限設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionLimitSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting);
	my $DNSBL = $Sys->Get('DNSBL_TOREXIT');
	$DNSBL += $Sys->Get('DNSBL_S5H');
	$DNSBL += $Sys->Get('DNSBL_DRONEBL');
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my $bbsLN;
		$bbsLN = $Form->Get('BBS_LINE_NUMBER') /2;
		$bbsLN = ( $bbsLN == int($bbsLN) ? $bbsLN : int($bbsLN+1) );
		$Form->Set( 'BBS_LINE_NUMBER', $bbsLN );

		my @inList = qw(BBS_SUBJECT_COUNT BBS_NAME_COUNT BBS_MAIL_COUNT BBS_MESSAGE_COUNT
						BBS_LINE_NUMBER BBS_COLUMN_NUMBER BBS_DATMAX
						timecount timeclose BBS_THREAD_TATESUGI BBS_TATESUGI_COUNT2
						BBS_TATESUGI_HOUR BBS_TATESUGI_COUNT BBS_SPAMKILL_ASCII BBS_SPAMKILL_MAIL
						BBS_SPAMKILL_HOST BBS_SPAMKILL_URL BBS_SPAMKILL_MESSAGE BBS_SPAMKILL_LINK
						BBS_SPAMKILL_MESPOINT BBS_SPAMKILL_POINT);
		# 入力有無
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		# 規定外文字
		if (!$Form->IsNumber(\@inList)) {
			return 1002;
		}
		foreach (@inList) {
			push @$pLog, "「$_」を「" . $Form->Get($_) . '」に設定';
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	if ( $Form->Get('timeclose') eq 0 && $Form->Get('timecount') eq 0 ) {
		$Form->Set('timeclose' ,'');
		$Form->Set('timecount' ,'');
	}
	
	$Setting->Set('BBS_SUBJECT_MAX', $Form->Get('BBS_SUBJECT_MAX'));
	$Setting->Set('BBS_RES_MAX', $Form->Get('BBS_RES_MAX'));
	$Setting->Set('BBS_SUBJECT_COUNT', $Form->Get('BBS_SUBJECT_COUNT'));
	$Setting->Set('BBS_NAME_COUNT', $Form->Get('BBS_NAME_COUNT'));
	$Setting->Set('BBS_MAIL_COUNT', $Form->Get('BBS_MAIL_COUNT'));
	$Setting->Set('BBS_MESSAGE_COUNT', $Form->Get('BBS_MESSAGE_COUNT'));
	$Setting->Set('BBS_LINE_NUMBER',$Form->Get('BBS_LINE_NUMBER'));
	$Setting->Set('timecount', $Form->Get('timecount'));
	$Setting->Set('timeclose', $Form->Get('timeclose'));
	$Setting->Set('NANASHI_CHECK', ($Form->Equal('NANASHI_CHECK', 'on') ? 'checked' : ''));
	if($Sys->Get('PROXYCHECK_APIKEY')){
	$Setting->Set('BBS_PROXY_CHECK', ($Form->Equal('BBS_PROXY_CHECK', 'on') ? 'checked' : ''));
	}
	if($DNSBL != 0){
	$Setting->Set('BBS_DNSBL_CHECK', ($Form->Equal('BBS_DNSBL_CHECK', 'on') ? 'checked' : ''));
	}
	$Setting->Set('BBS_JP_CHECK', ($Form->Equal('BBS_JP_CHECK', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_RAWIP_CHECK', ($Form->Equal('BBS_RAWIP_CHECK', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_DATMAX', $Form->Get('BBS_DATMAX'));
	$Setting->Set('BBS_COLUMN_NUMBER', $Form->Get('BBS_COLUMN_NUMBER'));
	$Setting->Set('BBS_READONLY', $Form->Get('BBS_READONLY'));
	$Setting->Set('BBS_THREADCAPONLY', ($Form->Equal('BBS_THREADCAPONLY', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_THREADMOBILE', ($Form->Equal('BBS_THREADMOBILE', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_SAMBATIME', $Form->Get('BBS_SAMBATIME'));
	$Setting->Set('BBS_HOUSHITIME', $Form->Get('BBS_HOUSHITIME'));
	$Setting->Set('BBS_THREAD_TATESUGI', $Form->Get('BBS_THREAD_TATESUGI'));
	$Setting->Set('BBS_TATESUGI_HOUR', $Form->Get('BBS_TATESUGI_HOUR'));
	$Setting->Set('BBS_TATESUGI_COUNT', $Form->Get('BBS_TATESUGI_COUNT'));
	$Setting->Set('BBS_TATESUGI_COUNT2', $Form->Get('BBS_TATESUGI_COUNT2'));

	$Setting->Set('BBS_SPAMKILLI_ASKII', $Form->Get('BBS_SPAMKILL_ASCII'));
	$Setting->Set('BBS_SPAMKILLI_MAIL', $Form->Get('BBS_SPAMKILL_MAIL'));
	$Setting->Set('BBS_SPAMKILLI_HOST', $Form->Get('BBS_SPAMKILL_HOST'));
	$Setting->Set('BBS_SPAMKILLI_URL', $Form->Get('BBS_SPAMKILL_URL'));
	$Setting->Set('BBS_SPAMKILLI_MESSAGE', $Form->Get('BBS_SPAMKILL_MESSAGE'));
	$Setting->Set('BBS_SPAMKILLI_LINK', $Form->Get('BBS_SPAMKILL_LINK'));
	$Setting->Set('BBS_SPAMKILLI_MESPOINT', $Form->Get('BBS_SPAMKILL_MESPOINT'));
	$Setting->Set('BBS_SPAMKILLI_DOMAIN', $Form->Get('BBS_SPAMKILL_DOMAIN'));
	$Setting->Set('BBS_SPAMKILLI_POINT', $Form->Get('BBS_SPAMKILL_POINT'));

	# 改造版で追加
<<<<<<< HEAD
	$Setting->Set('BBS_HCAPTCHA', ($Form->Equal('BBS_HCAPTCHA', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_SAMETHREAD', ($Form->Equal('BBS_SAMETHREAD', 'on') ? 'checked' : ''));
=======
	$Setting->Set('BBS_CAPTCHA', ($Form->Equal('BBS_CAPTCHA', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_SAMETHREAD', ($Form->Equal('BBS_SAMETHREAD', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_REVERSE_CHECK', ($Form->Equal('BBS_REVERSE_CHECK', 'on') ? 'checked' : ''));
>>>>>>> main

	$Setting->Save($Sys);
	
	return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	コマンド設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionCommandSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	my $commandSet = 0;
	my @inList = qw(PASS MAXRES SAGE SLIP NOID CHID FC774 CH774 LIVE 
					NONUSI AGE NOPOOL NINLV STOP POOL DELCMD BAN CHTT ADD DELETE);

	foreach (@inList) {
		# 入力チェック	
		my $status = $Form->Get($_) ?  '有効' : '無効';
		$commandSet |= $Form->Get($_);
		push @$pLog, "「$_」を「" . $status. '」に設定';
	}
	
	$Setting->Set('BBS_COMMAND', $commandSet);
	$Setting->Save($Sys);
	
	return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	忍法帖設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionNinpochoSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = qw(NINJA_WRITE_MESSAGE NINJA_FORCE_SAGE NINJA_MAKE_THREAD NINJA_USER_BAN
		 NINJA_USE_COMMAND NINJA_THREAD_STOP NINJA_RES_DELETE);
		foreach (@inList) {
			push @$pLog, "「$_」を「" . $Form->Get($_) . '」に設定';
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	$Setting->Set('NINJA_WRITE_MESSAGE', $Form->Get('NINJA_WRITE_MESSAGE'));
	$Setting->Set('NINJA_FORCE_SAGE', $Form->Get('NINJA_FORCE_SAGE'));
	$Setting->Set('NINJA_MAKE_THREAD', $Form->Get('NINJA_MAKE_THREAD').'-'.$Form->Get('COST_TH'));
	$Setting->Set('NINJA_USER_BAN', $Form->Get('NINJA_USER_BAN').'-'.$Form->Get('COST_BAN'));
	$Setting->Set('NINJA_USE_COMMAND', $Form->Get('NINJA_USE_COMMAND').'-'.$Form->Get('COST_COM'));
	$Setting->Set('NINJA_THREAD_STOP', $Form->Get('NINJA_THREAD_STOP').'-'.$Form->Get('COST_STOP'));
	$Setting->Set('NINJA_RES_DELETE', $Form->Get('NINJA_RES_DELETE').'-'.$Form->Get('COST_DEL'));

	$Setting->Save($Sys);
	
	return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	その他設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionOtherSetting
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Setting);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = qw(BBS_THREAD_NUMBER BBS_CONTENTS_NUMBER BBS_INDEX_LINE_NUMBER BBS_MAX_MENU_THREAD BBS_TRIPCOLUMN);
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		foreach (@inList) {
			push @$pLog, "「$_」を「" . $Form->Get($_) . '」に設定';
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	$Setting->Set('BBS_THREAD_NUMBER', $Form->Get('BBS_THREAD_NUMBER'));
	$Setting->Set('BBS_CONTENTS_NUMBER', $Form->Get('BBS_CONTENTS_NUMBER'));
	$Setting->Set('BBS_INDEX_LINE_NUMBER', $Form->Get('BBS_INDEX_LINE_NUMBER'));
	$Setting->Set('BBS_MAX_MENU_THREAD', $Form->Get('BBS_MAX_MENU_THREAD'));
	$Setting->Set('BBS_UNICODE', ($Form->Equal('BBS_UNICODE', 'on') ? 'pass' : 'change'));
	$Setting->Set('SUBBBS_CGI_ON', ($Form->Equal('SUBBBS_CGI_ON', 'on') ? '1' : ''));
	$Setting->Set('BBS_NAMECOOKIE_CHECK', ($Form->Equal('BBS_NAMECOOKIE_CHECK', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_MAILCOOKIE_CHECK', ($Form->Equal('BBS_MAILCOOKIE_CHECK', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_PASSWORD_CHECK', ($Form->Equal('BBS_PASSWORD_CHECK', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_NEWSUBJECT', ($Form->Equal('BBS_NEWSUBJECT', 'on') ? '1' : ''));
	$Setting->Set('BBS_YMD_WEEKS', $Form->Get('BBS_YMD_WEEKS'));
	$Setting->Set('BBS_TRIPCOLUMN', $Form->Get('BBS_TRIPCOLUMN'));
<<<<<<< HEAD
	$Setting->Set('BBS_SLIP', ($Form->Equal('BBS_SLIP', 'on') ? 'checked' : ''));

    	$Setting->Set('BBS_IMGUR', ($Form->Equal('BBS_IMGUR', 'on') ? 'checked' : ''));
    	$Setting->Set('BBS_MOVIE', ($Form->Equal('BBS_MOVIE', 'on') ? 'checked' : ''));
    	$Setting->Set('BBS_TWITTER', ($Form->Equal('BBS_TWITTER', 'on') ? 'checked' : ''));
    	$Setting->Set('BBS_URL_TITLE', ($Form->Equal('BBS_URL_TITLE', 'on') ? 'checked' : ''));
    	#$Setting->Set('BBS_VIDEO', ($Form->Equal('BBS_VIDEO', 'on') ? 'checked' : ''));
=======
	$Setting->Set('BBS_SLIP', $Form->Get('BBS_SLIP'));
	$Setting->Set('BBS_NINJA', ($Form->Equal('BBS_NINJA', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_HIDENUSI', ($Form->Equal('BBS_HIDENUSI', 'on') ? 'checked' : ''));
    $Setting->Set('BBS_IMGUR', ($Form->Equal('BBS_IMGUR', 'on') ? 'checked' : ''));
    $Setting->Set('BBS_MOVIE', ($Form->Equal('BBS_MOVIE', 'on') ? 'checked' : ''));
    $Setting->Set('BBS_TWITTER', ($Form->Equal('BBS_TWITTER', 'on') ? 'checked' : ''));
    $Setting->Set('BBS_URL_TITLE', ($Form->Equal('BBS_URL_TITLE', 'on') ? 'checked' : ''));
	$Setting->Set('BBS_TITLEID', ($Form->Equal('BBS_TITLEID', 'on') ? 'checked' : ''));
    #$Setting->Set('BBS_VIDEO', ($Form->Equal('BBS_VIDEO', 'on') ? 'checked' : ''));
>>>>>>> main
	
	# ID表示設定
	my %settings_map = (
    'BBS_DISP_IP1' => { 'BBS_DISP_IP' => 'checked', 'BBS_FORCE_ID' => '', 'BBS_NO_ID' => '' },	#ホスト表示
    'BBS_DISP_IP2' => { 'BBS_DISP_IP' => 'karafuto', 'BBS_FORCE_ID' => '', 'BBS_NO_ID' => '' },	#発信元表示(樺太)
    'BBS_DISP_IP3' => { 'BBS_DISP_IP' => 'siberia', 'BBS_FORCE_ID' => '', 'BBS_NO_ID' => '' },	#発信元表示(シベリア)
    'BBS_FORCE_ID' => { 'BBS_DISP_IP' => '', 'BBS_FORCE_ID' => 'checked', 'BBS_NO_ID' => '' },	#強制ID
    'BBS_NO_ID'    => { 'BBS_DISP_IP' => '', 'BBS_FORCE_ID' => '', 'BBS_NO_ID' => 'checked' },	#ID表示なし
	);

	if (my $settings = $settings_map{$Form->Get('ID_DISP')}) {
		while (my ($key, $value) = each %$settings) {
			$Setting->Set($key, $value);
		}
	} else {
		$Setting->Set('BBS_DISP_IP', '');
		$Setting->Set('BBS_FORCE_ID', '');
		$Setting->Set('BBS_NO_ID', '');
	}
	
	
	$Setting->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	設定インポート
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionSettingImport
{
	my ($Sys, $Form, $pLog, $BBS) = @_;
	my ($Setting, @setKeys, @importKeys, $key);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSSETTING, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('IMPORT_BBS');
		
		# 既存掲示板からのインポート時のみ
		if ($Form->Equal('IMPORT_KIND', 'FROM_BBS')) {
			# 入力有無
			if (! $Form->IsInput(\@inList)) {
				return 1001;
			}
		}
	}
	require './module/setting.pl';
	$Setting = SETTING->new;
	$Setting->Load($Sys);
	
	# importするキーを設定する
	$Setting->GetKeySet(\@setKeys);
	foreach (@setKeys) {
		if ($_ ne 'BBS_TITLE' && $_ ne 'BBS_SUBTITLE') {
			push @importKeys, $_;
		}
	}
	
	# 既存BBSからインポート
	if ($Form->Equal('IMPORT_KIND', 'FROM_BBS')) {
		my $bbs = $BBS->Get('DIR', $Form->Get('IMPORT_BBS'));
		my $baseSetting = SETTING->new;
		my $path = $Sys->Get('BBSPATH') . "/$bbs/SETTING.TXT";
		
		push @$pLog, "■掲示板「$path」から設定情報をインポートします。";
		
		# 既存BBSのSETTING.TXTを読み込む
		if ($baseSetting->LoadFrom($path)) {
			# 設定情報を設定する
			foreach $key (@importKeys) {
				$Setting->Set($key, $baseSetting->Get($key));
				push @$pLog, "　　「$key」をインポートしました。";
			}
		}
	}
	# 直接インポート
	else {
		my $data = $Form->Get('IMPORT_DIRECT');
		my @datas = split(/\r\n|\r|\n/, $data);
		my (%setTemp, $line, $inKey);
		
		push @$pLog, '■入力内容をインポートします。';
		
		# フォーム情報から設定情報ハッシュを作成する
		foreach $line (@datas){
			($key, $data) = split(/=/, $line);
			$setTemp{$key} = $data;
		}
		# 設定情報を設定する
		foreach $key (keys %setTemp) {
			foreach $inKey (@importKeys) {
				if ($key eq $inKey) {
					$Setting->Set($key, $setTemp{$key});
					push @$pLog, "　　「$key」をインポートしました。";
				}
			}
		}
	}
	# 更新後保存
	$Setting->Save($Sys);
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
