#============================================================================================================
#
#	アップデート通知
#
#============================================================================================================

package ZP_NEWRELEASE;

use strict;
#use warnings;

use Encode;

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
		'NEWRELEASE'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化 - Init
#	-------------------------------------------------------------------------------------
#	引　数：$Sys : MELKOR
#	戻り値：0
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'NEWRELEASE'} = {
		'CheckURL'	=> 'http://zerochplus.sourceforge.jp/Release.txt',
		'Interval'	=> 60 * 60 * 24, # 24時間
		'RawVer'	=> $Sys->Get('VERSION'),
		'CachePATH'	=>  '.' . $Sys->Get('INFO') . '/Release.cgi',
		'CachePM'	=> $Sys->Get('PM-ADM'),
		'Update'	=> 0,
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
sub Check
{
	my $this = shift;
	
	my $hash = $this->{'NEWRELEASE'};
	
	my $url = $hash->{'CheckURL'};
	my $interval = $hash->{'Interval'};
	
	my $rawver = $hash->{'RawVer'};
	my @ver;
	# 0ch+ BBS n.m.r YYYYMMDD 形式であることをちょっと期待している
	# または 0ch+ BBS dev-rREV YYYYMMDD
	if ( $rawver =~ /(\d+(?:\.\d+)+)/ ) {
		@ver = split /\./, $1;
	} elsif ( $rawver =~ /dev-r(\d+)/ ) {
		@ver = ( 'dev', $1 );
	} else {
		@ver = ( 'dev', 0 );
	}
	my $date = '00000000';
	if ( $rawver =~ /(\d{8})/ ) {
		$date = $1;
	}
	
	my $path = $hash->{'CachePATH'};
	
	
	# キャッシュの有効期限が過ぎてたらデータをとってくる
	if ( !-f $path || ( stat $path )[9] < time - $interval ) {
		# 同時接続防止みたいな
		utime ( undef, undef, $path );
		
		require('./module/httpservice.pl');
		
		my $proxy = HTTPSERVICE->new;
		# URLを指定
		$proxy->setURI($url);
		# UserAgentを設定
		$proxy->setAgent($rawver);
		# タイムアウトを設定
		$proxy->setTimeout(3);
		
		# とってくるよ
		$proxy->request();
		
		# とれた
		if ( $proxy->getStatus() eq 200 ) {
			if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
				flock($fh, 2);
				seek($fh, 0, 0);
				binmode($fh);
				print $fh $proxy->getContent();
				truncate($fh, tell($fh));
				close($fh);
			}
			chmod($hash->{'CachePM'}, $path);
		}
	}
	
	
	# 比較部
	my @release = ();
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		while ( <$fh> ) {
			# $l =~ s/\x0d?\x0a?$//;
			# samwiseと同等のサニタイジングを行います
			$_ =~ s/[\x0d\x0a\0]//g;
			$_ =~ s/"/&quot;/g;
			$_ =~ s/</&lt;/g;
			$_ =~ s/>/&gt;/g;
			
			Encode::from_to( $_, 'utf8', 'sjis' );
			push @release, $_;
		}
		close($fh);
	}
	# 爆弾(BOM)処理
	$release[0] =~ s/^\xef\xbb\xbf//;
	
	# n.m.r形式であることを期待している
	my @newver = split /\./, $release[0];
	# YYYY.MM.DD形式であることを期待している
	my $newdate = join '', (split /\./, $release[2], 3);
	
	my $i = 0;
	my $newrelease = 0;
	# バージョン比較
	# とりあえず自verがdevなら無視(下の日付で確認)
	if ( $ver[0] ne 'dev' ) {
		foreach my $nv ( @newver ) {
			my $vv = shift @ver;
			if ( $vv < $nv ) {
				$newrelease = 1;
			} elsif ( $vv > $nv ) {
				# なぜかインストール済みの方があたらしい
				last;
			}
		}
	}
	# よくわかんなかったらあらためて日付で確認する
	unless ( $newrelease ) {
		if ( $date < $newdate ) {
			$newrelease = 1;
		}
	}
	
	
	$this->{'NEWRELEASE'}->{'Update'}	= $newrelease;
	$this->{'NEWRELEASE'}->{'Ver'}		= shift @release;
	$this->{'NEWRELEASE'}->{'URL'}		= 'http://sourceforge.jp/projects/zerochplus/releases/' . shift @release;
	$this->{'NEWRELEASE'}->{'Date'}		= shift @release;
	
	shift @release; # 4行目(空行)を消す
	# 残りはリリースノートとかそういうのが残る
	$this->{'NEWRELEASE'}->{'Detail'}	= \@release;
	
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
	
	my $val = $this->{'NEWRELEASE'}->{$key};
	
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
	
	$this->{'NEWRELEASE'}->{$key} = $data;
}

1;
