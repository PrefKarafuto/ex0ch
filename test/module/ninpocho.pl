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
#	@return	パスワードがあり、かつセッションIDが見つからない場合0
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys,$password) = @_;

    my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";

	mkdir $ninDir if ! -d $ninDir;
    mkdir $ninDir.'hash/' if ! -d $ninDir.'hash/';

    my $sid = $Cookie->Get('countsession');
    my $ninpocho = '';
    my $session = '';

    # パスワードが提供された場合
    if (defined $password) {
        # パスワードとセッションIDのハッシュテーブルをファイルから読み込む
        my $ctx = Digest::MD5->new;
        $ctx->add('0ch+ ID Generation');
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
                $ctx->add('0ch+ ID Generation');
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
    }
    $session = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});
    $ninpocho = $session->param('ninpocho');

    $this->{'SESSION'} = $session;
    $this->{'SID'} = $sid;
	$this->{'NINJA'} = %{$ninpocho};

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
	
    $this->{'SESSION'}->param('ninpocho',$this->{'NINJA'});

    my $sid = $this->{'SESSION'}->id();
    my $session = $this->{'SESSION'};

	# SIDをクッキーに出力
	$Cookie->Set('countsession', $sid);
    # セッション有効期限を30日後に設定
    $session->expire('+30d');
	# セッションを閉じる
	$session->close();

    # Hashテーブルを設定
    my $addr = $ENV{HTTP_CF_CONNECTING_IP} ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
    my $ctx = Digest::MD5->new;
    $ctx->add('0ch+ ID Generation');
    $ctx->add(':', $Sys->Get('SERVER'));
    $ctx->add(':', $addr);
    my $ip_hash = $ctx->b64digest;
    my $user = MakeUserInfo($Sys);

    SetHash($ip_hash,$sid,$ninDir.'hash/ip_addr.cgi',$limit);
    SetHash($user,$sid,$ninDir.'hash/user_info.cgi',$limit);
    if (defined $password) {
        my $ctx = Digest::MD5->new;
        $ctx->add('0ch+ ID Generation');
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
    $ctx->add('0ch+ ID Generation');
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
