#============================================================================================================
#
#	アップデート通知
#
#============================================================================================================

package ZP_UPDATE_NOTICE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use LWP::UserAgent;
use JSON;
use Encode;
use Time::Local;

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
		'UPDATE_NOTICE'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化 - Init
#	-------------------------------------------------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：0
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'UPDATE_NOTICE'} = {
		'CheckURL'	=> 'https://api.github.com/repos/PrefKarafuto/ex0ch/releases/latest',
		'Interval'	=> 60 * 60 * 24, # 24時間
		'RawVer'	=> $Sys->Get('VERSION'),
		'Update'	=> 0,
		'LastCheck' => $Sys->Get('LASTCHECK'),
	};
	
}


#------------------------------------------------------------------------------------------------------------
#
#	更新チェック - Check
#	-------------------------------------------------------------------------------------
#	引　数：なし
#	戻り値：0
#
#------------------------------------------------------------------------------------------------------------
sub Check {
	my $this = shift;

	my $hash = $this->{'UPDATE_NOTICE'};

	my $url = $hash->{'CheckURL'};
	my $interval = $hash->{'Interval'};
	my $lastcheck = $hash->{'LastCheck'};

	my $rawver = (split(/ /, $hash->{'RawVer'}))[2];
	my $ver = "";
	my $dev = "";
	if ($rawver =~ /^(\d+\.\d+\.\d+)$/) {
		$ver = $1;
	} elsif ($rawver =~ /^dev-r(\d+)$/) {
		$dev = $1;
	}

	# APIから取得
	my ($latest_release, $release_url, $release_date, $release_note);
	if (time - $lastcheck > $interval) {
		my $ua = LWP::UserAgent->new;
		$ua->agent("Mozilla/5.0");

		# APIリクエストの送信
		my $response = $ua->get($url);

		# レスポンスの確認
		if ($response->is_success) {
			my $content = $response->decoded_content;
			my $json = decode_json($content);

			# リリース情報の抽出
			$latest_release = $json->{tag_name};
			$release_url = $json->{html_url};
			$release_date = $json->{published_at};
			$release_note = $json->{body};
		} else {
			return 0;
		}
	}

	if ($release_date =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z$/) {
		my ($year, $month, $day, $hour, $minute, $second) = ($1, $2, $3, $4, $5, $6);
		$month -= 1;
		$release_date = timegm($second, $minute, $hour, $day, $month, $year);
	}

	$this->{'UPDATE_NOTICE'}->{'Update'} = (!$dev && 'v' . $ver ne $latest_release && $latest_release) ? 1 : 0;		# dev版なら通知しない
	$this->{'UPDATE_NOTICE'}->{'Ver'} = $latest_release;
	$this->{'UPDATE_NOTICE'}->{'URL'} = $release_url;
	$this->{'UPDATE_NOTICE'}->{'Date'} = $release_date;
	$this->{'UPDATE_NOTICE'}->{'Detail'} = $release_note;

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	設定値取得 - Get
#	-------------------------------------------------------------------------------------
#	@param	$key	取得キー
#			$default : デフォルト
#	@return	設定値
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($key, $default) = @_;
	
	my $val = $this->{'UPDATE_NOTICE'}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	設定値設定 - Set
#	-------------------------------------------------------------------------------------
#	@param	$key	設定キー
#	@param	$data	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($key, $data) = @_;
	
	$this->{'UPDATE_NOTICE'}->{$key} = $data;
}

1;
