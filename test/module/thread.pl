#============================================================================================================
#
#	スレッド情報管理モジュール
#	-------------------------------------------------------------------------------------
#	このモジュールはスレッド情報を管理します。
#	以下の2つのパッケージによって構成されます
#
#	THREAD	: 現行スレッド情報管理
#	POOL_THREAD	: プールスレッド情報管理
#
#============================================================================================================

#============================================================================================================
#
#	スレッド情報管理パッケージ
#
#============================================================================================================
package	THREAD;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use Storable qw(lock_store lock_retrieve);

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
		'SUBJECT'	=> undef,
		'RES'		=> undef,
		'SORT'		=> undef,
		'NUM'		=> undef,
		'HANDLE'	=> undef,
		'ATTR'		=> undef,
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
	
	my $handle = $this->{'HANDLE'};
	if ($handle) {
		close($handle);
	}
	$this->{'HANDLE'} = undef;
}

#------------------------------------------------------------------------------------------------------------
#
#	オープン
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	ファイルハンドル
#
#------------------------------------------------------------------------------------------------------------
sub Open
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/subject.txt';
	my $fh = undef;
	
	if ($this->{'HANDLE'}) {
		$fh = $this->{'HANDLE'};
		seek($fh, 0, 0);
	}
	else {
		chmod($Sys->Get('PM-TXT'), $path);
		if (open($fh, (-f $path ? '+<' : '>'), $path)) {
			flock($fh, 2);
			#binmode($fh);
			seek($fh, 0, 0);
			$this->{'HANDLE'} = $fh;
		}
		else {
			warn "can't load subject: $path";
		}
	}
	
	return $fh;
}

