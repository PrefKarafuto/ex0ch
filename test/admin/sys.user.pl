#============================================================================================================
#
#	システム管理 - ユーザ モジュール
#	sys.user.pl
#	---------------------------------------------------------------------------
#	2004.06.26 start
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
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys);
	
	if ($subMode eq 'LIST') {														# スレッド一覧画面
		PrintUserList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'CREATE') {													# ユーザ作成画面
		PrintUserSetting($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'EDIT') {													# ユーザ編集画面
		PrintUserSetting($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'DELETE') {													# ユーザ削除確認画面
		PrintUserDelete($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# ユーザ設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('ユーザ処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# ユーザ設定失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
	$BASE->Print($Sys->Get('_TITLE'), 1);
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
	my ($subMode, $err);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'CREATE') {														# ユーザ作成
		$err = FuncUserSetting($Sys, $Form, 0, $this->{'LOG'});
	}
	elsif ($subMode eq 'EDIT') {													# ユーザ編集
		$err = FuncUserSetting($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {													# ユーザ削除
		$err = FuncUserDelete($Sys, $Form, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "USER($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"USER($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$this->DoPrint($Sys, $Form, $pSys);
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューリスト設定
#	-------------------------------------------------------------------------------------
#	@param	$Base	ADMIN_CGI_BASE
#	@param	$Sys	SYSTEM
#	@param	$pSys	管理システム
#	@param	$Form	FORM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys) = @_;
	
	# 共通表示メニュー
	$Base->SetMenu('ユーザー一覧', "'sys.user','DISP','LIST'");
	
	# システム管理権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_SYSADMIN, '*')) {
		$Base->SetMenu('ユーザー登録', "'sys.user','DISP','CREATE'");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintUserList
{
	my ($Page, $Sys, $Form) = @_;
	my ($User, @userSet, $name, $expl, $full, $id, $common);
	my ($dispNum, $i, $dispSt, $dispEd, $userNum, $isAuth);
	
	$Sys->Set('_TITLE', 'Users List');
	
	require './module/security.pl';
	$User = USER_INFO->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	
	# ユーザ情報を取得
	$User->GetKeySet('ALL', '', \@userSet);
	
	# 表示数の設定
	$userNum	= @userSet;
	$dispNum	= ($Form->Get('DISPNUM') eq '' ? 10 : $Form->Get('DISPNUM'));
	$dispSt		= ($Form->Get('DISPST') eq '' ? 0 : $Form->Get('DISPST'));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $userNum ? $userNum : ($dispSt + $dispNum));
	
	$common		= "DoSubmit('sys.user','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><b><a href=\"javascript:SetOption('DISPST', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('DISPST', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表\示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表\示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30\">　</th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Full Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Explanation</td></td>\n");
	
	# 権限取得
	$isAuth = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');
	
	# ユーザ一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$id		= $userSet[$i];
		$name	= $User->Get('NAME', $id);
		$full	= $User->Get('FULL', $id);
		$expl	= $User->Get('EXPL', $id);
		
		$common = "\"javascript:SetOption('SELECT_USER','$id');";
		$common .= "DoSubmit('sys.user','DISP','EDIT')\"";
		
		# システム権限有無による表示抑制
		if ($isAuth) {
			$Page->Print("<tr><td><input type=checkbox name=USERS value=$id></td>");
			$Page->Print("<td><a href=$common>$name</a></td>");
		}
		else{
			$Page->Print("<tr><td><input type=checkbox></td><td>$name</td>");
		}
		$Page->Print("<td>$full</td><td>$expl</td></tr>\n");
	}
	$common = "onclick=\"DoSubmit('sys.user','DISP'";
	
	$Page->HTMLInput('hidden', 'SELECT_USER', '');
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	
	# システム権限有無による表示抑制
	if ($isAuth) {
		$Page->Print("<tr><td colspan=4 align=left>");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ設定の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	作成の場合:0, 編集の場合:1
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintUserSetting
{
	my ($Page, $Sys, $Form, $mode) = @_;
	my ($User, $id, $common, $name, $pass, $expl, $full, $sysad);
	
	$Sys->Set('_TITLE', 'User Edit')	if ($mode == 1);
	$Sys->Set('_TITLE', 'User Create')	if ($mode == 0);
	
	require './module/security.pl';
	$User = USER_INFO->new;
	
	# ユーザ情報の読み込み
	$User->Load($Sys);
	
	# 編集モードならユーザ情報を取得する
	if ($mode) {
		$name	= $User->Get('NAME', $Form->Get('SELECT_USER'));
		$pass	= $User->Get('PASS', $Form->Get('SELECT_USER'));
		$expl	= $User->Get('EXPL', $Form->Get('SELECT_USER'));
		$full	= $User->Get('FULL', $Form->Get('SELECT_USER'));
		$sysad	= $User->Get('SYSAD', $Form->Get('SELECT_USER')) ? 'checked' : '';
	}
	else {
		$Form->Set('SELECT_USER', '');
		$name	= '';
		$pass	= '';
		$expl	= '';
		$full	= '';
		$sysad	= '';
	}
	
	$Page->Print("<center><table border=0 cellspacing=2>");
	$Page->Print("<tr><td colspan=2>各項目を設定して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">ユーザ名</td><td>");
	$Page->Print("<input type=text size=30 name=NAME value=\"$name\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">パスワード</td><td>");
	$Page->Print("<input type=password size=30 name=PASS value=\"$pass\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">ユーザフルネーム</td><td>");
	$Page->Print("<input type=text size=30 name=FULL value=\"$full\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">説明</td><td>");
	$Page->Print("<input type=text size=30 name=EXPL value=\"$expl\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2 valign=absmiddle>");
	$Page->Print("<input type=checkbox name=SYSAD $sysad value=on>システム管理者権限</td></tr>");
	
	$Page->HTMLInput('hidden', 'SELECT_USER', $Form->Get('SELECT_USER'));
	
	# submit設定
	$common = "'" . $Form->Get('MODE_SUB') . "'";
	$common = "onclick=\"DoSubmit('sys.user','FUNC',$common)\"";
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=center>");
	$Page->Print("<input type=button value=\"　設定　\" $common></td></tr>\n");
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ削除確認画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintUserDelete
{
	my ($Page, $SYS, $Form) = @_;
	my ($User, $Group, @userSet, $id, $name, $grop, $expl, $full);
	
	$SYS->Set('_TITLE', 'User Delete Confirm');
	
	require './module/security.pl';
	$User = USER_INFO->new;
	
	
	# ユーザ情報を取得
	$User->Load($SYS);
	@userSet = $Form->GetAtArray('USERS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のユーザを削除します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	
	$Page->Print("<tr bgcolor=silver>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Full Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Explanation</td></td>\n");
	
	# ユーザリストを出力
	foreach $id (@userSet) {
		$name = $User->Get('NAME', $id);
		$expl = $User->Get('EXPL', $id);
		$full = $User->Get('FULL', $id);
		
		$Page->Print("<tr><td>$name</a></td>");
		$Page->Print("<td>$full</td>");
		$Page->Print("<td>$expl</td></tr>\n");
		$Page->HTMLInput('hidden', 'USERS', $id);
	}
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：削除したユーザを元に戻すことはできません。</b><br>");
	$Page->Print("※注：Administratorと自分自身は削除できません。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	$Page->Print("<tr><td colspan=3 align=left><input type=button value=\"　削除　\" ");
	$Page->Print("onclick=\"DoSubmit('sys.user','FUNC','DELETE')\" class=\"delete\"></td></tr>");
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ作成/編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	編集:1, 作成:0
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FuncUserSetting
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($User, $name, $pass, $expl, $grop, $chg, $full, $sysad);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('NAME', 'PASS');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		if (! $Form->IsAlphabet(\@inList)) {
			return 1002;
		}
	}
	require './module/security.pl';
	$User = USER_INFO->new;
	
	$User->Load($Sys);
	
	# 設定入力情報を取得
	$name	= $Form->Get('NAME');
	$pass	= $Form->Get('PASS');
	$expl	= $Form->Get('EXPL');
	$full	= $Form->Get('FULL');
	$sysad	= $Form->Equal('SYSAD', 'on') ? 1 : 0;
	$chg	= 0;
	
	if ($mode) {																	# 編集モード
		# パスワードが変更されていたら再設定する
		if ($pass ne $User->Get('PASS', $Form->Get('SELECT_USER'))) {
			$User->Set($Form->Get('SELECT_USER'), 'PASS', $pass);
			$chg = 1;
		}
		$User->Set($Form->Get('SELECT_USER'), 'NAME', $name);
		$User->Set($Form->Get('SELECT_USER'), 'EXPL', $expl);
		$User->Set($Form->Get('SELECT_USER'), 'FULL', $full);
		$User->Set($Form->Get('SELECT_USER'), 'SYSAD', $sysad);
	}
	else {																			# 登録モード
		$User->Add($name, $pass, $full, $expl, $sysad);
		$chg = 1;
	}
	
	# 設定情報を保存
	$User->Save($Sys);
	
	# ログの設定
	{
		push @$pLog, "■ ユーザ [ $name ] " . ($mode ? '設定' : '作成');
		push @$pLog, '　　　　パスワード：' . ($chg ? $pass : '変更なし');
		push @$pLog, "　　　　フルネーム：$full";
		push @$pLog, "　　　　説明：$expl";
		push @$pLog, '　　　　システム管理：' . ($sysad ? '有り' : '無し');
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FuncUserDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my ($User, $Sec, @userSet, $id, $name);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		$id = $chkID;
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	require './module/security.pl';
	$User = USER_INFO->new;
	$Sec = SECURITY->new;
	
	$User->Load($Sys);
	$Sec->Init($Sys);
	
	@userSet = $Form->GetAtArray('USERS');
	
	# 選択ユーザを全削除
	foreach (@userSet) {
		next if (! defined $User->Get('NAME', $_));
		# Administratorは削除不可
		if ($_ eq '0000000001') {
			push @$pLog, '□ ユーザ [ Administrator ] は削除できませんでした。';
		}
		# 自分自身も削除不可
		elsif ($_ eq $id) {
			my $name = $User->Get('NAME', $id);
			push @$pLog, "□ ユーザ [ $name ] は自分自身のため削除できませんでした。";
		}
		# それ以外は削除可
		else {
			my $name = $User->Get('NAME', $_);
			push @$pLog, "■ ユーザ [ $name ] を削除しました。";
			$User->Delete($_);
		}
	}
	
	# 設定情報を保存
	$User->Save($Sys);
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
