#============================================================================================================
#
#	システム管理 - ユーザ モジュール
#	sys.top.pl
#	---------------------------------------------------------------------------
#	2004.09.11 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
no warnings 'redefine';

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
	
	if ($subMode eq 'NOTICE') {														# 通知一覧画面
		CheckVersionUpdate($Sys);
		PrintNoticeList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'NOTICE_CREATE') {											# 通知一覧画面
		PrintNoticeCreate($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'ADMINLOG') {												# ログ閲覧画面
		PrintAdminLog($Page, $Sys, $Form, $pSys->{'LOGGER'});
	}
	elsif ($subMode eq 'EXTIMELOG') {												# BBS.CGI実行時間ログ閲覧画面
		PrintExecutionTimeLog($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# 設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('ユーザ通知処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 設定失敗画面
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
	
	if ($subMode eq 'CREATE') {														# 通知作成
		$err = FunctionNoticeCreate($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {													# 通知削除
		$err = FunctionNoticeDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'LOG_REMOVE') {												# 操作ログ削除
		$err = FunctionLogRemove($Sys, $Form, $pSys->{'LOGGER'}, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "SYSTEM_TOP($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "SYSTEM_TOP($subMode)", 'COMPLETE');
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
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys) = @_;
	
	# 共通表示メニュー
	$Base->SetMenu('ユーザ通知一覧', "'sys.top','DISP','NOTICE'");
	$Base->SetMenu('ユーザ通知作成', "'sys.top','DISP','NOTICE_CREATE'");
	
	# システム管理権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_SYSADMIN, '*')) {
		$Base->SetMenu('<hr>', '');
		$Base->SetMenu('操作ログ閲覧', "'sys.top','DISP','ADMINLOG'");
		# デバッグ用
		#$Base->SetMenu('BBS.CGI実行時間ログ閲覧', "'sys.top','DISP','EXTIMELOG'");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ通知一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNoticeList
{
	my ($Page, $Sys, $Form) = @_;
	my ($Notices, @noticeSet, $from, $subj, $text, $date, $id, $common);
	my ($dispNum, $i, $dispSt, $dispEd, $listNum, $isAuth, $curUser);
	my ($orz, $or2);
	
	$Sys->Set('_TITLE', 'User Notice List');
	
	require './module/notice.pl';
	require './module/data_utils.pl';
	$Notices = NOTICE->new;
	
	# 通知情報の読み込み
	$Notices->Load($Sys);
	
	# 通知情報を取得
	$Notices->GetKeySet('ALL', '', \@noticeSet);
	@noticeSet = sort @noticeSet;
	@noticeSet = reverse @noticeSet;
	
	# 表示数の設定
	$listNum	= @noticeSet;
	$dispNum	= $Form->Get('DISPNUM_NOTICE', 5) || 5;
	$dispSt		= $Form->Get('DISPST_NOTICE', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $listNum ? $listNum : ($dispSt + $dispNum));
	
	$orz = $dispSt - $dispNum;
	$or2 = $dispSt + $dispNum;
	
	$common		= "DoSubmit('sys.top','DISP','NOTICE');";
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="2" width="100%">
   <tr>
	<td>
	</td>
	<td>
	<a href="javascript:SetOption('DISPST_NOTICE', $orz);$common">&lt;&lt; PREV</a> |
	<a href="javascript:SetOption('DISPST_NOTICE', $or2);$common">NEXT &gt;&gt;</a>
	</td>
	<td align=right colspan="2">
	表示数 <input type=text name="DISPNUM_NOTICE" size="4" value="$dispNum">
	<input type=button value="　表示　" onclick="$common">
	</td>
   </tr>
   <tr>
	<td style="width:30px;"><br></td>
	<td colspan="3" class="DetailTitle">Notification</td>
   </tr>
HTML
	
	# カレントユーザ
	$curUser = $Sys->Get('ADMIN')->{'USER'};
	
	# 通知一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$id = $noticeSet[$i];
		if ($Notices->IsInclude($id, $curUser) && ! $Notices->IsLimitOut($id)) {
			if ($Notices->Get('FROM', $id) eq '0000000000') {
				$from = 'ex0ch管理システム';
			}
			else {
				$from = $Sys->Get('ADMIN')->{'SECINFO'}->{'USER'}->Get('NAME', $Notices->Get('FROM', $id));
			}
			$subj = $Notices->Get('SUBJECT', $id);
			$text = $Notices->Get('TEXT', $id);
			$date = DATA_UTILS::GetDateFromSerial(undef, $Notices->Get('DATE', $id), 0);
			
$Page->Print(<<HTML);
   <tr>
	<td><input type=checkbox name="NOTICES" value="$id"></td>
	<td class="Response" colspan="3">
	<dl style="margin:0px;">
	 <dt><b>$subj</b> <font color="blue">From：$from</font> $date</dt>
	  <dd>
	  $text<br>
	  <br></dd>
	</dl>
	</td>
   </tr>
HTML

		}
		else {
			$dispEd++ if ($dispEd + 1 < $listNum);
		}
	}
	
$Page->Print(<<HTML);
   <tr>
	<td colspan="4" align="left">
	<input type="button" class="delete" value="　削除　" onclick="DoSubmit('sys.top','FUNC','DELETE')">
	</td>
   </tr>
  </table>
  <input type="hidden" name="DISPST_NOTICE" value="">
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ通知作成画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNoticeCreate
{
	my ($Page, $Sys, $Form) = @_;
	my ($isSysad, $User, @userSet, $id, $name, $full, $common);
	
	$Sys->Set('_TITLE', 'User Notice Create');
	
	$isSysad = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');
	$User = $Sys->Get('ADMIN')->{'SECINFO'}->{'USER'};
	$User->GetKeySet('ALL', '', \@userSet);
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="2" width="100%">
	<tr>
	<td class="DetailTitle">タイトル</td>
	<td><input type="text" size="60" name="NOTICE_TITLE"></td>
   </tr>
   <tr>
	<td class="DetailTitle">本文</td>
	<td>
	<textarea rows="10" cols="70" name="NOTICE_CONTENT"></textarea>
	</td>
   </tr>
   <tr>
	<td class="DetailTitle">通知先ユーザ</td>
	<td>
	<table width="100%" cellspacing="2">
HTML
	
	if ($isSysad) {
		
$Page->Print(<<HTML);
	 <tr>
	  <td class="DetailTitle">
	  <input type="radio" name="NOTICE_KIND" value="ALL">全体通知
	  </td>
	  <td>
	  有効期限：<input type="text" name="NOTICE_LIMIT" size="10" value="30">日
	  </td>
	 </tr>
	 <tr>
	  <td class="DetailTitle">
	  <input type="radio" name="NOTICE_KIND" value="ONE" checked>個別通知
	  </td>
	  <td>
HTML
	}
	else {
$Page->Print(<<HTML);
	 <tr>
	  <td class="DetailTitle">
	  <input type="radio" name="NOTICE_KIND" value="ONE" checked>個別通知
	  </td>
	  <td>
HTML
	}
	
	# ユーザ一覧を表示
	foreach $id (@userSet) {
		$name = $User->Get('NAME', $id);
		$full = $User->Get('FULL', $id);
		$Page->Print("      <input type=\"checkbox\" name=\"NOTICE_USERS\" value=\"$id\"> $name($full)<br>\n");
	}
	
$Page->Print(<<HTML);
	  </td>
	 </tr>
	</table>
	</td>
   </tr>
   <tr>
	<td colspan="2" align="left">
	<input type="button" value="　送信　" onclick="DoSubmit('sys.top','FUNC','CREATE')">
	</td>
   </tr>
  </table>
HTML
}

#------------------------------------------------------------------------------------------------------------
#
#	管理操作ログ閲覧画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintAdminLog
{
	my ($Page, $Sys, $Form, $Logger) = @_;
	my ($common);
	my ($dispNum, $i, $dispSt, $dispEd, $listNum, $isSysad, $data, @elem);
	my ($orz, $or2);
	
	$Sys->Set('_TITLE', 'Operation Log');
	$isSysad = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');
	
	# 表示数の設定
	$listNum	= $Logger->Size();
	$dispNum	= ($Form->Get('DISPNUM_LOG') eq '' ? 10 : $Form->Get('DISPNUM_LOG'));
	$dispSt		= ($Form->Get('DISPST_LOG') eq '' ? 0 : $Form->Get('DISPST_LOG'));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $listNum ? $listNum : ($dispSt + $dispNum));
	$common		= "DoSubmit('sys.top','DISP','ADMINLOG');";
	
	$orz		= $dispSt - $dispNum;
	$or2		= $dispSt + $dispNum;
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="2" width="100%">
   <tr>
	<td colspan="2">
	<a href="javascript:SetOption('DISPST_LOG', $orz);$common">&lt;&lt; PREV</a> |
	<a href="javascript:SetOption('DISPST_LOG', $or2);$common">NEXT &gt;&gt;</a>
	</td>
	<td align="right" colspan="2">
	表示数 <input type="text" name="DISPNUM_LOG" size="4" value="$dispNum">
	<input type="button" value="　表示　" onclick="$common">
	</td>
   </tr>
   <tr>
	<td class="DetailTitle">Date</td>
	<td class="DetailTitle">User</td>
	<td class="DetailTitle">Operation</td>
	<td class="DetailTitle">Result</td>
   </tr>
HTML
	
	require './module/data_utils.pl';
	
	# ログ一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$data = $Logger->Get($listNum - $i - 1);
		@elem = split(/<>/, $data);
		if (1) {
			$elem[0] = DATA_UTILS::GetDateFromSerial(undef, $elem[0], 0);
			DATA_UTILS::ConvertCharacter1(undef, \$elem[1], 0);
			$Page->Print("   <tr><td>$elem[0]</td><td>$elem[1]</td><td>$elem[2]</td><td>$elem[3]</td></tr>\n");
		}
		else {
			$dispEd++ if ($dispEd + 1 < $listNum);
		}
	}
	
$Page->Print(<<HTML);
   <tr>
	<td colspan="4"><hr></td>
   </tr>
   <tr>
	<td colspan="4" align="right">
	<input type="button" value="ログの削除" onclick="DoSubmit('sys.top','FUNC','LOG_REMOVE')" class=\"delete\">
	</td>
   </tr>
  </table>
  
  <input type="hidden" name="DISPST_LOG" value="">
  
HTML
	
}

#------------------------------------------------------------------------------------------------------------
#
#	BBS.CGI実行時間計測ログ閲覧画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintExecutionTimeLog
{
	my ($Page, $Sys, $Form) = @_;
	my ($common);
	my ($dispNum, $i, $dispSt, $dispEd, $listNum, $isSysad, $data, @elem);
	my ($orz, $or2);
	
	$Sys->Set('_TITLE', 'Execution Time Log');
	$isSysad = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');
	
	# 表示数の設定
	require './module/log.pl';
	my $exLog = LOG->new;
	$exLog->Open('.'.$Sys->Get('INFO').'/execution_time', 0, 1 | 2);
	$listNum	= $exLog->Size();
	$dispNum	= ($Form->Get('DISPNUM_LOG') eq '' ? 10 : $Form->Get('DISPNUM_LOG'));
	$dispSt		= ($Form->Get('DISPST_LOG') eq '' ? 0 : $Form->Get('DISPST_LOG'));
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $listNum ? $listNum : ($dispSt + $dispNum));
	$common		= "DoSubmit('sys.top','DISP','EXTIMELOG');";
	
	$orz		= $dispSt - $dispNum;
	$or2		= $dispSt + $dispNum;
	
$Page->Print(<<HTML);
  <table border="0" cellspacing="2" width="100%">
   <tr>
	<td colspan="2">
	<a href="javascript:SetOption('DISPST_LOG', $orz);$common">&lt;&lt; PREV</a> |
	<a href="javascript:SetOption('DISPST_LOG', $or2);$common">NEXT &gt;&gt;</a>
	</td>
	<td align="right" colspan="2">
	表示数 <input type="text" name="DISPNUM_LOG" size="4" value="$dispNum">
	<input type="button" value="　表示　" onclick="$common">
	</td>
   </tr>
   <tr>
	<td class="DetailTitle">Date</td>
	<td class="DetailTitle">ExecutionTime [msec]</td>
	<td class="DetailTitle">BBS (:FastCGI count)</td>
	<td class="DetailTitle">Result</td>
   </tr>
HTML
	
	require './module/data_utils.pl';
	
	# ログ一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$data = $exLog->Get($listNum - $i - 1);
		@elem = split(/<>/, $data);
		if (1) {
			my ($s,$m,$h,$d,$t,$y) = localtime($elem[0]);
			$y += 1900;
			$t++;
			my $result = $elem[3] ? $elem[3] : 'Success';
			my $msec = $elem[1] * 1000;
			my $date = sprintf("%d/%02d/%02d %02d:%02d:%02d",$y,$t,$d,$h,$m,$s);
			$Page->Print("   <tr><td>$date</td><td>$msec</td><td>$elem[2]</td><td>$result</td></tr>\n");
		}
		else {
			$dispEd++ if ($dispEd + 1 < $listNum);
		}
	}
	
$Page->Print(<<HTML);
   <tr>
	<td colspan="4"><hr></td>
   </tr>
   <tr>
	<td colspan="4" align="right">
	サーバーの管理画面で直接ログファイルを削除してください。
	</td>
   </tr>
  </table>
  
  <input type="hidden" name="DISPST_LOG" value="">
  
HTML
	
}
#------------------------------------------------------------------------------------------------------------
#
#	ユーザ通知作成
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionNoticeCreate
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Notice, $subject, $content, $date, $limit, $users);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if ($chkID eq '') {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = ('NOTICE_TITLE', 'NOTICE_CONTENT');
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
		@inList = ('NOTICE_LIMIT');
		if ($Form->Equal('NOTICE_KIND', 'ALL') && ! $Form->IsInput(\@inList)) {
			return 1001;
		}
		@inList = ('NOTICE_USERS');
		if ($Form->Equal('NOTICE_KIND', 'ONE') && ! $Form->IsInput(\@inList)) {
			return 1001;
		}
	}
	require './module/notice.pl';
	$Notice = NOTICE->new;
	$Notice->Load($Sys);
	
	$date = time;
	$subject = $Form->Get('NOTICE_TITLE');
	$content = $Form->Get('NOTICE_CONTENT');
	
	require './module/data_utils.pl';
	DATA_UTILS::ConvertCharacter1(undef, \$subject, 0);
	DATA_UTILS::ConvertCharacter1(undef, \$content, 2);
	
	if ($Form->Equal('NOTICE_KIND', 'ALL')) {
		$users = '*';
		$limit = $Form->Get('NOTICE_LIMIT');
		$limit = $date + ($limit * 24 * 60 * 60);
	}
	else {
		my @toSet = $Form->GetAtArray('NOTICE_USERS');
		$users = join(',', @toSet);
		$limit = 0;
	}
	# 通知情報を追加
	$Notice->Add($users, $Sys->Get('ADMIN')->{'USER'}, $subject, $content, $limit);
	$Notice->Save($Sys);
	
	push @$pLog, 'ユーザへの通知終了';
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	通知削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionNoticeDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Notice, @noticeSet, $curUser, $id);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if ($chkID eq '') {
			return 1000;
		}
	}
	require './module/notice.pl';
	$Notice = NOTICE->new;
	$Notice->Load($Sys);
	
	@noticeSet = $Form->GetAtArray('NOTICES');
	$curUser = $Sys->Get('ADMIN')->{'USER'};
	
	foreach $id	(@noticeSet) {
		next if (! defined $Notice->Get('SUBJECT', $id));
		if ($Notice->Get('TO', $id) eq '*') {
			if ($Notice->Get('FROM', $id) ne $curUser) {
				my $subj = $Notice->Get('SUBJECT', $id);
				push @$pLog, "通知「$subj」は全体通知なので削除できませんでした。";
			}
			else {
				my $subj = $Notice->Get('SUBJECT', $id);
				$Notice->Delete($id);
				push @$pLog, "全体通知「$subj」を削除しました。";
			}
		}
		else {
			my $subj = $Notice->Get('SUBJECT', $id);
			$Notice->RemoveToUser($id, $curUser);
			push @$pLog, "通知「$subj」を削除しました。";
		}
	}
	$Notice->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	操作ログ削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionLogRemove
{
	my ($Sys, $Form, $Logger, $pLog) = @_;
	my ($Notice, @noticeSet, $curUser, $id);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	$Logger->Clear();
	push @$pLog, '操作ログを削除しました。';
	
	return 0;
}


