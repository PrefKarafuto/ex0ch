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
use CGI::Cookie;
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
        'SID'	        => undef,   # セッションID
        'STATUS'        => undef,   # 忍法帖が有効か無効か
        'ANON'          => undef,   # 匿名化状態か
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖ロード
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$isAnon 	匿名化されてるかどうか
#	@param	$password	あればパスワードで忍法帖をロード。無ければ通常ロード
#	@param	$sid	あればセッションIDで忍法帖をロード。無ければ通常ロード
#	@param	$mode	1なら忍法帖を作らない（セッションIDのみ利用したい場合）
#	@return	パスワードがあり、かつセッションIDが見つからない場合0
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys,$isAnon,$password) = @_;
    my ($sid,$sid_saved,$sid_before,$sec);

    my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
    my $Form = $Sys->Get('MainCGI')->{'FORM'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = "./$infoDir/.ninpocho/";

    # ディレクトリ作成は掲示板作成時に行うようにする予定
	mkdir $ninDir if ! -d $ninDir;
    mkdir $ninDir.'hash/' if ! -d $ninDir.'hash/';

    $this->{'ANON'} = $isAnon eq '8' ? 1 : 0;

    if($Sys->Get('BBS_NINJA')){
        $this->{'SATUS'} = 1;
    }else{
        $this->{'SATUS'} = 0;
    }

    #cookieから取得
    $sid = $Cookie->Get('countsession');
    $sec = $Cookie->Get('securitykey');
    my %cookies = fetch CGI::Cookie;
    if (!$sid && exists $cookies{'countsession'}) {
        $sid = $cookies{'countsession'}->value;
        $sid =~ s/"//g;
    }
    if (!$sec && exists $cookies{'securitykey'}) {
        $sec = $cookies{'securitykey'}->value;
        $sec =~ s/"//g;
    }

    #改竄をチェック
    if($sec){
        my $ctx = Digest::MD5->new;
        $ctx->add($Sys->Get('SECURITY_KEY'));
        $ctx->add(':', $sid);
        #一致しなかったら改竄されている
        return if ($ctx->b64digest ne $sec);
    }else{
        #セキュリティキーが無い場合
        #return;
    }

    #cookieにsessionIDが保存されていない場合
    if(!$sid && !$this->{'ANON'}){
        my $addr = $ENV{'REMOTE_ADDR'};
        my $ctx = Digest::MD5->new;
        $ctx->add('ex0ch ID Generation');
        $ctx->add(':', $Sys->Get('SERVER'));
        $ctx->add(':', $addr);

        $sid = GetHash($ctx->b64digest,$ninDir.'hash/ip_addr.cgi');
        if(!$sid) {
            $sid = GetHash(MakeUserInfo($Sys),$ninDir.'hash/user_info.cgi');
        }
    }

    #パスワードがあった場合
    if($password && $this->{'SATUS'}){
        my $ctx = Digest::MD5->new;
        $ctx->add('ex0ch ID Generation');
        $ctx->add(':', $Sys->Get('SERVER'));
        $ctx->add(':', $password);

        $sid_saved = GetHash($ctx->b64digest,$ninDir.'hash/password.cgi');
        if($sid_saved && $sid_saved ne $sid){
            $sid_before = $sid;
            $sid = $sid_saved;
        }
    }

    if($this->{'SATUS'}){
        #忍法帖が有効の場合
        $this->{'SESSION'} = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});
        if($this->{'SESSION'}->is_empty){
            $this->{'SESSION'} = CGI::Session->new("driver:file", $sid, {Directory => $ninDir});
            $sid = CGI::Session->id();
            #新規作成時に追加
            Set('new_message',substr($Form->Get('MESSAGE'), 0, 30));
        }else{
            if ($sid && $sid_before && $sid_before ne $sid_saved){
                #忍法帖ロード時に追加
                Set('load_message',substr($Form->Get('MESSAGE'), 0, 30));
                Set('load_from',$sid_before);
                Set('load_time',localtime(time));
                Set('load_addr',$ENV{'REMOTE_ADDR'});
                Set('load_host',$ENV{'REMOTE_HOST'});
            }
        }
        $this->{'SID'} = $sid;
    }else{
        #セッションIDのみ使う場合
        if($sid){
            $this->{'SID'} = $sid;
        }else{
            $this->{'SID'} = generate_id();
        }
    }

    return $this->{'SID'};
}
# セッションIDから忍法帖を読み込む(admin.cgi用)
sub LoadOnly {
    my $this = shift;
    my ($Sys, $sid) = @_;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir = "./$infoDir/.ninpocho/";
    my $session = CGI::Session->load("driver:file", $sid, {Directory => $ninDir});

    # セッションの読み込みが失敗した場合、0を返す
    unless (defined $session) {
       $this->{'STATUS'} = 0;
      return 0;
    }

    $this->{'SESSION'} = $session;
    $this->{'STATUS'} = 1;
    $this->{'SID'} = $sid;
    return 1; # 正常に読み込みが完了した場合、1を返す
}
# セッションに忍法帖保存(admin.cgi用)
sub SaveOnly
{
    my $this = shift;
    return 0 if $this->{'STATUS'} == 0;
    # セッションを閉じる
    $this->{'SESSION'}->flush();
    return 1;
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
    my ($name) = @_;
    return if !$this->{'STATUS'};
    my $session = $this->{'SESSION'};
    my $val = $session->param($name);
    
    return $val;
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
    my ($name, $val) = @_;
    
    return 0 if !$this->{'STATUS'};
    $this->{'SESSION'}->param($name,$val);

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
    my $this=shift;
    my ($Sys, $sid_array_ref) = @_;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir = "./$infoDir/.ninpocho/";
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
            if ( ($session->ctime) <= time() ) {
                $session->delete();
                $session->flush();
            }
            foreach my $filename (@file_list) {
                DeleteHashValue($sid, $filename);
            }
        }
    }
    return 1; # 処理が完了したら1を返す
}
# ID生成
sub generate_id
{
    my $md5 = Digest::MD5->new();
    $md5->add($$,time(),rand(time));
    return $md5->hexdigest();
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
    my $limit = 60*60*24;
    my $sid = $this->{'SID'};

    if($password){
        $limit = $limit*365;
    }else{
        $limit = $limit*30;
    }

	# SIDをクッキーに出力
	$Cookie->Set('countsession', $sid);

    my $ctx = Digest::MD5->new;
    $ctx->add($Sys->Get('SECURITY_KEY'));
    $ctx->add(':', $sid);
    my $sec = $ctx->b64digest;
    $Cookie->Set('securitykey', $sec);

    if($this->{'STATUS'}){
        my $session = $this->{'SESSION'};
        # セッション有効期限を30日後に設定
        $session->expire($limit);
        # セッションを閉じる
        $session->flush();
    }

    # Hashテーブルを設定
    if(!$this->{'ANON'} && $this->{'STATUS'}){
        my $addr = $ENV{'REMOTE_ADDR'};
        my $ctx2 = Digest::MD5->new;
        $ctx2->add(':', $Sys->Get('SERVER'));
        $ctx2->add(':', $addr);
        my $ip_hash = $ctx2->b64digest;
        my $user = MakeUserInfo($Sys);

        SetHash($ip_hash,$sid,60*60*24+localtime(time),$ninDir.'hash/ip_addr.cgi');
        SetHash($user,$sid,60*60*24+localtime(time),$ninDir.'hash/user_info.cgi');
    }
    if (defined $password && $this->{'STATUS'}) {
        my $ctx3 = Digest::MD5->new;
        $ctx3->add(':', $Sys->Get('SERVER'));
        $ctx3->add(':', $password);
        my $pass_hash = $ctx3->b64digest;
        SetHash($pass_hash,$sid,$limit+localtime(time),$ninDir.'hash/password.cgi');
    }
	
}

# ハッシュテーブルをファイルから読み込む関数
sub GetHash {
    my ($key, $filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }
    
    # キーに対応する値が存在するかチェック
    if (exists $hash_table->{$key}) {
        # 有効期限をチェック
        if ($hash_table->{$key}{expiry} < localtime(time)) {
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
    my ($key, $value, $expiry ,$filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }

    $hash_table->{$key} = {
        value => $value,
        expiry => $expiry,
    };
    store $hash_table, $filename;
    chmod 0600,$filename,
}
sub DeleteHash
{
    my ($key, $filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
        # 値が目的の値と一致した場合、その要素を削除
        if ($hash_table->{$key}) {
            delete $hash_table->{$key};
        }
    }
        # 変更をファイルに保存
        store $hash_table, $filename;
        chmod 0600,$filename;
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
    my $addr = $ENV{'REMOTE_ADDR'};
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
