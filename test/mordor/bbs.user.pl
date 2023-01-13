#============================================================================================================
#
#	掲示板管理 - 管理グループ モジュール
#	bbs.user.pl
#	---------------------------------------------------------------------------
#	2004.07.10 start
#
#============================================================================================================
package	MODULE;

use strict;
#use warnings;

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
#	@param	$Sys	MELKOR
#	@param	$Form	SAMWISE
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoPrint
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $BASE, $BBS, $Page);
	
	require './mordor/sauron.pl';
	$BASE = SAURON->new;
	$BBS = $pSys->{'AD_BBS'};
	
	# 掲示板情報の読み込みとグループ設定
	if (! defined $BBS) {
		require './module/nazguls.pl';
		$BBS = NAZGUL->new;
		
		$BBS->Load($Sys);
		$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
		$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	}
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys, $Sys->Get('BBS'));
	
	if ($subMode eq 'LIST') {														# グループ一覧画面
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
		$BASE->PrintComplete('管理グループ処理', $this->{'LOG'});
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
#	@param	$Sys	MELKOR
#	@param	$Form	SAMWISE
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoFunction
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $err, $BBS);
	
	require './module/nazguls.pl';
	$BBS = NAZGUL->new;
	
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
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"USER_GROUP($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"USER_GROUP($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$pSys->{'AD_BBS'} = $BBS;
	$this->DoPrint($Sys, $Form, $pSys);
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューリスト設定
#	-------------------------------------------------------------------------------------
#	@param	$Base	SAURON
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys, $bbs) = @_;
	
	$Base->SetMenu('グループ一覧', "'bbs.user','DISP','LIST'");
	
	# 管理グループ設定権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_USERGROUP, $bbs)) {
		$Base->SetMenu('グループ登録', "'bbs.user','DISP','CREATE'");
		$Base->SetMenu('グループインポート', "'bbs.user','DISP','IMPORT'");
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
	my ($Group, $BBS, @groupSet, @user, $name, $expl, $id, $common, $isAuth, $n);
	
	$Sys->Set('_TITLE', 'Group List');
	
	require './module/elves.pl';
	$Group = GILDOR->new;
	
	# グループ情報の読み込み
	$Group->Load($Sys);
	$Group->GetKeySet(\@groupSet);
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	$Page->Print("<tr><td style=\"width:30\">　</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">Group Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Subscription</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30\">Users</td></tr>\n");
	
	# 権限取得
	$isAuth = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_USERGROUP, $Sys->Get('BBS'));
	
	# グループ一覧を出力
	foreach $id (@groupSet) {
		$name = $Group->Get('NAME', $id, '');
		$expl = $Group->Get('EXPL', $id, '');
		@user = split(/\, ?/, $Group->Get('USERS', $id, ''));
		$n = @user;
		
		$common = "\"javascript:SetOption('SELECT_GROUP','$id');";
		$common .= "DoSubmit('bbs.user','DISP','EDIT')\"";
		
		# 権限によって表示を抑制
		$Page->Print("<tr><td><input type=checkbox name=GROUPS value=$id></td>");
		if ($isAuth) {
			$Page->Print("<td><a href=$common>$name</a></td><td>$expl</td><td>$n</td></tr>\n");
		}
		else {
			$Page->Print("<td>$name</td><td>$expl</td><td>$n</td></tr>\n");
		}
	}
	$Page->HTMLInput('hidden', 'SELECT_GROUP', '');
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.user','DISP'";
		$Page->Print("<tr><td colspan=4 align=left>");
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
	my ($name, $expl, @auth, @user, $common);
	
	$Sys->Set('_TITLE', 'Group Edit')	if ($mode == 1);
	$Sys->Set('_TITLE', 'Group Create')	if ($mode == 0);
	
	require './module/elves.pl';
	$User = GLORFINDEL->new;
	$Group = GILDOR->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	$Group->Load($Sys);
	$User->GetKeySet('ALL', '', \@userSet);
	
	# 編集モードならユーザ情報を取得する
	if ($mode) {
		$name = $Group->Get('NAME', $Form->Get('SELECT_GROUP', ''), '');
		$expl = $Group->Get('EXPL', $Form->Get('SELECT_GROUP', ''), '');
		@auth = split(/\, ?/, $Group->Get('AUTH', $Form->Get('SELECT_GROUP', ''), ''));
		@user = split(/\, ?/, $Group->Get('USERS', $Form->Get('SELECT_GROUP', ''), ''));
		
		# 権限番号マッピング配列を作成
		for ($i = 0 ; $i < 15 ; $i++) {
			$authNum[$i] = '';
		}
		foreach $num (@auth) {
			$authNum[$num - 1] = 'checked';
		}
	}
	else {
		$name = '';
		$expl = '';
		@auth = ();
		@user = ();
		$Form->Set('SELECT_GROUP', '');
		for ($i = 0 ; $i < 15 ; $i++) {
			$authNum[$i] = '';
		}
	}
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2>各情報を入力して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>基本情報</td></tr>");
	$Page->Print("<tr><td colspan=2><table cellspcing=2>");
	$Page->Print("<tr><td class=\"DetailTitle\">グループ名称</td><td>");
	$Page->Print("<input name=GROUPNAME type=text size=50 value=\"$name\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">説明</td><td>");
	$Page->Print("<input name=GROUPSUBS type=text size=50 value=\"$expl\"></td></tr>");
	$Page->Print("</table><br></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\" width=40%>権限情報</td>");
	$Page->Print("<td class=\"DetailTitle\">所属ユーザ</td></tr><tr><td valign=top>");
	
	# 権限一覧表示
	$Page->Print("<input type=checkbox name=A_USERGROUP $authNum[0] value=on>管理グループ設定<br>");
	$Page->Print("<input type=checkbox name=A_CAPGROUP $authNum[1] value=on>キャップグループ設定<br>");
	$Page->Print("<input type=checkbox name=A_LOGVIEW $authNum[14] value=on>ログの閲覧・削除<br>");
	$Page->Print("<hr>");
	$Page->Print("<input type=checkbox name=A_THREADSTOP $authNum[2] value=on>スレッド停止・再開<br>");
	$Page->Print("<input type=checkbox name=A_THREADPOOL $authNum[3] value=on>スレッドdat落ち・復活<br>");
	$Page->Print("<input type=checkbox name=A_TREADDELETE $authNum[4] value=on>スレッド削除<br>");
	$Page->Print("<input type=checkbox name=A_THREADINFO $authNum[5] value=on>スレッド情報更新<br>");
	$Page->Print("<input type=checkbox name=A_PASTCREATE $authNum[6] value=on>過去ログ生成<br>");
	$Page->Print("<input type=checkbox name=A_PASTDELETE $authNum[7] value=on>過去ログ削除<br>");
	$Page->Print("<input type=checkbox name=A_BBSSETTING $authNum[8] value=on>掲示板設定<br>");
	$Page->Print("<input type=checkbox name=A_BBSEDIT $authNum[13] value=on>各種編集<br>");
	$Page->Print("<input type=checkbox name=A_NGWORDS $authNum[9] value=on>NGワード編集<br>");
	$Page->Print("<input type=checkbox name=A_ACCESUSER $authNum[10] value=on>アクセス制限編集<br>");
	$Page->Print("<hr>");
	$Page->Print("<input type=checkbox name=A_RESABONE $authNum[11] value=on>レスあぼーん<br>");
	$Page->Print("<input type=checkbox name=A_RESEDIT $authNum[12] value=on>レス編集<br>");
	$Page->Print("</td>\n<td valign=top>");
	
	# 所属ユーザ一覧表示
	foreach $id (@userSet) {
		# システム権限ユーザ、他のグループに所属しているユーザは非表示
		if (0 == $User->Get('SYSAD', $id) &&
			($Group->GetBelong($id) eq '' || $Group->GetBelong($id) eq $Form->Get('SELECT_GROUP'))) {
			my $userName = $User->Get('NAME', $id);
			my $fullName = $User->Get('FULL', $id);
			my $check = '';
			foreach (@user) {
				if ($_ eq $id) {
					$check = 'checked';
				}
			}
			$Page->Print("<input type=checkbox name=BELONGUSER value=$id $check>$userName($fullName)<br>");
		}
	}
	
	# submit設定
	$common = "'" . $Form->Get('MODE_SUB') . "'";
	$common = "onclick=\"DoSubmit('bbs.user','FUNC',$common)\"";
	
	$Page->HTMLInput('hidden', 'SELECT_GROUP', $Form->Get('SELECT_GROUP'));
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
	
	$SYS->Set('_TITLE', 'Group Delete Confirm');
	
	require './module/elves.pl';
	$Group = GILDOR->new;
	$Group->Load($SYS);
	
	# ユーザ情報を取得
	@groupSet = $Form->GetAtArray('GROUPS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2>以下のグループを削除します。</td></tr>");
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
		$Page->HTMLInput('hidden', 'GROUPS', $id);
	}
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：削除したグループを元に戻すことはできません。</b><br>");
	$Page->Print("※注：自分が所属しているグループは削除できません。<br>");
	$Page->Print("※注：削除するグループに所属しているユーザはすべて未所属状態になります。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=right><input type=button value=\"　削除　\" ");
	$Page->Print("onclick=\"DoSubmit('bbs.user','FUNC','DELETE')\" class=\"delete\"></td></tr>");
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
	
	$SYS->Set('_TITLE', 'Group Import');
	
	# 所属BBSを取得
	$SYS->Get('ADMIN')->{'SECINFO'}->GetBelongBBSList($SYS->Get('ADMIN')->{'USER'}, $BBS, \@bbsSet);
	
	$Page->Print("<center><table cellspcing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">既存BBSからインポート</td>");
	$Page->Print("<td><select name=IMPORT_BBS><option value=\"\">--掲示板を選択--</option>");
	
	# 掲示板一覧の出力
	foreach $id (@bbsSet) {
		$name	= $BBS->Get('NAME', $id);
		$Page->Print("<option value=$id>$name</option>\n");
	}
	
	$Page->Print("</select></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left><input type=button value=\"インポート\"");
	$Page->Print("onclick=\"DoSubmit('bbs.user','FUNC','IMPORT');\"></td></tr></table>");
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
#------------------------------------------------------------------------------------------------------------
sub FunctionGroupSetting
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Group, $User, @userSet, @authNum, @belongUser);
	my ($name, $expl, $auth, $user, $i);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_USERGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('GROUPNAME');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
	}
	require './module/elves.pl';
	$User = GLORFINDEL->new;
	$Group = GILDOR->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	$Group->Load($Sys);
	
	# 基本情報の設定
	$name = $Form->Get('GROUPNAME');
	$expl = $Form->Get('GROUPSUBS');
	
	# 権限情報の生成
	my %field2auth = (
		'A_USERGROUP'	=> $ZP::AUTH_USERGROUP,
		'A_CAPGROUP'	=> $ZP::AUTH_CAPGROUP,
		'A_THREADSTOP'	=> $ZP::AUTH_THREADSTOP,
		'A_THREADPOOL'	=> $ZP::AUTH_THREADPOOL,
		'A_TREADDELETE'	=> $ZP::AUTH_TREADDELETE,
		'A_THREADINFO'	=> $ZP::AUTH_THREADINFO,
		'A_PASTCREATE'	=> $ZP::AUTH_KAKOCREATE,
		'A_PASTDELETE'	=> $ZP::AUTH_KAKODELETE,
		'A_BBSSETTING'	=> $ZP::AUTH_BBSSETTING,
		'A_NGWORDS'		=> $ZP::AUTH_NGWORDS,
		'A_ACCESUSER'	=> $ZP::AUTH_ACCESUSER,
		'A_RESABONE'	=> $ZP::AUTH_RESDELETE,
		'A_RESEDIT'		=> $ZP::AUTH_RESEDIT,
		'A_BBSEDIT'		=> $ZP::AUTH_BBSEDIT,
		'A_LOGVIEW'		=> $ZP::AUTH_LOGVIEW,
	);
	my @auths = ();
	foreach (keys %field2auth) {
		if ($Form->Equal($_, 'on')) {
			push @auths, $field2auth{$_};
		}
	}
	$auth = join(',', @auths);
	
	# 所属ユーザ情報の生成
	@belongUser = $Form->GetAtArray('BELONGUSER');
	$user = join(',', @belongUser);
	
	# 設定情報の登録
	if ($mode) {
		my $groupID = $Form->Get('SELECT_GROUP');
		$Group->Set($groupID, 'NAME', $name);
		$Group->Set($groupID, 'EXPL', $expl);
		$Group->Set($groupID, 'AUTH', $auth);
		$Group->Set($groupID, 'USERS', $user);
	}
	else {
		$Group->Add($name, $expl, $auth, $user);
	}
	
	# 設定を保存
	$Group->Save($Sys);
	
	# 処理ログ
	{
		my $id;
		push @$pLog, '■以下のグループを登録しました。';
		push @$pLog, "グループ名称：$name";
		push @$pLog, "説明：$expl";
		push @$pLog, "権限：$auth";
		push @$pLog, '所属ユーザ：';
		foreach $id (@belongUser) {
			push @$pLog,"　　> " . $User->Get('NAME', $id);
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
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_USERGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/elves.pl';
	$Group = GILDOR->new;
	
	# ユーザ情報の読み込み
	$Group->Load($Sys);
	
	push @$pLog, '■以下のグループを削除しました。';
	@groupSet = $Form->GetAtArray('GROUPS');
	
	foreach $id (@groupSet) {
		next if (! defined $Group->Get('NAME', $id));
		if ($Group->GetBelong($Sys->Get('ADMIN')->{'USER'}) eq $id) {
			push(@$pLog,
				'※自分の所属グループのため「' . $Group->Get('NAME', $id) . '」を削除できませんでした。');
		}
		else {
			push @$pLog, $Group->Get('NAME', $id) . '(' . $Group->Get('EXPL', $id) . ')';
			$Group->Delete($id);
		}
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
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_USERGROUP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/earendil.pl';
	
	$src = $Sys->Get('BBSPATH') . '/' . $BBS->Get('DIR', $Form->Get('IMPORT_BBS', ''), '') . '/info/groups.cgi';
	$dst = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/groups.cgi';
	
	return 0 if ($src eq $dst);
	
	# グループ設定をコピー
	EARENDIL::Copy($src, $dst);
	
	# ログの出力
	my $name = $BBS->Get('NAME', $Form->Get('IMPORT_BBS'));
	push @$pLog, "「$name」のグループ設定をインポートしました。";
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
