#============================================================================================================
#
#	アクセスユーザ管理モジュール
#
#============================================================================================================
package	USER;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use Time::Local qw(timelocal);

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
		'TYPE'		=> undef,
		'METHOD'	=> undef,
		'USER'		=> undef,
		'SYS'		=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザデータ読み込み - Load
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：正常読み込み:0,エラー:1
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'SYS'} = $Sys;
	$this->{'USER'} = [];
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . "/info/access.cgi";
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @datas = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @datas;
		
		my @head = split(/<>/, shift(@datas), -1);
		$this->{'TYPE'} = $head[0];
		$this->{'METHOD'} = $head[1];
		
		push @{$this->{'USER'}}, @datas;
		return 0;
	}
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザデータ書き込み - Save
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：正常書き込み:0,エラー:-1
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . "/info/access.cgi";
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		print $fh "$this->{'TYPE'}<>$this->{'METHOD'}\n";
		foreach (@{$this->{'USER'}}) {
			print $fh "$_\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $path);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ追加 - Set
#	-------------------------------------------
#	引　数：$name : 追加ユーザ
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($name) = @_;
	
	push @{$this->{'USER'}}, $name;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザデータ取得 - Get
#	-------------------------------------------
#	引　数：$key : 取得キー
#			$default : デフォルト
#	戻り値：ユーザデータ
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($key, $default) = @_;
	
	my $val = $this->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザクリア - Clear
#	-------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Clear
{
	my $this = shift;
	
	$this->{'USER'} = [];
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザデータ設定 - SetData
#	-------------------------------------------
#	引　数：$key  : 設定キー
#			$data : 設定データ
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($key, $data) = @_;
	
	$this->{$key} = $data;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ調査 - Check
#	-------------------------------------------
#	引　数：$host : 調査ホスト
#			$addr : 調査IPアドレス
#			$koyuu : 端末固有識別子
#	戻り値：登録ユーザ:1,未登録ユーザ:0
#
#------------------------------------------------------------------------------------------------------------
sub ip_to_bin {
    my $ip = shift;
    return unpack("B*", pack("H*", join('', map { sprintf('%04x', hex($_)) } split(/:/, $ip))));
}

sub Check {
    my $this = shift;
    my ($host, $addr, $koyuu, $ua, $sid) = @_;

    require './module/data_utils.pl';
    my $Conv = DATA_UTILS->new;

    my $Sys = $this->{'SYS'};
    my $flag = 0;
    my $method = $this->{'METHOD'};
    my $adex_ipv4 = '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';
    my $adex_ipv6 = '([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}';
    my $adex = qr/$adex_ipv4|$adex_ipv6/;
    my $sid_regex = qr/^[0-9a-fA-F]{32}$/;

    my $addrb;
    if ($addr =~ /:/) {
        $addrb = ip_to_bin($Conv->expand_ipv6($addr));
    } else {
        $addrb = unpack('B32', pack('C*', split(/\./, $addr)));
    }

    foreach my $line (@{$this->{'USER'}}) {
        next if ($line =~ /^[#;]|^$/);    # コメント・空行はスキップ

        my %opt;
        # 行頭にオプション部分（例: !exdeny:...!）がある場合は抽出して削除する
        if ($line =~ s/^!exdeny:([^!]+)!//) {
            my $opt_str = $1;
            foreach (split(/&/, $opt_str)) {
                my ($key, $val) = split(/=/, $_, 2);
                $opt{$key} = $val;
            }
        }
        
        # スレ立て規制のチェック
        if ($opt{'tate'} && !$Sys->Equal('MODE', 1)) {
            next;
        }
        
        # 有効期限のチェック
        if ($opt{'expires'} && $opt{'expires'} =~ m|^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+):([0-9]+)$|) {
            my $expires = timelocal($6, $5, $4, $3, $2-1, $1);
            next if (time >= $expires);
        }
        
        # 規制方法指定のチェック
        if ($opt{'method'} && grep { $_ eq $opt{'method'} } qw(disable host)) {
            $method = $opt{'method'};
        }

        # IPアドレス/CIDRのチェック
        if ($line =~ m|^($adex)(?:/([0-9]+))?$|) {
            my ($ip_check, $length) = ($1, $2);
            $length ||= ($ip_check =~ /:/) ? 128 : 32;
            my $bin_check;
            if ($ip_check =~ /:/) {
                $bin_check = substr(ip_to_bin($Conv->expand_ipv6($ip_check)), 0, $length);
            } else {
                $bin_check = substr(unpack("B32", pack('C*', split(/\./, $ip_check))), 0, $length);
            }
            if (substr($addrb, 0, $length) eq $bin_check) {
                $flag = 1;
                $Sys->Set('HITS', $line);
                last;
            }
        }
        # IPアドレス範囲指定のチェック
        elsif ($line =~ m|^($adex)-($adex)$|) {
            my ($ip_start, $ip_end) = ($1, $2);
            my ($bin_start, $bin_end);
            if ($ip_start =~ /:/ && $ip_end =~ /:/) {
                $bin_start = ip_to_bin($Conv->expand_ipv6($ip_start));
                $bin_end   = ip_to_bin($Conv->expand_ipv6($ip_end));
            } else {
                $bin_start = unpack('B32', pack('C*', split(/\./, $ip_start)));
                $bin_end   = unpack('B32', pack('C*', split(/\./, $ip_end)));
            }
            ($bin_start, $bin_end) = ($bin_end, $bin_start) if $bin_start gt $bin_end;
            if ($addrb ge $bin_start && $addrb le $bin_end) {
                $flag = 1;
                $Sys->Set('HITS', $line);
                last;
            }
        }
        # 端末固有識別子のチェック
        elsif (defined $koyuu && $koyuu =~ /^\Q$line\E$/) {
            $flag = 1;
            $Sys->Set('HITS', $line);
            last;
        }
        # ホスト名(正規表現)のチェック
        if (defined $host) {
            my $host_pat = eval { qr/$line/ };
            if (!$@ && $host =~ $host_pat) {
                $flag = 1;
                $Sys->Set('HITS', $line);
                last;
            }
        }
        # ユーザーエージェントのチェック
        # 「!reg:」付きなら正規表現モード
            if ($line =~ /^!reg:(.*)$/) {
                my $pattern_str = $1;
                next if (index($pattern_str, '(?{') >= 0 or index($pattern_str, '(??{') >= 0);
                my $pat = eval { qr#$pattern_str# };
                next if $@;
                if (!$@ && $ua =~ $pat) {
                    $flag = 1;
                    $Sys->Set('HITS', $line);
                    last;
                }
            }
            elsif (defined $ua) {
                my $pat = eval { qr{\Q$line\E}i };
                if (!$@ && $ua =~ $pat) {
                    $flag = 1;
                    $Sys->Set('HITS', $line);
                    last;
                }
            }
        # セッションIDのチェック
        elsif (defined $sid && $line =~ $sid_regex && $sid =~ /^\Q$line\E$/) {
            $flag = 1;
            $Sys->Set('HITS', $line);
            last;
        }
    }

    # 規制ユーザの場合
    $this->{'TYPE'} //= '';
    if ($flag && $this->{'TYPE'} eq 'disable') {
        if ($this->{'METHOD'} eq 'disable') {
            # 書き込み不可
            return 4;
        }
        elsif ($this->{'METHOD'} eq 'host') {
            # ホスト表示
            return 2;
        }
        else {
            return 4;
        }
    }
    # 限定ユーザ以外の場合
    elsif (! $flag && $this->{'TYPE'} eq 'enable') {
        if ($this->{'METHOD'} eq 'disable') {
            # 書き込み不可
            return 4;
        }
        elsif ($this->{'METHOD'} eq 'host') {
            # ホスト表示
            return 2;
        }
        else {
            return 4;
        }
    }
    return 0;
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
