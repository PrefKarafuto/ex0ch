#============================================================================================================
#
#	元号表示
#	0ch_era.pl
#	---------------------------------------------------------------------------
#	202x.xx.xx start
#
#============================================================================================================
package ZPL_era;
use utf8;
use open IO =>':encoding(cp932)';
use Time::Local;
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
#	拡張機能名称取得
#	-------------------------------------------------------------------------------------
#	@return	名称文字列
#------------------------------------------------------------------------------------------------------------
sub getName
{
	my	$this = shift;
	return '元号';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return '日付表示を元号にします。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ(スレ立て:1, レス:2, read:4, index:8, 書き込み前処理:16)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return (4|8);
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	設定ハッシュリファレンス
#		\%config = (
#			'設定名'	=> {
#				'default'		=> 初期値,			# 真偽値の場合は on/true: 1, off/false: 0
#				'valuetype'		=> 値のタイプ,		# 数値: 1, 文字列: 2, 真偽値: 3
#				'description'	=> '設定の説明',	# 無くても構いません
#			},
#		);
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	my	$this = shift;
	my	%config;
	
	%config = (
		'元号'	=> {
			'default'		=> '令和',
			'valuetype'		=> 2,
			'description'	=> '元号を入れてください。',
		},
		'開始日時'	=> {
			'default'		=> '2019/5/1',
			'valuetype'		=> 2,
			'description'	=> '元号がスタートした日付をYYYY/MM/DD形式(もしくはYYYY/MM/DD hour:min:sec)で指定してください。',
		},
		'フォーマット'	=> {
			'default'		=> 1,
			'valuetype'		=> 1,
			'description'	=> '出力される日付のフォーマット。0:YYYY/MM/DD 1:YYYY(ERA)/MM/DD 2:ERA/MM/DD',
		},
        '(次の元号)'	=> {
			'default'		=> '',
			'valuetype'		=> 2,
			'description'	=> '改元が分かっている場合に、次の元号を入れてください。',
		},
		'(改元日時)'	=> {
			'default'		=> '',
			'valuetype'		=> 2,
			'description'	=> '改元が分かっている場合に、その日付をYYYY/MM/DD形式(もしくはYYYY/MM/DD hour:min:sec)で指定してください。',
		},
		'対象掲示板'	=> {
			'default'		=> '',
			'valuetype'		=> 2,
			'description'	=> '機能を有効化する掲示板のディレクトリ名を指定してください。（複数の場合はカンマ区切り。無記入で全ての掲示板。）',
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
	
	if ($type & (4|8)) {
		my ($year, $month, $day, $hour, $minute, $second, $epoch);

		my $era_name = $this->GetConf('元号');
        my $next_era_name = $this->GetConf('(次の元号)');
        my $dateStr = $this->GetConf('開始日時');
        my $nextDateStr = $this->GetConf('(改元日時)');
		my $start_date = $this->ymd_to_unixtime($dateStr);
        my $next_date = $this->ymd_to_unixtime($nextDateStr);
		my $format = $this->GetConf('フォーマット');
        my $target_bbs = $this->GetConf('対象掲示板');
        my $bbs = $sys->Get('BBS');

		if ($sys->Get('_DAT_')->[2] =~ /^(\d{4})\/(\d{2})\/(\d{2})\([^\)]+\)\s+(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?/) {
			($year, $month, $day, $hour, $minute, $second) = ($1, $2, $3, $4, $5, $6);
			$epoch = timelocal($second, $minute, $hour, $day, $month - 1, $year);
		}

		if($start_date && $epoch >= $start_date && (!$target_bbs||$target_bbs =~ /$bbs/)){
            if($next_era_name && $next_date && $epoch >= $next_date && $next_date > $start_date){
                # 改元
                $dateStr = $nextDateStr;
                $era_name = $next_era_name;
				$this->SetConf('元号', $era_name);
				$this->SetConf('開始日時', $dateStr);
				$this->SetConf('(次の元号)','');
				$this->SetConf('(改元日時)','');
            }
			my $era_year = $year - (split(/\//,$dateStr,2))[0];
			$era_year = $era_year ? $era_year + 1 : '元';
			if ($format == 1) {
				# YYYY(ERA)/MM/DD (西暦(元号)表示)
				$form->Set('datepart', "$year(${era_name}${era_year}年)/$other");
			}
			elsif ($format == 2) {
				# ERA(YYYY)/MM/DD (元号表示)
				$form->Set('datepart', "${era_name}${era_year}($year)年/$other");
			}
		}
	}
	
	return 0;
}

sub ymd_to_unixtime {
	my	$this = shift;
    my ($date_time) = @_;

    my ($date, $time) = split(/\s/, $date_time);

    return 0 if (!$date && !$time);
    
    # YYYY/MM/DD を年、月、日それぞれに分割
    my ($year, $month, $day) = split(/\//, $date);
    my ($hour, $min, $sec) = split(/:/, $time);
    $month--;
    
    # timelocal関数でUnix時間を取得
    my $unixtime = timelocal($sec, $min, $hour, $day, $month, $year);
    
    return $unixtime;
}
#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@return	設定値
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
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@param	$val	設定値
#	@return	なし
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

#============================================================================================================
#	Module END
#============================================================================================================
1;
