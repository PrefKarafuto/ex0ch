#============================================================================================================
#
#	掲示板管理 - POOLスレッド モジュール
#	bbs.pool.pl
#	---------------------------------------------------------------------------
#	2004.02.07 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
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
	require './module/bbs_info.pl';
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
	SetMenuList($BASE);
	
	if ($subMode eq 'LIST') {														# スレッド一覧画面
		PrintThreadList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'REPARE') {													# スレッド復帰確認画面
		PrintThreadRepare($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'CREATE') {													# 過去ログ作成確認画面
		PrintThreadCreate($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'DELETE') {													# スレッド削除確認画面
		PrintThreadDelete($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# スレッド処理完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('過去ログ処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# スレッド処理失敗画面
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
	$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'REPARE') {														# 復帰
		$err = FunctionThreadRepare($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {													# 削除
		$err = FunctionThreadDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'UPDATE') {													# 情報更新
		$err = FunctionUpdateSubject($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'UPDATEALL') {												# 全更新
		$err = FunctionUpdateSubjectAll($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'CREATE') {													# 過去ログ生成
		$err = FunctionCreateLogs($Sys, $Form, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"POOL($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"POOL($subMode)", 'COMPLETE');
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
	my ($Base) = @_;
	
	$Base->SetMenu('POOLスレッド一覧', "'bbs.pool','DISP','LIST'");
	$Base->SetMenu('<hr>', '');
	$Base->SetMenu('システム管理へ戻る', "'sys.bbs','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadList
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadSet, $ThreadNum, $key, $res, $subj, $i);
	my ($dispSt, $dispEd, $dispNum);
	my ($common, $common2, $n, $Threads, $id);
	
	$SYS->Set('_TITLE', 'Pool Thread List');
	
	require './module/thread.pl';
	$Threads = POOL_THREAD->new;
	
	$Threads->Load($SYS);
	$Threads->GetKeySet('ALL', '', \@threadSet);
	$ThreadNum = $Threads->GetNum();
	
	# 表示数の設定
	$dispNum	= ($Form->Get('DISPNUM') eq '' ? 10 : $Form->Get('DISPNUM'));
	$dispSt		= ($Form->Get('DISPST') eq '' ? 0 : $Form->Get('DISPST'));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $ThreadNum ? $ThreadNum : ($dispSt + $dispNum));
	
	$common		= "DoSubmit('bbs.pool','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3><b><a href=\"javascript:SetOption('DISPST', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('DISPST', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表\示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表\示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"><a href=\"javascript:toggleAll('THREADS')\">全</a></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250px\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30px\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:20px\">Res</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">Attribute</td></tr>\n");
	
	# 権限取得
	my ($isRepare, $isDelete, $isUpdate, $isCreate);
	
	$isRepare = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADPOOL, $SYS->Get('BBS'));
	$isDelete = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_TREADDELETE, $SYS->Get('BBS'));
	$isUpdate = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADINFO, $SYS->Get('BBS'));
	$isCreate = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_KAKOCREATE, $SYS->Get('BBS'));
	
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$id		= $threadSet[$i];
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td><input type=checkbox name=THREADS value=$id></td>");
		$Page->Print("<td>$subj</td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td>");
		
		my @attrstr = ();
		#push @attrstr, '停止' if ($Threads->GetAttr($id, 'stop'));
		#push @attrstr, '停止' if ($isstop);
		push @attrstr, '浮上' if ($Threads->GetAttr($id, 'float'));
		push @attrstr, '不落' if ($Threads->GetAttr($id, 'nopool'));
		push @attrstr, 'sage進行' if ($Threads->GetAttr($id, 'sagemode'));
		$Page->Print("<td>@attrstr</td></tr>\n");
	}
	$common		= "onclick=\"DoSubmit('bbs.pool','DISP'";
	$common2	= "onclick=\"DoSubmit('bbs.pool','FUNC'";
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");
	$Page->Print("<input type=button value=\"　更新　\" $common2,'UPDATE')\"> ")	if ($isUpdate);
	$Page->Print("<input type=button value=\" 全更新 \" $common2,'UPDATEALL')\"> ")	if ($isUpdate);
	$Page->Print("<input type=button value=\"　復帰　\" $common,'REPARE')\"> ")		if ($isRepare);
	$Page->Print("<input type=button value=\"過去ログ化\" $common,'CREATE')\"> ")	if ($isCreate);
	$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ")		if ($isDelete);
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドDAT落ち復帰確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadRepare
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Threads, $id, $subj, $res, $common);
	
	$SYS->Set('_TITLE', 'Pool Thread Repare');
	
	require './module/thread.pl';
	$Threads = POOL_THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<br><center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のPOOLスレッドを復帰します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></tr>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.pool','FUNC','REPARE')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print("<input type=button value=\"　復帰　\" onclick=\"$common\"> ");
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログ化確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadCreate
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Threads, $id, $subj, $res, $common);
	
	$SYS->Set('_TITLE', 'Pool Thread Create');
	
	require './module/thread.pl';
	$Threads = POOL_THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<br><center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のPOOLスレッドを過去ログ化します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></tr>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.pool','FUNC','CREATE')";
	my $isDelete = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_TREADDELETE, $SYS->Get('BBS'));
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print("<input type=button value=\"過去ログ化\" onclick=\"$common\"> ");
	$Page->Print("<label style=\"color:red;\"><input type=checkbox name=\"DELPOOL\" value=\"test\">プールスレッドを削除</label>") if ($isDelete);
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド削除確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadDelete
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Threads, $id, $subj, $res, $common);
	
	$SYS->Set('_TITLE', 'Pool Thread Delete');
	
	require './module/thread.pl';
	$Threads = POOL_THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<br><center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを削除します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></tr>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.pool','FUNC','DELETE')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：削除したスレッドを元に戻すことはできません。</b><br>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print("<input type=button value=\"　削除　\" onclick=\"$common\" class=\"delete\"> ");
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドdat落ち復帰
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadRepare
{
	my ($Sys, $Form, $pLog) = @_;
	my (@threadList, $Threads, $Pools, $path, $bbs, $id);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADPOOL, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	require './module/file_utils.pl';
	$Threads = THREAD->new;
	$Pools = POOL_THREAD->new;
	
	$Threads->Load($Sys);
	$Pools->Load($Sys);
	
	@threadList = $Form->GetAtArray('THREADS');
	$bbs		= $Sys->Get('BBS');
	$path		= $Sys->Get('BBSPATH') . "/$bbs";
	
	foreach $id (@threadList) {
		next if (! defined $Pools->Get('SUBJECT', $id));
		push @$pLog, '"POOLスレッド「' . $Pools->Get('SUBJECT', $id) . '」を復帰';
		$Threads->Add($id, $Pools->Get('SUBJECT', $id), $Pools->Get('RES', $id));
		$Pools->Delete($id);
		
		FILE_UTILS::Move("$path/pool/$id.cgi", "$path/dat/$id.dat");
	}
	$Threads->Save($Sys);
	$Pools->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my (@threadList, $Pools, $path, $bbs, $id);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_TREADDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	$Pools = POOL_THREAD->new;
	
	$Pools->Load($Sys);
	
	@threadList = $Form->GetAtArray('THREADS');
	$bbs		= $Sys->Get('BBS');
	$path		= $Sys->Get('BBSPATH') . "/$bbs";
	
	foreach $id (@threadList) {
		next if (! defined $Pools->Get('SUBJECT', $id));
		push @$pLog, 'POOLスレッド「' . $Pools->Get('SUBJECT', $id) . '」を削除';
		$Pools->Delete($id);
		$Pools->DeleteAttr($id);
		unlink "$path/pool/$id.cgi";
		unlink "$path/log/$id.cgi";
		unlink "$path/log/del_$id.cgi";
	}
	$Pools->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionUpdateSubject
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Pools);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADINFO, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	$Pools = POOL_THREAD->new;
	
	$Pools->Load($Sys);
	$Pools->Update($Sys);
	$Pools->Save($Sys);
	
	push @$pLog, 'POOLスレッド情報(subject.cgi)を更新しました。';
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報全更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionUpdateSubjectAll
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Pools);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADINFO, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	$Pools = POOL_THREAD->new;
	
	$Pools->Load($Sys);
	$Pools->UpdateAll($Sys);
	$Pools->Save($Sys);
	
	push @$pLog, 'POOLスレッド情報(subject.cgi)を再作成しました。';
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログの生成
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionCreateLogs
{
	my ($Sys, $Form, $pLog) = @_;
	
	my $isDelete = $Form->Get('DELPOOL', 0);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_KAKOCREATE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
		
		$isDelete &&= $SEC->IsAuthority($chkID, $ZP::AUTH_TREADDELETE, $Sys->Get('BBS'));
	}
	my @poolSet = $Form->GetAtArray('THREADS');
	
	require './module/dat.pl';
	require './module/buffer_output.pl';
	require './module/setting.pl';
	require './module/data_utils.pl';
	require './module/banner.pl';
	require './module/archive.pl';
	my $Dat = DAT->new;
	my $Set = SETTING->new;
	my $Banner = BANNER->new;
	my $Conv = DATA_UTILS->new;
	my $Page = BUFFER_OUTPUT->new;
	my $Logs = ARCHIVE->new;
	
	$Set->Load($Sys);
	$Banner->Load($Sys);
	$Logs->Load($Sys);
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	my $bCreate = 0;
	
	my $Pools;
	if ($isDelete) {
		require './module/thread.pl';
		$Pools = POOL_THREAD->new;
		$Pools->Load($Sys);
	}
	
	foreach my $key (@poolSet) {
		my $bCreate = 0;
		if ($Dat->Load($Sys,"$path/pool/$key.cgi", 1)) {
			if (CreateKAKOLog($Page, $Sys, $Set, $Banner, $Dat, $Conv, $key)) {
				my $path1 = '/' . substr($key, 0, 4);
				my $path2 = '/' . substr($key, 0, 5);
				if ($Logs->Get('KEY', $key, '') eq '') {
					$Logs->Add($key, $Dat->GetSubject(), time, "$path1$path2");
				}
				else {
					$Logs->($key, 'SUBJECT', $Dat->GetSubject());
					$Logs->($key, 'DATE', time);
					$Logs->($key, 'PATH', "$path1$path2");
				}
				if ($Logs->Get('PATH', $path1, '') eq '') {
					$Logs->Add(0, 0, 0, $path1);
				}
				$bCreate = 1;
				push @$pLog, "■$key：過去ログ生成完了";
				if ($isDelete) {
					push @$pLog, "■$key：プールスレッドを削除";
					$Pools->Delete($key);
					$Pools->DeleteAttr($key);
					unlink "$path/pool/$key.cgi";
					unlink "$path/log/$key.cgi";
					unlink "$path/log/del_$key.cgi";
				}
			}
		}
		if (! $bCreate){
			push @$pLog, "■$key：過去ログ生成失敗";
		}
	}
	
	$Pools->Save($Sys) if ($isDelete);
	$Logs->UpdateIndex($Sys, $Page);
	$Logs->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログの生成 - 1ファイルの出力
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub CreateKAKOLog
{
	my ($Page, $Sys, $Set, $Banner, $Dat, $Conv, $key) = @_;
	my ($datPath, $logDir, $logPath, $i, @color, $title, $account, $board, $var);
	my ($Caption, $cgipath);
	
	$cgipath	= $Sys->Get('CGIPATH');
	
	require './module/header_footer_meta.pl';
	$Caption = HEADER_FOOTER_META->new;
	$Caption->Load($Sys, 'META');
	
	# 過去ログ生成pooldatパスの生成
	$datPath	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/pool/' . $key . '.cgi';
	$logDir		= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/kako/' . substr($key, 0, 4) . '/' . substr($key, 0, 5);
	$logPath	= $logDir . '/' . $key . '.html';
	
	$title 		= $Dat->GetSubject();
	$account	= $Sys->Get('COUNTER');
	$board		= $Sys->Get('CGIPATH') . '/' . $Sys->Get('BBSPATH') . '/'. $Sys->Get('BBS');
	$var		= $Sys->Get('VERSION');
	
	# 色情報取得
	$color[0]	= $Set->Get('BBS_THREAD_COLOR');
	$color[1]	= $Set->Get('BBS_SUBJECT_COLOR');
	$color[2]	= $Set->Get('BBS_TEXT_COLOR');
	$color[3]	= $Set->Get('BBS_LINK_COLOR');
	$color[4]	= $Set->Get('BBS_ALINK_COLOR');
	$color[5]	= $Set->Get('BBS_VLINK_COLOR');
	
	require './module/file_utils.pl';
	
	$Page->Clear();
	
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv="Content-Type" content="text/html;charset=UTF-8">

HTML
	
	$Caption->Print($Page, undef);
	
	$Page->Print(<<HTML);
 <title>$title</title>

</head>
<!--nobanner-->
<body bgcolor="$color[0]" text="$color[2]" link="$color[3]" alink="$color[4]" vlink="$color[5]">

HTML

	# 告知欄出力
	$Banner->Print($Page, 100, 2, 0) if ($Sys->Get('BANNER') & 5);
	
	$Page->Print(<<HTML);
<div style="margin:0px;">
 <a href="http://ofuda.cc/"><img width="400" height="15" border="0" src="http://e.ofuda.cc/disp/$account/00813400.gif" alt="無料アクセスカウンターofuda.cc「全世界カウント計画」"></a>
 <div style="margin-top:1em;">
  <a href="$board/">■掲示板に戻る■</a>
  <a href="$board/kako/">■過去ログ倉庫へ戻る■</a>
 </div>
</div>

<hr style="background-color:#888;color:#888;border-width:0;height:1px;position:relative;top:-.4em;">

<h1 style="color:red;font-size:larger;font-weight:normal;margin:-.5em 0 0;">$title</h1>

HTML
	
	$Page->Print("<dl>\n");
	
	# レスの出力
	for ($i = 0 ; $i < $Dat->Size() ; $i++) {
		PrintResponse($Sys, $Page, $Dat->Get($i), $i + 1, $Conv, $Set);
	}
	
	$Page->Print("</dl>\n");
	
	$Page->Print(<<HTML);

<hr>

<div style="margin-top:1em;">
 <a href="$board/">■掲示板に戻る■</a>
 <a href="$board/kako/">■過去ログ倉庫へ戻る■</a>
</div>
<div align="right">
$var
</div>


HTML
	
	$Page->Print("</body>\n</html>\n");
	$Dat->Close();
	
	# 過去ログの出力
	FILE_UTILS::CreateFolderHierarchy($logDir, $Sys->Get('PM-KDIR'));
	FILE_UTILS::Copy($datPath, "$logDir/$key.dat") or return 0;
	$Page->Flush(1, $Sys->Get('PM-TXT'), $logPath);
	
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログの生成 - 1レスの出力
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub PrintResponse
{
	my ($Sys, $Page, $pDat, $n, $Conv, $Set) = @_;
	my ($oConv, @elem, $nameCol);
	
	$nameCol	= $Set->Get('BBS_NAME_COLOR');
	@elem		= split(/<>/, $$pDat);
	
	# URLと引用個所の適応
	$Conv->ConvertURL($Sys, $Set, 0, \$elem[3]);
	
	$Page->Print(" <dt><a name=\"$n\">$n</a> ：");
	$Page->Print("<font color=\"$nameCol\"><b>$elem[0]</b></font>")	if ($elem[1] eq '');
	$Page->Print("<a href=\"mailto:$elem[1]\"><b>$elem[0]</b></a>")	if ($elem[1] ne '');
	$Page->Print("：$elem[2]</dt>\n  <dd>$elem[3]<br><br></dd>\n");
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
