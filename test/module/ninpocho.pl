#============================================================================================================
#
#	忍法帖情報管理パッケージ
#
#============================================================================================================
package	NINPOCHO;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use CGI::Session;
use Digest::MD5;
use Storable qw(store retrieve);

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
        'SESSION'	    => undef,   # セッション
	    'NINJA'	        => undef,   # 忍法帖情報
        'SID'	        => undef,   # セッションID
        'STATUS'        => undef,   # 忍法帖が有効か無効か
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖ロード
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$password	あればパスワードで忍法帖をロード。無ければ通常ロード
#	@param	$sid	あればセッションIDで忍法帖をロード。無ければ通常ロード
#	@param	$mode	1なら忍法帖を作らない（セッションIDのみ利用したい場合）
#	@return	パスワードがあり、かつセッションIDが見つからない場合0
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys,$password,$sid,$mode) = @_;

    my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";

    # ディレクトリ作成は掲示板作成時に行うようにする予定
	mkdir $ninDir if ! -d $ninDir;
    mkdir $ninDir.'hash/' if ! -d $ninDir.'hash/';

    $sid = $Cookie->Get('countsession') if !defined $sid;
    my $ninpocho = '';
    my $session = '';

    # パスワードが提供された場合
    if (defined $password) {
        # パスワードとセッションIDのハッシュテーブルをファイルから読み込む
        my $ctx = Digest::MD5->new;
        $ctx->add('ex0ch ID Generation');
        $ctx->add(':', $Sys->Get('SERVER'));
        $ctx->add(':', $password);
        my $pass_hash = $ctx->b64digest;
        $sid = GetHash($pass_hash,$ninDir.'hash/password.cgi'); # ハッシュテーブルの読み込みロジック

        if ($sid) {
            # セッションをロード
            $session = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});
            $ninpocho = $session->param('ninpocho') if defined $session;
        } else {
            # セッションIDが見つからない場合
            return 0;
        }
    } else {
        if ($sid eq '') {
        my %cookies = fetch CGI::Cookie;
            if (exists $cookies{'countsession'}) {
                $sid = $cookies{'countsession'}->value;
                $sid =~ s/"//g;
            }
            if($sid eq '') {
                my $addr = $ENV{HTTP_CF_CONNECTING_IP} ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
                my $ctx = Digest::MD5->new;
                $ctx->add('ex0ch ID Generation');
                $ctx->add(':', $Sys->Get('SERVER'));
                $ctx->add(':', $addr);
                my $ip_hash = $ctx->b64digest;

                $sid = GetHash($ip_hash,$ninDir.'hash/ip_addr.cgi');

                if(!$sid) {
                    my $user = MakeUserInfo($Sys);
                    $sid = GetHash($user,$ninDir.'hash/user_info.cgi');
                }
            }
        }
        $session = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});
    }
    
    if ($session->is_empty) {
        # セッションが空（存在しない）場合は新規作成
        $session = CGI::Session->new("driver:file", undef, {Directory => $ninDir});
        $sid = $session->id(); # 新しいセッションIDを取得
    }

    if($mode){
        # セッションIDのみ利用する場合
        $session->delete();
        $session->flush();
        $this->{'STATUS'} = 0;
    }else{
        $this->{'SATUS'} = 1;
        $ninpocho = $session->param('ninpocho');
        $this->{'SESSION'} = $session;
    }
    
    if (defined $ninpocho) {
        $this->{'NINJA'} = %{$ninpocho};
    } else {
        $this->{'NINJA'} = {};
    }
    $this->{'SID'} = $sid;
    return $sid;
}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報取得（可変長の引数リストに対応）
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @return 忍法帖の要素の情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
    my $this = shift;
    my @path = @_;
    my $current = $this->{'NINJA'};
    return 0 if !$this->{'STATUS'};
    
    for my $key (@path) {
        return unless exists $current->{$key};
        $current = $current->{$key};
    }
    
    return $current;
}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報設定（可変長の引数リストに対応）
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @param  $val        設定値
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
    my $this = shift;
    my $val = pop;  # 最後の引数は設定値
    my @path = @_;  # 残りの引数はパス
    
    # パスが空である場合は失敗とみなす
    return 0 unless @path;
    return 0 if !$this->{'STATUS'};
    
    my $current = $this->{'NINJA'};
    
    for my $i (0..$#path) {
        my $key = $path[$i];
        
        if ($i == $#path) {
            $current->{$key} = $val;
        } else {
            unless (exists $current->{$key} && ref $current->{$key} eq 'HASH') {
                $current->{$key} = {};
            }
            $current = $current->{$key};
        }
    }
}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖削除（admin.cgiでの使用を想定）
#   -------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#   @param  $sid_array_ref    セッションIDの配列リファレンス
#   @return 削除に成功したら1　$sidで指定されたセッションがなければ0
#
#------------------------------------------------------------------------------------------------------------
sub Delete {
    my ($Sys, $sid_array_ref) = @_;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir = ".$infoDir/.ninpocho/";
    my @file_list = (
        'hash/user_info.cgi',
        'hash/password.cgi',
        'hash/ip_addr.cgi'
    );

    foreach my $sid (@$sid_array_ref) {
        my $session = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});
        if ($session->is_empty) {
            next; # このセッションIDは無効なので次へ
        } else {
            $session->delete();
            foreach my $filename (@file_list) {
                DeleteHashValue($sid, $filename);
            }
        }
    }
    return 1; # 処理が完了したら1を返す
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$password	あればパスワードで忍法帖をセーブ。無ければ通常セーブ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys,$password) = @_;
	my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
    my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
    my $limit = 60*60*24*30; # 30日
    my $sid = $this->{'SID'};

	# SIDをクッキーに出力
	$Cookie->Set('countsession', $sid);

    if($this->{'STATUS'}){
        my $session = $this->{'SESSION'};
        $session->param('ninpocho',$this->{'NINJA'});
        # セッション有効期限を30日後に設定
        $session->expire('+30d');
        # セッションを閉じる
        $session->close();
    }

    # Hashテーブルを設定
    my $addr = $ENV{HTTP_CF_CONNECTING_IP} ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
    my $ctx = Digest::MD5->new;
    $ctx->add('ex0ch ID Generation');
    $ctx->add(':', $Sys->Get('SERVER'));
    $ctx->add(':', $addr);
    my $ip_hash = $ctx->b64digest;
    my $user = MakeUserInfo($Sys);

    SetHash($ip_hash,$sid,$ninDir.'hash/ip_addr.cgi',$limit);
    SetHash($user,$sid,$ninDir.'hash/user_info.cgi',$limit);
    if (defined $password && $this->{'STATUS'}) {
        my $ctx = Digest::MD5->new;
        $ctx->add('ex0ch ID Generation');
        $ctx->add(':', $Sys->Get('SERVER'));
        $ctx->add(':', $password);
        my $pass_hash = $ctx->b64digest;
        SetHash($pass_hash,$sid,$ninDir.'hash/password.cgi',$limit);
    }
	
}

