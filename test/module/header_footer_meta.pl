#============================================================================================================
#
#	ヘッダ・フッタ・META管理モジュール
#
#============================================================================================================
package	HEADER_FOOTER_META;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {
		'HEAD'	=> undef,
		'TEXT'	=> undef,
		'URL'	=> undef,
		'PATH'	=> undef,
		'FILE'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	ヘッダ・フッタの読み込み - Load
#	-------------------------------------------
#	引　数：$Sys    : モジュール
#			$kind : 種類
#	戻り値：エラー番号
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys, $kind) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	my $file = '';
	$file = 'head.txt' if ($kind eq 'HEAD');
	$file = 'foot.txt' if ($kind eq 'FOOT');
	$file = 'meta.txt' if ($kind eq 'META');
	
	$this->{'TEXT'} = $Sys->Get('HEADTEXT');
	$this->{'URL'} = $Sys->Get('HEADURL');
	$this->{'PATH'} = $path;
	$this->{'FILE'} = $file;
	
	my $head = $this->{'HEAD'} = [];
	
	if (open(my $fh, '<', "$path/$file")) {
		flock($fh, 2);
		@$head = <$fh>;
		close($fh);
		return 0;
	}
	
	return -1;
}

#------------------------------------------------------------------------------------------------------------
#
#	ヘッダ・フッタの書き込み - Save
#	-------------------------------------------
#	引　数：$Sys : SYSTEMモジュール
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = "$this->{'PATH'}/$this->{'FILE'}";
	
	chmod($Sys->Get('PM-TXT'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		print $fh @{$this->{'HEAD'}};
		truncate($fh, tell($fh));
		close($fh);
	}
	else {
		warn "can't save header/footer: $path";
	}
	chmod($Sys->Get('PM-TXT'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	内容の設定 - Set
#	-------------------------------------------
#	引　数：$head : 設定内容(リファレンス)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($head) = @_;
	
	open(my $fh, '<', $head);
	my @lines = <$fh>;
	close $fh;
	$this->{'HEAD'} = \@lines;
}

#------------------------------------------------------------------------------------------------------------
#
#	内容の取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	内容の参照
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	
	return $this->{'HEAD'};
}

#------------------------------------------------------------------------------------------------------------
#
#	内容の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@param	$Set	SETTING
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Print
{
	my $this = shift;
	my ($Page, $Set) = @_;
	
	# head.txtの場合はヘッダ全てを表示する
	if ($this->{'FILE'} eq 'head.txt') {
		my $bbs = $Set->Get('BBS_SUBTITLE');
		my $tcol = $Set->Get('BBS_MENU_COLOR');
		my $text = $this->{'TEXT'};
		my $url = $this->{'URL'};
	
	$Page->Print(<<HEAD);
<a name="info"></a>
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$tcol" style="margin-bottom:1.2em;" align="center">
 <tr>
  <td colspan="3">
  <table border="0" width="100%">
   <tr>
    <td><font size="+1"><b>$bbs</b></font></td>
    <td align="right"><a href="#menu">■</a> <a href="#1">▼</a></td>
   </tr>
   <tr>
    <td colspan="2">
HEAD
		
		foreach (@{$this->{'HEAD'}}) {
			$Page->Print("    $_");
		}
		
		$Page->Print("    </td>\n");
		$Page->Print("   </tr>\n");
		$Page->Print("  </table>\n");
		$Page->Print("  </td>\n");
		$Page->Print(" </tr>\n");
		
		if ($text ne '') {
			$Page->Print(" <tr align=\"center\">\n");
			$Page->Print("  <td><a href=\"../test/search.cgi\" target=\"_blank\">レス検索</a></td>\n");
			$Page->Print("  <td><a href=\"$url\" target=\"_blank\">$text</a></td>\n");
			$Page->Print("  <td><a href=\"../bbsmenu.html\" target=\"_blank\">BBS MENU</a></td>\n");
			$Page->Print(" </tr>\n");
		}
		
		$Page->Print("</table>\n\n");
		#$Page->Print("<br>\n");
	}
	# META.txtはインデント
	elsif ($this->{'FILE'} eq 'meta.txt') {
		foreach (@{$this->{'HEAD'}}) {
			$Page->Print(" $_");
		}
		$Page->Print("\n");
	}
	# その他は内容をそのまま表示
	else {
		foreach (@{$this->{'HEAD'}}) {
			$Page->Print($_);
		}
	}
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
