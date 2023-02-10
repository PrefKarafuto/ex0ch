#============================================================================================================
#
#	検索モジュール(SEARCH)
#
#============================================================================================================
package	SEARCH;

use strict;
use utf8;
binmode(STDIN,':encoding(cp932)');
binmode(STDOUT,':encoding(cp932)');
use open IO => ':encoding(cp932)';
#use warnings;
use Encode qw(encode decode);

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
#	@param	$mode	0:全検索,1:BBS内検索,2:スレッド内検索
#	@param	$type	0:全検索,1:名前検索,2:本文検索
#					4:ID(日付)検索
#	@param	$bbs	検索BBS名($mode=1の場合に指定)
#	@param	$thread	検索スレッド名($mode=2の場合に指定)
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Create
{
	my $this = shift;
	my ($Sys, $mode, $type, $bbs, $thread) = @_;
	
	$this->{'SYS'} = $Sys;
	$this->{'TYPE'} = $type;
	
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
			my $set = "$bbs<>$threadID";
			push @$pSearchSet, $set;
		}
	}
	# スレッド内全検索
	elsif ($mode == 2) {
		my $set = "$bbs<>$thread";
		push @$pSearchSet, $set;
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
sub Search
{
	my $this = shift;
	my ($word) = @_;
	
	my $bbs = $this->{'SYS'}->Get('BBS');
	my $key = $this->{'SYS'}->Get('KEY');
	my $Path = $this->{'SYS'}->Get('BBSPATH') . "/$bbs/dat/$key.dat";
	my $DAT = $this->{'DAT'};
	
	my $word = decode('cp932', $word);
	
	if ($DAT->Load($this->{'SYS'}, $Path, 1)) {
		my $pResultSet = $this->{'RESULTSET'};
		my $type = $this->{'TYPE'} || 0x7;
		
		# すべてのレス数でループ
		for (my $i = 0 ; $i < $DAT->Size() ; $i++) {
			my $bFind = 0;
			my $pDat = $DAT->Get($i);
			my $data = decode('cp932', $$pDat);
			my @elem = split(/<>/, $data, -1);
			
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
			# ID or 日付検索
			if ($type & 0x4) {
				if ($elem[2] =~ s/(\Q$word\E)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
					$bFind = 1;
				}
			}
			if ($bFind) {
				my $SetStr = "$bbs<>$key<>" . ($i + 1) . '<>';
				$SetStr .= join('<>', @elem);
				$SetStr = encode('cp932', $SetStr);
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
