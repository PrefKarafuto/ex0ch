#============================================================================================================
#
#	ログ管理モジュール
#	--------------------------------------
#	Modeのビットについて
#	0:読取専用
#	1:オープンと同時に内容読み込み
#	2:最大サイズを超えたログを保存
#	3～:未使用
#
#============================================================================================================
package	LOG;
use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	$file	ログファイルパス(拡張子除く)
#	@param	$limit	ログ最大サイズ
#	@param	$mode	モード
#	@return	モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my ($file, $limit, $mode) = @_;
	
	my $obj = {
		'PATH'		=> $file,
		'LIMIT'		=> $limit,
		'MODE'		=> $mode,
		'STAT'		=> 0,
		'HANDLE'	=> undef,
		'LOGS'		=> undef,
		'SIZE'		=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	デストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DESTROY
{
	my $this = shift;
	
	$this->Close;
}

#------------------------------------------------------------------------------------------------------------
#
#	ログオープン
#	-------------------------------------------------------------------------------------
#	@param	$file	ログファイルパス(拡張子除く)
#	@param	$limit	ログ最大サイズ
#	@param	$mode	モード
#	@return	成功:0,失敗:-1
#
#------------------------------------------------------------------------------------------------------------
sub Open
{
	my $this = shift;
	my ($file, $limit, $mode) = @_;
	
	if (defined $file && defined $limit && defined $mode) {
		$this->{'PATH'} = $file;
		$this->{'LIMIT'} = $limit;
		$this->{'MODE'} = $mode;
	}
	else {
		$file = $this->{'PATH'};
		$limit = int $this->{'LIMIT'};
		$mode = int $this->{'MODE'};
	}
	
	$this->Close;
	
	my $ret = -1;
	
	if (!$this->{'STAT'}) {
		$file .= '.cgi';
		if (open(my $fh, (-f $file ? '+<' : '>'), $file)) {
			flock($fh, 2);
			seek($fh, 0, 2);
			#binmode($fh);
			
			$this->{'HANDLE'} = $fh;
			$this->{'STAT'} = 1;
			$ret = ($mode & 2 ? $this->Read() : 0);
		}
		else {
			warn "can't open log: $file";
		}
	}
	
	return $ret;
}

#------------------------------------------------------------------------------------------------------------
#
#	ログクローズ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Close
{
	my $this = shift;
	
	if ($this->{'STAT'}) {
		close($this->{'HANDLE'});
		$this->{'HANDLE'} = undef;
		$this->{'STAT'} = 0;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	読み込み
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	成功:0,失敗:-1
#
#------------------------------------------------------------------------------------------------------------
sub Read
{
	my $this = shift;
	
	if ($this->{'STAT'}) {
		my $fh = $this->{'HANDLE'};
		seek($fh, 0, 0);
		
		my @lines = <$fh>;
		map { s/[\r\n]+\z// } @lines;
		
		$this->{'LOGS'} = \@lines;
		$this->{'SIZE'} = scalar(@lines);
		return 0;
	}
	
	return -1;
}

#------------------------------------------------------------------------------------------------------------
#
#	書き込み
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Write
{
	my $this = shift;
	
	# ファイルオープン状態なら書き込みを実行する
	if ($this->{'STAT'}) {
		if (!($this->{'MODE'} & 1)) {
			my $fh = $this->{'HANDLE'};
			seek($fh, 0, 0);
			
			for (my $i = 0 ; $i < $this->{'SIZE'} ; $i++) {
				print $fh "$this->{'LOGS'}->[$i]\n";
			}
			
			truncate($fh, tell($fh));
		}
		$this->Close();
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	データ取得
#	-------------------------------------------------------------------------------------
#	@param	$line	取得データ行
#	@return	取得データ
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($line) = @_;
	
	if ($line >= 0 && $line < $this->{'SIZE'}) {
		return $this->{'LOGS'}->[$line];
	}
	return undef;
}

#------------------------------------------------------------------------------------------------------------
#
#	データ追加
#	-------------------------------------------------------------------------------------
#	@param	$pData	追加データ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Put {
    my $this = shift;
    my (@datas) = @_;

    my $tm = time;
    my $logData = join('<>', $tm, @datas);
    my @time = localtime($tm);
    $time[5] += 1900;
    $time[4] += 1;

    push @{$this->{'LOGS'}}, $logData;
    $this->{'SIZE'}++;

    if ($this->{'SIZE'} > $this->{'LIMIT'}) {
        # ディレクトリの存在確認と作成
        unless (-d $this->{'PATH'}) {
            mkdir($this->{'PATH'}, 0700) or die "ディレクトリを作成できません: $!";
        }

        # 年と月をフォーマットしてファイル名を生成
        my $year  = $time[5];
        my $month = sprintf("%02d", $time[4]);
        my $logName = "$this->{'PATH'}/${year}_${month}.cgi";

        # ファイルを開く
        open(my $fh, '>>', $logName) or die "ファイルを開けません: $!";
        flock($fh, 2); # 排他的ロック

        # サイズがリミットを超えている場合、古いログを削除
        while ($this->{'SIZE'} > $this->{'LIMIT'}) {
            my $old = shift @{$this->{'LOGS'}};
            $this->{'SIZE'}--;
            if ($this->{'MODE'} & 4) {
                print $fh "$old\n";
            }
        }
        close($fh);
    }
}


#------------------------------------------------------------------------------------------------------------
#
#	サイズ取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	サイズ
#
#------------------------------------------------------------------------------------------------------------
sub Size
{
	my $this = shift;
	return $this->{'SIZE'};
}

#------------------------------------------------------------------------------------------------------------
#
#	ログ退避
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub MoveToOld
{
	my $this = shift;
	my @time=localtime;
	$time[5] += 1900;
	$time[4] ++;
	my $logName = "$this->{'PATH'}/$time[5]\_$time[4].cgi";
	mkdir ($this->{'PATH'},0600);
	if (open(my $fh, '>>', $logName)) {
		flock($fh, 2);
		#binmode($fh);
		for(my $i = 0 ; $i < $this->{'SIZE'} ; $i++) {
			print $fh "$this->{'LOGS'}->[$i]\n";
		}
		close($fh);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ログクリア
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Clear
{
	my $this = shift;
	
	$this->{'LOGS'} = [];
	$this->{'SIZE'} = 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	検索
#	-------------------------------------------------------------------------------------
#	@param	$index		検索要素のインデクス
#	@param	$word		検索データ
#	@param	$pResult	結果格納用配列の参照
#	@return	ヒット数
#
#------------------------------------------------------------------------------------------------------------
sub search
{
	my $this = shift;
	my ($index, $word, $pResult) = @_;
	
	my $num = 0;
	for(my $i = 0 ; $i < $this->{'SIZE'} ; $i++) {
		my @elem = split(/<>/, $this->{'LOGS'}->[$i], -1);
		if ($elem[$index] eq $word) {
			push @$pResult, $this->{'LOGS'}->[$i];
			$num++;
		}
	}
	return $num;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
