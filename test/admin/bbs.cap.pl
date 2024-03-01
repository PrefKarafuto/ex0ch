#============================================================================================================
#
#	掲示板管理 - キャップグループ モジュール
#	bbs.cap.pl
#	---------------------------------------------------------------------------
#	2004.07.17 start
#
#	EXぜろちゃんねる
#	2010.08.12 キャップ権限追加
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
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
		'LOG' => \@LOG
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
	if (! defined $BBS){
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
	
	if ($subMode eq 'LIST') {													# グループ一覧画面
		PrintGroupList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'CREATE') {													# グループ作成画面
		PrintGroupSetting($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'EDIT') {													# グループ編集画面
		PrintGroupSetting($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'DELETE') {													# グループ削除確認画面
		PrintGroupDelete($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'IMPORT') {													# グループインポート画面
		PrintGroupImport($Page, $Sys, $Form, $BBS);
	}
	elsif ($subMode eq 'COMPLETE') {												# グループ設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('キャップグループ処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# グループ設定失敗画面
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
	$pSys->{'SECINFO'}->SetGroupInfo($Sys->Get('BBS'));
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 9999;
	
	if ($subMode eq 'CREATE') {													# グループ作成
		$err = FunctionGroupSetting($Sys, $Form, 0, $this->{'LOG'});
	}
	elsif ($subMode eq 'EDIT') {													# グループ編集
		$err = FunctionGroupSetting($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {													# グループ削除
		$err = FunctionGroupDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'IMPORT') {													# グループインポート
		$err = FunctionGroupImport($Sys, $Form, $this->{'LOG'}, $BBS);
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "CAP_GROUP($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "CAP_GROUP($subMode)", 'COMPLETE');
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
	
	$Base->SetMenu('グループ一覧', "'bbs.cap','DISP','LIST'");
	
	# 管理グループ設定権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_CAPGROUP, $bbs)) {
		$Base->SetMenu('グループ登録', "'bbs.cap','DISP','CREATE'");
		$Base->SetMenu('グループインポート', "'bbs.cap','DISP','IMPORT'");
	}
	$Base->SetMenu('<hr>', '');
	$Base->SetMenu('システム管理へ戻る', "'sys.bbs','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintGroupList
{
	my ($Page, $Sys, $Form) = @_;
	my ($Group, $BBS, @groupSet, @user, $name, $expl, $color, $id, $common, $isAuth, $n);
	
	$Sys->Set('_TITLE', 'CAP Group List');
	
	require './module/cap.pl';
	$Group = CAP_GROUP->new;
	
	# グループ情報の読み込み
	$Group->Load($Sys);
	$Group->GetKeySet(\@groupSet);
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td style=\"width:30\">　</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">Group Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Subscription</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30\">Cap Color</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30\">Caps</td></tr>\n");
	
	# 権限取得
	$isAuth = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_CAPGROUP, $Sys->Get('BBS'));
	
	# グループ一覧を出力
	foreach $id (@groupSet) {
		$name = $Group->Get('NAME', $id);
		$expl = $Group->Get('EXPL', $id);
		$color = $Group->Get('COLOR', $id);
		@user = split(/\,/, (defined ($_ = $Group->Get('CAPS', $id)) ? $_ : ''));
		$n = @user;
		
		$common = "\"javascript:SetOption('SELECT_CAPGROUP', '$id');";
		$common .= "DoSubmit('bbs.cap', 'DISP', 'EDIT')\"";
		
		# 権限によって表示を抑制
		$Page->Print("<tr><td><input type=checkbox name=CAP_GROUPS value=$id></td>");
		if ($isAuth) {
			$Page->Print("<td><a href=$common>$name</a></td><td>$expl</td><td>$color</td><td>$n</td></tr>\n");
		}
		else {
			$Page->Print("<td>$name</td><td>$expl</td><td>$color</td><td>$n</td></tr>\n");
		}
	}
	$common = "onclick=\"DoSubmit('bbs.cap', 'DISP'";
	
	$Page->HTMLInput('hidden', 'SELECT_CAPGROUP', '');
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$Page->Print("<tr><td colspan=5 align=left>");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ設定の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	作成の場合:0, 編集の場合:1
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintGroupSetting
{
	my ($Page, $Sys, $Form, $mode) = @_;
	my ($Group, $User, @userSet, @authNum, $i, $num, $id);
	my ($name, $expl, $color, @auth, @user, $common);
	
	$Sys->Set('_TITLE', 'CAP Group Edit')	if ($mode == 1);
	$Sys->Set('_TITLE', 'CAP Group Create')	if ($mode == 0);
	
	require './module/cap.pl';
	$User = CAP->new;
	$Group = CAP_GROUP->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	$Group->Load($Sys);
	$User->GetKeySet('ALL', '', \@userSet);
	
	# 編集モードならユーザ情報を取得する
	if ($mode) {
		$name = $Group->Get('NAME', $Form->Get('SELECT_CAPGROUP'));
		$expl = $Group->Get('EXPL', $Form->Get('SELECT_CAPGROUP'));
		$color = $Group->Get('COLOR', $Form->Get('SELECT_CAPGROUP'));
		@auth = split(/\,/, (defined ($_ = $Group->Get('AUTH', $Form->Get('SELECT_CAPGROUP'))) ? $_ : ''));
		@user = split(/\,/, (defined ($_ = $Group->Get('CAPS', $Form->Get('SELECT_CAPGROUP'))) ? $_ : ''));
		
		# 権限番号マッピング配列を作成
		for ($i = 0 ; $i < $ZP::CAP_MAXNUM ; $i++) {
			$authNum[$i] = '';
		}
		foreach $num (@auth) {
			$authNum[$num - 1] = 'checked';
		}
	}
	else {
		$Form->Set('SELECT_CAPGROUP', '');
		$name = '';
		$expl = '';
		$color = '';
		for ($i = 0 ; $i < $ZP::CAP_MAXNUM ; $i++) {
			$authNum[$i] = '';
		}
	}
	
	$Page->Print("<center><br><table border=0 cellspacing=2 width=90%>");
	$Page->Print("<tr><td colspan=2>各情報を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>基本情報</td></tr>");
	$Page->Print("<tr><td colspan=2><table cellspcing=2>");
	$Page->Print("<tr><td class=\"DetailTitle\">グループ名称</td><td>");
	$Page->Print("<input name=GROUPNAME_CAP type=text size=50 value=\"$name\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">説明</td><td>");
	$Page->Print("<input name=GROUPSUBS_CAP type=text size=50 value=\"$expl\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">キャップの色(無記入でデフォルト)</td><td>");
	$Page->Print("<input name=GROUPCOLOR_CAP type=text size=50 value=\"$color\"></td></tr>");
	$Page->Print("</table><br></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\" width=40%>権限情報</td>");
	$Page->Print("<td class=\"DetailTitle\">所属キャップ</td></tr><tr><td valign=top>");
	
	# 権限一覧表示
	$Page->Print("<input type=checkbox name=C_SUBJECT $authNum[0] value=on>タイトル文字数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_NAME $authNum[1] value=on>名前文字数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_MAIL $authNum[2] value=on>メール文字数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_CONTENTS $authNum[3] value=on>本文文字数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_CONTLINE $authNum[4] value=on>本文行数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_LINECOUNT $authNum[5] value=on>本文1行文字数規制解除<br>");
	$Page->Print("<input type=checkbox name=C_NONAME $authNum[6] value=on>名無し規制解除<br>");
	$Page->Print("<input type=checkbox name=C_THREAD $authNum[7] value=on>スレッド作成規制解除<br>");
	$Page->Print("<input type=checkbox name=C_THREADCAP $authNum[8] value=on>スレッド作成可能\(キャップ)<br>");
	$Page->Print("<input type=checkbox name=C_CONTINUAS $authNum[9] value=on>連続投稿規制解除<br>");
	$Page->Print("<input type=checkbox name=C_DUPLICATE $authNum[10] value=on>二重書き込み規制解除<br>");
	$Page->Print("<input type=checkbox name=C_SHORTWRITE $authNum[11] value=on>短時間投稿規制解除<br>");
	$Page->Print("<input type=checkbox name=C_READONLY $authNum[12] value=on>読取専用規制解除<br>");
	$Page->Print("<input type=checkbox name=C_CUSTOMID $authNum[23] value=on>専用ID許可<br>");
	$Page->Print("<input type=checkbox name=C_IDDISP $authNum[13] value=on>ID非表\示<br>");
	$Page->Print("<input type=checkbox name=C_NOSLIP $authNum[22] value=on>端末識別子非表\示<br>");
	$Page->Print("<input type=checkbox name=C_HOSTDISP $authNum[14] value=on>本文ホスト非表\示<br>");
	$Page->Print("<input type=checkbox name=C_MOBILETHREAD $authNum[15] value=on>携帯からのスレッド作成<br>");
	$Page->Print("<input type=checkbox name=C_FIXHANLDLE $authNum[16] value=on>コテハン★表\示<br>");
	$Page->Print("<input type=checkbox name=C_SAMBA $authNum[17] value=on>Samba規制解除<br>");
	$Page->Print("<input type=checkbox name=C_PROXY $authNum[18] value=on>プロキシ規制解除<br>");
	$Page->Print("<input type=checkbox name=C_JPHOST $authNum[19] value=on>海外ホスト規制解除<br>");
	$Page->Print("<input type=checkbox name=C_NOHOST $authNum[26] value=on>逆引き不可規制解除<br>");
	$Page->Print("<input type=checkbox name=C_NGUSER $authNum[20] value=on>ユーザー規制解除<br>");
	$Page->Print("<input type=checkbox name=C_NGWORD $authNum[21] value=on>NGワード規制解除<br>");
	$Page->Print("<input type=checkbox name=C_COMMAND $authNum[24] value=on>コマンド使用可<br>");
	$Page->Print("<input type=checkbox name=C_NOATTR $authNum[25] value=on>スレッド属性無効<br>");
	$Page->Print("<input type=checkbox name=C_NONINJA $authNum[27] value=on>忍法帖無効<br>");
	$Page->Print("<input type=checkbox name=C_NOCAPTCHA $authNum[28] value=on>Captcha無効<br>");
	$Page->Print("</td>\n<td valign=top>");
	
	# 所属ユーザ一覧表示
	foreach $id (@userSet) {
		my $groupid = $Group->GetBelong($id);
		# システム共通キャップ、他のグループに所属しているキャップは非表示
		if (0 == $User->Get('SYSAD', $id) &&
			($groupid eq '' || $groupid eq $Form->Get('SELECT_CAPGROUP') || $Group->Get('ISCOMMON', $groupid, ''))) {
			my $userName = $User->Get('NAME', $id);
			my $fullName = $User->Get('FULL', $id);
			my $check = '';
			foreach (@user) {
				if ($_ eq $id) {
					$check = 'checked'
				}
			}
			if ($Group->Get('ISCOMMON', $groupid, '') eq 1) {
				$check = 'disabled'
			}
			$Page->Print("<input type=checkbox name=BELONGUSER_CAP value=$id $check>$userName($fullName)<br>");
		}
	}
	
	# submit設定
	$common = "'" . $Form->Get('MODE_SUB') . "'";
	$common = "onclick=\"DoSubmit('bbs.cap', 'FUNC', $common)\"";
	
	$Page->HTMLInput('hidden', 'SELECT_CAPGROUP', $Form->Get('SELECT_CAPGROUP'));
	$Page->Print("</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left>");
	$Page->Print("<input type=submit value=\"　設定　\" $common></td></tr>");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ削除確認画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintGroupDelete
{
	my ($Page, $SYS, $Form) = @_;
	my ($Group, $BBS, @groupSet, $name, $expl, $rang, $id, $common);
	
	$SYS->Set('_TITLE', 'CAP Group Delete Confirm');
	
	require './module/cap.pl';
	$Group = CAP_GROUP->new;
	$Group->Load($SYS);
	
	# ユーザ情報を取得
	@groupSet = $Form->GetAtArray('CAP_GROUPS');
	
	$Page->Print("<br><center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2>以下のキャップグループを削除します。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">Group Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Subscription</td>");
	
	# ユーザリストを出力
	foreach $id (@groupSet) {
		$name = $Group->Get('NAME', $id);
		$expl = $Group->Get('EXPL', $id);
		
		$Page->Print("<tr><td>$name</a></td>");
		$Page->Print("<td>$expl</td></tr>\n");
		$Page->HTMLInput('hidden', 'CAP_GROUPS', $id);
	}
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：削除したグループを元に戻すことはできません。</b><br>");
	$Page->Print("※注：削除するグループに所属しているキャップはすべて未所属状態になります。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left><input type=button value=\"　削除　\" ");
	$Page->Print("onclick=\"DoSubmit('bbs.cap','FUNC','DELETE')\" class=\"delete\"></td></tr>");
	$Page->Print("</table>");
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
sub PrintGroupImport
{
	my ($Page, $SYS, $Form, $BBS) = @_;
	my (@bbsSet, $id, $name);
	
	$SYS->Set('_TITLE', 'CAP Group Import');
	
	# 所属BBSを取得
	$SYS->Get('ADMIN')->{'SECINFO'}->GetBelongBBSList($SYS->Get('ADMIN')->{'USER'}, $BBS, \@bbsSet);
#	$BBS->GetKeySet('ALL', '', \@bbsSet);
	
	$Page->Print("<br><center><table cellspcing=2>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">既存BBSからインポート</td>");
	$Page->Print("<td><select name=IMPORT_BBS><option value=\"\">--掲示板を選択--</option>");
	
	# 掲示板一覧の出力
	foreach $id (@bbsSet) {
		$name = $BBS->Get('NAME', $id);
		$Page->Print("<option value=$id>$name</option>\n");
	}
	
	$Page->Print("</select></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left><input type=button value=\"インポート\"");
	$Page->Print("onclick=\"DoSubmit('bbs.cap','FUNC','IMPORT');\"></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ作成/編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	編集:1, 作成:0
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#	2010.08.12 windyakin ★
#	 -> キャップ権限の追加
#
#------------------------------------------------------------------------------------------------------------
sub FunctionGroupSetting
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Group, $User, @userSet, @authNum, @belongUser);
	my ($name, $expl, $color, $auth, $user, $i);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_CAPGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('GROUPNAME_CAP');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
	}
	require './module/cap.pl';
	$User = CAP->new;
	$Group = CAP_GROUP->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	$Group->Load($Sys);
	
	# 基本情報の設定
	$name = $Form->Get('GROUPNAME_CAP');
	$expl = $Form->Get('GROUPSUBS_CAP');
	$color = $Form->Get('GROUPCOLOR_CAP');
	$color =~ s/[^\w\d\#]//ig;
	
	# 権限情報の生成
	$auth = '';
	$authNum[0]		= $Form->Equal('C_SUBJECT', 'on') ? 1 : 0;
	$authNum[1]		= $Form->Equal('C_NAME', 'on') ? 1 : 0;
	$authNum[2]		= $Form->Equal('C_MAIL', 'on') ? 1 : 0;
	$authNum[3]		= $Form->Equal('C_CONTENTS', 'on') ? 1 : 0;
	$authNum[4]		= $Form->Equal('C_CONTLINE', 'on') ? 1 : 0;
	$authNum[5]		= $Form->Equal('C_LINECOUNT', 'on') ? 1 : 0;
	$authNum[6]		= $Form->Equal('C_NONAME', 'on') ? 1 : 0;
	$authNum[7]		= $Form->Equal('C_THREAD', 'on') ? 1 : 0;
	$authNum[8]		= $Form->Equal('C_THREADCAP', 'on') ? 1 : 0;
	$authNum[9]		= $Form->Equal('C_CONTINUAS', 'on') ? 1 : 0;
	$authNum[10]	= $Form->Equal('C_DUPLICATE', 'on') ? 1 : 0;
	$authNum[11]	= $Form->Equal('C_SHORTWRITE', 'on') ? 1 : 0;
	$authNum[12]	= $Form->Equal('C_READONLY', 'on') ? 1 : 0;
	$authNum[13]	= $Form->Equal('C_IDDISP', 'on') ? 1 : 0;
	$authNum[14]	= $Form->Equal('C_HOSTDISP', 'on') ? 1 : 0;
	$authNum[15]	= $Form->Equal('C_MOBILETHREAD', 'on') ? 1 : 0;
	$authNum[16]	= $Form->Equal('C_FIXHANLDLE', 'on') ? 1 : 0;
	$authNum[17]	= $Form->Equal('C_SAMBA', 'on') ? 1 : 0;
	$authNum[18]	= $Form->Equal('C_PROXY', 'on') ? 1 : 0;
	$authNum[19]	= $Form->Equal('C_JPHOST', 'on') ? 1 : 0;
	$authNum[20]	= $Form->Equal('C_NGUSER', 'on') ? 1 : 0;
	$authNum[21]	= $Form->Equal('C_NGWORD', 'on') ? 1 : 0;
	$authNum[22]	= $Form->Equal('C_NOSLIP', 'on') ? 1 : 0;
	$authNum[23]	= $Form->Equal('C_CUSTOMID', 'on') ? 1 : 0;
	$authNum[24]	= $Form->Equal('C_COMMAND', 'on') ? 1 : 0;
	$authNum[25]	= $Form->Equal('C_NOATTR', 'on') ? 1 : 0;
	$authNum[26]	= $Form->Equal('C_NOHOST', 'on') ? 1 : 0;
	$authNum[27]	= $Form->Equal('C_NONINJA', 'on') ? 1 : 0;
	$authNum[28]	= $Form->Equal('C_NOCAPTCHA', 'on') ? 1 : 0;
	
	for ($i = 0 ; $i < $ZP::CAP_MAXNUM ; $i++) {
		if ($authNum[$i]){
			$auth .= ''.($i+1).',';
		}
	}
	$auth = substr($auth, 0, length($auth) - 1);
	
	# 所属ユーザ情報の生成
	@belongUser = $Form->GetAtArray('BELONGUSER_CAP');
	$user = join(',', @belongUser);
	
	# 設定情報の登録
	if ($mode){
		my $groupID = $Form->Get('SELECT_CAPGROUP');
		$Group->Set($groupID, 'NAME', $name);
		$Group->Set($groupID, 'EXPL', $expl);
		$Group->Set($groupID, 'COLOR', $color);
		$Group->Set($groupID, 'AUTH', $auth);
		$Group->Set($groupID, 'CAPS', $user);
	}
	else {
		$Group->Add($name, $expl, $color, $auth, $user);
	}
	
	# 設定を保存
	$Group->Save($Sys);
	
	# 処理ログ
	{
		my $id;
		push @$pLog, '■以下のキャップグループを登録しました。';
		push @$pLog, "グループ名称：$name";
		push @$pLog, "説明：$expl";
		push @$pLog, "色：$color";
		push @$pLog, "権限：$auth";
		push @$pLog, '所属キャップ：';
		foreach	$id (@belongUser){
			push @$pLog, '　　> ' . $User->Get('NAME', $id);
		}
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionGroupDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Group, @groupSet, $id);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_CAPGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/cap.pl';
	$Group = CAP_GROUP->new;
	
	# ユーザ情報の読み込み
	$Group->Load($Sys);
	
	push @$pLog, '■以下のグループを削除しました。';
	@groupSet = $Form->GetAtArray('CAP_GROUPS');
	
	foreach $id (@groupSet) {
		next if (! defined $Group->Get('NAME', $id));
		push @$pLog, $Group->Get('NAME', $id, '') . '(' . $Group->Get('EXPL', $id, '') . ')';
		$Group->Delete($id);
	}
	
	# 設定の保存
	$Group->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	グループインポート
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionGroupImport
{
	my ($Sys, $Form, $pLog, $BBS) = @_;
	my ($src, $dst);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_CAPGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/file_utils.pl';
	
	$src = $Sys->Get('BBSPATH') . '/' . $BBS->Get('DIR', $Form->Get('IMPORT_BBS')) . '/info/capgroups.cgi';
	$dst = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/capgroups.cgi';
	
	# グループ設定をコピー
	FILE_UTILS::Copy($src, $dst);
	
	# ログの出力
	my $name = $BBS->Get('NAME', $Form->Get('IMPORT_BBS'));
	push @$pLog, "「$name」のキャップグループ設定をインポートしました。";
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
