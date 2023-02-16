#============================================================================================================
#
#	プラグイン管理モジュール
#
#============================================================================================================
package	PLUGIN;

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
	my $class = shift;
	
	my $obj = {
		'Sys'		=> undef,
		'FILE'		=> undef,
		'CLASS'		=> undef,
		'NAME'		=> undef,
		'EXPL'		=> undef,
		'TYPE'		=> undef,
		'VALID'		=> undef,
		'CONFIG'	=> undef,
		'CONFTYPE'	=> undef,
		'ORDER'		=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	# ハッシュ初期化
	$this->{'SYS'} = $Sys;
	$this->{'FILE'} = {};
	$this->{'CLASS'} = {};
	$this->{'NAME'} = {};
	$this->{'EXPL'} = {};
	$this->{'TYPE'} = {};
	$this->{'VALID'} = {};
	$this->{'CONFIG'} = {};
	$this->{'CONFTYPE'} = {};
	$this->{'ORDER'} = [];
	
	my $path = '.' . $Sys->Get('INFO') . '/plugins.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '');
			
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 7) {
				warn "invalid line in $path";
				#next;
			}
			
			eval { require "./plugin/$elem[1]"; };
			next if ($@);
			
			my $id = $elem[0];
			$this->{'FILE'}->{$id} = $elem[1];
			$this->{'CLASS'}->{$id} = $elem[2];
			$this->{'NAME'}->{$id} = $elem[3];
			$this->{'EXPL'}->{$id} = $elem[4];
			$this->{'TYPE'}->{$id} = $elem[5];
			$this->{'VALID'}->{$id} = $elem[6];
			$this->{'CONFIG'}->{$id} = {};
			$this->{'CONFTYPE'}->{$id} = {};
			push @{$this->{'ORDER'}}, $id;
			$this->SetDefaultConfig($id);
			$this->LoadConfig($id);
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン個別設定読み込み
#	-------------------------------------------------------------------------------------
#	@param	$id	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub LoadConfig
{
	my $this = shift;
	my ($id) = @_;
	
	my $config = $this->{'CONFIG'}->{$id};
	my $conftype = $this->{'CONFTYPE'}->{$id};
	my $file = $this->{'FILE'}->{$id};
	my $path = undef;
	
	if ($file =~ /^(0ch_.*)\.pl$/) {
		$path = "./plugin_conf/$1.cgi";
	}
	else {
		warn "invalid plugin file name: $file";
		return;
	}
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		foreach (@lines) {
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 3) {
				warn "invalid line in $path";
				next;
			}
			$config->{$elem[1]} = $elem[2];
			$conftype->{$elem[1]} = $elem[0];
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン個別設定保存
#	-------------------------------------------------------------------------------------
#	@param	$id	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SaveConfig
{
	my $this = shift;
	my ($id) = @_;
	
	my $config = $this->{'CONFIG'}->{$id};
	my $conftype = $this->{'CONFTYPE'}->{$id};
	my $file = $this->{'FILE'}->{$id};
	my $path = undef;
	
	if ($file =~ /^(0ch_.*)\.pl$/) {
		$path = "./plugin_conf/$1.cgi";
	}
	else {
		warn "invalid plugin file name: $file";
		return;
	}
	
	if (scalar(keys %$config) > 0) {
		chmod($this->{'SYS'}->Get('PM-ADM'), $path);
		if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
			flock($fh, 2);
			seek($fh, 0, 0);
			
			foreach my $key (sort keys %$config) {
				next unless (defined $config->{$key});
				
				my $val = $config->{$key};
				my $type = $conftype->{$key};
				if ($type == 1) {
					$val -= 0;
				}
				elsif ($type == 2) {
					$val =~ s/\r\n|[\r\n]/<br>/g;
					$val =~ s/<>/&lt;&gt;/g;
				}
				elsif ($type == 3) {
					$val = ($val ? 1 : 0);
				}
				print $fh "$type<>$key<>$val\n";
			}
			
			truncate($fh, tell($fh));
			close($fh);
		}
		else {
			warn "can't save subject: $path";
		}
		chmod($this->{'SYS'}->Get('PM-ADM'), $path);
	}
	else {
		unlink $path;
	}
}

