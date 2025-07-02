#============================================================================================================
#
#   検索モジュール(ADMIN_SEARCH)
#
#============================================================================================================
package ADMIN_SEARCH;
 
use strict;
use Encode;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
 use Time::Local;

#------------------------------------------------------------------------------------------------------------
#
#   コンストラクタ
#   -------------------------------------------------------------------------------------
#   @param  なし
#   @return モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
   
	my $obj = {
		'SYS'       => undef,
		'TYPE_M'    => undef,
		'TYPE_C'    => undef,
		'TYPE_R'    => undef,
		'FROM'      => undef,
		'TO'      	=> undef,
		'SEARCHSET' => undef,
		'RESULTSET' => undef,
	};
	bless $obj, $class;
   
	return $obj;
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索設定
#   -------------------------------------------------------------------------------------
#   @param  $Sys    MELKOR
#   @param  $mode   0:全検索,1:BBS内検索,2:スレッド内検索
#   @param  $type   0:全検索,1:名前検索,2:本文検索
#                   4:ID(日付)検索
#   @param  $bbsID  検索BBSid($mode=1の場合に指定)
#   @param  $bbs    検索BBS名($mode=1の場合に指定)
#   @param  $thread 検索スレッド名($mode=2の場合に指定)
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub Create
{
	my $this = shift;
	my ($Sys, $typeM, $typeC, $typeR, $bbsID, $bbs, $from, $to) = @_;
   
	$this->{'SYS'} = $Sys;
	$this->{'TYPE_C'} = $typeC;
	$this->{'TYPE_M'} = $typeM;
	$this->{'TYPE_R'} = $typeR;
	$this->{'FROM'} = $from;
	$this->{'TO'} 	= $to;
   
	$this->{'SEARCHSET'} = [];
	$this->{'RESULTSET'} = [];
	my $pSearchSet = $this->{'SEARCHSET'};

	if (!$bbs) {
		# 鯖内全検索
		require './module/thread.pl';
		require './module/bbs_info.pl';
		my $BBSs = BBS_INFO->new;
	   
		$BBSs->Load($Sys);
		my @bbsSet = ();
		$BBSs->GetKeySet('ALL', '', \@bbsSet);
	   
		my $BBSpath = $Sys->Get('BBSPATH');
	   
		foreach my $bbsIDtmp (@bbsSet) {
			my $dir = $BBSs->Get('DIR', $bbsIDtmp);
		   
			# 板ディレクトリに.0ch_hiddenというファイルがあれば読み飛ばす
			next if (-e "$BBSpath/$dir/.0ch_hidden");
		   
			$Sys->Set('BBS', $dir);
			my $Threads = THREAD->new;
			$Threads->Load($Sys);
			my @threadSet = ();
			$Threads->GetKeySet('ALL', '', \@threadSet);
		   
			foreach my $threadID (@threadSet) {
				my $set = "$bbsIDtmp<>$dir<>$threadID";
				push @$pSearchSet, $set;
			}
		}
	}else{
		# 掲示板内全検索
		require './module/thread.pl';
		my $Threads = THREAD->new;
	   
		$Sys->Set('BBS', $bbs);
		$Threads->Load($Sys);
		my @threadSet = ();
		$Threads->GetKeySet('ALL', '', \@threadSet);
	   
		foreach my $threadID (@threadSet) {
			my $set = "$bbsID<>$bbs<>$threadID";
			push @$pSearchSet, $set;
		}
	}
	# datモジュール読み込み
	if (! defined $this->{'DAT'}) {
		require './module/dat.pl';
		$this->{'DAT'} = DAT->new;
	}
	if (! defined $this->{'LOG'}) {
		require './module/log.pl';
		$this->{'LOG'} = LOG->new;
	}
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索実行
#   -------------------------------------------------------------------------------------
#   @param  $word   検索ワード
#   @param  $f      前結果クリアフラグ
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub Run
{
	my $this = shift;
	my ($word, $f) = @_;
	my $pSearchSet = $this->{'SEARCHSET'};
	$this->{'RESULTSET'} = [] if ($f);
   
	foreach (@$pSearchSet) {
		my ($bbsID, $bbs, $key) = split(/<>/, $_);
		$this->{'SYS'}->Set('BBS_ID', $bbsID);
		$this->{'SYS'}->Set('BBS', $bbs);
		$this->{'SYS'}->Set('KEY', $key);
		$this->Search($word);
	}
	return $this->{'RESULTSET'};
}

# キーとワードから忍法帖検索
sub Run_LogN
{
	my $this = shift;
	my ($key,$word,$f) = @_;
	$this->{'RESULTSET'} = [] if ($f);
	$this->NinSearch($key, $word,);
	return $this->{'RESULTSET'};
}
#------------------------------------------------------------------------------------------------------------
#
#   検索結果取得
#   -------------------------------------------------------------------------------------
#   @param  なし
#   @return 結果セット
#
#------------------------------------------------------------------------------------------------------------
sub GetResultSet
{
	my $this = shift;
   
	return $this->{'RESULTSET'};
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索実装部
#   -------------------------------------------------------------------------------------
#   @param  $word : 検索ワード
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub Search {
    my $this = shift;
    my ($word) = @_;

    my $SYS    = $this->{SYS};
    my $bbsID  = $SYS->Get('BBS_ID');
    my $bbs    = $SYS->Get('BBS');
    my $key    = $SYS->Get('KEY');
    my $base   = $SYS->Get('BBSPATH') . "/$bbs";
    my $datPath = "$base/dat/$key.dat";
    my $logPath = "$base/log/$key";

    my $DAT = $this->{DAT};
    my $LOG = $this->{LOG};

	# 日付範囲
	my $from = $this->{'FROM'} || 0;	# 開始
    my $to = $this->{'TO'} || 0;	# 終了
	my $mtime = (stat($datPath))[9];	# 最終更新日時
	my $ctime = $key;					# 作成日時
	if ($from > $to){
		my $tmp = $from;
		$from = $to;
		$to = $tmp;
	}
	# スレッドが指定日付範囲外の場合、パス
	return if (($mtime < $from && $from) || ($ctime > $to && $to));

    # 【1】 投稿データをロード
    $DAT->Load($SYS, $datPath, 1);
    my $datsize = $DAT->Size;

    # 【2】 ログデータをオープン
    $LOG->Open($logPath, 0, 1|2);
    my $logsize = $LOG->Size;

    # dat と log の行ずれを吸収
    my $base_offset = $logsize - $datsize;

    my $mode       = $this->{TYPE_M} || 'res';    # 'res' or 'log'
    my $type_check = $this->{TYPE_C} || 0;        # ビットフラグ（1:名前,2:本文,4:ID,8:スレタイ,16:メール）
    my $type_radio = $this->{TYPE_R} || '';       # 'ip','host','ua','sid'

    my $pResultSet = $this->{RESULTSET};

    # キーワード検索用に正規表現を組む（resモード時だけ）
    my $regex = undef;
    if ($mode =~ /res/ && defined $word) {
        if ($word =~ /(\p{Zs}+)/ && $word !~ /[.?\*\/\(\)\|\{\}\[\]\=\^\$]/) {
            my @ws = split /\p{Zs}+/, $word;
            $regex = '^' . join('', map { "(?=.*\Q$_\E)" } @ws) . '.*$';
        } else {
            $regex = qr/$word/;
        }
    }

    # 【3】 メインループ
	my $date_regex = qr/(\d{4})\/(\d{2})\/(\d{2})\(\w+\) (\d{2}):(\d{2}):(\d{2})/;
    for (my $i = 0; $i < $datsize; $i++) {
        my $pDat = $DAT->Get($i);
        next unless defined $pDat;
        my @elem = split /<>/, $$pDat, -1;

		# — レス時刻取得と日付範囲のチェック —
        if (($from || $to) && $elem[2] =~ $date_regex) {
            my $unixtime = timelocal($6, $5, $4, $3, $2 - 1, $1);
            next if ($unixtime < $from);
            last if ($unixtime > $to);
        }

        # — 対応するログ行を近傍探索 —
        my @log_data;
        for my $d (0,1,-1,2,3,-2,-3) {
            my $idx = $base_offset + $i + $d;
            next if $idx < 0 || $idx >= $logsize;
            my $log_line = $LOG->Get($idx) or next;
            my @data = split /<>/, $log_line, -1;
            # ID(日付)で一致確認
            if ($data[2] && $data[2] eq $elem[2]) {
                @log_data = @data;
                last;
            }
        }

        # — マッチ判定 —
        my $matched = 0;
        if ($mode =~ /res/) {
			# スレタイ
			if (($type_check & 16) && $i == 0 && $elem[4] =~ s/($regex)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
				$matched = 1;
			}
			# 本文検索
			if (($type_check & 1) && $elem[3] =~ s/($regex)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
				$matched = 1;
			}
			# 名前検索
			if (($type_check & 2) && $elem[0] =~ s/($regex)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
				$matched = 1;
			}
			# ID・日付検索
			if (($type_check & 4) && $elem[2] =~ s/($regex)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
				$matched = 1;
			}
			# メール検索
			if (($type_check & 8) && $elem[1] =~ s/($regex)(?![^<>]*>)/<span class="res">$1<\/span>/g) {
				$matched = 1;
			}

		}
        else {
            # ログ検索モード：ラジオ選択で１件のみ比較
            if (@log_data) {
                if ($type_radio eq 'ip') {
                    $matched = ($log_data[6] // '') =~ /\Q$word\E/ ? 1 : 0;
                }
                elsif ($type_radio eq 'host') {
                    $matched = ($log_data[5] // '') =~ /\Q$word\E/ ? 1 : 0;
                }
                elsif ($type_radio eq 'ua') {
                    $matched = ($log_data[8] // '') =~ /\Q$word\E/ ? 1 : 0;
                }
                elsif ($type_radio eq 'sid') {
                    $matched = (($log_data[9] // '') eq $word) ? 1 : 0;
                }
            }
        }

        # — 結果セットへ追加 —
        if ($matched) {
            my $set = join('<>', $bbsID, $key, $i+1) . '<>';
            $set .= $$pDat;
            if (@log_data) {
                chomp $set;
                # log_data の [5]=HOST, [6]=IP, [8]=UA, [9]=SID
                $set .= '<>' . join('<>', 
                    ($log_data[5]//''), 
                    ($log_data[6]//''), 
                    ($log_data[8]//''), 
                    ($log_data[9]//'')
                );
            }
            push @$pResultSet, $set;
        }elsif($type_check == 16 && $i){
			# スレタイ検索のみなら2ループ目で抜ける
			last;
		}
    }

    $DAT->Close;
    $LOG->Close;
}

sub SearchOld
{
	my $this = shift;
	my ($word) = @_;
   
	my $bbsID = $this->{'SYS'}->Get('BBS_ID');
	my $bbs = $this->{'SYS'}->Get('BBS');
	my $key = $this->{'SYS'}->Get('KEY');
	my $Path = $this->{'SYS'}->Get('BBSPATH') . "/$bbs/dat/$key.dat";
	my $DAT = $this->{'DAT'};

	if($word =~ /(\p{Zs}+)/ && $word !~ /(\.|\?|\*|\/|\(|\)|\||\{|\}|\[|\]|\=|\^|\$)/){
		my @words = split(/\p{Zs}+/,$word);
		$word = "";
		foreach my $and(@words){
			$word .= "(?=.*$and)";
		}
		$word = '^'.$word.'.*$';
	}

	if ($DAT->Load($this->{'SYS'}, $Path, 1)) {
		my $pResultSet = $this->{'RESULTSET'};
		my $type = $this->{'TYPE_C'} || 31;
	   
		# すべてのレス数でループ
		for (my $i = 0 ; $i < $DAT->Size() ; $i++) {
			my $bFind = 0;
			my $pDat = $DAT->Get($i);
			my @elem = split(/<>/, $$pDat, -1);
		   
		   	# スレタイ検索
			if (!$i && $type & 8) {
				my $sub = $elem[4];
				chomp $sub;
				if ($sub =~ s/($word)(?![^<>]*>)/<span class="res">$1<\/span> /g) {
					$bFind = 1;
				}
			}

			# スレタイ検索のみだったら飛ばす
			unless ($type == 8){
				# 名前検索
				if ($type & 1) {
					if ($elem[0] =~ s/($word)(?![^<>]*>)/<span class="res">$1<\/span> /g) {
						$bFind = 1;
					}
				}
				# 本文検索
				if ($type & 2) {
					if ($elem[3] =~ s/($word)(?![^<>]*>)/<span class="res">$1<\/span> /g) {
						$bFind = 1;
					}
				}
				# ID or 日付検索
				if ($type & 4) {
					if ($elem[2] =~ s/($word)(?![^<>]*>)/<span class="res">$1<\/span> /g) {
						$bFind = 1;
					}
				}
				# メール欄検索
				if ($type & 16) {
					if ($elem[1] =~ s/($word)(?![^<>]*>)/<span class="res">$1<\/span> /g) {
						$bFind = 1;
					}
				}
			}
			if ($bFind) {
				my $SetStr = "$bbsID<>$key<>" . ($i + 1) . '<>';
				$SetStr .= join('<>', @elem);
				push @$pResultSet, $SetStr;
			}
			last if $type == 8;
		}
	}
	$DAT->Close();
}
sub LogSearch
{
	my $this = shift;
	my ($ip_addr,$host,$ua,$sid) = @_;
   
	my $bbsID = $this->{'SYS'}->Get('BBS_ID');
	my $bbs = $this->{'SYS'}->Get('BBS');
	my $key = $this->{'SYS'}->Get('KEY');
	my $Path = $this->{'SYS'}->Get('BBSPATH') . "/$bbs/dat/$key.dat";
	my $DAT = $this->{'DAT'};
	my $LOG = $this->{'LOG'};
	my $Sys = $this->{'SYS'};

	my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $Sys->Get('KEY');
	$LOG->Open($logPath, 0, 1 | 2);
	$DAT->Load($this->{'SYS'}, $Path, 1);
	my $datsize = $DAT->Size();
	my $logsize = $LOG->Size();

	my $base_offset = $logsize - $datsize;
	if($logsize){
		my $pResultSet = $this->{'RESULTSET'};
		if($datsize){
			for (my $i = 0; $i < $logsize; $i++) {
				my $offset = $base_offset;
				my $match_count = 0;
				my $condition_count = 0;
				my @data;
				my $log = "";
				my $pRes	= $DAT->Get($i);
				next unless defined $pRes;
				my @elem	= split(/<>/, $$pRes,-1);
				
				for my $d (0, 1, -1, 2, 3, -2, -3) {
					my $idx = $offset + $i + $d;
					next if $idx < 0 || $idx >= $logsize;
					
					$log = $LOG->Get($offset + $d + $i);
					@data = split(/<>/, $log, -1) if (defined $log);
					if (defined $log && $data[2] eq $elem[2]) {
						# ログとレスが一致
						$offset += $d;
						last;
					}
					$log = undef;
					@data = ();
				}
				my ($log_ip, $log_host, $log_ua) = ($data[6], $data[5], $data[8]);
				my $log_sid = defined $data[9] ? $data[9] : '';

				if ($ip_addr) {
					$condition_count++;
					if ($log_ip =~ /$ip_addr/) {
						$match_count++;
					}
				}
				if ($host) {
					$condition_count++;
					if ($log_host =~ /$host/) {
						$match_count++;
					}
				}
				if ($ua) {
					$condition_count++;
					if ($log_ua =~ m{\Q$ua\E}) {
						$match_count++;
					}
				}
				if ($sid) {
					$condition_count++;
					if ($log_sid eq $sid) {
						$match_count++;
					}
				}

				if ($match_count == $condition_count) {
					my $SetStr = "$bbsID<>$key<>" . ($i + 1) . '<>';
					if(defined $pRes){
						$SetStr .= $$pRes;
						if(defined $log){
							chomp ($SetStr);
							$SetStr .= "<>$log_host<>$log_ip<>$log_ua<>$log_sid";
						}
						push @$pResultSet, $SetStr;
					}
				}
			}
			$DAT->Close();
		}
	}
}
sub NinSearch
{
	my $this = shift;
	my ($key, $word, $sid) = @_;
	my $ninDir = ".".$this->{'SYS'}->Get('INFO')."/.ninpocho/";
	my $pResultSet = $this->{'RESULTSET'};

	if($sid){
		if(length($sid) == 32){
			my $set = glob($ninDir.'cgisess_'.$sid);
			$set =~ s/${ninDir}cgisess_//m;
			@$pResultSet = $set;            
		}else{
			my $allSid = [];
			@$allSid = sort { (stat($b))[9] <=> (stat($a))[9] } glob($ninDir.'cgisess_*');
			foreach my $id (@$allSid){
				$id =~ s/${ninDir}cgisess_//m;
				if(crypt($id,$id) eq $sid){
					push @$pResultSet,$id;
				}
			}
		}
	}else{
		my $allSid = [];
		@$allSid = sort { (stat($b))[9] <=> (stat($a))[9] } glob($ninDir.'cgisess_*');
		if($key){
			require './module/ninpocho.pl';
			my $Ninja = NINPOCHO->new;
			foreach my $id (@$allSid){
				$id =~ s/${ninDir}cgisess_//m;
				$Ninja->LoadOnly($this->{'SYS'},$id);
				if($Ninja->Get($key) =~ /\Q$word\E/i){
					push @$pResultSet,$id;
				}
			}
		}
	}
	return $pResultSet;
}
#============================================================================================================
#   Module END
#============================================================================================================
1;
