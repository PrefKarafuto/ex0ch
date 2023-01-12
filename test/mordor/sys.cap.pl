#============================================================================================================
#
#	システム管理 - キャップ モジュール
#	sys.cap.pl
#	---------------------------------------------------------------------------
#	2004.06.26 start
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
		'LOG'	=> \@LOG
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
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys);
	
	if ($subMode eq 'LIST') {														# スレッド一覧画面
		PrintCapList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'CREATE') {													# キャップ作成画面
		PrintCapSetting($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'EDIT') {													# キャップ編集画面
		PrintCapSetting($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'DELETE') {													# キャップ削除確認画面
		PrintCapDelete($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# キャップ設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('キャップ処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# キャップ設定失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
	$BASE->Print($Sys->Get('_TITLE'), 1);
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
	my ($subMode, $err);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'CREATE') {														# キャップ作成
		$err = FuncCapSetting($Sys, $Form, 0, $this->{'LOG'});
	}
	elsif ($subMode eq 'EDIT') {													# キャップ編集
		$err = FuncCapSetting($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {													# キャップ削除
		$err = FuncCapDelete($Sys, $Form, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"CAP($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"CAP($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$this->DoPrint($Sys, $Form, $pSys);
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューリスト設定
#	-------------------------------------------------------------------------------------
#	@param	$Base	SAURON
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys) = @_;
	
	# 共通表示メニュー
	$Base->SetMenu('キャップ一覧', "'sys.cap','DISP','LIST'");
	
	# システム管理権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_SYSADMIN, '*')) {
		$Base->SetMenu('キャップ登録', "'sys.cap','DISP','CREATE'");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	キャップ一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCapList
{
	my ($Page, $Sys, $Form) = @_;
	my ($Cap, @userSet, $name, $expl, $full, $id, $common, $customid);
	my ($dispNum, $i, $dispSt, $dispEd, $userNum, $isAuth);
	
	$Sys->Set('_TITLE', 'Caps List');
	
	require './module/ungoliants.pl';
	$Cap = UNGOLIANT->new;
	
	# キャップ情報の読み込み
	$Cap->Load($Sys);
	
	# キャップ情報を取得
	$Cap->GetKeySet('ALL', '', \@userSet);
	
	# 表示数の設定
	$userNum	= @userSet;
	$dispNum	= ($Form->Get('DISPNUM') eq '' ? 10 : $Form->Get('DISPNUM'));
	$dispSt		= ($Form->Get('DISPST') eq '' ? 0 : $Form->Get('DISPST'));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $userNum ? $userNum : ($dispSt + $dispNum));
	
	$common		= "DoSubmit('sys.cap','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3><b><a href=\"javascript:SetOption('DISPST', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('DISPST', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表\示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表\示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30\">　</th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Cap Display Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Cap Full Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Custom ID</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Explanation</td></tr>\n");
	
	# 権限取得
	$isAuth = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');
	
	# キャップ一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$id			= $userSet[$i];
		$name		= $Cap->Get('NAME', $id);
		$full		= $Cap->Get('FULL', $id);
		$expl		= $Cap->Get('EXPL', $id);
		$customid	= $Cap->Get('CUSTOMID', $id);
		
		$common = "\"javascript:SetOption('SELECT_CAP','$id');";
		$common .= "DoSubmit('sys.cap','DISP','EDIT')\"";
		
		# システム権限有無による表示抑制
		if ($isAuth) {
			$Page->Print("<tr><td><input type=checkbox name=CAPS value=$id></td>");
			$Page->Print("<td><a href=$common>$name</a></td>");
		}
		else{
			$Page->Print("<tr><td><input type=checkbox></td><td>$name</td>");
		}
		$Page->Print("<td>$full</td><td>$customid</td><td>$expl</td></tr>\n");
	}
	$common = "onclick=\"DoSubmit('sys.cap','DISP'";
	
	$Page->HTMLInput('hidden', 'SELECT_CAP', '');
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	
	# システム権限有無による表示抑制
	if ($isAuth) {
		$Page->Print("<tr><td colspan=5 align=left>");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
}

#------------------------------------------------------------------------------------------------------------
#
#	キャップ設定の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	作成の場合:0, 編集の場合:1
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCapSetting
{
	my ($Page, $Sys, $Form, $mode) = @_;
	my ($User, $id, $common, $name, $pass, $expl, $full, $sysad, $customid);
	
	$Sys->Set('_TITLE', 'Cap Edit')		if ($mode == 1);
	$Sys->Set('_TITLE', 'Cap Create')	if ($mode == 0);
	
	require './module/ungoliants.pl';
	$User = UNGOLIANT->new;
	
	# キャップ情報の読み込み
	$User->Load($Sys);
	
	# 編集モードならキャップ情報を取得する
	if ($mode) {
		$name		= $User->Get('NAME', $Form->Get('SELECT_CAP'));
		$pass		= $User->Get('PASS', $Form->Get('SELECT_CAP'));
		$expl		= $User->Get('EXPL', $Form->Get('SELECT_CAP'));
		$full		= $User->Get('FULL', $Form->Get('SELECT_CAP'));
		$sysad		= $User->Get('SYSAD', $Form->Get('SELECT_CAP')) ? 'checked' : '';
		$customid	= $User->Get('CUSTOMID', $Form->Get('SELECT_CAP'));
	}
	else {
		$Form->Set('SELECT_CAP', '');
		$name	= '';
		$pass	= '';
		$expl	= '';
		$full	= '';
		$sysad	= '';
	}
	
	$Page->Print("<center><table border=0 cellspacing=2>");
	$Page->Print("<tr><td colspan=2>各項目を設定して[設定]ボタンを押してください。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">キャップ表\示名</td><td>");
	$Page->Print("<input type=text size=30 name=NAME value=\"$name\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">パスワード</td><td>");
	$Page->Print("<input type=password size=30 name=PASS value=\"$pass\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">キャップフルネーム</td><td>");
	$Page->Print("<input type=text size=30 name=FULL value=\"$full\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">説明</td><td>");
	$Page->Print("<input type=text size=30 name=EXPL value=\"$expl\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">専用ID(要権限)</td><td>");
	$Page->Print("<input type=text size=30 name=CUSTOMID value=\"$customid\"></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2 valign=absmiddle>");
	$Page->Print("<input type=checkbox name=SYSAD $sysad value=on>システム共通権限</td></tr>");
	
	$Page->HTMLInput('hidden', 'SELECT_CAP', $Form->Get('SELECT_CAP'));
	
	# submit設定
	$common = "'" . $Form->Get('MODE_SUB') . "'";
	$common = "onclick=\"DoSubmit('sys.cap','FUNC',$common)\"";
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=center>");
	$Page->Print("<input type=button value=\"　設定　\" $common></td></tr>\n");
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	キャップ削除確認画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintCapDelete
{
	my ($Page, $SYS, $Form) = @_;
	my ($Cap, $Group, @userSet, $id, $name, $grop, $expl, $full);
	
	$SYS->Set('_TITLE', 'Cap Delete Confirm');
	
	require './module/ungoliants.pl';
	$Cap = UNGOLIANT->new;
	
	# キャップ情報を取得
	$Cap->Load($SYS);
	@userSet = $Form->GetAtArray('CAPS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のキャップを削除します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	
	$Page->Print("<tr bgcolor=silver>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">User Full Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">Explanation</td></td>\n");
	
	# キャップリストを出力
	foreach $id (@userSet) {
		$name = $Cap->Get('NAME', $id);
		$expl = $Cap->Get('EXPL', $id);
		$full = $Cap->Get('FULL', $id);
		
		$Page->Print("<tr><td>$name</a></td>");
		$Page->Print("<td>$full</td>");
		$Page->Print("<td>$expl</td></tr>\n");
		$Page->HTMLInput('hidden', 'CAPS', $id);
	}
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：削除したキャップを元に戻すことはできません。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>");
	$Page->Print("<tr><td colspan=3 align=left><input type=button value=\"　削除　\" ");
	$Page->Print("onclick=\"DoSubmit('sys.cap','FUNC','DELETE')\" class=\"delete\"></td></tr>");
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	キャップ作成/編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	編集:1, 作成:0
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FuncCapSetting
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Cap, $name, $pass, $expl, $grop, $chg, $sysad, $full, $customid);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('PASS');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		if (! $Form->IsCapKey(\@inList)) {
			return 1002;
		}
	}
	require './module/ungoliants.pl';
	$Cap = UNGOLIANT->new;
	
	$Cap->Load($Sys);
	
	# 設定入力情報を取得
	$name		= $Form->Get('NAME');
	$pass		= $Form->Get('PASS');
	$expl		= $Form->Get('EXPL');
	$full		= $Form->Get('FULL');
	$customid	= $Form->Get('CUSTOMID');
	$sysad		= $Form->Equal('SYSAD', 'on') ? 1 : 0;
	$chg		= 0;
	
	if ($mode) {																	# 編集モード
		# パスワードが変更されていたら再設定する
		if ($pass ne $Cap->Get('PASS', $Form->Get('SELECT_CAP'))){
			$Cap->Set($Form->Get('SELECT_CAP'), 'PASS', $pass);
			$chg = 1;
		}
		$Cap->Set($Form->Get('SELECT_CAP'), 'NAME', $name);
		$Cap->Set($Form->Get('SELECT_CAP'), 'EXPL', $expl);
		$Cap->Set($Form->Get('SELECT_CAP'), 'FULL', $full);
		$Cap->Set($Form->Get('SELECT_CAP'), 'SYSAD', $sysad);
		$Cap->Set($Form->Get('SELECT_CAP'), 'CUSTOMID', $customid);
	}
	else {																			# 登録モード
		$Cap->Add($name, $pass, $full, $expl, $sysad, $customid);
		$chg = 1;
	}
	
	# 設定情報を保存
	$Cap->Save($Sys);
	
	# ログの設定
	{
		push @$pLog, "■ キャップ [ $name ] " . ($mode ? '設定' : '作成');
		push @$pLog, '　　　　パスワード：' . ($chg ? $pass : '変更なし');
		push @$pLog, "　　　　フルネーム：$full";
		push @$pLog, "　　　　説明：$expl";
		push @$pLog, "　　　　専用ID：$customid";
		push @$pLog, '　　　　システム管理：' . ($sysad ? '有り' : '無し');
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	キャップ削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FuncCapDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Cap, @userSet);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	require './module/ungoliants.pl';
	$Cap = UNGOLIANT->new;
	
	$Cap->Load($Sys);
	@userSet = $Form->GetAtArray('CAPS');
	
	# 選択キャップを全削除
	foreach (@userSet) {
		next if (! defined $Cap->Get('NAME', $_));
		# Administratorは削除不可
		if ($_ eq '0000000001') {
			push @$pLog, '□ キャップ [ Administrator ] は削除できませんでした。';
		}
		# それ以外は削除可
		else {
			my $name = $Cap->Get('NAME', $_);
			my $pass = $Cap->Get('PASS', $_);
			push @$pLog, "■ キャップ [ $name / $pass ] を削除しました。";
			$Cap->Delete($_);
		}
	}
	
	# 設定情報を保存
	$Cap->Save($Sys);
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
