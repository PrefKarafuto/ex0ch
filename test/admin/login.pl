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
	
	PrintLogin($Page, $Form);
	
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
	
	require './module/data_utils.pl';
	$host = DATA_UTILS::GetRemoteHost();
	
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
	my ($Page, $Form) = @_;
	
$Page->Print(<<HTML);
  <center>
   <div align="center" class="LoginForm">
HTML
	
	if ($Form->Get('FALSE') == 1) {
		$Page->Print("    <div class=\"xExcuted\">ユーザ名もしくはパスワードが間違っています。</div>\n");
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
      <input type="submit" value="　ログイン　">
      </td>
     </tr>
    </table>
    
    <div class="Sorce">
     <b>
     <font face="Arial" size="3" color="red">ex0ch Administration Page</font><br>
     <font face="Arial">Powered by 0ch/0ch+/ex0ch script and 0ch/0ch+/ex0ch modules 2001-2023</font>
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

#============================================================================================================
#	Module END
#============================================================================================================
1;
