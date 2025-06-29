#============================================================================================================
#
#	システム管理CGI - ログイン モジュール
#	login.pl
#	---------------------------------------------------------------------------
#	2004.01.31 start
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
	my ($obj);
	
	$obj = {
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
	my ($BASE, $Page);
	
	require './admin/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	
	$Page = $BASE->Create($Sys, $Form);
	
	PrintLogin($Sys, $Page, $Form);
	
	$BASE->PrintNoList('LOGIN', 0);
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
	my ($host, $Security, $Mod);
	$host = $ENV{'REMOTE_HOST'};
	
	# ログイン情報を確認
	if ($pSys->{'USER'}) {
		require './admin/sys.top.pl';
		$Mod = MODULE->new;
		$Form->Set('MODE_SUB', 'NOTICE');
		
		$pSys->{'LOGGER'}->Put($Form->Get('UserName') . "[$host]", 'Login', 'TRUE');
		
		$Mod->DoPrint($Sys, $Form, $pSys);
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName') . "[$host]", 'Login', 'FALSE');
		$Form->Set('FALSE', 1);
		$this->DoPrint($Sys, $Form, $pSys);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	表示メソッド
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintLogin
{
	my ($Sys, $Page, $Form) = @_;

	my $auth = ImgurCallback($Sys, $Form);

	my $sitekey = $Sys->Get('CAPTCHA_SITEKEY');
	my $classname = $Sys->Get('CAPTCHA');
	my $Captcha = $sitekey && $classname && $Sys->Get('ADMINCAP') ? "<div class=\"$classname\" data-sitekey=\"$sitekey\"></div><br>" : '';
	my $text = $sitekey && $classname && $Captcha ? 'Captcha認証に失敗したか、' : "" ;
	$text .= 'ユーザ名もしくはパスワードが間違っています。';

	if($auth){
		$text = 'Imgur連携に成功しました。' if $auth eq 'success';
		$text = 'Imgur連携に失敗しました。' if $auth eq 'failed';
	}
	
$Page->Print(<<HTML);
  <center>
   <div align="center" class="LoginForm">
HTML
	
	if ($Form->Get('FALSE') == 1) {
		$Page->Print("    <div class=\"xExcuted\">${text}</div>\n");
	}
	if($Captcha){
		$Page->Print("<script src=\"./datas/form-captcha.js\" defer></script>");
	}
	
$Page->Print(<<HTML);
	<table align="center" border="0" style="margin:30px 0;">
	 <tr>
	  <td>ユーザ名</td><td><input type="text" name="UserName" style="width:200px"></td>
	 </tr>
	 <tr>
	  <td>パスワード</td><td><input type="password" name="PassWord" style="width:200px"></td>
	 </tr>
	 <tr>
	  <td colspan="2" align="center">
	  <hr>
	  $Captcha
	  <input type="submit" id="form-btn" value="　ログイン　">
	  </td>
	 </tr>
	</table>
	
	<div class="Sorce">
	 <b>
	 <font face="Arial" size="3" color="red">Ex0ch Administration Page</font><br>
	 <font face="Arial">Powered by 0ch/0ch+/ex0ch script and 0ch/0ch+/ex0ch modules 2001-2025</font>
	 </b>
	</div>
	
   </div>
   
  </center>
  
  <!-- ▼こんなところに地下要塞(ry -->
   <input type="hidden" name="MODE" value="FUNC">
   <input type="hidden" name="MODE_SUB" value="">
  <!-- △こんなところに地下要塞(ry -->
  
HTML
	
}

sub ImgurCallback
{
	my ($Sys, $Form) = @_;
	return 0 unless $Sys->Get('IMGUR_ID') || $Sys->Get('IMGUR_SECRET');

	if (my $code = $Form->Get('code')) {
		require './module/imgur.pl';

		my $Img = IMGUR->new;
		$Img->Load($Sys);
    	my $err = $Img->ObtainAccessToken($code);
		return 'failed' unless $err;

		$Img->Save();
		$Sys->Set('IMGUR_AUTH','authed');
		$Sys->Save();
		return 'success';
	}
	return 0;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
