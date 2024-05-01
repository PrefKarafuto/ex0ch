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
        'SESSION'	    => undef,   # セッションオブジェクト
        'SID'	        => undef,   # セッションID
        'ANON_FLAG'     => undef,   # 匿名化状態か
        'CREATE_FLAG'   => undef,   # 新規作成か
        'LOAD_FLAG'     => undef,   # passからロードか
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖ロード
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$slip    	slip文字列
#	@param	$isAnon 	匿名化されてるかどうか
#	@param	$password	あればパスワードで忍法帖をロード。無ければ通常ロード
#	@return	パスワードがあり、かつセッションIDが見つからない場合0
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys,$slip,$isAnon,$password) = @_;
    my ($sid,$sid_saved,$sid_before,$sec,$auth);

    my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
    my $Form = $Sys->Get('MainCGI')->{'FORM'};
    my $Set = $Sys->Get('MainCGI')->{'SET'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";

    $this->{'ANON_FLAG'} = $isAnon eq '8' ? 1 : 0;
    $sid = $Sys->Get('SID');

    my $addr = $ENV{'REMOTE_ADDR'};
    my $ctx3 = Digest::MD5->new;
    $ctx3->add('ex0ch ID Generation');
    $ctx3->add(':', $Sys->Get('SERVER'));
    $ctx3->add(':', $addr);
    my $ip_hash = $ctx3->b64digest;
    my $ctx = Digest::MD5->new;
    $ctx->add('ex0ch ID Generation');
    $ctx->add(':', $Sys->Get('SERVER'));
    $ctx->add(':', $slip);
    my $slip_hash = $ctx->b64digest;

    #cookieにsessionIDが保存されていない場合
    if (!$sid && !$this->{'ANON_FLAG'}){
        my $expiry = 60*60*24;      # 紐付け有効期限は24h
        $sid = GetHash($ip_hash,$expiry,$ninDir.'hash/ip_addr.cgi');
        if(!$sid) {
            $sid = GetHash($slip_hash,$expiry,$ninDir.'hash/user_info.cgi');
        }
    }
    
    if($Set->Get('BBS_NINJA')){
        #パスワードがあった場合
        if($password){
            my $ctx2 = Digest::MD5->new;
            my $exp = $Sys->Get('PASS_EXPITY');
            my $long_expiry = 60*60*24*$exp;
            
            $ctx2->add($Sys->Get('SECURITY_KEY'));
            $ctx2->add(':', $password);

            $sid_saved = GetHash($ctx2->b64digest,$long_expiry,$ninDir.'hash/password.cgi');
            if($sid_saved && $sid_saved ne $sid){
                $sid_before = $sid;
                $sid = $sid_saved;
            }
        }
        #忍法帖が有効の場合
        my $session = CGI::Session->new("driver:file;serializer:storable", $sid, {Directory => $ninDir});
        if($session ->is_new()){
            $sid = $session->id();
            $this->{'CREATE_FLAG'} = 1;

            #新規作成時に追加
            $session->param('new_message',substr($Form->Get('MESSAGE'), 0, 30));
            $session->param('c_bbsdir',$Sys->Get('BBS'));
            $session->param('c_threadkey',$Sys->Get('KEY'));
            $session->param('c_addr',$ENV{'REMOTE_ADDR'});
            $session->param('c_host',$ENV{'REMOTE_HOST'});
            $session->param('c_ua',$ENV{'HTTP_USER_AGENT'});
        }else{
            if ($sid && $sid_before){
                #忍法帖ロード時に追加
                my $load_count = $session->param('load_count') || 0;
                $this->{'LOAD_FLAG'} = 1;
                $load_count++;
                $session->param('load_count',$load_count);
                $session->param('load_message',substr($Form->Get('MESSAGE'), 0, 30));
                $session->param('load_from',$sid_before);
                $session->param('load_time',time);
                $session->param('load_bbsdir',$Sys->Get('BBS'));
                $session->param('load_threadkey',$Sys->Get('KEY'));
                $session->param('load_addr',$ENV{'REMOTE_ADDR'});
                $session->param('load_host',$ENV{'REMOTE_HOST'});
                $session->param('load_ua',$ENV{'HTTP_USER_AGENT'});
            }else{
                # 通常時処理
                # ninpocho.plでは行わない
            }
        }
        $this->{'SESSION'} = $session;
    }else{
        $this->{'SESSION'} = undef;
        #セッションIDのみ使う場合
        if(!$sid){
            $sid = generate_id();
        }
    }
    $this->{'SID'} = $sid;
    $Sys->Set('SID',$sid);
    # Hashテーブルを設定
    if(!$this->{'ANON_FLAG'}){
        SetHash($ip_hash,$sid,time,$ninDir.'hash/ip_addr.cgi');
        SetHash($slip_hash,$sid,time,$ninDir.'hash/user_info.cgi');
    }

    return $sid;
}
# セッションIDから忍法帖を読み込む(admin.cgi用)
sub LoadOnly {
    my $this = shift;
    my ($Sys,$sid) = @_;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir = ".$infoDir/.ninpocho/";
    my $session = CGI::Session->load("driver:file;serializer:storable", $sid, {Directory => $ninDir});

    # セッションの読み込みが失敗した場合、0を返す
    return 0 unless $session;

    $this->{'SESSION'} = $session;
    $this->{'SID'} = $sid;
    return 1; # 正常に読み込みが完了した場合、1を返す
}
# セッションに忍法帖保存(admin.cgi用)
sub SaveOnly
{
    my $this = shift;
    return 0 unless $this->{'SESSION'};
    # セッションを閉じる
    $this->{'SESSION'}->flush();
    return 1;
}
#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報取得
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @return 忍法帖の要素の情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
    my $this = shift;
    my ($name) = @_;

    return unless $this->{'SESSION'};
    my $val = $this->{'SESSION'}->param($name);
    
    return $val;
}
#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報設定
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @param  $val        設定値
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
    my $this = shift;
    my ($name, $val) = @_;
    
    return unless $this->{'SESSION'};
    $this->{'SESSION'}->param($name,$val);

    return $this->{'SESSION'}->param($name);
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
    my $ninDir = ".$infoDir/.ninpocho/";
    my @file_list = (
        'hash/user_info.cgi',
        'hash/password.cgi',
        'hash/ip_addr.cgi'
    );
    my $count = 0;

    foreach my $sid (@$sid_array_ref) {
        my $session = CGI::Session->load("driver:file;serializer:storable", $sid, {Directory => $ninDir});
        if ($session->is_empty) {
            next; # このセッションIDは無効なので次へ
        } else {
            if ( ($session->ctime) <= time() ) {
                $session->delete();
                $session->flush();
                $count++;
            }
            foreach my $filename (@file_list) {
                DeleteHashValue($sid, $filename);
            }
        }
    }
    return $count;
}
sub DeleteOnly
{
    my $this=shift;
    $this->{'SESSION'}->delete();
    $this->{'SESSION'}->flush();
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
    my $sid = $this->{'SID'};
    my $session = $this->{'SESSION'};

    # 忍法帖を使わない場合
    return unless $session;

    if ($password) {
        my $ctx3 = Digest::MD5->new;
        $ctx3->add($Sys->Get('SECURITY_KEY'));
        $ctx3->add(':', $password);
        my $pass_hash = $ctx3->b64digest;
        # 既にpasswordが設定されていた場合、既存のパスワードを削除
        if($session->param('password')){
            DeleteHash($session->param('password'),$ninDir.'hash/password.cgi');
        }
        SetHash($pass_hash,$sid,time,$ninDir.'hash/password.cgi');
        $session->param('password',$pass_hash);
    }

    # セッション有効期限を設定
    if($session->param('password')){
        $session->expire($Sys->Get('PASS_EXPIRY').'d');
    }else{
        $session->expire($Sys->Get('NIN_EXPIRY').'d');
    }
    # セッションを閉じる
    $session->flush();
}

# ハッシュテーブルをファイルから読み込む関数
sub GetHash {
    my ($key, $expiry,$filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }
    
    # キーに対応する値が存在するかチェック
    if (exists $hash_table->{$key}) {
        # 有効期限をチェック
        if (($hash_table->{$key}{time} + $expiry) < time) {
            # 有効期限切れの場合は削除してundefを返す
            delete $hash_table->{$key};
            store $hash_table, $filename;
            return undef;
        } else {
            # 有効期限内の場合は値を返す
            $hash_table->{$key}{time} = time;
            store $hash_table, $filename;
            return $hash_table->{$key}{value};
        }
    } else {
        # キーが存在しない場合はundefを返す
        return undef;
    }
}

# パラメータをハッシュテーブルに保存し、ファイルに保存する関数
sub SetHash {
    my ($key, $value, $time ,$filename) = @_;
    my $hash_table = {};

    if (-e $filename) {
        $hash_table = retrieve($filename);
    }

    $hash_table->{$key} = {
        value => $value,
        time => $time,
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

#============================================================================================================
#	Module END
#============================================================================================================
1;
