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

    my $from = $this->{'FROM'} || 0;
    my $to = $this->{'TO'} || time();  # デフォルトで現在時刻まで

    my $mtime = (stat($Path))[9];

    return if (($mtime < $from && $from) || ($key > $to && $to));

    open my $fh, '<', $Path or return;

    my $word_regex = qr/(\Q$word\E)(?![^<>]*>)/;

    my $pResultSet = $this->{'RESULTSET'};
    my $type = $this->{'TYPE'} || 0x15;
    my $line_num = 0;

    while (my $line = <$fh>) {
		last if ($type == 0x8 && $line_num);

        $line_num++;
        my @elem = split(/<>/, $line, -1);

        # レス時刻取得と日付範囲のチェック
        if ($elem[2] =~ /(\d{4})\/(\d{2})\/(\d{2})\(\w+\) (\d{2}):(\d{2}):(\d{2})/) {
            my $unixtime = timelocal($6, $5, $4, $3, $2 - 1, $1);
            next if ($unixtime < $from);
            last if ($unixtime > $to);
        }

        my $bFind = 0;

        # 各種検索タイプに応じた処理
        if ($type & 0x1 && $elem[0] =~ s/$word_regex/<span class="res">$1<\/span>/g) {
            $bFind = 1;
        }
        if ($type & 0x2 && $elem[3] =~ s/$word_regex/<span class="res">$1<\/span>/g) {
            $bFind = 1;
        }
        if ($type & 0x4 && $elem[2] =~ s/$word_regex/<span class="res">$1<\/span>/g) {
            $bFind = 1;
        }
        if ($type & 0x8 && $elem[4] =~ s/$word_regex/<span class="res">$1<\/span>/g) {
            $bFind = 1;
            last;  # スレタイ検索のみの場合、最初の行で終了
        }

        if ($bFind) {
            my $SetStr = "$bbs<>$key<>$line_num<>" . join('<>', @elem);
            push @$pResultSet, $SetStr;
        }
    }
    close $fh;
}


#============================================================================================================
#	Module END
#============================================================================================================
1;
