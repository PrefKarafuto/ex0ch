#============================================================================================================
#
#	拡張機能 - VIPクオリティ コネクタモジュール for 0ch+ 0.7.4
#	0ch_vip_quality_mod.pl
#
#============================================================================================================
package ZPL_vip_quality_mod;



#------------------------------------------------------------------------------------------------------------
#	拡張機能名称取得
#------------------------------------------------------------------------------------------------------------
sub getName
{
	return 'それがVIPクオリティ';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	return 'VIPクオリティ機能\<br>使える機能\の詳細はVip_quality.plを参照。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#------------------------------------------------------------------------------------------------------------
sub getType
{
	return 16;
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	return {};
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my $this = shift;
	my ($Sys, $Form, $type) = @_;
	
	# 0ch本家では実行しない
	return 0 if (!$this->{'is0ch+'});
	
	# 「VIP クオリティ」モジュールの読み込み
	require './module/Vip_quality.pl';
	
	my $CGI = $Sys->Get('MainCGI');
	my $Set = $CGI->{'SET'};
	
	# 加工データを準備
	my $version = $Sys->Get('VERSION');
	my $bbs = $Sys->Get('BBS');
	my $key = $Sys->Get('KEY');
	my $name = $Form->Get('FROM');
	my $mail = $Form->Get('mail');
	my $text = $Form->Get('MESSAGE');
	my $info = $Form->Get('datepart') . ' '. $Form->Get('idpart');
	
	# @RRGGBB@ 指定のデフォルト名無し
	if ($name =~ /^\@[0-9a-f]{6}\@$/i) {
		$name .= $Set->Get('BBS_NONAME_NAME');
	}
	
	# 「VIP クオリティ」名無し制御サブルーチンの実行
	$name = Vip_quality::vip_quality_new_treed($name, $bbs, $key) if ($Sys->Equal('MODE', 1));
	# 「VIP クオリティ」サブルーチンの実行
	($name, $mail, $info, $text) = Vip_quality::vip_quality($name, $mail, $info, $text, $version, $bbs, $key);
	
	# 加工済みデータを再設定
	$Form->Set('FROM', $name);
	$Form->Set('mail', $mail);
	$Form->Set('MESSAGE', $text);
	my @info = split(/ /, $info, 3);
	$Form->Set('datepart', "$info[0] $info[1]");
	$Form->Set('idpart', "$info[2]");
	
	# 強制sage対応
	$Sys->Set('updown', '') if ($mail =~ /sage/);
	
	return 0;
}



#------------------------------------------------------------------------------------------------------------
#	コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my ($Config) = @_;
	
	my $this = {};
	bless $this, $class;
	
	if (defined $Config) {
		$this->{'PLUGINCONF'} = $Config;
		$this->{'is0ch+'} = 1;
	}
	else {
		$this->{'CONFIG'} = $class->getConfig();
		$this->{'is0ch+'} = 0;
	}
	
	return $this;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my $this = shift;
	my ($key) = @_;
	if ($this->{'is0ch+'}) {
		return $this->{'PLUGINCONF'}->GetConfig($key);
	}
	elsif (defined $this->{'CONFIG'}->{$key}) {
		return $this->{'CONFIG'}->{$key}->{'default'};
	}
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my $this = shift;
	my ($key, $val) = @_;
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	elsif (defined $this->{'CONFIG'}->{$key}) {
		$this->{'CONFIG'}->{$key}->{'default'} = $val;
	}
	else {
		$this->{'CONFIG'}->{$key} = { 'default' => $val };
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
