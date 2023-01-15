#============================================================================================================
#
#	掲示板管理 - ログ閲覧 モジュール
#	bbs.log.pl
#	---------------------------------------------------------------------------
#	2005.05.21 start
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
	
	if ($subMode eq 'INFO') {														# トップ画面
		PrintLogsInfo($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'THREADLOG') {												# スレッド作成ログ画面
		PrintLogs($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'HOSTLOG') {													# ホストログ画面
		PrintLogs($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'ERRORLOG') {												# エラーログ画面
		PrintLogs($Page, $Sys, $Form, 2);
	}
	elsif ($subMode eq 'COMPLETE') {												# 完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('ログ操作処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 失敗画面
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
	
	if ($subMode eq 'REMOVE_THREADLOG') {										# ログ削除
		$err = FunctionLogDelete($Sys, $Form, 0, $this->{'LOG'});
	}
	elsif ($subMode eq 'REMOVE_HOSTLOG') {										# ログ削除
		$err = FunctionLogDelete($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'REMOVE_ERRORLOG') {										# ログ削除
		$err = FunctionLogDelete($Sys, $Form, 2, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "BBS_LOG($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "BBS_LOG($subMode)", 'COMPLETE');
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
	
	$Base->SetMenu('ログ情報', "'bbs.log','DISP','INFO'");
	$Base->SetMenu('<hr>', '');
	
	# ログ閲覧権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_LOGVIEW, $bbs)) {
		$Base->SetMenu('スレッド作成ログ', "'bbs.log','DISP','THREADLOG'");
		$Base->SetMenu('ホストログ', "'bbs.log','DISP','HOSTLOG'");
		$Base->SetMenu('エラーログ', "'bbs.log','DISP','ERRORLOG'");
		$Base->SetMenu('<hr>', '');
	}
	$Base->SetMenu('システム管理へ戻る', "'sys.bbs','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ情報の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintLogsInfo
{
	my ($Page, $Sys, $Form) = @_;
	my (@logFiles, $i, $size, $date);
	
	$logFiles[0] = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/IP.cgi';
	$logFiles[1] = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/HOST.cgi';
	$logFiles[2] = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/errs.cgi';
	
	$Sys->Set('_TITLE', 'Log Information');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\" style=\"width:50\">Log Kind</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">Log File</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:200\">File Size</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Last Update</td></tr>\n");
	
	require './module/galadriel.pl';
	my @logKind = ('スレッド作成ログ', 'ホストログ', 'エラーログ');
	
	for ($i = 0 ; $i < 3 ; $i++) {
		$size = (stat $logFiles[$i])[7];
		$date = (stat _)[9];
		$date = DATA_UTILS::GetDateFromSerial(undef, $date, 0);
		
		$Page->Print("<tr><td>$logKind[$i]</td>");
		$Page->Print("<td>$logFiles[$i]</td>");
		$Page->Print("<td>$size bytes</td>");
		$Page->Print("<td>$date</td></tr>\n");
	}
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	$Page->Print("</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	ログの表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	0:スレッド作成ログ
#					1:ホストログ
#					2:エラーログ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintLogs
{
	my ($Page, $Sys, $Form, $mode) = @_;
	my ($Logger, $common, $logFile, $keyNum, $keySt);
	my ($dispNum, $i, $dispSt, $dispEd, $listNum, $isSysad, $data, @elem);
	
	$Sys->Set('_TITLE', 'Thread Create Log')	if ($mode == 0);
	$Sys->Set('_TITLE', 'Hosts Log')			if ($mode == 1);
	$Sys->Set('_TITLE', 'Error Log')			if ($mode == 2);
	
	require './module/log.pl';
	$Logger = LOG->new;
	
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/IP'	if ($mode == 0);
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/HOST'	if ($mode == 1);
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/errs'	if ($mode == 2);
	$Logger->Open($logFile, 0, 1 | 2);
	
	$keyNum = 'DISPNUM_' . $Form->Get('MODE_SUB');
	$keySt = 'DISPST_' . $Form->Get('MODE_SUB');
	
	# 表示数の設定
	$listNum	= $Logger->Size();
	$dispNum	= ($Form->Get($keyNum) eq '' ? 10 : $Form->Get($keyNum));
	$dispSt		= ($Form->Get($keySt) eq '' ? 0 : $Form->Get($keySt));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $listNum ? $listNum : ($dispSt + $dispNum));
	$common		= "DoSubmit('bbs.log','DISP','" . $Form->Get('MODE_SUB') . "');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><b><a href=\"javascript:SetOption('$keySt', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('$keySt', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td align=right colspan=2>");
	$Page->Print("表\示数<input type=text name=$keyNum size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表\示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	
	# カラムヘッダの表示
	$Page->Print("<tr><td class=\"DetailTitle\">Date</td>");
	if ($mode == 0) {
		$Page->Print("<td class=\"DetailTitle\">Thread KEY</td>");
		$Page->Print("<td class=\"DetailTitle\">Script ver.</td>");
		$Page->Print("<td class=\"DetailTitle\">Create HOST</td></tr>\n");
	}
	elsif ($mode == 1) {
		$Page->Print("<td class=\"DetailTitle\">HOST</td>");
		$Page->Print("<td class=\"DetailTitle\">Thread KEY</td>");
		$Page->Print("<td class=\"DetailTitle\">Operation</td></tr>\n");
	}
	elsif ($mode == 2) {
		$Page->Print("<td class=\"DetailTitle\">Error Code</td>");
		$Page->Print("<td class=\"DetailTitle\">Script ver.</td>");
		$Page->Print("<td class=\"DetailTitle\">HOST</td></tr>\n");
	}
	
	require './module/galadriel.pl';
	require './module/error_info.pl';
	my $Error = ERROR_INFO->new;
	$Error->Load($Sys);
	
	# ログ一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$data = $Logger->Get($listNum - $i - 1);
		@elem = split(/<>/, $data);
		if (1) {
			$elem[0] = DATA_UTILS::GetDateFromSerial(undef, $elem[0], 0);
			if ($mode == 2) {
				$elem[1] .= ' (' . $Error->Get($elem[1], 'SUBJECT') . ')';
			}
			$Page->Print("<tr><td>$elem[0]</td><td>$elem[1]</td><td>$elem[2]</td><td>$elem[3]</td></tr>\n");
		}
		else {
			$dispEd++ if ($dispEd + 1 < $listNum);
		}
	}
	$common = "onclick=\"DoSubmit('bbs.log','FUNC'";
	
	$Page->Print("<tr><td colspan=4><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=4 align=left>");
	$Page->Print("<input type=button value=\"　削除　\" $common,'REMOVE_" . $Form->Get('MODE_SUB') . "')\" class=\"delete\"> ");
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	$Page->HTMLInput('hidden', $keySt, '');
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	0:スレッド作成ログ
#					1:ホストログ
#					2:エラーログ
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionLogDelete
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Logger, $logFile, $size, @dummy);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_LOGVIEW, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/log.pl';
	$Logger = LOG->new;
	
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/IP'	if ($mode == 0);
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/HOST'	if ($mode == 1);
	$logFile = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/errs'	if ($mode == 2);
	
	# ログ情報の削除
	$Logger->Open($logFile, 0, 2 | 4);
	
	# 既存ログを退避する
	$Logger->MoveToOld();
	push @$pLog, '既存ログの退避完了...';
	
	# ログのクリアと保存
	$Logger->Clear();
	$Logger->Write();
	$Logger->Close();
	push @$pLog, 'ログの削除完了...';
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
