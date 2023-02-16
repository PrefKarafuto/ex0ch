#============================================================================================================
#
#	システム管理 - 編集 モジュール
#	sys.edit.pl
#	---------------------------------------------------------------------------
#	2004.09.15 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

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
	my ($subMode, $BASE, $Page);
	
	require './admin/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	
	# 管理情報を登録
	$Sys->Set('ADMIN', $pSys);
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys);
	
	if ($subMode eq 'BANNER_PC') {													# PC用告知編集画面
		PrintBannerForPCEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'BANNER_MOBILE') {											# 携帯用告知編集画面
		PrintBannerForMobileEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'BANNER_SUB') {												# サブ告知編集画面
		PrintBannerForSubEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# システム設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('システム編集処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# システム設定失敗画面
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
	
	# 管理情報を登録
	$Sys->Set('ADMIN', $pSys);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'BANNER_PC') {														# PC用告知
		$err = FunctionBannerEdit($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'BANNER_MOBILE') {												# 携帯用告知
		$err = FunctionBannerEdit($Sys, $Form, 2, $this->{'LOG'});
	}
	elsif ($subMode eq 'BANNER_SUB') {													# サブバナー
		$err = FunctionBannerEdit($Sys, $Form, 3, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "SYSTEM_EDIT($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "SYSTEM_EDIT($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
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
	my ($Base, $pSys) = @_;
	
	$Base->SetMenu('告知編集(PC用)', "'sys.edit','DISP','BANNER_PC'");
	$Base->SetMenu('告知編集(携帯用)', "'sys.edit','DISP','BANNER_MOBILE'");
	$Base->SetMenu('告知編集(サブ)', "'sys.edit','DISP','BANNER_SUB'");
}

#------------------------------------------------------------------------------------------------------------
#
#	告知欄(PC)編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBannerForPCEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Banner, $bgColor, $content, $common);
	
	$SYS->Set('_TITLE', 'PC Banner Edit');
	
	require './module/banner.pl';
	$Banner = BANNER->new;
	$Banner->Load($SYS);
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=center>");
	
	# 告知欄プレビュー表示
	if ($Form->IsExist('PC_CONTENT')) {
		$Banner->Set('COLPC', $Form->Get('PC_BGCOLOR'));
		$Banner->Set('TEXTPC', $Form->Get('PC_CONTENT'));
		$bgColor = $Form->Get('PC_BGCOLOR');
		$content = $Form->Get('PC_CONTENT');
	}
	else {
		$bgColor = $Banner->Get('COLPC');
		$content = $Banner->Get('TEXTPC');
	}
	
	# プレビューデータの作成
	my $BannerPage = BUFFER_OUTPUT->new;
	$Banner->Print($BannerPage, 100, 0, 0);
	$BannerPage->{'BUFF'} = CreatePreviewData($BannerPage->{'BUFF'});
	$Page->Merge($BannerPage);
	
	$common = "onclick=\"DoSubmit('sys.edit'";
	
	$Page->Print("</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">背景色</td><td>");
	$Page->Print("<input type=text size=20 name=PC_BGCOLOR value=\"$bgColor\"></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">内容</td><td>");
	$Page->Print("<textarea rows=10 cols=70 name=PC_CONTENT wrap=off>$content</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=2>※告知欄の表\示は設定で消すことができます。 [システム設定]→[表\示設定]→告知欄表\示(index.html以外の告知欄を表\示するのチェックをOFF)</td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=left>");
	$Page->Print("<input type=button value=\"　設定　\" $common,'FUNC','BANNER_PC');\"> ");
	$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','BANNER_PC');\">");
	$Page->Print("</td></tr>\n</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	告知欄(携帯)編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBannerForMobileEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Banner, $bgColor, $content, $common);
	
	$SYS->Set('_TITLE', 'Mobile Banner Edit');
	
	require './module/banner.pl';
	$Banner = BANNER->new;
	$Banner->Load($SYS);
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=center>");
	
	# 告知欄プレビュー表示
	if ($Form->IsExist('MOBILE_CONTENT')) {
		$Banner->Set('COLMB', $Form->Get('MOBILE_BGCOLOR'));
		$Banner->Set('TEXTMB', $Form->Get('MOBILE_CONTENT'));
		$bgColor = $Form->Get('MOBILE_BGCOLOR');
		$content = $Form->Get('MOBILE_CONTENT');
	}
	else {
		$bgColor = $Banner->Get('COLMB');
		$content = $Banner->Get('TEXTMB');
	}
	
	# プレビューデータの作成
	my $BannerPage = BUFFER_OUTPUT->new;
	$Banner->Print($BannerPage, 100, 0, 1);
	$BannerPage->{'BUFF'} = CreatePreviewData($BannerPage->{'BUFF'});
	$Page->Merge($BannerPage);
	
	$common = "onclick=\"DoSubmit('sys.edit'";
	
	$Page->Print("</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">背景色</td><td>");
	$Page->Print("<input type=text size=20 name=MOBILE_BGCOLOR value=\"$bgColor\"></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">内容</td><td>");
	$Page->Print("<textarea rows=10 cols=70 name=MOBILE_CONTENT wrap=off>$content</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=left>");
	$Page->Print("<input type=button value=\"　設定　\" $common,'FUNC','BANNER_MOBILE');\"> ");
	$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','BANNER_MOBILE');\">");
	$Page->Print("</td></tr>\n</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	告知欄(サブ)編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBannerForSubEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Banner, $content, $common);
	
	$SYS->Set('_TITLE', 'Sub Banner Edit');
	
	require './module/banner.pl';
	$Banner = BANNER->new;
	$Banner->Load($SYS);
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=center>");
	
	# 告知欄プレビュー表示
	if ($Form->IsExist('SUB_CONTENT')) {
		$Banner->Set('TEXTSB', $Form->Get('SUB_CONTENT'));
		$content = $Form->Get('SUB_CONTENT');
	}
	else {
		$content = $Banner->Get('TEXTSB');
	}
	
	# プレビューデータの作成
	my $BannerPage = BUFFER_OUTPUT->new;
	$Banner->PrintSub($BannerPage);
	$BannerPage->{'BUFF'} = CreatePreviewData($BannerPage->{'BUFF'});
	$Page->Merge($BannerPage);
	
	$common = "onclick=\"DoSubmit('sys.edit'";
	
	$Page->Print("</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">内容</td><td>");
	$Page->Print("<textarea rows=10 cols=70 name=SUB_CONTENT wrap=off>$content</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=2 align=left>");
	$Page->Print("<input type=button value=\"　設定　\" $common,'FUNC','BANNER_SUB');\"> ");
	$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','BANNER_SUB');\">");
	$Page->Print("</td></tr>\n</table>");
}

#------------------------------------------------------------------------------------------------------------
#
#	告知欄編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionBannerEdit
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Banner);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	if ($mode != 3) {
		my @inList;
		
		@inList = ('PC_CONTENT', 'PC_BGCOLOR')			if ($mode == 1);
		@inList = ('MOBILE_CONTENT', 'MOBILE_BGCOLOR')	if ($mode == 2);
		
		if (! $Form->IsInput(\@inList)) {
			return 1001;
		}
	}
	require './module/banner.pl';
	$Banner = BANNER->new;
	$Banner->Load($Sys);
	
	if ($mode == 1) {
		$Banner->Set('TEXTPC', $Form->Get('PC_CONTENT'));
		$Banner->Set('COLPC', $Form->Get('PC_BGCOLOR'));
		push @$pLog, 'PC用告知欄を設定しました。';
	}
	elsif ($mode == 2) {
		$Banner->Set('TEXTMB', $Form->Get('MOBILE_CONTENT'));
		$Banner->Set('COLMB', $Form->Get('MOBILE_BGCOLOR'));
		push @$pLog, '携帯用告知欄を設定しました。';
	}
	elsif ($mode == 3) {
		$Banner->Set('TEXTSB', $Form->Get('SUB_CONTENT'));
		push @$pLog, 'サブバナーを設定しました。';
	}
	
	# 設定の保存
	$Banner->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	プレビューデータの作成
#	-------------------------------------------------------------------------------------
#	@param	$pData	作成元配列の参照
#	@return	プレビューデータの配列
#
#------------------------------------------------------------------------------------------------------------
sub CreatePreviewData
{
	my ($pData) = @_;
	my @temp;
	
	foreach (@$pData) {
		$_ =~ s/<[fF][oO][rR][mM].*?>/<!--form--><br>/g;
		$_ =~ s/<\/[fF][oO][rR][mM]>/<!--\/form--><br>/g;
		$_ =~ s/[nN][aA][mM][eE].*?=/_name_=/g;
		push @temp, $_;
	}
	return \@temp;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
