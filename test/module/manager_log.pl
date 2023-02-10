#============================================================================================================
#
#	管理ログデータ管理モジュール
#
#============================================================================================================
package	MANAGER_LOG;

use strict;
use utf8;
binmode(STDIN,':encoding(cp932)');
binmode(STDOUT,':encoding(cp932)');
use open IO => ':encoding(cp932)';
#use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	
	my $obj = {
		'LOG'	=> undef,
		'PATH'	=> undef,
		'FILE'	=> undef,
		'MAX'	=> undef,
		'MAXA'	=> undef,
		'MAXH'	=> undef,
		'MAXS'	=> undef,
		'KIND'	=> undef,
		'NUM'	=> undef,
	};
	bless $obj, $this;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ読み込み - Load
#	------------------------------------------------
#	引　数：$Sys : SYSTEM
#			$log : ログ種類
#			$key : スレッドキー(書き込みの場合のみ)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys, $log, $key) = @_;
	
	$this->{'LOG'} = [];
	$this->{'PATH'}	= '';
	$this->{'FILE'}	= '';
	$this->{'KIND'}	= 0;
	$this->{'MAX'}	= $Sys->Get('ERRMAX');
	$this->{'MAXA'}	= $Sys->Get('ADMMAX');
	$this->{'MAXH'}	= $Sys->Get('HSTMAX');
	$this->{'MAXS'}	= $Sys->Get('SUBMAX');
	$this->{'NUM'}	= 0;
	
	my $file = '';
	my $kind = 0;
	if ($log eq 'ERR') { $file = 'errs.cgi';	$kind = 1; }	# エラーログ
	if ($log eq 'THR') { $file = 'IP.cgi';		$kind = 2; }	# スレッド作成ログ
	if ($log eq 'WRT') { $file = "$key.cgi";	$kind = 3; }	# 書き込みログ
	if ($log eq 'HST') { $file = "HOST.cgi";	$kind = 5; }	# ホストログ
	if ($log eq 'SMB') { $file = "samba.cgi";	$kind = 6; }	# Sambaログ
	if ($log eq 'SBH') { $file = "houshi.cgi";	$kind = 7; }	# Samba規制ログ
	
	$this->{'KIND'} = $kind;
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log';
	
	if ($kind) {
		if (open(my $fh, '<', "$path/$file")) {
			flock($fh, 2);
			my @lines = <$fh>;
			close($fh);
			push @{$this->{'LOG'}}, @lines;
			$this->{'NUM'} = scalar(@lines);
		}
		$this->{'PATH'} = $path;
		$this->{'FILE'} = $file;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	エラーログ書き込み - SaveError
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = "$this->{'PATH'}/$this->{'FILE'}";
	
	if ($this->{'KIND'}) {
		chmod($Sys->Get('PM-LOG'), $path);
		if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
			flock($fh, 2);
			seek($fh, 0, 0);
			print $fh @{$this->{'LOG'}};
			truncate($fh, tell($fh));
			close $fh;
		}
		chmod($Sys->Get('PM-LOG'), $path);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ追加 - Set
#	-------------------------------------------
#	引　数：$I     : SETTING
#			$data1 : 汎用データ1
#			$data2 : 汎用データ2
#			$koyuu : 端末固有識別子
#			$data  : DAT形式のログ
#			$mode  : ID末尾分
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($I, $data1, $data2, $koyuu, $data, $mode) = @_;
	
	$mode = '0' if (! defined $mode);
	
	my $host = $ENV{'REMOTE_HOST'};
	if ($mode ne '0') {
		if ($mode eq 'P') {
			$host = "$host($koyuu)(($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR})";
		}
		else {
			$host = "$host($koyuu)";
		}
	}
	
	# 読み込み済み
	my $kind = $this->{'KIND'};
	if ($kind) {
		my $tm = time;
		my $work = '';
		
		if ($kind == 3) {
			my @logdat = split(/<>/, $data, -1);
			
			$work = join('<>',
				$logdat[0],
				$logdat[1],
				$logdat[2],
				substr($logdat[3], 0, 30),
				$logdat[4],
				$host,
				(($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}),
				$data1,
				$ENV{'HTTP_USER_AGENT'}
			);
			
		}
		else {
			$work = join('<>',
				$tm,
				$data1,
				$data2,
				$host
			);
		}
		
		my $log = $this->{'LOG'};
		# 末尾へ追加
		push @$log, "$work\n";
		my $nm = ++$this->{'NUM'};
		
		my $bf = 0;
		if ($kind == 1) { $bf = $nm - $this->{'MAX'}; }			# エラーログ
		if ($kind == 2) { $bf = $nm - $this->{'MAXS'}; }		# スレッドログ
	#	if ($kind == 3) { $bf = $nm - $I->Get('timecount'); }	# 書き込みログ
		if ($kind == 5) { $bf = $nm - $this->{'MAXH'}; }		# ホストログ
		if ($kind == 6) { $bf = $nm - $this->{'MAX'}; }			# samba
		if ($kind == 7) { $bf = $nm - $this->{'MAX'}; }			# houshi
		
		# 先頭ログの削除
		splice @$log, 0, $bf;
		$this->{'NUM'} = scalar(@$log);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ取得 - Get
#	-------------------------------------------
#	引　数：$ln : ログ番号
#	戻り値：@data
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($ln) = @_;
	
	if ($ln >= 0 && $ln < $this->{'NUM'}) {
		my $work = $this->{'LOG'}->[$ln];
		$work =~ s/[\r\n]+\z//;
		my @data = split(/<>/, $work, -1);
		
		return @data;
	}
	else {
		return undef;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ数取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	レス数
#
#------------------------------------------------------------------------------------------------------------
sub Size
{
	my $this = shift;
	
	return $this->{'NUM'};
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ検索 - Search
#	-------------------------------------------
#	引　数：$data  : サーチキー
#			$f     : サーチモード
#			$mode  : エージェント
#			$host  : リモートホスト
#			$count : 検索数
#	戻り値：各種データ
#
#------------------------------------------------------------------------------------------------------------
sub Search
{
	my $this = shift;
	my ($data, $f, $mode, $host, $count) = @_;
	
	my $kind = $this->{'KIND'};
	
	# data1で検索
	if ($f == 1) {
		my $max = scalar(@{$this->{'LOG'}}) - 1;
		for my $i (reverse(0 .. $max)) {
			my $log = $this->{'LOG'}->[$i];
			$log =~ s/[\r\n]+\z//;
			
			my ($key, $val) = (split /<>/, $log, -1)[$kind == 3 ? (5, 7) : (1, 3)];
			$key = $1 if ($key =~ /\((.*)\)/);
			if ($data eq $key) {
				return $val;
			}
		}
	}
	else {
		if ($mode ne '0') {
			if ($mode eq 'P') {
				$host = "$host($data)(($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR})";
			}
			else {
				$host = "$host($data)";
			}
		}
		
		# host出現数
		if ($f == 2) {
			my $num = 0;
			my $max = scalar(@{$this->{'LOG'}}) - 1;
			$count = $max + 1 if (!defined $count);
			my $min = 1 + $max - $count;
			$min = 0 if ($min < 0);
			
			for my $i (reverse($min .. $max)) {
				my $log = $this->{'LOG'}->[$i];
				$log =~ s/[\r\n]+\z//;
				
				my $key = (split /<>/, $log, -1)[$kind == 3 ? 5 : $kind == 5 ? 1 : 3];
				$key = $1 if ($key =~ /\((.*)\)/);
				if ($data eq $key) {
					$num++;
				}
			}
			return $num;
		}
		# THR
		elsif ($f == 3) {
			my $num = 0;
			my $max = scalar(@{$this->{'LOG'}}) - 1;
			$count = $max + 1 if (! defined $count);
			my $min = 1 + $max - $count;
			$min = 0 if ($min < 0);
			
			for my $i (reverse($min .. $max)) {
				my $log = $this->{'LOG'}->[$i];
				$log =~ s/[\r\n]+\z//;
				
				my ($key, $val) = (split /<>/, $log, -1)[1, 3];
				$val = $1 if ($val =~ /\((.*)\)/);
				if ($data eq $val) {
					$num++;
				}
			}
			return $num;
		}
	}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	時間判定 - IsTime
#	-------------------------------------------
#	引　数：$tmn  : 判定時間(秒)
#			$host : リモートホスト
#	戻り値：時間内:残り秒数,時間外:0
#	備　考：最終ログから$tmn秒経過したかどうかを判定
#
#------------------------------------------------------------------------------------------------------------
sub IsTime
{
	my $this = shift;
	my ($tmn, $host) = @_;
	
	my $kind = $this->{'KIND'};
	
	return 0 if ($kind == 3);
	
	my $nw = time;
	my $n = scalar(@{$this->{'LOG'}});
	
	for my $i (reverse(0 .. $n - 1)) {
		my $log = $this->{'LOG'}->[$i];
		$log =~ s/[\r\n]+\z//;
		my ($tm, undef, undef, $val) = split(/<>/, $log, -1);
		if ($host eq $val) {
			# 残り秒数を返す
			my $rem = $tmn - ($nw - $tm);
			$rem = 0 if ($rem < 0);
			return $rem;
		}
	}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	Samba判定 - IsSamba
#	-------------------------------------------
#	引　数：$sb		: Samba時間(秒)
#			$host	: リモートホスト
#	戻り値：$n		: Samba回数
#			$tm		: 必要待ち時間
#
#------------------------------------------------------------------------------------------------------------
sub IsSamba
{
	my $this = shift;
	my ($sb, $host) = @_;
	
	my $kind = $this->{'KIND'};
	
	return (0, 0) if ($kind != 6);
	
	my $nw = time;
	my $n = scalar(@{$this->{'LOG'}});
	my @iplist = ();
	my $ptm = $nw;
	
	for my $i (reverse(0 .. $n - 1)) {
		my $log = $this->{'LOG'}->[$i];
		$log =~ s/[\r\n]+\z//;
		my ($tm, undef, undef, $val) = split(/<>/, $log, -1);
		
		next if ($host ne $val);
		last if ($sb <= $ptm - $tm);
		
		push @iplist, $tm;
		$ptm = $tm;
	}
	
	$n = scalar(@iplist);
	if ($n) {
		return ($n, ($nw - $iplist[0]));
	}
	
	return (0, 0);
}

#------------------------------------------------------------------------------------------------------------
#
#	奉仕活動中判定 - IsHoushi
#	-------------------------------------------
#	引　数：$houshi		: 奉仕活動時間(分)
#			$host		: リモートホスト
#	戻り値：$ishoushi	: 奉仕活動中
#			$tm			: 必要待ち時間(分)
#
#------------------------------------------------------------------------------------------------------------
sub IsHoushi
{
	my $this = shift;
	my ($houshi, $host) = @_;
	
	my $kind = $this->{'KIND'};
	
	return (0, 0) if ($kind != 7);
	
	my $nw = time;
	my $n = scalar(@{$this->{'LOG'}});
	
	for my $i (reverse(0 .. $n - 1)) {
		my $log = $this->{'LOG'}->[$i];
		$log =~ s/[\r\n]+\z//;
		my ($tm, undef, undef, $val) = split(/<>/, $log, -1);
		
		next if ($host ne $val);
		
		my $intv = $nw - $tm;
		last if ($houshi * 60 <= $intv);
		
		return (1, $houshi - ($intv - ($intv % 60 || 60)) / 60);
	}
	return (0, 0);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド立てすぎ判定 - IsTatesugi
#	-------------------------------------------
#	引　数：$hour		: スレッド作成数規制時間(時間)
#	戻り値：$count		: スレッド数
#
#------------------------------------------------------------------------------------------------------------
sub IsTatesugi
{
	my $this = shift;
	my ($hour) = @_;
	
	my $kind = $this->{'KIND'};
	
	return 0 if ($kind != 2);
	
	my $nw = time;
	my $n = scalar(@{$this->{'LOG'}});
	my $count = 0;
	
	for my $i (reverse(0 .. $n - 1)) {
		my $log = $this->{'LOG'}->[$i];
		$log =~ s/[\r\n]+\z//;
		
		my $tm = (split(/<>/, $log, -1))[0];
		last if ($hour * 3600 <= $nw - $tm);
		
		$count++;
	}
	return $count;
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ1行削除 - Delete
#	-------------------------------------------
#	引　数：$num
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($num) = @_;
	
	$this->{'NUM'} -= scalar splice @{$this->{'LOG'}}, $num, 1;
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
