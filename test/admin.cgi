#!/usr/bin/perl
#============================================================================================================
#
#	システム管理CGI
#
#============================================================================================================

use lib './perllib';

use strict;
#use warnings;
no warnings 'once';
##use CGI::Carp qw(fatalsToBrowser warningsToBrowser);


# CGIの実行結果を終了コードとする
exit(AdminCGI());

#------------------------------------------------------------------------------------------------------------
#
#	admin.cgiメイン
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	エラー番号
#
#------------------------------------------------------------------------------------------------------------
sub AdminCGI
{
	require './module/constant.pl';
	
	# システム初期設定
	my $CGI = {};
	SystemSetting($CGI);
	
	# 0chシステム情報を取得
	require "./module/system.pl";
	my $Sys = SYSTEM->new;
	$Sys->Init();
	$Sys->Set('BBS', '');
	$CGI->{'LOGGER'}->Open('.'.$Sys->Get('INFO').'/AdminLog', 100, 2 | 4);
	$CGI->{'SECINFO'}->Init($Sys);
	
	# 夢が広がりんぐ
	$Sys->Set('ADMIN', $CGI);
	$Sys->Set('MainCGI', $CGI);
	
	# フォーム情報を取得
	require "./module/form.pl";
	my $Form = FORM->new(0);
	$Form->DecodeForm(0);
	$Form->Set('FALSE', 0);
	
	# ログインユーザ設定
	my $name = $Form->Get('UserName', '');
	my $pass = $Form->Get('PassWord', '');
	my $sid = $Form->Get('SessionID', '');
	$Form->Set('PassWord', '');
	#$Form->Set('SessionID', '');
	my ($userID, $SID) = $CGI->{'SECINFO'}->IsLogin($name, $pass, $sid);
	$CGI->{'USER'} = $userID;
	$Form->Set('SessionID', $SID);
	
	# バージョンチェック
	my $upcheck = $Sys->Get('UPCHECK', 1) - 0;
	$CGI->{'UPDATE_NOTICE'}->Init($Sys);
	if ($upcheck) {
		$CGI->{'UPDATE_NOTICE'}->Set('Interval', 24*60*60*$upcheck);
		$CGI->{'UPDATE_NOTICE'}->Check;
	}
	
	# 処理モジュールオブジェクトの生成
	my $modName = $Form->Get('MODULE', 'login');
	$modName = 'login' if (!$userID);
	require "./admin/$modName.pl";
	my $oModule = MODULE->new;
	
	# 表示モード
	if ($Form->Get('MODE', '') eq 'DISP') {
		$oModule->DoPrint($Sys, $Form, $CGI);
	}
	# 機能モード
	elsif ($Form->Get('MODE', '') eq 'FUNC') {
		$oModule->DoFunction($Sys, $Form, $CGI);
	}
	# ログイン
	else {
		$CGI->{'SECINFO'}->Logout($SID);
		$oModule->DoPrint($Sys, $Form, $CGI);
	}
	
	$CGI->{'LOGGER'}->Write();
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	管理システム設定
#	-------------------------------------------------------------------------------------
#	@param	$pSYS	システム管理ハッシュの参照
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SystemSetting
{
	my ($CGI) = @_;
	
	%$CGI = (
		'SECINFO'	=> undef,		# セキュリティ情報
		'LOGGER'	=> undef,		# ログオブジェクト
		'AD_BBS'	=> undef,		# BBS情報オブジェクト
		'AD_DAT'	=> undef,		# dat情報オブジェクト
		'USER'		=> undef,		# ログインユーザID
		'UPDATE_NOTICE'=> undef,		# バージョンチェック
	);
	
	require './module/security.pl';
	require './module/log.pl';
	require './module/update_notice.pl';
	
	$CGI->{'SECINFO'} = SECURITY->new;
	$CGI->{'LOGGER'} = LOG->new;
	$CGI->{'UPDATE_NOTICE'} = ZP_UPDATE_NOTICE->new;
}