#------------------------------------------------------------------------------------------------------------
#
#	強制クローズ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Close
{
	my $this = shift;
	
	my $handle = $this->{'HANDLE'};
	if ($handle) {
		close($handle);
	}
	$this->{'HANDLE'} = undef;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'SUBJECT'} = {};
	$this->{'RES'} = {};
	$this->{'SORT'} = [];
	
	my $fh = $this->Open($Sys) or return;
	my @lines = <$fh>;
	map { s/[\r\n]+\z// } @lines;
	
	my $num = 0;
	foreach (@lines) {
		next if ($_ eq '');
		
		if ($_ =~ /^(.+?)\.dat<>(.*?) ?\(([0-9]+)\)$/) {
			$this->{'SUBJECT'}->{$1} = $2;
			$this->{'RES'}->{$1} = $3;
			push @{$this->{'SORT'}}, $1;
			$num++;
		}
		else {
			warn "invalid line";
			next;
		}
	}
	$this->{'NUM'} = $num;
	
	$this->LoadAttr($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $fh = $this->Open($Sys) or return;
	my $subject = $this->{'SUBJECT'};
	
	$this->CustomizeOrder();
	
	foreach (@{$this->{'SORT'}}) {
		next if (!defined $subject->{$_});
		print $fh "$_.dat<>$subject->{$_} ($this->{'RES'}->{$_})\n";
	}
	
	truncate($fh, tell($fh));
	
	$this->Close();
	my $path = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/subject.txt';
	chmod($Sys->Get('PM-TXT'), $path);
	
	$this->SaveAttr($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	オンデマンド式レス数更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$id		スレッドID
#	@param	$val	レス数
#	@param	$updown	'', 'top', 'bottom', '+n', '-n'
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub OnDemand
{
	my $this = shift;
	my ($Sys, $id, $val, $updown) = @_;
	
	my $subject = {};
	$this->{'SUBJECT'} = $subject;
	$this->{'RES'} = {};
	$this->{'SORT'} = [];
	
	my $fh = $this->Open($Sys) or return;
	my @lines = <$fh>;
	map { s/[\r\n]+\z// } @lines;
	
	my $num = 0;
	foreach (@lines) {
		next if ($_ eq '');
		
		if ($_ =~ /^(.+?)\.dat<>(.*?) ?\(([0-9]+)\)$/) {
			$subject->{$1} = $2;
			$this->{'RES'}->{$1} = $3;
			push @{$this->{'SORT'}}, $1;
			$num++;
		}
		else {
			warn "invalid line";
			next;
		}
	}
	$this->{'NUM'} = $num;
	
	# レス数更新
	if (exists $this->{'RES'}->{$id}) {
		$this->{'RES'}->{$id} = $val;
	}
	
	# スレッド移動
	if ($updown eq 'top') {
		$this->AGE($id);
	} elsif ($updown eq 'bottom') {
		$this->DAME($id);
	} elsif ($updown eq 'age') {
		$this->UpDown($id, 1);
	} elsif ($updown eq 'sink') {
		$this->UpDown($id, -1);
	} elsif ($updown =~ /^([\+\-][0-9]+)$/) {
		$this->UpDown($id, int($1));
	}
	
	$this->CustomizeOrder();
	
	# subject書き込み
	seek($fh, 0, 0);
	
	foreach (@{$this->{'SORT'}}) {
		next if (!defined $subject->{$_});
		print $fh "$_.dat<>$subject->{$_} ($this->{'RES'}->{$_})\n";
	}
	
	truncate($fh, tell($fh));
	
	$this->Close();
	my $path = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/subject.txt';
	chmod($Sys->Get('PM-TXT'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドIDセット取得
#	-------------------------------------------------------------------------------------
#	@param	$kind	検索種別('ALL'の場合すべて)
#	@param	$name	検索ワード
#	@param	$pBuf	IDセット格納バッファ
#	@return	キーセット数
#
#------------------------------------------------------------------------------------------------------------
sub GetKeySet
{
	my $this = shift;
	my ($kind, $name, $pBuf) = @_;
	
	my $n = 0;
	
	if ($kind eq 'ALL') {
		$n += push @$pBuf, @{$this->{'SORT'}};
	}
	else {
		foreach my $key (keys %{$this->{$kind}}) {
			if ($this->{$kind}->{$key} eq $name || $kind eq 'ALL') {
				$n += push @$pBuf, $key;
			}
		}
	}
	
	return $n;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報取得
#	-------------------------------------------------------------------------------------
#	@param	$kind		情報種別
#	@param	$key		スレッドID
#	@param	$default	デフォルト
#	@return	スレッド情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($kind, $key, $default) = @_;
	
	my $val = $this->{$kind}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報追加
#	-------------------------------------------------------------------------------------
#	@param	$id			スレッドID
#	@param	$subject	スレッドタイトル
#	@param	$res		レス
#	@return	スレッドID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($id, $subject, $res) = @_;
	
	$this->{'SUBJECT'}->{$id} = $subject;
	$this->{'RES'}->{$id} = $res;
	unshift @{$this->{'SORT'}}, $id;
	$this->{'NUM'}++;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		スレッドID
#	@param	$kind	情報種別
#	@param	$val	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($id, $kind, $val) = @_;
	
	if (defined $id && exists $this->{$kind}->{$id}) {
		$this->{$kind}->{$id} = $val;
	}else{
		$this->{$kind} = $val;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除スレッドID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'SUBJECT'}->{$id};
	delete $this->{'RES'}->{$id};
	# for pool
	#delete $this->{'ATTR'}->{$id};
	
	my $sort = $this->{'SORT'};
	for (my $i = 0; $i < scalar(@$sort); $i++) {
		if ($id eq $sort->[$i]) {
			splice @$sort, $i, 1;
			$this->{'NUM'}--;
			last;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド属性情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub LoadAttr
{
	my $this = shift;
	my ($Sys,$threadID) = @_;

	$threadID //= $Sys->Get('KEY');
	my $attr = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/info';
	
	require './module/file_utils.pl';
	FILE_UTILS::CreateDirectory("$attr/attr", $Sys->Get('PM-ADIR'));	# 無かったら作成

	my $path = $attr . '/attr.cgi';	# 旧仕様の属性ファイル
	my $AttrPath = $attr . "/attr/attr_$threadID.cgi";
	
	if (-e $path) {
		# 旧ファイルが残ってる場合、移行
		open(my $fh, '<', $path);
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);       
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '');
			
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 2) {
				warn "invalid line in $path";
				next;
			}
			
			my $id = $elem[0];
			# for pool, don't skip
			#next if (!defined $this->{'SUBJECT'}->{$id});
			
			my $hash = {};
			foreach (split /[&;]/, $elem[1]) {
				my ($key, $val) = split(/=/, $_, 2);
				$key =~ tr/+/ /;
				$key =~ s/%([0-9a-f][0-9a-f])/pack('C', hex($1))/egi;
				$val =~ tr/+/ /;
				$val =~ s/%([0-9a-f][0-9a-f])/pack('C', hex($1))/egi;
				$hash->{$key} = $val if ($val ne '');
			}
			
			$this->{'ATTR'}->{$id} = $hash;
		}

		# データ移行
		if ($this->{'ATTR'}) {
			foreach my $id (keys %{$this->{'ATTR'}}) {
				my $new_path = $attr . "/attr/attr_$id.cgi";
				
				# スレッドIDごとのファイルに保存
				eval {
					lock_store($this->{'ATTR'}->{$id}, $new_path);
				};
				if ($@) {
					warn "Failed to store data to $new_path: $@";
				}
			}
			
			# 移行が完了したら、旧ファイルを削除する
			unlink $path or warn "Failed to delete old file $path: $!";
		}
	}elsif(-e $AttrPath){
		# 新方式
		eval {
			$this->{'ATTR'}->{$threadID} = lock_retrieve($AttrPath);
		};
		if ($@) {
			warn "Failed to retrieve data from $AttrPath: $@";
			$this->{'ATTR'}->{$threadID} = {};
		}
	} else {
		$this->{'ATTR'}->{$threadID} = {};  # ファイルが存在しない場合は空のデータ
	}
}

# 互換性維持のため(主にadmin.cgi用)
sub LoadAttrAll
{
    my $this = shift;
    my ($Sys) = @_;
    
    $this->{'ATTR'} = {};  # 属性データの初期化
    
    my $attr_dir = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/info/attr';
	require './module/file_utils.pl';
	FILE_UTILS::CreateDirectory("$attr_dir", $Sys->Get('PM-ADIR'));
    
    # attrディレクトリ内のすべての "attr_xxx.cgi" ファイルを探索
    opendir(my $dh, $attr_dir) or die "Could not open '$attr_dir' for reading: $!";
    my @files = grep { /^attr_.+\.cgi$/ && -f "$attr_dir/$_" } readdir($dh);
    closedir($dh);

    # 各ファイルからデータを読み込み
    foreach my $file (@files) {
        my $filepath = "$attr_dir/$file";
        my $thread_id = $file;
        $thread_id =~ s/^attr_//;  # "attr_"を削除
        $thread_id =~ s/\.cgi$//;  # 拡張子を削除
        
        eval {
            my $data = lock_retrieve($filepath);
            $this->{'ATTR'}->{$thread_id} = $data if defined $data;
        };
        if ($@) {
            warn "Failed to retrieve data from $filepath: $@";
        }
    }
}
#------------------------------------------------------------------------------------------------------------
#
#	スレッド属性情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SaveAttr
{
    my $this = shift;
    my ($Sys,$threadID) = @_;

    $threadID //= $Sys->Get('KEY');

	my $AttrPath = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . "/info/attr/attr_$threadID.cgi";

    # データをファイルに保存
    eval {
        lock_store($this->{'ATTR'}->{$threadID}, $AttrPath);
    };
    if ($@) {
        warn "Failed to store data to $AttrPath: $@";
    }

    # ファイルの権限を設定
    chmod($Sys->Get('PM-ADM'), $AttrPath);
}

# 互換性維持のため(主にadmin.cgi用)
sub SaveAttrAll
{
    my $this = shift;
    my ($Sys) = @_;
    
    # 属性データが存在しない場合は何もしない
    return unless defined $this->{'ATTR'} && ref($this->{'ATTR'}) eq 'HASH';

    my $attr_dir = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/attr';

    # ディレクトリが存在しない場合は作成
    unless (-d $attr_dir) {
        mkdir $attr_dir or die "Could not create directory '$attr_dir': $!";
    }

    # 各スレッドIDに対応する属性データを保存
    foreach my $thread_id (keys %{$this->{'ATTR'}}) {
        my $AttrPath = "$attr_dir/attr_$thread_id.cgi";
        
        # データをファイルに保存
        eval {
            lock_store($this->{'ATTR'}->{$thread_id}, $AttrPath);
        };
        if ($@) {
            warn "Failed to store data to $AttrPath: $@";
        }

        # ファイルの権限を設定
        chmod($Sys->Get('PM-ADM'), $AttrPath);
    }
}

#------------------------------------------------------------------------------------------------------------
#
#   スレッド属性情報取得
#   -------------------------------------------------------------------------------------
#   @param  $key        スレッドID
#   @param  @attrs      属性名のリスト
#   @return スレッド属性情報（スカラー値またはハッシュリファレンス）
#
#------------------------------------------------------------------------------------------------------------
sub GetAttr
{
    my $this = shift;
    my $key = shift;
    my @attrs = @_;
    
    # スレッド属性データがロードされていない場合
    unless (defined $this->{'ATTR'}->{$key}) {
        #warn "Attr info for thread '$key' is not loaded.";
        return undef;
    }
    
    my $ref = $this->{'ATTR'}->{$key};
    
    # 属性が指定されていない場合は、すべての属性を返す
    if (!@attrs) {
        return $ref;
    }
    
    # 属性を順に辿って値を取得
    foreach my $attr (@attrs) {
        if (ref($ref) eq 'HASH' && exists $ref->{$attr}) {
            $ref = $ref->{$attr};
        } else {
            # 属性が存在しない、またはハッシュでない場合はundefを返す
            return undef;
        }
    }
    
    # 最終的な値を返す（スカラー値またはハッシュリファレンス）
    return $ref;
}


#------------------------------------------------------------------------------------------------------------
#
#   スレッド属性情報設定
#   -------------------------------------------------------------------------------------
#   @param  $key        スレッドID
#   @param  @args       属性名のリスト（最後の引数が値）
#
#------------------------------------------------------------------------------------------------------------
sub SetAttr
{
    my $this = shift;
    my $key = shift;
    my @args = @_;
    
    # スレッド属性データがロードされていない場合
    unless (defined $this->{'ATTR'}->{$key}) {
        #warn "Attr info for thread '$key' is not loaded.";
        return;
    }
    
    # 引数が1つの場合は、スレッド全体の属性を置き換える
    if (@args == 1) {
        my $val = $args[0];
        $this->{'ATTR'}->{$key} = $val;
        return;
    }
    
    # 最後の引数を値として取得
    my $val = pop @args;
    my $ref = $this->{'ATTR'}->{$key};
    
    # 属性を順に辿って値を設定
    for my $attr (@args[0 .. $#args - 1]) {
        # ハッシュが存在しない場合は新規作成
        if (!exists $ref->{$attr} || ref($ref->{$attr}) ne 'HASH') {
            $ref->{$attr} = {};
        }
        $ref = $ref->{$attr};
    }
    
    # 最後の属性に値を設定
    my $last_attr = $args[-1];
    $ref->{$last_attr} = $val;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド属性情全削除
#	-------------------------------------------------------------------------------------
#	@param	$key		スレッドID
#
#------------------------------------------------------------------------------------------------------------
sub DeleteAttr
{
    my $this = shift;
    my ($key) = @_;
    
    if (!defined $this->{'ATTR'}->{$key}) {
        warn "Attr info is not loaded.";
        return;
    }
    delete $this->{'ATTR'}->{$key};
}


#------------------------------------------------------------------------------------------------------------
#
#	スレッド数取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	スレッド数
#
#------------------------------------------------------------------------------------------------------------
sub GetNum
{
	my $this = shift;
	
	return $this->{'NUM'};
}

#------------------------------------------------------------------------------------------------------------
#
#	最後のスレッドID取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	スレッドID
#
#------------------------------------------------------------------------------------------------------------
sub GetLastID
{
	my $this = shift;
	
	my $sort = $this->{'SORT'};
	return $sort->[$#$sort];
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド順調整
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub CustomizeOrder
{
	my $this = shift;
	
	my @float = ();
	my @sort = ();
	
	foreach my $id (@{$this->{'SORT'}}) {
		if ($this->GetAttr($id, 'float')) {
			push @float, $id;
		} else {
			push @sort, $id;
		}
	}
	
	$this->{'SORT'} = [@float, @sort];
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドあげ
#	-------------------------------------------------------------------------------------
#	@param	スレッドID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub AGE
{
	my $this = shift;
	my ($id) = @_;
	
	my $sort = $this->{'SORT'};
	for (my $i = 0; $i < scalar(@$sort); $i++) {
		if ($id eq $sort->[$i]) {
			splice @$sort, $i, 1;
			unshift @$sort, $id;
			last;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドだめ
#	-------------------------------------------------------------------------------------
#	@param	スレッドID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DAME
{
	my $this = shift;
	my ($id) = @_;
	
	my $sort = $this->{'SORT'};
	for (my $i = 0; $i < scalar(@$sort); $i++) {
		if ($id eq $sort->[$i]) {
			splice @$sort, $i, 1;
			push @$sort, $id;
			last;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド移動
#	-------------------------------------------------------------------------------------
#	@param	$id	スレッドID
#	@param	$n	移動数(+上げ -下げ)
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub UpDown
{
	my $this = shift;
	my ($id, $n) = @_;
	
	my $sort = $this->{'SORT'};
	my $max = scalar(@$sort);
	for (my $i = 0; $i < $max; $i++) {
		if ($id eq $sort->[$i]) {
			my $to = $i - $n;
			$to = 0 if ($to < 0);
			$to = $max-1 if ($to > $max-1);
			splice @$sort, $i, 1;
			splice @$sort, $to, 0, $id;
			last;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Update
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $base = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat';
	
	$this->CustomizeOrder();
	
	foreach my $id (@{$this->{'SORT'}}) {
		if (open(my $fh, '<', "$base/$id.dat")) {
			flock($fh, 2);
			my $n = 0;
			$n++ while (<$fh>);
			close($fh);
			$this->{'RES'}->{$id} = $n;
		}
		else {
			warn "can't open file: $base/$id.dat";
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報完全更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub UpdateAll
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $psort = $this->{'SORT'};
	$this->{'SORT'} = [];
	$this->{'SUBJECT'} = {};
	$this->{'RES'} = {};
	my $idhash = {};
	my @dirSet = ();
	
	my $base = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat';
	my $num	= 0;
	
	# ディレクトリ内一覧を取得
	if (opendir(my $fh, $base)) {
		@dirSet = readdir($fh);
		closedir($fh);
	}
	else {
		warn "can't open dir: $base";
		return;
	}
	
	foreach my $el (@dirSet) {
		if ($el =~ /^(.*)\.dat$/ && open(my $fh, '<', "$base/$el")) {
			flock($fh, 2);
			my $id = $1;
			my $n = 1;
			my $first = <$fh>;
			$n++ while (<$fh>);
			close($fh);
			$first =~ s/[\r\n]+\z//;
			
			my @elem = split(/<>/, $first, -1);
			$this->{'SUBJECT'}->{$id} = $elem[4];
			$this->{'RES'}->{$id} = $n;
			$idhash->{$id} = 1;
			$num++;
		}
	}
	$this->{'NUM'} = $num;
	
	foreach my $id (@$psort) {
		if (defined $idhash->{$id}) {
			push @{$this->{'SORT'}}, $id;
			delete $idhash->{$id};
		}
	}
	foreach my $id (sort keys %$idhash) {
		unshift @{$this->{'SORT'}}, $id;
	}
	
	$this->CustomizeOrder();
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド位置取得
#	-------------------------------------------------------------------------------------
#	@param	$id	スレッドID
#	@return	スレッド位置。取得できない場合は-1
#
#------------------------------------------------------------------------------------------------------------
sub GetPosition
{
	my $this = shift;
	my ($id) = @_;
	
	my $sort = $this->{'SORT'};
	for (my $i = 0; $i < scalar(@$sort); $i++) {
		if ($id eq $sort->[$i]) {
			return $i;
		}
	}
	
	return -1;
}


#============================================================================================================
#
#	プールスレッド情報管理パッケージ
#
#============================================================================================================
package	POOL_THREAD;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

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
		'SUBJECT'	=> undef,
		'RES'		=> undef,
		'SORT'		=> undef,
		'NUM'		=> undef,
		'ATTR'		=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'SUBJECT'} = {};
	$this->{'RES'} = {};
	$this->{'SORT'} = [];
	
	my $path = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/pool/subject.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		my $num = 0;
		for (@lines) {
			next if ($_ eq '');
			
			if ($_ =~ /^(.+?)\.dat<>(.*?) ?\(([0-9]+)\)$/) {
				$this->{'SUBJECT'}->{$1} = $2;
				$this->{'RES'}->{$1} = $3;
				push @{$this->{'SORT'}}, $1;
				$num++;
			}
			else {
				warn "invalid line in $path";
				next;
			}
		}
		$this->{'NUM'} = $num;
	}
	
	$this->LoadAttr($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' .$Sys->Get('BBS') . '/pool/subject.cgi';
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		my $subject = $this->{'SUBJECT'};
		foreach (@{$this->{'SORT'}}) {
			next if (!defined $subject->{$_});
			print $fh "$_.dat<>$subject->{$_} ($this->{'RES'}->{$_})\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	else {
		warn "can't save subject: $path";
	}
	chmod($Sys->Get('PM-ADM'), $path);
	
	$this->SaveAttr($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドIDセット取得
#	-------------------------------------------------------------------------------------
#	@param	$kind	検索種別('ALL'の場合すべて)
#	@param	$name	検索ワード
#	@param	$pBuf	IDセット格納バッファ
#	@return	キーセット数
#
#------------------------------------------------------------------------------------------------------------
sub GetKeySet
{
	my $this = shift;
	my ($kind, $name, $pBuf) = @_;
	
	my $n = 0;
	
	if ($kind eq 'ALL') {
		$n += push @$pBuf, @{$this->{'SORT'}};
	}
	else {
		foreach my $key (keys %{$this->{$kind}}) {
			if ($this->{$kind}->{$key} eq $name || $kind eq 'ALL') {
				$n += push @$pBuf, $key;
			}
		}
	}
	
	return $n;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報取得
#	-------------------------------------------------------------------------------------
#	@param	$kind		情報種別
#	@param	$key		スレッドID
#	@param	$default	デフォルト
#	@return	スレッド情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($kind, $key, $default) = @_;
	
	my $val = $this->{$kind}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報追加
#	-------------------------------------------------------------------------------------
#	@param	$id			スレッドID
#	@param	$subject	スレッドタイトル
#	@param	$res		レス
#	@return	スレッドID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($id, $subject, $res) = @_;
	
	$this->{'SUBJECT'}->{$id} = $subject;
	$this->{'RES'}->{$id} = $res;
	unshift @{$this->{'SORT'}}, $id;
	$this->{'NUM'}++;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		スレッドID
#	@param	$kind	情報種別
#	@param	$val	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($id, $kind, $val) = @_;
	
	if (exists $this->{$kind}->{$id}) {
		$this->{$kind}->{$id} = $val;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除スレッドID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'SUBJECT'}->{$id};
	delete $this->{'RES'}->{$id};
	
	my $sort = $this->{'SORT'};
	for (my $i = 0; $i < scalar(@$sort); $i++) {
		if ($id eq $sort->[$i]) {
			splice @$sort, $i, 1;
			$this->{'NUM'}--;
			last;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド数取得
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	スレッド数
#
#------------------------------------------------------------------------------------------------------------
sub GetNum
{
	my $this = shift;
	
	return $this->{'NUM'};
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド属性情報関連
#
#------------------------------------------------------------------------------------------------------------
sub LoadAttr
{
	return THREAD::LoadAttr(@_);
}

sub SaveAttr
{
	return THREAD::SaveAttr(@_);
}

sub GetAttr
{
	return THREAD::GetAttr(@_);
}

sub SetAttr
{
	return THREAD::SetAttr(@_);
}

sub DeleteAttr
{
	return THREAD::DeleteAttr(@_);
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Update
{
	my $this = shift;
	my ($Sys) = @_;
	my ($id, $base, $n);
	
	$base = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/pool';
	
	foreach my $id (@{$this->{'SORT'}}) {
		if (open(my $fh, '<', "$base/$id.cgi")) {
			flock($fh, 2);
			my $n = 0;
			$n++ while (<$fh>);
			close($fh);
			$this->{'RES'}->{$id} = $n;
		}
		else {
			warn "can't open file: $base/$id.dat";
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッド情報完全更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub UpdateAll
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'SORT'} = [];
	$this->{'SUBJECT'} = {};
	$this->{'RES'} = {};
	my @dirSet = ();
	
	my $base = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/pool';
	my $num = 0;
	
	# ディレクトリ内一覧を取得
	if (opendir(my $fh, $base)) {
		@dirSet = readdir($fh);
		closedir($fh);
	}
	else {
		warn "can't open dir: $base";
		return;
	}
	
	foreach my $el (@dirSet) {
		if ($el =~ /^(.*)\.cgi$/ && open(my $fh, '<', "$base/$el")) {
			flock($fh, 2);
			my $id = $1;
			my $n = 1;
			my $first = <$fh>;
			$n++ while (<$fh>);
			close($fh);
			$first =~ s/[\r\n]+\z//;
			
			my @elem = split(/<>/, $first, -1);
			$this->{'SUBJECT'}->{$id} = $elem[4];
			$this->{'RES'}->{$id} = $n;
			push @{$this->{'SORT'}}, $id;
			$num++;
		}
	}
	$this->{'NUM'} = $num;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