# ハッシュテーブルをファイルから読み込む関数
sub GetHash {
    my ($key, $filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }

    # 現在時刻
    my $now = time;
    
    # キーに対応する値が存在するかチェック
    if (exists $hash_table->{$key}) {
        # 有効期限をチェック
        if ($hash_table->{$key}{expiry} < $now) {
            # 有効期限切れの場合は削除してundefを返す
            delete $hash_table->{$key};
            store $hash_table, $filename;
            return undef;
        } else {
            # 有効期限内の場合は値を返す
            return $hash_table->{$key}{value};
        }
    } else {
        # キーが存在しない場合はundefを返す
        return undef;
    }
}

# パラメータをハッシュテーブルに保存し、ファイルに保存する関数
sub SetHash {
    my ($key, $value, $filename, $expiry) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }

    $hash_table->{$key} = {
        value => $value,
        expiry => time + $expiry,
    };
    store $hash_table, $filename;
    chmod 0600,$filename,
}
sub DeleteHashValue {
    my ($target_value, $filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);

        # ハッシュテーブルの各キーと値を繰り返し確認
        foreach my $key (keys %$hash_table) {
            # 値が目的の値と一致した場合、その要素を削除
            if ($hash_table->{$key}->{value} eq $target_value) {
                delete $hash_table->{$key};
            }
        }

        # 変更をファイルに保存
        store $hash_table, $filename;
        chmod 0600,$filename;
    }
}
sub MakeUserInfo
{
    my $Sys = shift;
    my $addr = $ENV{HTTP_CF_CONNECTING_IP} ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
    my @ip = split(/\./,$addr);
    my $ua = $ENV{'HTTP_SEC_CH_UA'} // $ENV{'HTTP_USER_AGENT'};

    my $provider;
    my $HOST = $ENV{'HTTP_HOST'};

    # プロバイダのドメインを取得
    if ($HOST) {
        $HOST =~ s/ne\.jp/nejp/g;
        $HOST =~ s/ad\.jp/adjp/g;
        $HOST =~ s/or\.jp/orjp/g;

        my @d = split(/\./, $HOST);  # リモートホストからドメイン部分を取り出す
        if (@d) {
            my $c = scalar @d;
            $provider = $d[$c - 2] . $d[$c - 1];
        }
    }
    my $ctx = Digest::MD5->new;
    $ctx->add('ex0ch ID Generation');
    $ctx->add(':', $Sys->Get('SERVER'));
    $ctx->add(':', $ip[0].$ip[1].$provider);
    $ctx->add(':', $ua);
    my $user = $ctx->b64digest;

    return $user;
}
#============================================================================================================
#	Module END
#============================================================================================================
1;
