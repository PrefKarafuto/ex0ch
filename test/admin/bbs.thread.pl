#============================================================================================================
#
#	掲示板管理 - スレッド モジュール
#	bbs.thread.pl
#	---------------------------------------------------------------------------
#	2004.02.07 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use HTML::Entities;
no warnings 'once';

# 共通スレッド属性情報
my %threadAttr = (
	'sagemode'  => { 'name' => 'sage進行', 'type' => 'checkbox' },
	'float'     => { 'name' => '浮上', 'type' => 'checkbox' },
	'pass'      => { 'name' => 'パスワード', 'type' => 'text' },
	'maxres'    => { 'name' => '最大レス数', 'type' => 'number' },
	'slip'      => { 'name' => 'BBS_SLIP', 'type' => 'slip' },
	'noid'      => { 'name' => 'IDなし', 'type' => 'checkbox' },
	'changeid'  => { 'name' => '独自ID', 'type' => 'checkbox' },
	'force774'  => { 'name' => '強制名無し', 'type' => 'checkbox' },
	'change774' => { 'name' => '名無し変更', 'type' => 'text' },
	'live'      => { 'name' => '実況モード', 'type' => 'checkbox' },
	'hidenusi'  => { 'name' => 'スレ主表示なし', 'type' => 'checkbox' },
	'nopool'    => { 'name' => '不落', 'type' => 'checkbox' },
	'ninlv'     => { 'name' => '忍法帖Lv制限', 'type' => 'number' },
	'ban'       => { 'name' => 'アクセス禁止<small>SessionID（:投票数）</small>', 'type' => 'hash' },
	'sub'    	=> { 'name' => '副主', 'type' => 'text' },
);

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
	require './admin/bbs.autodel.pl';
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
	
	if ($subMode eq 'LIST') {														# スレッド一覧画面
		PrintThreadList($Page, $Sys, $Form, $BBS);
	}
	elsif ($subMode eq 'CREATE') {                                          # レス一括削除確認画面
		PrintResCreate($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COPY') {													# スレッドコピー確認画面
		PrintThreadCopy($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'MOVE') {													# スレッド移動確認画面
		PrintThreadCopy($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'STOP') {													# スレッド停止確認画面
		PrintThreadStop($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'RESTART') {													# スレッド停止解除確認画面
		PrintThreadStop($Page, $Sys, $Form, 0);
	}
	elsif ($subMode eq 'ATTR') {													# 属性付加確認画面
		PrintThreadAttr($Page, $Sys, $Form, 1);
	}
	elsif ($subMode eq 'POOL') {													# スレッドDAT落ち確認画面
		PrintThreadPooling($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'DELETE') {													# スレッド削除確認画面
		PrintThreadDelete($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'AUTOPOOL') {												# 一括DAT落ち画面
		PrintThreadAutoPooling($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# 処理完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('スレッド処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 処理失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	elsif ($subMode eq 'AUTORESDEL') {                                             # レス一括削除設定画面
		PrintResAutoDelete($Page, $Sys, $Form, $BBS);
	}
	elsif ($subMode eq 'ABONELUMPRES') {                                        # レス一括あぼーん確認画面
		PrintResLumpDelete($Page, $Sys, $Form, $BBS, 1);
	}
	elsif ($subMode eq 'DELLUMPRES') {                                          # レス一括削除確認画面
		PrintResLumpDelete($Page, $Sys, $Form, $BBS, 0);
	}
	
	# 掲示板情報を設定
	if($subMode eq 'ABONELUMPRES'||'DELLUMPRES' && !$Form->Get('TARGET_BBS')){	# システム画面から来た場合
		$BASE->Print($Sys->Get('_TITLE'), 1);
	}else{																		# 掲示板画面から来た場合
		$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
		$BASE->Print($Sys->Get('_TITLE') . ' - ' . $BBS->Get('NAME', $Form->Get('TARGET_BBS')), 2);
	}
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
	require './admin/bbs.autodel.pl';
	$BBS = BBS_INFO->new;
	
	# 管理情報を登録
	$BBS->Load($Sys);
	$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	$Sys->Set('ADMIN', $pSys);
	$pSys->{'SECINFO'}->SetGroupInfo($Sys->Get('BBS'));
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'STOP') {														# 停止
		$err = FunctionThreadStop($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'RESTART') {													# 再開
		$err = FunctionThreadStop($Sys, $Form, $this->{'LOG'}, 0);
	}
	elsif ($subMode eq 'CREATE') {													# コピー
		$err = FunctionThreadCreate($Sys, $Form ,$this->{'LOG'});
	}
	elsif ($subMode eq 'COPY') {													# コピー
		$err = FunctionThreadCopy($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'MOVE') {													# 移動
		$err = FunctionThreadCopy($Sys, $Form, $this->{'LOG'}, 0);
	}
	elsif ($subMode eq 'ATTR') {													# 属性付加
		$err = FunctionThreadAttr($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'DEATTR') {													# 属性解除
		$err = FunctionThreadAttr($Sys, $Form, $this->{'LOG'}, 0);
	}
	elsif ($subMode eq 'DETAILATTR') {													# 属性解除
		$err = FunctionThreadDetailAttr($Sys, $Form, $this->{'LOG'},0);
	}
	elsif ($subMode eq 'POOL') {													# DAT落ち
		$err = FunctionThreadPooling($Sys, $Form, $this->{'LOG'});
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
	elsif ($subMode eq 'AUTOPOOL') {												# 一括dat落ち
		$err = FunctionThreadAutoPooling($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'ABONELUMPRES') {                                           # レス一括あぼ～ん
		$err = FunctionResLumpDelete($Sys, $Form, $this->{'LOG'}, $BBS, 1);
	}
	elsif ($subMode eq 'DELLUMPRES') {                                          # レス一括削除
		$err = FunctionResLumpDelete($Sys, $Form, $this->{'LOG'}, $BBS, 0);
	}
	elsif ($subMode eq 'CLEAR') {                                          # TLクリア
		$err = FunctionClearTimeline($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'PINNED') {                                          # ピン留め
		$err = FunctionThreadPinned($Sys, $Form, $this->{'LOG'}, $BBS);
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
	if($bbs){
		$Base->SetMenu('スレッド一覧', "'bbs.thread','DISP','LIST'");
		# スレッド編集権限のみ
		if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_RESEDIT, $bbs)) {
			$Base->SetMenu('スレッド新規作成', "'bbs.thread','DISP','CREATE'");
		}
		$Base->SetMenu('レス全体検索・削除', "'bbs.thread','DISP','AUTORESDEL'");
		# スレッドdat落ち権限のみ
		if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_THREADPOOL, $bbs)) {
			$Base->SetMenu('一括DAT落ち', "'bbs.thread','DISP','AUTOPOOL'");
		}
		$Base->SetMenu('<hr>', '');
	}
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
	my ($Page, $SYS, $Form, $BBS) = @_;
	my (@threadSet, $ThreadNum, $key, $res, $subj, $i);
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base, $pinnedThread);
	my ($common, $common2, $common3, $n, $Threads, $id, $is_checked);
	
	$SYS->Set('_TITLE', 'Thread List');
	
	require './module/thread.pl';
	require './module/dat.pl';
	require './module/setting.pl';
	my $Set = SETTING->new;
	$Set->Load($SYS);
	my $resmax = $Set->Get('BBS_RES_MAX') || $SYS->Get('RESMAX');
	$Threads = THREAD->new;
	
	$Threads->Load($SYS);
	$Threads->LoadAttrAll($SYS);
	$Threads->GetKeySet('ALL', '', \@threadSet);
	$ThreadNum = $Threads->GetNum();
	$base = $SYS->Get('BBSPATH') . '/' . $SYS->Get('BBS') . '/dat';

	$pinnedThread = $BBS->Get('PINNED',$Form->Get('TARGET_BBS')) // '';
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 15);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $ThreadNum ? $ThreadNum : ($dispSt + $dispNum));

	# スレッド上げ下げ
	my @threadList = $Form->GetAtArray('THREADS');
	require './module/data_utils.pl';
	# UP/DOWN/TOP/BOTTOM を move_threads に渡すオフセットへマッピング
	my %offset_map = (
		UP     => -1,
		DOWN   =>  1,
		TOP    => 'top',
		BOTTOM => 'bottom',
	);

	# フォームからの指示を取得
	my $cmd = $Form->Get('UPDOWN');
	my $cmd2 = $Form->Get('UPDATE');
	my $cmd3 = $Form->Get('PINNED');

	# 有効なコマンドなら実行
	# スレッド順変更
	if ( exists $offset_map{$cmd} ) {
		my $offset = $offset_map{$cmd};
		DATA_UTILS::move_threads($offset, \@threadSet, \@threadList);
		$Threads->Set(undef, 'SORT', \@threadSet);
		$Threads->Save($SYS);
	}
	# index更新
	if ($cmd2) {
		require './module/bbs_service.pl';
		require './module/banner.pl';
		my $BBSAid = BBS_SERVICE->new;
		$SYS->Set('MODE', 'CREATE');
		$BBSAid->{'SYS'} = $SYS;
		$BBSAid->{'SET'} = $Set;
		$BBSAid->{'THREADS'} = $Threads;
		$BBSAid->{'CONV'} = DATA_UTILS->new;
		$BBSAid->{'BANNER'} = BANNER->new;
		$BBSAid->CreateIndex();
		$BBSAid->CreateSubback();
	}
	# スレッドピン留め
	my $num = @threadList;
	if ($cmd3 && $num ==1){
		if($pinnedThread eq $threadList[0]){
			$BBS->Set($Form->Get('TARGET_BBS'),'PINNED','');
			$pinnedThread = '';
		}else{
			$BBS->Set($Form->Get('TARGET_BBS'),'PINNED',$threadList[0]);
			$pinnedThread = $threadList[0];
		}
		@threadList = ();	# 選択解除
		$BBS->Save($SYS);
	}
	
	# 権限取得
	my ($isStop, $isPool, $isDelete, $isUpdate, $isResEdit, $isResAbone);
	$isStop		= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADSTOP, $SYS->Get('BBS'));
	$isPool		= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADPOOL, $SYS->Get('BBS'));
	$isDelete	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_TREADDELETE, $SYS->Get('BBS'));
	$isUpdate	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADINFO, $SYS->Get('BBS'));
	$isResEdit	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESEDIT, $SYS->Get('BBS'));
	$isResAbone	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $SYS->Get('BBS'));
	
	# ヘッダ部分の表示
	$common = "DoSubmit('bbs.thread','DISP','LIST');";
	
	# ページャーの出力開始
	$Page->Print("<center><table border=0 cellspacing=2 width=100%><tr><td colspan=3 style=\"font-size:1.2em\">");
	PrintPagenation($Page, $ThreadNum, $dispNum ,$dispSt, $common);
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"><a href=\"javascript:toggleAll('THREADS')\">全</a></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250px\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30px\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:20px\">Res</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">Attribute</td></tr>\n");

	my @slice = @threadSet[ $dispSt .. $dispEd - 1 ];
	unshift @slice, $pinnedThread if $pinnedThread;
	my $flag = 0;
	my %in_List = map { $_ => 1 } @threadList;
	for my $offset (0 .. $#slice) {
		$n  = $dispSt + $offset + 1;
		$id = $slice[$offset];
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		my $permt = DAT::GetPermission("$base/$id.dat");
		my $perms = $SYS->Get('PM-STOP');
		my $isstop = $permt == $perms;
		
		# 表示背景色設定
		#if ($Threads->GetAttr($id, 'stop')) { # use from 0.8.x
		if ($id == $pinnedThread) {				$bgColor = '#eeeeee'; }	# ピン留めスレッド
		elsif ($isstop) {				$bgColor = '#ffcfff'; }	# 停止スレッド
		elsif ($res > $resmax) {		$bgColor = '#cfffff'; }	# 最大数スレッド
		elsif ($Threads->GetAttr($id, 'pass')) {$bgColor = '#cfcfff'; }	# パス設定スレッド
		elsif (DAT::IsMoved("$base/$id.dat")) {	$bgColor = '#ffffcf'; }	# 移転スレッド
		else {					$bgColor = '#ffffff'; }	# 通常スレッド
		
		$common = "\"javascript:SetOption('TARGET_THREAD','$id');";
		$common .= "DoSubmit('thread.res','DISP','LIST')\"";
		
		$Page->Print("<tr bgcolor=$bgColor>");
		if($id eq $pinnedThread && !$flag){
			$Page->Print("<td>　&#x1f4cc;</td>");
			$flag = 1;
			$n = '0';
		}else{
			$is_checked = $in_List{$id} ? 'checked' : '';
			$Page->Print("<td><input type=checkbox name=THREADS value=$id $is_checked></td>");
			$n-- if $pinnedThread && $flag;
		}
		if ($isResEdit || $isResAbone) {
			if (! ($subj =~ /[^\s　]/) || $subj eq '') {
				$subj = '(空欄もしくは空白のみ)';
			}
			$Page->Print("<td>$n: <a href=$common>$subj</a></td>");
		}
		else {
			$Page->Print("<td>$n: $subj</td>");
		}
		$Page->Print("<td align=center>$id</td><td align=center>$res</td>");
		
		my $isSLIP = $Threads->GetAttr($id, 'slip');
		my $is774 = $Threads->GetAttr($id, 'change774');
		$is774 = HTML::Entities::decode($is774);
		my $maxres = $Threads->GetAttr($id, 'maxres');
		my $ninLv = $Threads->GetAttr($id, 'ninLv');
		my @attrstr = ();
		push @attrstr, '停止' if ($isstop);
		push @attrstr, '浮上' if ($Threads->GetAttr($id, 'float'));
		push @attrstr, '不落' if ($Threads->GetAttr($id, 'nopool'));
		push @attrstr, 'sage進行' if ($Threads->GetAttr($id, 'sagemode'));
		push @attrstr, "SLIP:$isSLIP" if ($isSLIP);
		push @attrstr, "最大レス数:$maxres" if ($maxres);
		push @attrstr, 'ID無し' if ($Threads->GetAttr($id, 'noid'));
		push @attrstr, '実況モード' if ($Threads->GetAttr($id, 'live'));
		push @attrstr, 'ID変更' if ($Threads->GetAttr($id, 'changeid'));
		push @attrstr, '過去ログ送り' if ($Threads->GetAttr($id, 'pool'));
		push @attrstr, '強制名無し' if ($Threads->GetAttr($id, 'force774'));
		push @attrstr, 'スレ主表示なし' if ($Threads->GetAttr($id, 'hidenusi'));
		push @attrstr, "レベル制限:$ninLv" if ($ninLv && $Set->Get('BBS_NINJA'));
		push @attrstr, "名無し->$is774" if ($is774);

		$common = "\"javascript:SetOption('TARGET_THREAD','$id');";
		$common .= "DoSubmit('bbs.thread','DISP','ATTR')\"";
		if(@attrstr){
			$Page->Print("<td><a href=$common>@attrstr</td></tr>\n");
		}else{
			$Page->Print("<td><a href=$common>属性追加</a></td></tr>\n");
		}
		
	}
	$common		= "onclick=\"DoSubmit('bbs.thread','DISP'";
	$common2	= "onclick=\"DoSubmit('bbs.thread','FUNC'";
	$common3	= "SetOption('DISPST','$dispSt');DoSubmit('bbs.thread','DISP','LIST');";

	my $tl_max = $Set->Get('BBS_TL_MAX');
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");

	# スレッド表示順変更ボタン
	$Page->Print("<input type=button value=\"&#x1F504;\" onclick=\"SetOption('UPDATE','1');$common3\"> ");	
	$Page->Print("<input type=button value=\"&#x23eb;\" onclick=\"SetOption('UPDOWN','TOP');$common3\"> ");		# 最上部
	$Page->Print("<input type=button value=\"&#x1f53c;\" onclick=\"SetOption('UPDOWN','UP');$common3\"> ");		# 1上げ
	$Page->Print("<input type=button value=\"&#x1f53d;\" onclick=\"SetOption('UPDOWN','DOWN');$common3\"> ");	# 1下げ
	$Page->Print("<input type=button value=\"&#x23ec;\" onclick=\"SetOption('UPDOWN','BOTTOM');$common3\"> ");	# 最下部
	$Page->Print("<input type=button value=\"&#x1f4cc;\" onclick=\"SetOption('PINNED','1');$common3\">  ")	if ($isResAbone);
	$Page->Print("<span style=\"float:right\">");
	$Page->Print("<input type=button value=\"subject更新\" $common2,'UPDATE')\"> ")			if ($isUpdate);
	$Page->Print("<input type=button value=\"subject再作成\" $common2,'UPDATEALL')\"> ")	if ($isUpdate);
	$Page->Print("<input type=button value=\"タイムラインのクリア\" $common2,'CLEAR')\"> ")		if ($isResAbone && $tl_max);
	$Page->Print("</span><hr>");
	$Page->Print("<input type=button value=\" コピー \" $common,'COPY')\"> ")				if ($isDelete);
	$Page->Print("<input type=button value=\"　移動　\" $common,'MOVE')\"> ")				if ($isDelete);
	$Page->Print("<input type=button value=\"　停止　\" $common,'STOP')\"> ")				if ($isStop);
	$Page->Print("<input type=button value=\"　再開　\" $common,'RESTART')\"> ")			if ($isStop);
	$Page->Print("<input type=button value=\"DAT落ち\" $common,'POOL')\"> ")				if ($isPool);
	
	$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ")if ($isDelete);
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	
	# ボタン制御用
	$Page->HTMLInput('hidden', 'UPDOWN', '');
	$Page->HTMLInput('hidden', 'UPDATE', '');
	$Page->HTMLInput('hidden', 'PINNED', '');
	
	# 表示指定用
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'TARGET_THREAD', '');
}