sub HasConfig
{
	my $this = shift;
	my ($id) = @_;
	
	return scalar(keys %{$this->{'CONFIG'}->{$id}});
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン個別設定初期値設定
#	-------------------------------------------------------------------------------------
#	@param	$id	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetDefaultConfig
{
	my $this = shift;
	my ($id) = @_;
	
	my $config = $this->{'CONFIG'}->{$id} = {};
	my $conftype = $this->{'CONFTYPE'}->{$id} = {};
	my $file = $this->{'FILE'}->{$id};
	my $className = undef;
	
	if ($file =~ /^0ch_(.*)\.pl$/) {
		$className = "ZPL_$1";
	}
	else {
		warn "invalid plugin file name: $file";
		return;
	}
	
	require "./plugin/$file";
	if ($className->can('getConfig')) {
		my $plugin = $className->new;
		my $conf = $plugin->getConfig;
		foreach my $key (keys %$conf) {
			$config->{$key} = $conf->{$key}->{'default'};
			$conftype->{$key} = $conf->{$key}->{'valuetype'};
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = '.' . $Sys->Get('INFO') . '/plugins.cgi';
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		foreach my $id (@{$this->{'ORDER'}}) {
			my $data = join('<>',
				$id,
				$this->{'FILE'}->{$id},
				$this->{'CLASS'}->{$id},
				$this->{'NAME'}->{$id},
				$this->{'EXPL'}->{$id},
				$this->{'TYPE'}->{$id},
				$this->{'VALID'}->{$id}
			);
			
			print $fh "$data\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグインIDセット取得
#	-------------------------------------------------------------------------------------
#	@param	$kind	検索種別
#	@param	$name	検索ワード
#	@param	$pBuf	IDセット格納バッファ
#	@return	キーセット数
#
#------------------------------------------------------------------------------------------------------------
sub GetKeySet
{
	my $this = shift;
	my ($kind, $name, $pBuf) = @_;
	
	my $n = 0;
	
	if ($kind eq 'ALL') {
		$n += push @$pBuf, @{$this->{'ORDER'}};
	}
	else {
		foreach my $key (@{$this->{'ORDER'}}) {
			if ($this->{$kind}->{$key} eq $name || $name eq 'ALL') {
				$n += push @$pBuf, $key;
			}
		}
	}
	
	return $n;
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報取得
#	-------------------------------------------------------------------------------------
#	@param	$kind		情報種別
#	@param	$key		ユーザID
#	@param	$default	デフォルト
#	@return	ユーザ情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($kind, $key, $default) = @_;
	
	my $val = $this->{$kind}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		ユーザID
#	@param	$kind	情報種別
#	@param	$val	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($id, $kind, $val) = @_;
	
	if (exists $this->{$kind}->{$id}) {
		$this->{$kind}->{$id} = $val;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン追加
#	-------------------------------------------------------------------------------------
#	@param	$file	プラグインファイル名
#	@param	$valid	有効フラグ
#	@return	プラグインID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($file, $valid) = @_;
	
	my $id = time;
	$id++ while (exists $this->{'FILE'}->{$id});
	
	if (! -e "./plugin/$file") {
		warn "not found plugin: ./plugin/$file";
		return undef;
	}
	
	my $className = undef;
	if ($file =~ /0ch_(.*)\.pl/) {
		$className = "ZPL_$1";
	}
	else {
		warn "invalid plugin file name: $file";
		return undef;
	}
	
	require "./plugin/$file";
	if (!$className->can('new')) {
		warn "invalid plugin file name: $file";
		return undef;
	}
	
	my $plugin = $className->new;
	$this->{'FILE'}->{$id} = $file;
	$this->{'CLASS'}->{$id} = $className;
	$this->{'NAME'}->{$id} = $plugin->getName;
	$this->{'EXPL'}->{$id} = $plugin->getExplanation;
	$this->{'TYPE'}->{$id} = $plugin->getType;
	$this->{'VALID'}->{$id} = $valid;
	$this->{'CONFIG'}->{$id} = {};
	$this->{'CONFTYPE'}->{$id} = {};
	$this->SetDefaultConfig($id);
	$this->LoadConfig($id);
	$this->SaveConfig($id);
	push @{$this->{'ORDER'}}, $id;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除プラグインID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'FILE'}->{$id};
	delete $this->{'CLASS'}->{$id};
	delete $this->{'NAME'}->{$id};
	delete $this->{'EXPL'}->{$id};
	delete $this->{'TYPE'}->{$id};
	delete $this->{'VALID'}->{$id};
	delete $this->{'CONFIG'}->{$id};
	delete $this->{'CONFTYPE'}->{$id};
	
	my $order = $this->{'ORDER'};
	for my $i (reverse(0 .. $#$order)) {
		if ($order->[$i] eq $id) {
			splice(@$order, $i, 1);
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン情報更新
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Update
{
	my $this = shift;
	my ($plugin, $exist);
	
	my @files = ();
	if (opendir(my $dh, './plugin')) {
		@files = readdir($dh);
		closedir($dh);
	}
	else {
		$this->{'FILE'} = {};
		$this->{'CLASS'} = {};
		$this->{'NAME'} = {};
		$this->{'EXPL'} = {};
		$this->{'TYPE'} = {};
		$this->{'VALID'} = {};
		$this->{'CONFIG'} = {};
		$this->{'CONFTYPE'} = {};
		$this->{'ORDER'} = [];
		return;
	}
	
	# プラグイン追加・更新フェイズ
	foreach my $file (@files) {
		if ($file =~ /^0ch_(.*)\.pl/) {
			my $className = "ZPL_$1";
			my @keySet = ();
			if (scalar $this->GetKeySet('FILE', $file, \@keySet) > 0) {
				my $id = $keySet[0];
				require "./plugin/$file";
				my $plugin = $className->new;
				$this->{'NAME'}->{$id} = $plugin->getName;
				$this->{'EXPL'}->{$id} = $plugin->getExplanation;
				$this->{'TYPE'}->{$id} = $plugin->getType;
				$this->SetDefaultConfig($id);
				$this->LoadConfig($id);
				$this->SaveConfig($id);
			}
			else {
				$this->Add($file, 0);
			}
		}
	}
	# プラグイン削除フェイズ
	my @keySet = ();
	if ($this->GetKeySet('ALL', '', \@keySet) > 0) {
		foreach my $id (@keySet) {
			my $exist = 0;
			foreach my $file (@files) {
				if ($this->Get('FILE', $id) eq $file) {
					$exist = 1;
					last;
				}
			}
			if ($exist == 0) {
				$this->Delete($id);
			}
		}
	}
}


#============================================================================================================
#
#	プラグイン個別設定管理モジュール
#
#============================================================================================================

package	PLUGINCONF;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	$Plugin	PLUGIN
#	@param	$id		
#	@return	モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my ($Plugin, $id) = @_;
	
	my $obj = {
		'PLUGIN'	=> $Plugin,
		'id'		=> $id
	};
	
	bless $obj, $class;
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン個別設定設定
#	-------------------------------------------------------------------------------------
#	@param	$key	
#	@param	$val	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetConfig
{
	my $this = shift;
	my ($key, $val) = @_;
	
	my $id = $this->{'id'};
	my $Plugin = $this->{'PLUGIN'};
	my $config = $Plugin->{'CONFIG'}->{$id};
	my $conftype = $Plugin->{'CONFTYPE'}->{$id};
	my $type = 0;
	
	if (defined $conftype->{$key}) {
		$type = $conftype->{$key};
	}
	else {
		if (ref(\$val) eq 'SCALAR') {
			$type = 2;
		}
		else {
			$type = 0;
			return;
		}
		$conftype->{$key} = $type;
	}
	
	if ($type == 1) {
		$val -= 0;
	}
	elsif ($type == 2) {
		$val =~ s/\r\n|[\r\n]/<br>/g;
		$val =~ s/<>/&lt;&gt;/g;
	}
	elsif ($type == 3) {
		$val = ($val ? 1 : 0);
	}
	
	$config->{$key} = $val;
	
	$Plugin->SaveConfig($id);
}

#------------------------------------------------------------------------------------------------------------
#
#	プラグイン個別設定取得
#	-------------------------------------------------------------------------------------
#	@param	$key	
#	@return	プラグイン個別設定
#
#------------------------------------------------------------------------------------------------------------
sub GetConfig
{
	my $this = shift;
	my ($key) = @_;
	
	my $id = $this->{'id'};
	my $config = $this->{'PLUGIN'}->{'CONFIG'}->{$id};
	
	return $config->{$key};
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