sub CheckVersionUpdate
{
	my ($Sys) = @_;
	
	my $nr = $Sys->Get('ADMIN')->{'UPDATE_NOTICE'};
	
	if ( $nr->Get('Update') eq 1) {
		my $newver = $nr->Get('Ver');
		my $date = $nr->Get('Date');
		my $url = $nr->Get('URL');
		
		# ユーザ通知 準備
		require './module/notice.pl';
		my $Notice = NOTICE->new;
		$Notice->Load($Sys);
		my $nid = 'verupnotif';
		my $limit = 0;
		
		# 通知内容
		my $note = $nr->Get('Detail');
		$note =~ s/\r\n/<br>/g;
		my $subject = "ex0ch New Version $newver is Released.";
		my $content = "<!-- \*Ver=$newver\* --> $note<br><br>GitHub:<a href=\"$url\" target=\"_blank\">$newver</a>";

		# 既に通知があった場合、通知を行わない
		my @noticeSet;
		$Notice->GetKeySet('ALL', '', \@noticeSet);
		@noticeSet = sort @noticeSet;
		@noticeSet = reverse @noticeSet;
		foreach my $noticeKey(@noticeSet){
			return 0 if ($Notice->Get('FROM', $noticeKey) eq '0000000000'&& $Notice->Get('SUBJECT', $noticeKey) eq $subject);
		}
		
		# 通知者 ex0ch管理システム
		my $from = '0000000000';
		
		# 通知先 管理者権限を持つユーザ
		require './module/security.pl';
		my $User = USER_INFO->new;
		$User->Load($Sys);
		my @toSet = ();
		$User->GetKeySet('SYSAD', 1, \@toSet);
		my $users = join(',', @toSet, 'nouser');
		
		# 通知を追加
		if ($Notice->Get('TEXT', $nid, '') =~ /\*Ver=(.+?)\*/ && $1 eq $newver) {
			$Notice->{'TO'}->{$nid}			= $users;
			$Notice->{'TEXT'}->{$nid}		= $content;
			$Notice->{'DATE'}->{$nid}		= $date;
		}
		else {
			#$Notice->Add($users, $from, $subject, $content, $limit);
			$Notice->{'TO'}->{$nid}			= $users;
			$Notice->{'FROM'}->{$nid}		= $from;
			$Notice->{'SUBJECT'}->{$nid}	= $subject;
			$Notice->{'TEXT'}->{$nid}		= $content;
			$Notice->{'DATE'}->{$nid}		= $date;
			$Notice->{'LIMIT'}->{$nid}		= $limit;
			$Notice->Save($Sys);
		}
	}
	
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
