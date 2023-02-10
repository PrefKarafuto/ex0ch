#============================================================================================================
#
#	スレッド管理 - レス モジュール
#	thread.res.pl
#	---------------------------------------------------------------------------
#	2004.07.21 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
binmode(STDIN,':encoding(cp932)');
binmode(STDOUT,':encoding(cp932)');
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
	my ($subMode, $BASE, $BBS, $DAT, $Page,$Logger);
	
	require './admin/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	$BBS = $pSys->{'AD_BBS'};
	$DAT = $pSys->{'AD_DAT'};
	
	# 掲示板情報の読み込みとグループ設定
	if (! defined $pSys->{'AD_BBS'}) {
		require './module/bbs_info.pl';
		$BBS = BBS_INFO->new;
		
		$BBS->Load($Sys);
		$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
		$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	}
	
	# datの読み込み
	if (! defined $pSys->{'AD_DAT'}) {
		require './module/dat.pl';
		$DAT = DAT->new;
		
		$Sys->Set('KEY', $Form->Get('TARGET_THREAD'));
		my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $Sys->Get('KEY') . '.dat';
		$DAT->Load($Sys, $datPath, 1);
	}
	
	#logの読み込み
	require './module/log.pl';
	$Logger = LOG->new;
	my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $Sys->Get('KEY');
	$Logger->Open($logPath, 0, 1 | 2);
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys, $Sys->Get('BBS'));
	
	if ($subMode eq 'LIST') {														# レス一覧画面
		PrintResList($Page, $Sys, $Form, $DAT,$Logger);
	}
	elsif ($subMode eq 'EDIT') {													# レス編集画面
		PrintResEdit($Page, $Sys, $Form, $DAT);
	}
	elsif ($subMode eq 'ABONE') {													# レス削除確認画面
		PrintResDelete($Page, $Sys, $Form, $DAT, 1);
	}
	elsif ($subMode eq 'DELETE') {													# レス削除確認画面
		PrintResDelete($Page, $Sys, $Form, $DAT, 0);
	}
	elsif ($subMode eq 'DELLUMP') {													# レス一括削除画面
		PrintResLumpDelete($Page, $Sys, $Form, $DAT);
	}
	elsif ($subMode eq 'COMPLETE') {												# 完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('過去ログ処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
	# 掲示板・スレッド情報を設定
	$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	$Page->HTMLInput('hidden', 'TARGET_THREAD', $Form->Get('TARGET_THREAD'));
	
	$BASE->Print($Sys->Get('_TITLE') . ' - ' . $BBS->Get('NAME', $Form->Get('TARGET_BBS'))
					. ' - ' . $DAT->GetSubject(), 3);
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
	my ($subMode, $err, $BBS, $DAT);
	
	require './module/dat.pl';
	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	$DAT = DAT->new;
	
	# 掲示板情報の読み込みとグループ設定
	$BBS->Load($Sys);
	$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	
	# datの読み込み
	$Sys->Set('KEY', $Form->Get('TARGET_THREAD'));
	my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $Sys->Get('KEY') . '.dat';
	$DAT->Load($Sys, $datPath, 1);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 9999;
	
	if ($subMode eq 'EDIT') {													# レス編集
		$err = FunctionResEdit($Sys, $Form, $DAT, $this->{'LOG'});
	}
	elsif ($subMode eq 'ABONE') {												# レスあぼ〜ん
		$err = FunctionResDelete($Sys, $Form, $DAT, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'DELETE') {												# レス削除
		$err = FunctionResDelete($Sys, $Form, $DAT, $this->{'LOG'}, 0);
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "RESPONSE($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "RESPONSE($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$pSys->{'AD_BBS'} = $BBS;
	$pSys->{'AD_DAT'} = $DAT;
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
	
	$Base->SetMenu('レス一覧', "'thread.res','DISP','LIST'");
	
	# レス削除権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_RESDELETE, $bbs)){
		$Base->SetMenu('レス一括削除', "'thread.res','DISP','DELLUMP'");
	}
	# 管理グループ権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_USERGROUP, $bbs)){
	#	$Base->SetMenu('<hr>', '');
	#	$Base->SetMenu('書き込みログ', "'thread.res','DISP','LOG_THREAD_WRITE'");
	}
	$Base->SetMenu('<hr>', '');
	$Base->SetMenu('掲示板管理へ戻る', "'bbs.thread','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	dat変数
#	@return	なし
#
#	2010.08.12 windyakin ★
#	 -> デフォルト表示最新１０に変更
#
#------------------------------------------------------------------------------------------------------------
sub PrintResList
{
	my ($Page, $Sys, $Form, $Dat,$Logger) = @_;
	my (@elem, $resNum, $dispNum, $dispSt, $dispEd, $common, $i);
	my ($pRes, $isAbone, $isEdit, $isAccessUser, $format);
	my ($log, @logs, $datsize, $logsize);
	
	$Sys->Set('_TITLE', 'Res List');
	
	# 表示書式の設定
	$format = $Form->Get('DISP_FORMAT') eq '' ? 'l10' : $Form->Get('DISP_FORMAT');
	($dispSt, $dispEd) = AnalyzeFormat($format, $Dat);
	
	$common = "DoSubmit('thread.res','DISP','LIST');";
	
	$Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2 align=right>表\示書式：<input type=text name=DISP_FORMAT");
	$Page->Print(" value=\"$format\"><input type=button value=\"　表\示　\" onclick=\"$common\">");
	$Page->Print("</td></tr>\n<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30\">　</th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:300\">Contents</td></tr>\n");
	
	# 権限取得
	$isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
	$isEdit = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESEDIT, $Sys->Get('BBS'));
	$isAccessUser = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_ACCESUSER, $Sys->Get('BBS'));
	
	$datsize = $Dat->Size();
	$logsize = $Logger->Size();
	
	$datsize -= 1 if ($Dat->IsStopped($Sys));
	
	# レス一覧を出力
	my $offset = $logsize - $datsize;
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$pRes	= $Dat->Get($i);
		@elem	= split(/<>/, $$pRes);
		
		for my $d (0, 1, -1, 2, 3, -2, -3) {
			$log = $Logger->Get($offset+$d + $i);
			@logs = split(/<>/, $log, -1) if (defined $log);
			if (defined $log && $logs[2] eq $elem[2]) {
				# ログとレスが一致
				$offset += $d;
				last;
			}
			$log = undef;
			@logs = ();
		}
		
		foreach (0 .. $#logs) {
			$logs[$_] =~ s/[\x0d\x0a\0]//g;
			$logs[$_] =~ s/&/&amp;/g;
			$logs[$_] =~ s/"/&quot;/g;
			$logs[$_] =~ s/'/&#39;/g;
			$logs[$_] =~ s/</&lt;/g;
			$logs[$_] =~ s/>/&gt;/g;
		}
		
		$Page->Print("<tr><td class=\"Response\" valign=top>");
		
		# レス削除権による表示抑制
		if ($isAbone) {
			$Page->Print("<input type=checkbox name=RESS value=$i></td>");
		}
		else {
			$Page->Print("</td>");
		}
		$Page->Print("<td class=\"Response\"><dt>");
		
		# レス編集権による表示抑制
		if ($isEdit) {
			$common = "\"javascript:SetOption('SELECT_RES','$i');";
			$common = $common . "DoSubmit('thread.res','DISP','EDIT')\"";
			$Page->Print("<a href=$common>" . ($i + 1) . "</a>");
		}
		else {
			$Page->Print('' . ($i + 1));
		}
		$Page->Print("：<font color=forestgreen><b>$elem[0]</b></font>[$elem[1]]");
		$Page->Print("：$elem[2]</dt><dd>$elem[3]");
		$Page->Print("<br><br><hr>HOST:$logs[5]<br>IP:$logs[6]<br>UA:$logs[8]") if (defined $log && $isAccessUser);
		$Page->Print("</dd></td></tr>\n");
	}
	$Page->HTMLInput('hidden', 'SELECT_RES', '');
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# システム権限有無による表示抑制
	if ($isAbone) {
		$common = "onclick=\"DoSubmit('thread.res','DISP'";
		$Page->Print("<tr><td colspan=2 align=right>");
		$Page->Print("<input type=button value=\"あぼ〜ん\" $common,'ABONE')\"> ");
		$Page->Print("<input type=button value=\"透明あぼ〜ん\" $common,'DELETE')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table></dl><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	dat変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResEdit
{
	my ($Page, $Sys, $Form, $Dat) = @_;
	my (@elem, $pRes, $isEdit, $common);
	
	$Sys->Set('_TITLE', 'Res Edit');
	
	$isEdit = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESEDIT, $Sys->Get('BBS'));
	$pRes	= $Dat->Get($Form->Get('SELECT_RES'));
	@elem	= split(/<>/, $$pRes);
	
	$elem[3] =~ s/^ //;
	$elem[3] =~ s/ $//;
	$elem[3] =~ s/ ?<br> ?/\n/g;
	foreach (0 .. 3) {
		$elem[$_] =~ s/&/&amp;/g;
		$elem[$_] =~ s/"/&quot;/g;
		$elem[$_] =~ s/</&lt;/g;
		$elem[$_] =~ s/>/&gt;/g;
	}
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名前</td><td>");
	$Page->Print("<input type=text size=50 value=\"$elem[0]\" name=FROM></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">メール</td><td>");
	$Page->Print("<input type=text size=50 value=\"$elem[1]\" name=mail></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">日付・ID</td><td>");
	$Page->Print("<input type=text size=50 value=\"$elem[2]\" name=_DATE_></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">本文</td><td>");
	$Page->Print("<textarea name=MESSAGE cols=70 rows=10>$elem[3]</textarea></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	
	$Page->HTMLInput('hidden', 'SELECT_RES', $Form->Get('SELECT_RES'));
	
	# システム権限有無による表示抑制
	if ($isEdit) {
		$common = "onclick=\"DoSubmit('thread.res','FUNC'";
		$Page->Print("<tr><td colspan=2 align=right>");
		$Page->Print("<input type=button value=\"　変更　\" $common,'EDIT')\"> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス削除確認の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	dat変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResDelete
{
	my ($Page, $Sys, $Form, $Dat, $mode) = @_;
	my (@resSet, @elem, $pRes, $num, $common, $isAbone);
	
	$Sys->Set('_TITLE', 'Res Delete Confirm');
	
	# 選択レスを取得
	@resSet = $Form->GetAtArray('RESS');
	
	# 権限取得
	$isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
	
	$Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td>以下のレスを" . ($mode ? 'あぼ〜ん' : '削除') . "します。</td></tr>\n");
	$Page->Print("<tr><td><hr></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">Contents</td></tr>\n");
	
	# レス一覧を出力
	foreach $num (@resSet) {
		$pRes	= $Dat->Get($num);
		@elem	= split(/<>/, $$pRes);
		
		$Page->Print("<tr><td class=\"Response\"><dt>" . ($num + 1));
		$Page->Print("：<font color=forestgreen><b>$elem[0]</b></font>[$elem[1]]");
		$Page->Print("：$elem[2]</dt><dd>$elem[3]<br><br></dd></td></tr>\n");
		$Page->HTMLInput('hidden', 'RESS', $num);
	}
	$Page->Print("<tr><td><hr></td></tr>\n");
	
	# システム権限有無による表示抑制
	if ($isAbone) {
		$common = "onclick=\"DoSubmit('thread.res','FUNC','";
		$common = $common . ($mode ? 'ABONE' : 'DELETE') . "')\"";
		$Page->Print("<tr><td align=right>");
		$Page->Print("<input type=button value=\"　実行　\" $common> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table></dl><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス一括削除の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	dat変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResLumpDelete
{
	my ($Page, $Sys, $Form, $Dat) = @_;
	my (@resSet, @elem, $pRes, $format, $num, $common, $isAbone);
	
	$Sys->Set('_TITLE', 'Res Lump Delete');
	
	# 書式の解析
	$num = 0;
	$format = $Form->Get('DEL_FORMAT');
	if ($format ne '') {
		AnalyzeDeleteFormat($format, $Dat, \@resSet);
		$num = @resSet;
	}
	
	# 権限取得
	$isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
	
	$Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">削除レス書式</td><td>");
	$Page->Print("<input type=text name=DEL_FORMAT size=40 value=$format></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	if ($num > 0) {
		$Page->Print("<tr><td colspan=2 class=\"DetailTitle\">Delete Contents</td></tr>");
		
		# レス一覧を出力
		foreach $num (@resSet) {
			$pRes	= $Dat->Get($num);
			@elem	= split(/<>/, $$pRes);
			
			$Page->Print("<tr><td colspan=2 class=\"Response\"><dt>" . ($num + 1));
			$Page->Print("：<font color=forestgreen><b>$elem[0]</b></font>[$elem[1]]");
			$Page->Print("：$elem[2]</dt><dd>$elem[3]<br><br></dd></td></tr>\n");
			$Page->HTMLInput('hidden', 'RESS', $num);
		}
		$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	}
	
	# システム権限有無による表示抑制
	if ($isAbone) {
		$common = "onclick=\"DoSubmit('thread.res'";
		$Page->Print("<tr><td align=right colspan=2>");
		$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','DELLUMP')\" style=\"float: left;\"> ");
		$Page->Print("<input type=button value=\"あぼ〜ん\" $common,'FUNC','ABONE')\"> ");
		$Page->Print("<input type=button value=\"透明あぼ〜ん\" $common,'FUNC','DELETE')\"> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table></dl><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	Dat変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionResEdit
{
	my ($Sys, $Form, $Dat, $pLog) = @_;
	my (@elem, $pRes, $data);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESEDIT, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	
	# 書き込みモードで読み直す
	$Dat->ReLoad($Sys, 0);
	
	$pRes = $Dat->Get($Form->Get('SELECT_RES'));
	@elem = split(/<>/, $$pRes);
	$elem[0] = $Form->Get('FROM');
	$elem[1] = $Form->Get('mail');
	$elem[2] = $Form->Get('_DATE_');
	$elem[3] = $Form->Get('MESSAGE');
	
	# 改行・禁則文字の変換
	$elem[3] =~ s/\r\n|\r|\n/ <br> /g;
	$elem[3] =~ s/<>/&lt;&gt;/g;
	$elem[3] = " $elem[3] ";
	
	# データの連結
	$data = join('<>', @elem);
	
	# データの設定と保存
	$Dat->Set($Form->Get('SELECT_RES'), $data);
	$Dat->Save($Sys);
	
	# ログの設定
	push @$pLog, '番号[' . $Form->Get('SELECT_RES') . ']のレスを以下のように変更しました。';
	foreach (@elem) {
		push @$pLog, $_;
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	レス削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	Dat変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionResDelete
{
	my ($Sys, $Form, $Dat, $pLog, $mode) = @_;
	my (@resSet, $pRes, $abone, $path, $tm, $user, $delCnt, $num, $datPath, $LOG, $logsize, $lastnum);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID	= $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	
	# あぼ〜ん時は削除名を取得
	if ($mode) {
		my $Setting;
		require './module/setting.pl';
		$Setting = SETTING->new;
		$Setting->Load($Sys);
		$abone	= $Setting->Get('BBS_DELETE_NAME');
	}
	else {
		require './module/manager_log.pl';
		$LOG = MANAGER_LOG->new;
		$LOG->Load($Sys, 'WRT', $Sys->Get('KEY'));
		$logsize = $LOG->Size();
		$lastnum = $Dat->Size() - 1;
	}
	
	# 各値を設定
	@resSet	= $Form->GetAtArray('RESS');
	$datPath= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $Sys->Get('KEY') . '.dat';
	$path	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/del_' . $Sys->Get('KEY') . '.cgi';
	$tm		= time;
	$user	= $Form->Get('UserName');
	$delCnt	= 0;
	
	# datを書き込みモードで読み直す
	$Dat->Close();
	$Dat->Load($Sys, $datPath, 0);
	
	# 削除と同時に削除ログへ削除した内容を保存する
	chmod($Sys->Get('PM-LOG'), $path);
	if (open(my $f_dellog, '>>', $path)) {
		flock($f_dellog, 2);
		binmode($f_dellog);
		foreach $num (sort {$b <=> $a} @resSet) {
			next if ($num == 0);
			$pRes = $Dat->Get($num);
			print $f_dellog "$tm<>$user<>$num<>$mode<>$$pRes";
			if ($mode) {
				$Dat->Set($num, "$abone<>$abone<>$abone<>$abone<>$abone\n");
			}
			else {
				$Dat->Delete($num);
				$_ = $logsize - 1 + $num - $lastnum;
				if ($_ >= 0) {
					$LOG->Delete($_);
					$logsize --;
				}
				$lastnum --;
			}
		}
		close($f_dellog);
		chmod($Sys->Get('PM-LOG'), $path);
		
		# 保存
		$Dat->Save($Sys);
		$LOG->Save($Sys) if (! $mode);
	}
	
	# ログの設定
	$delCnt = 0;
	$abone	= '';
	push @$pLog, '以下のレスを' . ($mode ? 'あぼ〜ん' : '削除') . 'しました。';
	foreach (@resSet) {
		next if ($_ == 0);
		if ($delCnt > 5) {
			push @$pLog, $abone;
			$abone = '';
			$delCnt = 0;
		}
		else {
			$abone .= ($_ + 1) . ', ';
			$delCnt ++;
		}
	}
	push @$pLog, $abone;
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	削除書式の解析
#	-------------------------------------------------------------------------------------
#	@param	$format	書式文字列
#	@param	$Dat	DATオブジェクト
#	@param	$pSet	結果格納配列の参照
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub AnalyzeDeleteFormat
{
	my ($format, $Dat, $pSet) = @_;
	my (%deleteTable, @elem, $i, $st, $ed);
	
	# セパレータで分解
	@elem = split(/\, /, $format);
	
	# 1区分ずつ書式解析をしてハッシュ(二重登録防止のため)に格納
	foreach (@elem){
		($st, $ed) = AnalyzeFormat($_, $Dat);
		if ($st != 0 || $ed != 0) {
			for ($i = $st ; $i < $ed ; $i++) {
				$deleteTable{$i} = 'true';
			}
		}
	}
	
	# 結果を配列に設定
	foreach (sort {$a <=> $b} (keys %deleteTable)) {
		push @$pSet, $_;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	書式の解析
#	-------------------------------------------------------------------------------------
#	@param	$format	書式文字列
#	@param	$Dat	DATオブジェクト
#	@return	(開始番号, 終了番号)
#
#------------------------------------------------------------------------------------------------------------
sub AnalyzeFormat
{
	my ($format, $Dat) = @_;
	my ($start, $end, $max);
	
	# 書式エラー
	if ($format =~ /[^0-9\-l]/ || $format eq '') {
		return (0, 0);
	}
	$max = $Dat->Size();
	
	# 最新n件
	if ($format =~ /l(\d+)/) {
		$end	= $max;
		$start	= ($max - $1 + 1) > 0 ? ($max - $1 + 1) : 1;
	}
	# n〜m
	elsif ($format =~ /(\d+)-(\d+)/) {
		$start	= $1 > $max ? $max : $1;
		$end	= $2 > $max ? $max : $2;
	}
	# n以降すべて
	elsif ($format =~ /(\d+)-/) {
		$start	= $1 > $max ? $max : $1;
		$end	= $max;
	}
	# n以前すべて
	elsif ($format =~ /-(\d+)/) {
		$start	= 1;
		$end	= $1 > $max ? $max : $1;
	}
	# nのみ
	elsif ($format =~ /(\d+)/) {
		$start	= $1 > $max ? $max : $1;
		$end	= $1 > $max ? $max : $1;
	}
	
	# 順序正規化
	if ($start > $end) {
		$max = $start;
		$start = $end;
		$end = $start;
	}
	
	return ($start - 1, $end);
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
