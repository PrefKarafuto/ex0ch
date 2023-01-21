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
	require './module/nazguls.pl';
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
	
	if ($subMode eq 'LIST') {														# スレッド一覧画面
		PrintThreadList($Page, $Sys, $Form);
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
	elsif ($subMode eq 'DEATTR') {													# 属性解除確認画面
		PrintThreadAttr($Page, $Sys, $Form, 0);
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
	elsif ($subMode eq 'ATTR') {													# 属性付加
		$err = FunctionThreadAttr($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'DEATTR') {													# 属性解除
		$err = FunctionThreadAttr($Sys, $Form, $this->{'LOG'}, 0);
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
#	@param	$Base	SAURON
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys, $bbs) = @_;
	
	$Base->SetMenu('スレッド一覧', "'bbs.thread','DISP','LIST'");
	
	# スレッドdat落ち権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_THREADPOOL, $bbs)) {
		$Base->SetMenu('一括DAT落ち', "'bbs.thread','DISP','AUTOPOOL'");
	}
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
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base);
	my ($common, $common2, $n, $Threads, $id);
	
	$SYS->Set('_TITLE', 'Thread List');
	
	require './module/baggins.pl';
	require './module/gondor.pl';
	$Threads = BILBO->new;
	
	$Threads->Load($SYS);
	$Threads->GetKeySet('ALL', '', \@threadSet);
	$ThreadNum = $Threads->GetNum();
	$base = $SYS->Get('BBSPATH') . '/' . $SYS->Get('BBS') . '/dat';
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 10);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $ThreadNum ? $ThreadNum : ($dispSt + $dispNum));
	
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
	
	require './module/isildur.pl';
	my $Set = ISILDUR->new;
	$Set->Load($SYS);
	my $resmax = $Set->Get('BBS_RES_MAX') || $SYS->Get('RESMAX');
	
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$n		= $i + 1;
		$id		= $threadSet[$i];
		$subj	= $Threads->Get('SUBJECT', $id);
		$res	= $Threads->Get('RES', $id);
		
		my $permt = ARAGORN::GetPermission("$base/$id.dat");
		my $perms = $SYS->Get('PM-STOP');
		my $isstop = $permt == $perms;
		
		# 表示背景色設定
		#if ($Threads->GetAttr($id, 'stop')) { # use from 0.8.x
		if ($isstop) {								$bgColor = '#ffcfff'; }	# 停止スレッド
		elsif ($res > $resmax) {					$bgColor = '#cfffff'; }	# 最大数スレッド
		elsif (ARAGORN::IsMoved("$base/$id.dat")) {	$bgColor = '#ffffcf'; }	# 移転スレッド
		else {										$bgColor = '#ffffff'; }	# 通常スレッド
		
		$common = "\"javascript:SetOption('TARGET_THREAD','$id');";
		$common .= "DoSubmit('thread.res','DISP','LIST')\"";
		
		$Page->Print("<tr bgcolor=$bgColor>");
		$Page->Print("<td><input type=checkbox name=THREADS value=$id></td>");
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
		my @attrstr = ();
		push @attrstr, '停止' if ($isstop);
		push @attrstr, '浮上' if ($Threads->GetAttr($id, 'float'));
		push @attrstr, '不落' if ($Threads->GetAttr($id, 'nopool'));
		push @attrstr, 'sage進行' if ($Threads->GetAttr($id, 'sagemode'));
		$Page->Print("<td>@attrstr</td></tr>\n");
	}
	$common		= "onclick=\"DoSubmit('bbs.thread','DISP'";
	$common2	= "onclick=\"DoSubmit('bbs.thread','FUNC'";
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");
#	$Page->Print("<input type=button value=\" コピー \" $common2,'COPY')\"> ");
#	$Page->Print("<input type=button value=\"　移動　\" $common2,'MOVE')\"> ");
	$Page->Print("<input type=button value=\"subject更新\" $common2,'UPDATE')\"> ")			if ($isUpdate);
	$Page->Print("<input type=button value=\"subject再作成\" $common2,'UPDATEALL')\"> ")	if ($isUpdate);
	$Page->Print("<input type=button value=\"　停止　\" $common,'STOP')\"> ")				if ($isStop);
	$Page->Print("<input type=button value=\"　再開　\" $common,'RESTART')\"> ")			if ($isStop);
	$Page->Print("<input type=button value=\"DAT落ち\" $common,'POOL')\"> ")				if ($isPool);
	
	if ($isStop) {
		$Page->Print("属性: <select name=ATTR>");
		$Page->Print("<option value=float>浮上");
		$Page->Print("<option value=nopool>不落");
		$Page->Print("<option value=sagemode>sage進行");
		$Page->Print("</select> ");
		$Page->Print("<input type=button value=\"付加\" $common,'ATTR')\"> ");
		$Page->Print("<input type=button value=\"解除\" $common,'DEATTR')\"> ");
	}
	
	$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ")				if ($isDelete);
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'TARGET_THREAD', '');
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
	
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
	$Threads->Load($SYS);
	@threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを$textします。</td></tr>");
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
	my ($Page, $Sys, $Form, $mode) = @_;
	
	$Sys->Set('_TITLE', ($mode ? 'Thread Add Attribute' : 'Thread Remove Attribute'));
	
	my %alist = ('float'=>'浮上', 'nopool'=>'不落', 'sagemode'=>'sage進行');
	my $attr = $Form->Get('ATTR');
	my $name = $attr;
	$name = $alist{$attr} if (defined $alist{$name});
	my $text = "[$name]属性" .($mode?'付加':'解除');
	
	require './module/baggins.pl';
	my $Threads = BILBO->new;
	$Threads->Load($Sys);
	
	my @threadList = $Form->GetAtArray('THREADS');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>以下のスレッドを$textします。</td></tr>");
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
	
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
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
	
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
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
	$Page->Print("<input type=text size=15 name=POOLTITLE value=>にマッチするもの(正規表\現)</td></tr>\n");
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
	require './module/gondor.pl';
	require './module/baggins.pl'; # use from 0.8.x
	
	$Thread		= ARAGORN->new;
	my $Threads	= BILBO->new; # use from 0.8.x
	@threadList	= $Form->GetAtArray('THREADS');
	$base		= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat';
	$Threads->LoadAttr($Sys);
	
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
	
	$Threads->SaveAttr($Sys); # use from 0.8.x
	
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
	require './module/baggins.pl';
	
	my $Threads	= BILBO->new;
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
	require './module/baggins.pl';
	require './module/earendil.pl';
	$Threads = BILBO->new;
	$Pools = FRODO->new;
	
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
		
		EARENDIL::Copy("$path/dat/$id.dat","$path/pool/$id.cgi");
		unlink "$path/dat/$id.dat";
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
	my (@threadList, $Threads, $path, $bbs, $id);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_TREADDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
	$Threads->Load($Sys);
	
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
	$Threads->Save($Sys);
	
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
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
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
	require './module/baggins.pl';
	$Threads = BILBO->new;
	
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
	require './module/gondor.pl';
	require './module/baggins.pl';
	require './module/earendil.pl';
	$Threads = BILBO->new;
	$Pools = FRODO->new;
	
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
			$permt = ARAGORN::GetPermission("$base/dat/$id.dat");
			$perms = $Sys->Get('PM-STOP');
			if (($permt eq $perms) || (ARAGORN::IsMoved("$base/dat/$id.dat"))) {
				$bPool = 1;
			}
		}
		
		# フラグありの状態ならDAT落ちする
		if ($bPool) {
			push @$pLog, 'スレッド「' . $Threads->Get('SUBJECT', $id) . '」をDAT落ち';
			$Pools->Add($id, $Threads->Get('SUBJECT', $id), $Threads->Get('RES', $id));
			$Threads->Delete($id);
			
			EARENDIL::Copy("$base/dat/$id.dat", "$base/pool/$id.cgi");
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
