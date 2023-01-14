#============================================================================================================
#
#	拡張機能 - スパムキラー
#	0ch_spamkiller.pl
#
#============================================================================================================
package ZPL_spamkiller;

#------------------------------------------------------------------------------------------------------------
#	拡張機能名称取得
#------------------------------------------------------------------------------------------------------------
sub getName
{
	return 'スパムキラー';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	return '英文スパムをベイジアンフィルタによって排除します。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#------------------------------------------------------------------------------------------------------------
sub getType
{
	return (1 | 2); # スレ立て・レス
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	my	$this = shift;
	my	%config;
	
	%config = (
		'name_ascii_point'	=> {
			'default'		=> 2,
			'valuetype'		=> 1,
			'description'	=> '[加点]名前欄がASCIIのみ',
		},
		'mail_atsign_point'	=> {
			'default'		=> 5,
			'valuetype'		=> 1,
			'description'	=> '[加点]メール欄に半角@を含む',
		},
		'nohost_point'	=> {
			'default'		=> 7,
			'valuetype'		=> 1,
			'description'	=> '[加点]ホスト名が逆引き不可',
		},
		'tldomain_setting'	=> {
			'default'		=> 'jp,com,net,org=2;*=3',
			'valuetype'		=> 2,
			'description'	=> '[指定]本文中リンクのTLドメインの種類ごとに加点<br>※text_url_pointが0の時のみ有効です',
		},
		'text_ascii_point'	=> {
			'default'		=> 2,
			'valuetype'		=> 1,
			'description'	=> '[加点]本文のASCIIの割合が指定した％以上',
		},
		'text_ascii_ratio'	=> {
			'default'		=> 95,
			'valuetype'		=> 1,
			'description'	=> '[しきい値]本文のASCIIの割合(％)',
		},
		'text_ahref_point'	=> {
			'default'		=> 5,
			'valuetype'		=> 1,
			'description'	=> '[加点]本文に「&lt;a href=」か「[url=」を含む',
		},
		'text_url_point'	=> {
			'default'		=> 3,
			'valuetype'		=> 1,
			'description'	=> '[加点]本文にリンクを含む<br>※0にするとtldomain_settingが有効になります',
		},
		'threshold_point'	=> {
			'default'		=> 10,
			'valuetype'		=> 1,
			'description'	=> '[しきい値]スパムと判定する点数',
		},
	);
	
	return \%config;
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$sys	SYSTEM
#	@param	$form	FORM
#	@param	$type	実行タイプ
#	@return	正常終了の場合は0
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my	$this = shift;
	my	($sys, $form, $type) = @_;
	
	if ($type & (1 | 2)) {
		
		my $nohost_point = $this->GetConf('nohost_point');
		my $tldomain_setting = $this->GetConf('tldomain_setting');
		my $name_ascii_point = $this->GetConf('name_ascii_point');
		my $mail_atsign_point = $this->GetConf('mail_atsign_point');
		my $text_ascii_point = $this->GetConf('text_ascii_point');
		my $text_ascii_ratio = $this->GetConf('text_ascii_ratio');
		my $text_ahref_point = $this->GetConf('text_ahref_point');
		my $text_url_point = $this->GetConf('text_url_point');
		my $threshold_point = $this->GetConf('threshold_point');
		
		require Encode;
		my $name = $form->Get('FROM');
		my $mail = $form->Get('mail');
		my $text = $form->Get('MESSAGE');
		$name = Encode::decode('sjis', $name);
		$mail = Encode::decode('sjis', $mail);
		$text = Encode::decode('sjis', $text);
		
		my $point = 0;
		
		if ($ENV{'REMOTE_HOST'} eq $ENV{'REMOTE_ADDR'}) {
			$point += $nohost_point;
		}
		if ($name ne '' && $name !~ /[^\x09\x0a\x0d\x20-\x7e]/) {
			$point += $name_ascii_point;
		}
		if ($mail =~ /@/) {
			$point += $mail_atsign_point;
		}
		if ($text =~ /&lt;a href=|\[url=/i) {
			$point += $text_ahref_point;
		}
		if ($text =~ m|http://|) {
			$point += $text_url_point;
		}
		
		if ('ASCII text') {
			$text =~ s/<br>//gi;
			$text =~ s/[\x00-\x1f\x7f\s]//g;
			my $c_asc = @_ = $text =~ /[\x20-\x7e]/g;
			my $c_nasc = @_ = $text =~ /[^\x20-\x7e]/g;
			if ($c_asc * 100 >= ($c_asc + $c_nasc) * $text_ascii_ratio) {
				$point += $text_ascii_point;
			}
		}
		
		if ('TLD of links' && $text_url_point == 0) {
			my %tld2pt = ('*' => 0);
			my $r_num = '^-?[0-9]+$';
			my $r_tld = '^[a-z](?:[a-z0-9\-](?:[a-z0-9])?)?$|^\*$';
			
			# 設定文を解釈し点数マップを作成
			foreach (split(/[^0-9a-zA-Z\-=,\*]/, $tldomain_setting)) {
				my @buf = split(/[=,]/, $_);
				my @num = grep { /$r_num/ } @buf;
				if (scalar(@num) == 1) {
					map { $tld2pt{$_} = $num[0] } grep { /$r_tld/i } @buf;
				} elsif (scalar(@num) > 1) {
					foreach (split(/,/, $_)) {
						my @buf2 = split(/=/, $_);
						next if (!defined (my $p = pop @{[grep { /$r_num/ } @buf2]}));
						map { $tld2pt{$_} = $p } grep { /$r_tld/i } @buf2;
					}
				}
			}
			
			# 本文リンクからTLDを抽出し重複排除
			my @tldlist = keys %{ {map { pop(@{[split(/\./, $_)]}), 1 }
							($text =~ m|http://([a-z0-9\-\.]+)|gi)} };
			
			# TLDの種類ごとに加点
			foreach $tld (@tldlist) {
				$tld = '*' if (!defined $tld2pt{$tld});
				$point += $tld2pt{$tld};
			}
		}
		
		if ($point >= $threshold_point) {
			PrintBBSError($sys, $form, 205);
		}
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($Config) = @_;
	my ($obj);
	
	$obj = {};
	bless $obj, $this;
	
	if (defined $Config) {
		$obj->{'PLUGINCONF'} = $Config;
		$obj->{'is0ch+'} = 1;
	}
	else {
		$obj->{'CONFIG'} = $this->getConfig();
		$obj->{'is0ch+'} = 0;
	}
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my	$this = shift;
	my	($key) = @_;
	my	($val);
	
	if ($this->{'is0ch+'}) {
		$val = $this->{'PLUGINCONF'}->GetConfig($key);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$val = $this->{'CONFIG'}->{$key}->{'default'};
		}
		else {
			$val = undef;
		}
	}
	
	return $val;
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my	$this = shift;
	my	($key, $val) = @_;
	
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$this->{'CONFIG'}->{$key}->{'default'} = $val;
		}
		else {
			$this->{'CONFIG'}->{$key} = { 'default' => $val };
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#	なんちゃってbbs.cgiエラーページ表示
#------------------------------------------------------------------------------------------------------------
sub PrintBBSError
{
	my ($sys, $form, $err) = @_;
	my $SYS;
	
	require './module/cookie.pl';
	require './module/setting.pl';
	require './module/buffer.pl';
	
	$SYS->{'SYS'} = $sys;
	$SYS->{'FORM'} = $form;
	$SYS->{'COOKIE'} = COOKIE->new;
	$SYS->{'COOKIE'}->Init;
	$SYS->{'SET'} = SETTING->new;
	$SYS->{'SET'}->Load($sys);
	my $Page = BUFFER->new;
	
	require('./module/error_info.pl');
	$ERROR = ERROR_INFO->new;
	$ERROR->Load($sys);
	
	$ERROR->Print($SYS, $Page, $err, $sys->Get('AGENT'));
	
	$Page->Flush('', 0, 0);
	
	exit($err);
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
