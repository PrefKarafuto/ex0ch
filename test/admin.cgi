#!/usr/bin/perl
#============================================================================================================
#
#	システム管理CGI
#
#============================================================================================================

use lib './perllib';

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
no warnings 'once';
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use JSON;
use LWP::UserAgent;

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

	# IP
	$ENV{'REMOTE_ADDR'} = $ENV{'HTTP_CF_CONNECTING_IP'} if $ENV{'HTTP_CF_CONNECTING_IP'};
	require './module/data_utils.pl';
	if(!defined $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_HOST'} eq '') {
		$ENV{'REMOTE_HOST'} = DATA_UTILS->new->reverse_lookup($ENV{'REMOTE_ADDR'});
	}
	
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
	my $capt = Certification_Captcha($Sys,$Form) if ($pass && $Sys->Get('ADMINCAP'));
	my ($userID, $SID) = $CGI->{'SECINFO'}->IsLogin($name, $pass, $sid);
	unless($capt){
		$CGI->{'USER'} = $userID;
		$Form->Set('SessionID', $SID);
		if ($CGI->{'SECINFO'}->IsAuthority($userID,$ZP::AUTH_SYSADMIN,'*')){
			$Sys->Set('LASTMOD',time);
			$Sys->Save();
		}
	}
	
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
#	Captcha検証
#	-------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub Certification_Captcha {
    my ($Sys,$Form) = @_;
	my ($captcha_response,$url);

	my $captcha_kind = $Sys->Get('CAPTCHA');
    my $secretkey = $Sys->Get('CAPTCHA_SECRETKEY');
	if($captcha_kind eq 'h-captcha'){
		$captcha_response = $Form->Get('h-captcha-response');
    	$url = 'https://api.hcaptcha.com/siteverify';
	}elsif($captcha_kind eq 'g-recaptcha'){
		$captcha_response = $Form->Get('g-recaptcha-response');
    	$url = 'https://www.google.com/recaptcha/api/siteverify';
	}elsif($captcha_kind eq 'cf-turnstile'){
		$captcha_response = $Form->Get('cf-turnstile-response');
    	$url = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
	}else{
		return 0;
	}

	my $ua = LWP::UserAgent->new();
	my $response = $ua->post($url,{
		secret => $secretkey,
		response => $captcha_response,
		remoteip => $ENV{'REMOTE_ADDR'},
    });
	
	if ($response->is_success()) {
		my $json_text = $response->decoded_content();
		my $out = decode_json($json_text);
		
		if ($out->{success} eq 'true') {
			return 0;
		}elsif ($out->{error_codes} =~ /(missing-input-secret|invalid-input-secret|sitekey-secret-mismatch)/){
			# 管理者側の設定ミス
			return 0;
		}else{
			return 1;
		}
	} else {
		# Captchaを素通りする場合、HTTPS関連のエラーの疑いあり
		# LWP::Protocol::httpsおよびNet::SSLeayが入っているか確認
		# このエラーの場合、スルーしてログインする
		return 0;
	}
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

