#============================================================================================================
#
#	検索モジュール(SEARCH)
#
#============================================================================================================
package	SEARCH;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use Encode qw(encode decode);
use Time::Local;

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
		'SYS'		=> undef,
		'TYPE'		=> undef,
		'FROM'		=> undef,
		'TO'		=> undef,
		'SEARCHSET'	=> undef,
		'RESULTSET'	=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	検索設定
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$mode	0:全検索,1:BBS内検索,2:カテゴリー内検索
#	@param	$type	0:全検索,1:名前検索,2:本文検索
#					4:ID検索,8:スレタイ検索
#	@param	$bbs	検索BBS名($mode=1の場合に指定)
#	@param	$cat	検索カテゴリー名($mode=2の場合に指定)
#	@param	$from,$to	$fromから$toまでの期間で検索
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Create
{
	my $this = shift;
	my ($Sys, $mode, $type, $bbs, $cat, $from, $to) = @_;
	
	$this->{'SYS'} = $Sys;
	$this->{'TYPE'} = $type;
	$this->{'FROM'} = $from;
	$this->{'TO'} = $to;
	
	$this->{'SEARCHSET'} = [];
	$this->{'RESULTSET'} = [];
	my $pSearchSet = $this->{'SEARCHSET'};
	
	# 鯖内全検索
	if ($mode == 0) {
		require './module/thread.pl';
		require './module/bbs_info.pl';
		my $BBSs = BBS_INFO->new;
		
		$BBSs->Load($Sys);
		my @bbsSet = ();
		$BBSs->GetKeySet('ALL', '', \@bbsSet);
		
		my $BBSpath = $Sys->Get('BBSPATH');
		
		foreach my $bbsID (@bbsSet) {
			my $dir = $BBSs->Get('DIR', $bbsID);
			
			# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
			next if (-e "$BBSpath/$dir/.0ch_hidden");
			
			$Sys->Set('BBS', $dir);
			my $Threads = THREAD->new;
			$Threads->Load($Sys);
			my @threadSet = ();
			$Threads->GetKeySet('ALL', '', \@threadSet);
			
			foreach my $threadID (@threadSet) {
				next if ($threadID > $to && $to);
				my $set = "$dir<>$threadID";
				push @$pSearchSet, $set;
			}
		}
	}
	# 掲示板内全検索
	elsif ($mode == 1) {
		require './module/thread.pl';
		my $Threads = THREAD->new;
		
		$Sys->Set('BBS', $bbs);
		$Threads->Load($Sys);
		my @threadSet = ();
		$Threads->GetKeySet('ALL', '', \@threadSet);
		
		foreach my $threadID (@threadSet) {
			next if ($threadID > $to && $to);
			my $set = "$bbs<>$threadID";
			push @$pSearchSet, $set;
		}
	}
	# カテゴリー内全検索
	elsif ($mode == 2) {
		require './module/thread.pl';
		require './module/bbs_info.pl';
		my $BBSs = BBS_INFO->new;
		
		$BBSs->Load($Sys);
		my @bbsSet = ();
		$BBSs->GetKeySet('ALL', '', \@bbsSet);
		
		my $BBSpath = $Sys->Get('BBSPATH');
		
		foreach my $bbsID (@bbsSet) {
			my $dir = $BBSs->Get('DIR', $bbsID);
			
			# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
			next if (-e "$BBSpath/$dir/.0ch_hidden");
			next if ($cat ne $BBSs->Get('CATEGORY', $bbsID));
			
			$Sys->Set('BBS', $dir);
			my $Threads = THREAD->new;
			$Threads->Load($Sys);
			my @threadSet = ();
			$Threads->GetKeySet('ALL', '', \@threadSet);
			
			foreach my $threadID (@threadSet) {
				next if ($threadID > $to && $to);
				my $set = "$dir<>$threadID";
				push @$pSearchSet, $set;
			}
		}
	}
	# 指定がおかすぃ
	else {
		return;
	}
	
	# datモジュール読み込み
	if (! defined $this->{'DAT'}) {
		require './module/dat.pl';
		$this->{'DAT'} = DAT->new;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	検索実行
#	-------------------------------------------------------------------------------------
#	@param	$word	検索ワード
#	@param	$f		前結果クリアフラグ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Run
{
	my $this = shift;
	my ($word, $f) = @_;
	
	my $pSearchSet = $this->{'SEARCHSET'};
	$this->{'RESULTSET'} = [] if ($f);
	
	foreach (@$pSearchSet) {
		my ($bbs, $key) = split(/<>/, $_);
		$this->{'SYS'}->Set('BBS', $bbs);
		$this->{'SYS'}->Set('KEY', $key);
		$this->Search($word);
	}
	return $this->{'RESULTSET'};
}

#------------------------------------------------------------------------------------------------------------
#
#	検索結果取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	結果セット
#
#------------------------------------------------------------------------------------------------------------
sub GetResultSet
{
	my $this = shift;
	
	return $this->{'RESULTSET'};
}

#------------------------------------------------------------------------------------------------------------
#
#	検索実装部
#	-------------------------------------------------------------------------------------
#	@param	$word : 検索ワード
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Search {
	my $this = shift;
	my ($word) = @_;

	my $bbs = $this->{'SYS'}->Get('BBS');
	my $key = $this->{'SYS'}->Get('KEY');
	my $Path = $this->{'SYS'}->Get('BBSPATH') . "/$bbs/dat/$key.dat";
	my $DAT = $this->{'DAT'};

	my $from = $this->{'FROM'} || 0;
	my $to = $this->{'TO'} || 0;

	my $mtime = (stat($Path))[9];

	return if(($mtime < $from && $from)||($key > $to && $to));

	if ($DAT->Load($this->{'SYS'}, $Path, 1)) {
		my $pResultSet = $this->{'RESULTSET'};
		my $type = $this->{'TYPE'} || 0x15;

		# すべてのレス数でループ
		for (my $i = 0; $i < $DAT->Size(); $i++) {
			last if ($type == 0x8 && $i);
			
			my $bFind = 0;
			my $pDat = $DAT->Get($i);
			my @elem = split(/<>/, $$pDat, -1);

			# レス時刻取得
			if ($elem[2] =~ /(\d{4})\/(\d{2})\/(\d{2})\(\w+\) (\d{2}):(\d{2}):(\d{2})/) {
				my $year = $1;
				my $month = $2 - 1;   # 月 (0から始まる)
				my $day = $3;         # 日
				my $hour = $4;        # 時
				my $min = $5;         # 分
				my $sec = $6;         # 秒

				my $unixtime = timelocal($sec, $min, $hour, $day, $month, $year);
				next if (($unixtime < $from && $from) || ($to < $unixtime && $to));
			}

			# 名前検索
			if ($type & 0x1) {
				if ($elem[0] =~ s/(\Q$word\E)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
					$bFind = 1;
				}
			}
			# 本文検索
			if ($type & 0x2) {
				if ($elem[3] =~ s/(\Q$word\E)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
					$bFind = 1;
				}
			}
			# ID検索
			if ($type & 0x4) {
				my $id = (split(/ /,$elem[2]))[2];
				if ($id =~ s/(\Q$word\E)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
					$bFind = 1;
				}
			}
			# スレタイ検索
			if ($type & 0x8) {
				if ($elem[4] =~ s/(\Q$word\E)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
					$bFind = 1;
				}
			}

			if ($bFind) {
				my $SetStr = "$bbs<>$key<>" . ($i + 1) . '<>';
				$SetStr .= join('<>', @elem);
				push @$pResultSet, $SetStr;
			}
		}
	}
	$DAT->Close();
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