#------------------------------------------------------------------------------------------------------------
#
#	レス投稿画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	dat変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResCreate
{
	my ($Page, $Sys, $Form) = @_;
	my ($thread_id, $pRes, $isEdit, $common);
	
	$Sys->Set('_TITLE', 'Thread Create');
	$thread_id = $Form->Get('TARGET_THREAD');
	
	$isEdit = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESEDIT, $Sys->Get('BBS'));
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">スレッドタイトル</td><td>");
	$Page->Print("<input type=text size=50 name=subject></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名前</td><td>");
	$Page->Print("<input type=text size=50 name=FROM></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">メール（コマンド）</td><td>");
	$Page->Print("<input type=text size=50 name=mail></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">本文</td><td>");
	$Page->Print("<textarea name=MESSAGE cols=70 rows=10></textarea></td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	
	$Page->HTMLInput('hidden', 'TARGET_THREAD', $thread_id);
	
	# システム権限有無による表示抑制
	if ($isEdit) {
		$common = "onclick=\"DoSubmit('bbs.thread','FUNC'";
		$Page->Print("<tr><td colspan=2>");
		$Page->Print("<input type=button value=\"　投稿　\" $common,'CREATE')\"> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}
#------------------------------------------------------------------------------------------------------------
#
#	スレッドコピー
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadCopy
{
	my ($Page, $SYS, $Form, $mode) = @_;
	my (@threadList, $Threads, $id, $subj, $res);
	my ($common, $text);
	my ($BBS, $Category, @bbsSet, @catSet, $name, $category, $subject, $status);
	my ($sCat, @belongBBS, $belongID);
	
	$SYS->Set('_TITLE', ($mode ? 'Thread Copy' : 'Thread Move'));
	$text = ($mode ? 'コピー' : '移動');
	
	require './module/thread.pl';
	$Threads = THREAD->new;

	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	$Category = CATEGORY_INFO->new;
	$BBS->Load($SYS);
	$Category->Load($SYS);
	
	$sCat = $Form->Get('BBS_CATEGORY', '');
	
	# ユーザ所属のBBS一覧を取得
	$SYS->Get('ADMIN')->{'SECINFO'}->GetBelongBBSList($SYS->Get('ADMIN')->{'USER'}, $BBS, \@belongBBS);
	
	# 掲示板情報を取得
	if ($sCat eq '' || $sCat eq 'ALL') {
		$BBS->GetKeySet('ALL', '', \@bbsSet);
	}
	else {
		$BBS->GetKeySet('CATEGORY', $sCat, \@bbsSet);
	}
	$Category->GetKeySet(\@catSet);
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	$status = @threadList ? "" : "disabled";

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを$text\します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></td>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.thread','FUNC','" . ($mode ? 'COPY' : 'MOVE') . "')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：スレッドの属性は$text\されません</b><br>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");

	$Page->Print("<tr><td colspan=3 align=left>");

	$Page->Print("$text\先: <select name=TOBBS required $status>");
	if(@bbsSet <= 1){
		$Page->Print("<option value=\"\" selected disabled>選択可能な掲示板がありません</option>");
		$Page->Print("</select> ");
	}else{
		$Page->Print("<option value=\"\" disabled>選択してください</option>");
		foreach my $listid (@bbsSet) {
			next if ($BBS->Get('DIR', $listid) eq $SYS->Get('BBS'));
			$category	= $Category->Get('NAME', $BBS->Get('CATEGORY', $listid));
			$Page->Print("<optgroup label=\"$category\">");
			foreach $belongID (@belongBBS) {
				if ($listid eq $belongID) {
					$name		= $BBS->Get('NAME', $listid);
					$Page->Print("<option value=$listid>$name</option>");
				}
			}
		}
		$Page->Print("</select> ");
		$Page->Print("<input type=checkbox value=on name=RENAME $status>同名のファイルがあればリネーム");
		$Page->Print('<input type=button value="　' . $text . "　\" onclick=\"$common;\" $status> ");
	}
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}
#------------------------------------------------------------------------------------------------------------
#
#	スレッド停止確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadStop
{
	my ($Page, $SYS, $Form, $mode) = @_;
	my (@threadList, $Threads, $id, $subj, $res);
	my ($common, $text);
	
	$SYS->Set('_TITLE', ($mode ? 'Thread Stop' : 'Thread Restart'));
	$text = ($mode ? '停止' : '再開');
	
	require './module/thread.pl';
	$Threads = THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを$text\します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></td>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.thread','FUNC','" . ($mode ? 'STOP' : 'RESTART') . "')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
	if ($mode) {
		$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
		$Page->Print("※注：停止したスレッドは[再開]で停止状態を解除できます。</b><br>");
		$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	}
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print('<input type=button value="　' . $text . "　\" onclick=\"$common;\"> ");
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド浮上確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadAttr
{
	my ($Page, $Sys, $Form) = @_;
	
	$Sys->Set('_TITLE', 'Thread Add Attribute');
	my $isStop = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_THREADSTOP, $Sys->Get('BBS'));
	my $disabled = $isStop ? '' : 'disabled';
	my $target_thread = $Form->Get('TARGET_THREAD');

	require './module/thread.pl';
	my $Threads = THREAD->new;
	$Threads->LoadAttr($Sys,$target_thread);

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>スレッドに属性を付加します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Attribute Name</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Key</td>\n");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Value</td>");
	
	foreach my $attrkey (sort keys %threadAttr) {
		my $attr = $Threads->GetAttr($target_thread, $attrkey);
		my $name = $threadAttr{$attrkey}->{'name'};
		my $type = $threadAttr{$attrkey}->{'type'};
		my $checked = $type eq 'checkbox' && $attr ? 'checked' : '';
		
		my $min = $type eq 'number' ? 'min=0' : '';
		my $size = $type eq 'text' ? 'size=60' : '';

		$Page->Print("<tr><td>$name</td><td>$attrkey</td>");
		if($type eq 'checkbox'){
			$Page->Print("<td><input name=\"$attrkey\" type=checkbox value=1 $checked $disabled></td></tr>\n");
		}
		elsif($type eq 'slip'){
			my $none = $attr eq '' ? 'selected' : '';
			my $vvv = $attr eq 'vvv' ? 'selected' : '';
			my $vvvv = $attr eq 'vvvv' ? 'selected' : '';
			my $vvvvv = $attr eq 'vvvvv' ? 'selected' : '';
			my $vvvvvv = $attr eq 'vvvvvv' ? 'selected' : '';
			$Page->Print("<td><select name=\"slip\" $disabled>\n");
			$Page->Print("<option value=\"\" $none></option>\n");
			$Page->Print("<option value=\"vvv\" $vvv>vvv</option>\n");
			$Page->Print("<option value=\"vvvv\" $vvvv>vvvv</option>\n");
			$Page->Print("<option value=\"vvvvv\" $vvvvv>vvvvv</option>\n");
			$Page->Print("<option value=\"vvvvvv\" $vvvvvv>vvvvvv</option>\n");
			$Page->Print("</select></td></tr>\n");
		}
		elsif($type eq 'hash'){
			my $viewStr = '';
			# $attr がハッシュリファレンスか確認
			if (ref($attr) eq 'HASH') {
				foreach my $userID (sort keys %{$attr}){    
					if(defined $userID && $attr->{$userID} == 0){
						$viewStr .= $userID."\n";
					} elsif(defined $userID && exists $attr->{$userID}){
						my $count = scalar keys %{$attr->{$userID}};
						$viewStr .= $userID .':'.$count."\n";
					}
				}
			}
			$Page->Print("<td><textarea name=\"$attrkey\" cols=\"60\" rows=\"5\" $disabled>$viewStr</textarea></td></tr>\n");
		}
		else{
			$Page->Print("<td><input name=\"$attrkey\" type=\"$type\" value=\"$attr\" $min $size $disabled></td></tr>\n");
		}
	}

	my $common = "DoSubmit('bbs.thread','FUNC'";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->HTMLInput('hidden', 'TARGET_THREAD', $target_thread);
	if($isStop){
		$Page->Print("<input type=button value=\"　保存　\" onclick=\"$common,'DETAILATTR');\"> ");
	}
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}
sub PrintThreadAttrOld
{
	my ($Page, $Sys, $Form, $mode) = @_;
	
	$Sys->Set('_TITLE', ($mode ? 'Thread Add Attribute' : 'Thread Remove Attribute'));
	
	my %alist = (
	'float'=>'浮上',
	'nopool'=>'不落',
	'sagemode'=>'sage進行',
	'noid'=>'IDなし',
	'changeid'=>'独自ID',
	'force774'=>'強制名無し',
	'live'=>'実況モード',
	'hidenusi'=>'スレ主表示なし',
	);
	my %blist = (
		'pass'=>'パスワード',
		'slip'=>'最大レス数',
		'change774'=>'名無し変更',
		'ban'=>'アクセス禁止',
		'ninLv'=>'忍法帖Lv制限',
	);
	my $attr = $Form->Get('ATTR');
	my $name = $attr;
	$name = $alist{$attr} if (defined $alist{$name});
	my $text = "[$name]属性" .($mode?'付加':'解除');
	
	require './module/thread.pl';
	my $Threads = THREAD->new;
	$Threads->Load($Sys);
	
	my @threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを$text\します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></td>\n");
	
	foreach my $id (@threadList) {
		my $subj = $Threads->Get('SUBJECT', $id);
		my $res = $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	my $common = "DoSubmit('bbs.thread','FUNC','" . ($mode ? 'ATTR' : 'DEATTR') . "')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->HTMLInput('hidden', 'ATTR', $attr);
	$Page->Print("<input type=button value=\" $text \" onclick=\"$common;\"> ");
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドDAT落ち確認表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadPooling
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Threads, $id, $subj, $res, $common);
	
	$SYS->Set('_TITLE', 'Thread Pooling');
	
	require './module/thread.pl';
	$Threads = THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドをDAT落ちします。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">Thread Title</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">Thread Key</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">Res</td></td>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.thread','FUNC','POOL')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td bgcolor=yellow colspan=3><b><font color=red>");
	$Page->Print("※注：DAT落ちしたスレッドは[DAT落ちスレッド]画面で復帰できます。</b><br>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print("<input type=button value=\"DAT落ち\" onclick=\"$common\"> ");
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
	
	$SYS->Set('_TITLE', 'Thread Remove');
	
	require './module/thread.pl';
	$Threads = THREAD->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを削除します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250\">スレッド名</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100\">スレッドキー</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:50\">レス数</td></td>\n");
	
	foreach $id (@threadList) {
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		$Page->Print("<tr><td>$subj</a></td>");
		$Page->Print("<td align=center>$id</td><td align=center>$res</td></tr>\n");
		$Page->HTMLInput('hidden', 'THREADS', $id);
	}
	$common = "DoSubmit('bbs.thread','FUNC','DELETE')";
	
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
#	スレッド自動DAT落ち画面表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadAutoPooling
{
	my ($Page, $SYS, $Form) = @_;
	my ($common);
	
	$SYS->Set('_TITLE', 'Thread Auto Pooling');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2>以下の各条件に当てはまるスレッドをdat落ちします。</td></tr>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:150\">条件(OR)</td>");
	$Page->Print("<td class=\"DetailTitle\">条件設定値</td></tr>\n");
	
	$Page->Print("<tr><td><input type=checkbox name=CONDITION_BYDATE value=on>");
	$Page->Print("<b>最終書き込み</b></td><td>最終書き込みが");
	$Page->Print("<input type=text size=4 name=POOLDATE value=30>日以前</td></tr>\n");
	$Page->Print("<tr><td><input type=checkbox name=CONDITION_BYPOS value=on>");
	$Page->Print("<b>スレッド位置</b></td><td>スレッド位置が");
	$Page->Print("<input type=text size=4 name=POOLPOS value=500>以降</td></tr>\n");
	$Page->Print("<tr><td><input type=checkbox name=CONDITION_BYRES value=on>");
	$Page->Print("<b>レス数</b></td><td>レス数が");
	$Page->Print("<input type=text size=4 name=POOLRES value=1000>を超えたもの</td></tr>\n");
	$Page->Print("<tr><td><input type=checkbox name=CONDITION_BYTITLE value=on>");
	$Page->Print("<b>タイトル</b></td><td>タイトルが");
	$Page->Print("<input type=text size=15 name=POOLTITLE value=>にマッチするもの(正規表現)</td></tr>\n");
	$Page->Print("<tr><td><input type=checkbox name=CONDITION_BYSTOP value=on>");
	$Page->Print("<b>停止スレッド</b></td><td>スレッドが停止・または移転されているもの</td></tr>");
	
	$common = "DoSubmit('bbs.thread','FUNC','AUTOPOOL')";
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>");
	$Page->Print("<tr><td colspan=2 align=left>");
	$Page->Print("<input type=button value=\"　実行　\" onclick=\"$common\">");
	$Page->Print("</td></tr></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド停止／解除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadStop
{
	my ($Sys, $Form, $pLog, $mode) = @_;
	my (@threadList, $Thread, $path, $base, $id, $subj);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADSTOP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/dat.pl';
	require './module/thread.pl'; # use from 0.8.x
	
	$Thread		= DAT->new;
	my $Threads	= THREAD->new; # use from 0.8.x
	@threadList	= $Form->GetAtArray('THREADS');
	$base		= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat';
	$Threads->LoadAttrAll($Sys);
	
	# スレッドの停止
	if ($mode) {
		foreach $id (@threadList) {
			$Threads->SetAttr($id, 'stop', 1); # use from 0.8.x
			$path = "$base/$id.dat";
			if ($Thread->Load($Sys, $path, 0)) {
				$subj = $Thread->GetSubject();
				if ($Thread->Stop($Sys)) {
					push @$pLog, "スレッド「$subj」を停止。";
					next;
				}
			}
			$Thread->Save($Sys);
			$Thread->Close();
			push @$pLog, "スレッド「$subj/$id」の停止に失敗しました。";
		}
	}
	# スレッドの再開
	else {
		foreach $id (@threadList) {
			$Threads->SetAttr($id, 'stop', ''); # use from 0.8.x
			$path = "$base/$id.dat";
			if ($Thread->Load($Sys, $path, 0)) {
				$subj = $Thread->GetSubject();
				if ($Thread->Start($Sys)) {
					push @$pLog, "スレッド「$subj」を再開。";
					next;
				}
			}
			$Thread->Save($Sys);
			$Thread->Close();
			push @$pLog, "スレッド「$subj/$id」の再開に失敗しました。";
		}
	}
	
	$Threads->SaveAttrAll($Sys); # use from 0.8.x
	
	return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	スレッドコピー
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadCopy
{
	my ($Sys, $Form, $pLog, $mode) = @_;
	my (@threadList, $Threads, $path, $bbs, $tobbs, $topath, $Info, $id,$rename,$withAttr);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADPOOL, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	require './module/bbs_info.pl';
	require './module/file_utils.pl';
	$Threads = THREAD->new;
	$Info = BBS_INFO->new;
	
	$Threads->Load($Sys);
	$Info->Load($Sys);

	$tobbs 		= $Form->Get('TOBBS');
	$rename		= $Form->Get('RENAME');
	$withAttr	= $Form->Get('ATTR');
	$bbs		= $Sys->Get('BBS');
	$path		= $Sys->Get('BBSPATH') . "/$bbs";
	$topath		= $Sys->Get('BBSPATH') . "/".$Info->Get('DIR',$tobbs);

	@threadList = $Form->GetAtArray('THREADS');
	return 1 if (!@threadList || !$tobbs);

	# IDの重複を除く
	my %seen;
	my @uniq = grep { !$seen{$_}++ } @threadList;

	my $text = $mode ? 'コピー':'移動';
	
	foreach $id (@uniq) {
		next if (! defined $Threads->Get('RES', $id));
		if($withAttr){
			$Threads->LoadAttr($Sys);
		}
		if($rename){
			while(0){
				if(-f "$topath/dat/$id.dat"){$id++;}
				else{last;}
			}
		}
		push @$pLog, 'スレッド「' . $Threads->Get('SUBJECT', $id) 
			. '」を'.$Info->Get('NAME',$tobbs).'に'.$text;
		if($mode){	#Copy
			FILE_UTILS::Copy("$path/dat/$id.dat","$topath/dat/$id.dat");
		}
		else{		#Move
			$Threads->Delete($id);
			FILE_UTILS::Move("$path/dat/$id.dat","$topath/dat/$id.dat");
		}
	}
	$Threads->Save($Sys);
	
	require './module/bbs_service.pl';
	my $BBSAid = BBS_SERVICE -> new;

	#$Sysで指すBBS名を一時変更するため保存
	my $originalBBSname = $Sys->Get('BBS');
	my $originalMODE = $Sys->Get('MODE');
	$Sys->Set('BBS', $Info->Get('DIR',$tobbs));
	$Sys->Set('MODE','CREATE');

	# subject.txt更新
	$Threads->Load($Sys);
	$Threads->UpdateAll($Sys);
	$Threads->Save($Sys);
	# index.html更新
	$BBSAid->Init($Sys,undef);
	$BBSAid->CreateIndex();
	$BBSAid->CreateSubback();

	#$Sysの内容を元に戻す
	$Sys->Set('BBS', $originalBBSname);

	if(!$mode){
		# index.html更新
		$BBSAid->Init($Sys,undef);
		$BBSAid->CreateIndex();
		$BBSAid->CreateSubback();
	}

	$Sys->Set('MODE',$originalMODE);

	return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	スレッド浮上／解除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadAttr
{
	my ($Sys, $Form, $pLog, $mode) = @_;
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADSTOP, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	
	my $Threads	= THREAD->new;
	$Threads->Load($Sys);
	my @threadList = $Form->GetAtArray('THREADS');
	
	my $attr = $Form->Get('ATTR');
	
	foreach my $id (@threadList) {
		$Threads->SetAttr($id, $attr, ($mode?1:''));
		my $subj = $Threads->Get('SUBJECT', $id, '');
		push @$pLog, "スレッド「$subj」の[$attr]属性を".($mode?'付加':'解除').'。';
	}
	
	$Threads->Save($Sys);
	
	return 0;
}

sub FunctionThreadDetailAttr
{
    my ($Sys, $Form, $pLog) = @_;
    
    # 権限チェック
    {
        my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
        my $chkID = $Sys->Get('ADMIN')->{'USER'};
        
        if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADSTOP, $Sys->Get('BBS'))) == 0) {
            return 1000;
        }
    }

    require './module/thread.pl';
    
    my $Threads = THREAD->new;
    $Threads->LoadAttrAll($Sys);
    my $target_thread = $Form->Get('TARGET_THREAD');

    foreach my $attrkey (sort keys %threadAttr) {
        my $defAttr = $Threads->GetAttr($target_thread, $attrkey);
        my $attr = $Form->Get($attrkey);
        my $name = $threadAttr{$attrkey}->{'name'};
        my $type = $threadAttr{$attrkey}->{'type'};

        # 数値型のバリデーション修正
        return 1002 if ($attr && $type eq 'number' && $attr !~ /^\d+$/);

        if ($attrkey eq 'ban' && $attr){
            my @userData = split(/\n/, $attr);
            my %hash = ();

            # $defAttr がハッシュリファレンスか確認
            my %defHash = ();
            if (ref($defAttr) eq 'HASH') {
                %defHash = %{$defAttr};
            }

            foreach my $userID (@userData){
                chomp $userID;
                if($userID =~ /^([0-9a-f]{32})(?::([1-9][0-9]*))?$/){
                    my ($id, $count) = ($1, $2);
                    if(defined $count){
                        # 既存の値をコピー
                        $hash{$id} = $defHash{$id} // {};
                    }else{
                        $hash{$id} = 0;
                    }
                }elsif($userID eq ''){
                    next;
                }else{
                    return 1002;
                }
            }
            $attr = \%hash;  # ハッシュリファレンスを代入
        }
        if($attrkey eq 'pass' && $attr ne $defAttr && $attr){
            require Digest::SHA::PurePerl;
            my $ctx = Digest::SHA::PurePerl->new;
            $ctx->add(':', $Sys->Get('SERVER'));
            $ctx->add(':', $target_thread);
            $ctx->add(':', $attr);
            $attr = $ctx->b64digest;
        }

        $Threads->SetAttr($target_thread, $attrkey, $attr) if ($defAttr || $attr);
        push @$pLog, "[$attrkey]属性を".($attr ? '付加' : '解除');
    }
    $Threads->SaveAttrAll($Sys);
    
    return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドdat落ち
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadPooling
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
		next if (! defined $Threads->Get('RES', $id));
		push @$pLog, 'スレッド「' . $Threads->Get('SUBJECT', $id) . '」をDAT落ち';
		$Pools->Add($id, $Threads->Get('SUBJECT', $id), $Threads->Get('RES', $id));
		$Threads->Delete($id);
		
		FILE_UTILS::Copy("$path/dat/$id.dat","$path/pool/$id.cgi");
		unlink "$path/dat/$id.dat";
	}
	$Threads->Save($Sys);
	$Pools->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド作成
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$Dat	Dat変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadCreate
{
	my ($Sys, $Form, $pLog) = @_;
	my (@elem, $PS, $Conv);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESEDIT, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}

	my $threadKey = time;
	my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $threadKey . '.dat';
	
	# Dat形式に整形
	require './module/post_service.pl';
	$PS = POST_SERVICE->new;
	$threadKey++ while -e $datPath;
	$Sys->Set('KEY',$threadKey);
	$PS->Init($Sys, $Form);
	$PS->ReadyBeforeCheck();
	$PS->NormalizationNameMail();

	if ($Form->Get('subject') eq ''){
		push @$pLog, "スレタイがありません。";
		return 0;
	}
	if ($Form->Get('MESSAGE') eq '' ){
		push @$pLog, "本文がありません。";
		return 0;
	}
	
	# 名前欄設定
	my $from = $Form->Get('FROM', '');
	if (($from eq ''||$PS->{'THREADS'}->GetAttr($threadKey,'force774'))) {
		if($PS->{'THREADS'}->GetAttr($threadKey,'change774')){
			require HTML::Entities;
			$from = HTML::Entities::decode($PS->{'THREADS'}->GetAttr($threadKey,'change774'));
		}
		else{
			$from = $PS->{'SET'}->Get('BBS_NONAME_NAME');
		}
		$Form->Set('FROM', $from);
	}
	
	my $datLine = $PS->MakeDatLine();
	require './module/dat.pl';
	my $err = DAT::DirectAppend($Sys, $datPath, $datLine);
	if ($err){
		push @$pLog, "ファイルを開けません。" if $err == 1;
		push @$pLog, "停止パーミッションです。" if $err == 2;
		return 0;
	}

	chomp($datLine);
	require './module/manager_log.pl';
	my $Log = MANAGER_LOG->new;
	my $host = $ENV{'REMOTE_HOST'};
	my $ip = $ENV{'REMOTE_ADDR'};
	my $ua = $ENV{'HTTP_USER_AGENT'};
	$ENV{'REMOTE_HOST'}	= $Form->Get('UserName');
	$ENV{'REMOTE_ADDR'}	= 'N/A';
	$ENV{'HTTP_USER_AGENT'}	= 'N/A';
	$Log->Load($Sys, 'WRT', $Sys->Get('KEY'));
	$Log->Set(undef, length($Form->Get('MESSAGE')),undef, undef, $datLine);
	$ENV{'REMOTE_HOST'}	= $host;
	$ENV{'REMOTE_ADDR'}	= $ip;
	$ENV{'HTTP_USER_AGENT'}	= $ua;
	$Log->Save($Sys);

	$PS->{'THREADS'}->UpdateAll($Sys);
	$PS->{'THREADS'}->Save($Sys);

	require './module/bbs_service.pl';
	my $BBSAid = BBS_SERVICE->new;
	$Sys->Set('MODE', 'CREATE');
	$BBSAid->Init($Sys, undef);
	$BBSAid->CreateIndex();
	$BBSAid->CreateSubback();
	
	# ログの設定
	push @$pLog, "新規スレッド「".$Form->Get('subject')."」を作成しました。";
	
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
	my (@threadList, $Threads, $path, $bbs, $id,$BBSAid);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_TREADDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	require './module/bbs_service.pl';
	$Threads = THREAD->new;
	$BBSAid = BBS_SERVICE->new;
	
	$Threads->Load($Sys);
	$Threads->LoadAttrAll($Sys);
	
	@threadList = $Form->GetAtArray('THREADS');
	$bbs		= $Sys->Get('BBS');
	$path		= $Sys->Get('BBSPATH') . "/$bbs";
	
	foreach $id (@threadList) {
		next if (! defined $Threads->Get('SUBJECT', $id));
		push @$pLog, 'スレッド「' . $Threads->Get('SUBJECT', $id) . '」を削除';
		$Threads->Delete($id);
		$Threads->DeleteAttr($id);
		unlink "$path/dat/$id.dat";
		unlink "$path/log/$id.cgi";
		unlink "$path/log/del_$id.cgi";
	}
	$Threads->SaveAttrAll($Sys);
	#subject.txt更新
	$Threads->Load($Sys);
	$Threads->UpdateAll($Sys);
	$Threads->Save($Sys);
	
	#index.html&subback.html更新
	$Sys->Set('MODE', 'CREATE');
	$BBSAid->Init($Sys, undef);
	$BBSAid->CreateIndex();
	$BBSAid->CreateSubback();
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	タイムラインのクリア
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionClearTimeline
{
	my ($Sys, $Form, $pLog) = @_;
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}

	my $TLpath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/timeline';
    opendir(my $dh, $TLpath) or die "Can't open $TLpath: $!";

	# ディレクトリ内のファイルを取得して処理
	while (my $file = readdir($dh)) {
		next if ($file =~ m/^\./);  # 「.」や「..」をスキップ
		if ($file =~ /\.cgi$/) {
			my $file_path = $TLpath.'/'.$file;
			if (-f $file_path) {
				unlink($file_path) or warn "Could not unlink $file_path: $!";
			}
		}
	}

	# ディレクトリを閉じる
	closedir($dh);
	
	push @$pLog, 'タイムラインをクリアしました。';
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドピン止め
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadPinned
{
	my ($Sys, $Form, $pLog, $BBS) = @_;
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}

	my @threadList = $Form->GetAtArray('THREADS');
	my $pinnedThread = $threadList[0];
	if( scalar(@threadList) != 1){
		push @$pLog, 'ピン留めできるのは１スレッドのみです。';
		return 0;
	}

	if($BBS->Get('PINNED', $Form->Get('TARGET_BBS')) eq $pinnedThread){
		$BBS->Set($Form->Get('TARGET_BBS'),'PINNED','');
		push @$pLog, 'ピン留め解除しました。';
	}else{
		$BBS->Set($Form->Get('TARGET_BBS'),'PINNED',$pinnedThread);
		push @$pLog, 'スレッドをピン留めしました。';
	}

	$BBS->Save($Sys);
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
	my ($Threads);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADINFO, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	$Threads = THREAD->new;
	
	$Threads->Load($Sys);
	$Threads->Update($Sys);
	$Threads->Save($Sys);
	
	push @$pLog, 'スレッド情報(subject.txt)を更新しました。';
	
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
	my ($Threads);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADINFO, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/thread.pl';
	$Threads = THREAD->new;
	
	$Threads->Load($Sys);
	$Threads->UpdateAll($Sys);
	$Threads->Save($Sys);
	
	push @$pLog, 'スレッド情報(subject.txt)を再作成しました。';
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド一括dat落ち
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionThreadAutoPooling
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Threads, $Pools, @threadList, $base, $id, $bPool);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_THREADPOOL, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/dat.pl';
	require './module/thread.pl';
	require './module/file_utils.pl';
	$Threads = THREAD->new;
	$Pools = POOL_THREAD->new;
	require './module/setting.pl';
	my $Set = SETTING->new;
	$Set->Load($Sys);
	
	$Threads->Load($Sys);
	$Pools->Load($Sys);
	
	$Threads->GetKeySet('ALL', '', \@threadList);
	$base = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	
	foreach $id (@threadList) {
		$bPool = 0;
		# 最終書き込み日による判定
		if ($Form->Equal('CONDITION_BYDATE', 'on') && $bPool == 0) {
			my ($ntime, $dtime, $ltime);
			$ntime = time;
			$dtime = (stat "$base/dat/$id.dat")[9];
			$ltime = $Form->Get('POOLDATE') * 24 * 3600;
			if (($ntime - $dtime) > $ltime) {
				$bPool = 1;
			}
		}
		# スレッド位置による判定
		if ($Form->Equal('CONDITION_BYPOS', 'on') && $bPool == 0) {
			my ($pos) = $Threads->GetPosition($id);
			if (($pos != -1) && ($pos + 1 >= $Form->Get('POOLPOS'))) {
				$bPool = 1;
			}
		}
		# レス数による判定
		if ($Form->Equal('CONDITION_BYRES', 'on') && $bPool == 0) {
			my ($res) = $Threads->Get('RES', $id);
			if ($res > $Form->Get('POOLRES')) {
				$bPool = 1;
			}
		}
		# タイトルによる判定
		if ($Form->Equal('CONDITION_BYTITLE', 'on') && $bPool == 0) {
			my ($subject) = $Threads->Get('SUBJECT', $id);
			my $reg = $Form->Get('POOLTITLE');
			if ($subject =~ /$reg/) {
				$bPool = 1;
			}
		}
		# 停止・移動スレッド
		if ($Form->Equal('CONDITION_BYSTOP', 'on') && $bPool == 0) {
			my ($permt, $perms);
			$permt = DAT::GetPermission("$base/dat/$id.dat");
			$perms = $Sys->Get('PM-STOP');
			if (($permt eq $perms) || (DAT::IsMoved("$base/dat/$id.dat"))) {
				$bPool = 1;
			}
		}
		
		# フラグありの状態ならDAT落ちする
		if ($bPool) {
			push @$pLog, 'スレッド「' . $Threads->Get('SUBJECT', $id) . '」をDAT落ち';
			if(!$Set->Get('BBS_KAKO')){
				$Pools->Add($id, $Threads->Get('SUBJECT', $id), $Threads->Get('RES', $id));
				FILE_UTILS::Copy("$base/dat/$id.dat", "$base/pool/$id.cgi");
			}
			#別の掲示板に移す場合
			else{
				FILE_UTILS::Move("$base/dat/$id.dat", $Set->Get('BBS_KAKO')."/dat/$id.dat");	
				require './module/bbs_service.pl';
				my $BBSAid = BBS_SERVICE -> new;
				#$Sysで指すBBS名を一時変更するため保存
				my $originalBBSname = $Sys->Get('BBS');
				#my $originalMODE = $Sys->Get('MODE');
				$Sys->Set('BBS', $Set->Get('BBS_KAKO'));
				#$Sys->Set('MODE','CREATE');
				# subject.txt更新
				$Threads->Load($Sys);
				$Threads->UpdateAll($Sys);
				$Threads->Save($Sys);
				# index.html更新
				#$BBSAid->Init($Sys,undef);
				#$BBSAid->CreateIndex();
				#$BBSAid->CreateSubback();
				#$Sysの内容を元に戻す
				$Sys->Set('BBS', $originalBBSname);
				#$Sys->Set('MODE',$originalMODE);
			}
			$Threads->Delete($id);
			unlink "$base/dat/$id.dat";
		}
	}
	$Threads->Save($Sys);
	$Pools->Save($Sys);
	
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
