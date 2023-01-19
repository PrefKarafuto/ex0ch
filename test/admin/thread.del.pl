#============================================================================================================
#
#	スレッド管理 - 削除レス モジュール
#	thread.del.pl
#	---------------------------------------------------------------------------
#	2004.08.02 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
binmode(STDOUT,":utf8");
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
	my ($subMode, $BASE, $BBS, $DAT, $Page);
	
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
		my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/del_' . $Sys->Get('KEY') . '.cgi';
		$DAT->Load($Sys, $datPath, 1);
	}
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys, $Form->Get('TARGET_BBS'));
	
	if ($subMode eq 'LIST') {														# レス一覧画面
		PrintResList($Page, $Sys, $Form, $DAT);
	}
	elsif ($subMode eq 'COMPLETE') {												# 完了画面
		PrintComplete($Page, $Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 失敗画面
		PrintError($Page, $Sys, $Form, $this->{'LOG'});
	}
	
	# 掲示板・スレッド情報を設定
	$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	$Page->HTMLInput('hidden', 'TARGET_THREAD', $Form->Get('TARGET_THREAD'));
	
	$BASE->Print($Sys->Get('_TITLE') . ' - ' . $BBS->Get('NAME', $Form->Get('TARGET_BBS'))
					. ' - 削除レス', 3);
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
	my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/del_' . $Sys->Get('KEY') . '.cgi';
	$DAT->Load($Sys, $datPath, 1);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 9999;
	
	if ($subMode eq 'DELETE') {													# レス完全削除
		$err = FunctionResDelete($Sys, $Form, $DAT, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"DELETE_RES($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"DELETE_RES($subMode)", 'COMPLETE');
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
	
	$Base->SetMenu('削除レス一覧', "'thread.del','DISP','LIST'");
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
#------------------------------------------------------------------------------------------------------------
sub PrintResList
{
	my ($Page, $Sys, $Form, $Dat) = @_;
	my (@elem, $resNum, $dispNum, $dispSt, $dispEd, $common, $i);
	my ($pRes, $isAbone, $isEdit, $format);
	
	$Sys->Set('_TITLE', 'Delete Res List');
	
	# 表示書式の設定
	$format = $Form->Get('DISP_FORMAT_DEL') eq '' ? '-10' : $Form->Get('DISP_FORMAT_DEL');
	($dispSt, $dispEd) = AnalyzeFormat($format, $Dat);
	
	$common = "DoSubmit('thread.del','DISP','LIST');";
	
	$Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2 align=right>表\示書式：<input type=text name=DISP_FORMAT_DEL");
	$Page->Print(" value=\"$format\"><input type=button value=\"　表\示　\" onclick=\"$common\">");
	$Page->Print("</td></tr>\n<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30\">　</th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:300\">Deleted Contents</td></tr>\n");
	
	# 権限取得
	$isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
	
	# レス一覧を出力
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$pRes	= $Dat->Get($i);
		@elem	= split(/<>/, $$pRes);
		
		# 自分が削除したものだけを表示(Administratorは全て表示)
		if ($elem[1] eq $Form->Get('UserName') || $Sys->Get('ADMIN')->{'USER'} eq '0000000001') {
			$Page->Print("<tr><td class=\"Response\" valign=top>");
			
			# レス削除権による表示抑制
			if ($isAbone) {
				$Page->Print("<input type=checkbox name=DEL_RESS value=$i></td>");
			}
			else {
				$Page->Print("</td>");
			}
			$common = ($elem[3] ? '【あぼーん】' : '【透明あぼーん】');
			$Page->Print("<td class=\"Response\"><dt>$common<br>" . ($elem[2] + 1));
			$Page->Print("：<font color=forestgreen><b>$elem[4]</b></font>[$elem[5]]");
			$Page->Print("：$elem[6]</dt><dd>$elem[7]<br><br></dd></td></tr>\n");
		}
	}
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# システム権限有無による表示抑制
	if ($isAbone) {
		$common = "onclick=\"DoSubmit('thread.del','FUNC'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table></dl><br>");
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
	@resSet = $Form->GetAtArray('DEL_RESS');
	
	# 権限取得
	$isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
	
	$Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td>以下の削除レスを完全に削除します。</td></tr>\n");
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
		$common .= ($mode ? 'ABONE' : 'DELETE') . "')\"";
		$Page->Print("<tr><td align=left>");
		$Page->Print("<input type=button value=\"　実行　\" $common> ");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table></dl><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	完了画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintComplete
{
	my ($Page, $Sys, $Form, $pLog) = @_;
	my ($text);
	
	$Sys->Set('_TITLE', 'Process Complete');
	
	$Page->Print("<center><table border=0 cellspacing=0 width=100%>");
	$Page->Print("<tr><td><b>レス設定を正常に完了しました。</b><br><br>");
	$Page->Print("<small>処理ログ<hr><blockquote>");
	
	# ログの表示
	foreach $text (@$pLog) {
		$Page->Print("$text<br>\n");
	}
	
	$Page->Print("</blockquote><hr></small></td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	エラーの表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintError
{
	my ($Page, $Sys, $Form, $pLog) = @_;
	my ($ecode);
	
	$Sys->Set('_TITLE', 'Process Error');
	
	# エラーコードの抽出
	$ecode = pop @$pLog;
	
	$Page->Print("<center><table border=0 cellspacing=0 width=100%>");
	$Page->Print("<tr><td><br><font color=red><b>");
	$Page->Print("ERROR:$ecode<hr><blockquote>\n");
	
	if ($ecode == 1000) {
		$Page->Print("レス操作を実行する権限がありません。");
	}
	elsif ($ecode == 1001) {
		$Page->Print("入力必須項目が空欄になっています。");
	}
	else {
		$Page->Print("不明なエラー<hr>");
		foreach (@$pLog) {
			$Page->Print("$_<br>");
		}
	}
	
	$Page->Print("</blockquote><hr></b></font>");
	$Page->Print("</td></tr></table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	レス完全削除
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
	my ($Sys, $Form, $Dat, $pLog) = @_;
	my (@resSet, $abone, $path, $delCnt);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID	= $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	
	# 各値を設定
	@resSet	= $Form->GetAtArray('DEL_RESS');
	$path	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/del_' . $Sys->Get('KEY') . '.cgi';
	my @dellist = ();
	
	$Dat->Close();
	$Dat->Load($Sys, $path, 0);
	
	foreach my $num (reverse sort @resSet) {
		push @dellist, (split(/<>/, ${$Dat->Get($num)}, -1))[2];
		$Dat->Delete($num);
	}
	$Dat->Save($Sys);
	
	# ログの設定
	$delCnt = 0;
	$abone	= '';
	push @$pLog, '以下の削除レスを完全に削除しました。';
	foreach (@dellist) {
		if ($delCnt > 5) {
			push @$pLog, $abone;
			$abone = '';
			$delCnt = 0;
		}
		else {
			$abone .= ($_ + 1) . ', ';
			$delCnt++;
		}
	}
	push @$pLog, $abone;
	
	return 0;
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
	if ($max < 1) {
		return (0, 0);
	}
	
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
