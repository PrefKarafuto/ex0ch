#============================================================================================================
#
#   忍法帖情報管理パッケージ (修正版)
#
#============================================================================================================
package NINPOCHO;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

use File::Path qw(mkpath);
use POSIX qw(strftime);
use CGI::Session;
use CGI::Cookie;
use Digest::MD5;
use Storable qw(lock_nstore lock_retrieve);
use File::Basename qw(dirname);
use MIME::Base64 ();  # encode_base64url

#------------------------------------------------------------------------------------------------------------
#   コンストラクタ
#   @return モジュールオブジェクト
#------------------------------------------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $obj = {
        SESSION     => undef,
        SID         => undef,
        ANON_FLAG   => undef,
        CREATE_FLAG => undef,
        LOAD_FLAG   => undef,
    };
    bless $obj, $class;
    return $obj;
}

#------------------------------------------------------------------------------------------------------------
#   忍法帖ロード
#   @param $Sys       SYSTEM
#   @param $password  パスワードがあれば指定
#   @return セッションIDまたは undef
#------------------------------------------------------------------------------------------------------------
sub Load {
    my ($this, $Sys, $password) = @_;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir  = ".$infoDir/.ninpocho/";

    my $sid = $Sys->Get('SID');
    my $sid_before;

    # パスワード指定時
	if ($password) {
		# 有効期限（日数）
		my $exp_days    = $Sys->Get('PASS_EXPIRY') || 1;
		my $long_expiry = 60 * 60 * 24 * $exp_days;

		# ダイジェスト（ファイル内キー）
		my $ctx  = Digest::MD5->new;
		$ctx->add($Sys->Get('SECURITY_KEY'), ':', $password);
		my $hash = $ctx->hexdigest;

		my $pw_file = "$ninDir/hash/password.cgi";

		# GetHash が期限切れチェック＆タイムスタンプ更新を行いつつ
		# 成功時は保存済 SID を返し、失敗時は undef を返す
		my $saved = GetHash($hash, $long_expiry, $pw_file);
		return undef unless defined $saved;

		# SID が変わっていたらロードフラグ用に保持
		if ($saved ne $sid) {
			$sid_before = $sid;
			$sid        = $saved;
		}
	}

    # セッション読み込み or 新規作成
    my $session = CGI::Session->new(
        "driver:file;serializer:Storable", $sid,
        { Directory => $ninDir }
    );
    if ($session->is_new) {
        $sid = $session->id;
        $this->{CREATE_FLAG} = 1;
        # 初回データ設定
        my $mes = $Sys->Get('MainCGI')->{'FORM'}->Get('MESSAGE') || '';
        $mes =~ s{<\s*(?:b|h)r\b[^>]*>}{}gi;
        $session->param(new_message => substr($mes, 0, 30));
        $session->param(c_bbsdir     => $Sys->Get('BBS'));
        $session->param(c_threadkey  => $Sys->Get('KEY'));
        $session->param(c_addr       => $ENV{REMOTE_ADDR});
        $session->param(c_host       => $ENV{REMOTE_HOST});
        $session->param(c_ua         => $ENV{HTTP_USER_AGENT});
    } else {
        if ($sid_before) {
            $this->{LOAD_FLAG} = 1;
            my $count = $session->param('load_count') || 0;
            $session->param(load_count => ++$count);
            my $mes = $Sys->Get('MainCGI')->{'FORM'}->Get('MESSAGE') || '';
            $mes =~ s{<\s*(?:b|h)r\b[^>]*>}{}gi;
            $session->param(load_message   => substr($mes, 0, 30));
            $session->param(load_from      => $sid_before);
            $session->param(load_time      => time);
            $session->param(load_bbsdir    => $Sys->Get('BBS'));
            $session->param(load_threadkey => $Sys->Get('KEY'));
            $session->param(load_addr      => $ENV{REMOTE_ADDR});
            $session->param(load_host      => $ENV{REMOTE_HOST});
            $session->param(load_ua        => $ENV{HTTP_USER_AGENT});
        }
    }
    $session->flush;
    $this->{SESSION} = $session;
    $this->{SID}     = $sid;
    $Sys->Set('SID', $sid);
    return $sid;
}

#------------------------------------------------------------------------------------------------------------
#   admin 用: SID から読み込み
#------------------------------------------------------------------------------------------------------------
sub LoadOnly {
    my ($this, $Sys, $sid) = @_;
    my $ninDir = "." . $Sys->Get('INFO') . "/.ninpocho/";
    return 0 unless -d $ninDir;
    my $session = CGI::Session->load(
        "driver:file;serializer:Storable", $sid,
        { Directory => $ninDir }
    );
    return 0 unless $session;
    $this->{SESSION} = $session;
    $this->{SID}     = $sid;
    return 1;
}

#------------------------------------------------------------------------------------------------------------
#   admin 用: セッション保存
#------------------------------------------------------------------------------------------------------------
sub SaveOnly {
    my $this = shift;
    return 0 unless $this->{SESSION};
    $this->{SESSION}->flush;
    return 1;
}

#------------------------------------------------------------------------------------------------------------
#   情報取得
#------------------------------------------------------------------------------------------------------------
sub Get {
    my ($this, $name) = @_;
    return '' unless $this->{SESSION};
    return $this->{SESSION}->param($name) // '';
}
sub isNew  { shift->{CREATE_FLAG} }
sub isLoad { shift->{LOAD_FLAG} }

#------------------------------------------------------------------------------------------------------------
#   情報設定
#------------------------------------------------------------------------------------------------------------
sub Set {
    my ($this, $name, $val) = @_;
    return unless $this->{SESSION};
    $this->{SESSION}->param($name => $val);
    return $this->{SESSION}->param($name);
}

# 全設定ハッシュ
sub All {
    my $this = shift;
    my ($sess) = @_;
    if(!$sess){
        return $this->{'SESSION'};
    }else{
        $this->{'SESSION'} = $sess;
    }
}

#------------------------------------------------------------------------------------------------------------
#   admin 用: セッション削除
#------------------------------------------------------------------------------------------------------------
sub Delete {
    my ($this, $Sys, $sid_array_ref) = @_;
    my $ninDir = "." . $Sys->Get('INFO') . "/.ninpocho/";
    my $count = 0;
    foreach my $sid (@$sid_array_ref) {
        if(-e $ninDir.'cgisess_'.$sid){
            unlink $ninDir.'cgisess_'.$sid;
            $count++;
        }
    }
    # ハッシュファイル内の参照削除
    foreach my $file ("$ninDir/hash/user_info.cgi",
                      "$ninDir/hash/ip_addr.cgi")
    {
        next unless -e $file;
        my $table = lock_retrieve($file) || {};
        foreach my $key (keys %$table) {
            # 値が sid_array_ref のいずれかに一致する場合はキーを削除
            if (grep { $table->{$key}{value} eq $_ } @{$sid_array_ref}) {
                delete $table->{$key};
            }
        }
        lock_nstore($table, $file);
        chmod 0600, $file;
    }
    return $count;
}

#------------------------------------------------------------------------------------------------------------
#   保存
#------------------------------------------------------------------------------------------------------------
sub Save {
    my ($this, $Sys, $com) = @_;
    return 0 unless $this->{SESSION};
    my $password;
    my $infoDir = $Sys->Get('INFO');
    my $ninDir  = "." . $infoDir . "/.ninpocho/";

    if ($com) {
        # パスワード生成
        my $seed;
        if ($this->{SESSION}->param('password_is_randomized')) {
            $password = $this->{SESSION}->param('password_is_randomized');
        } else {
            if (open my $fh, '<', '/dev/urandom') {
                binmode $fh;
                read $fh, $seed, 8;
                close $fh;
            } else {
                $seed = Digest::MD5->new->add($^O, rand, $^V, $$)->digest;
            }
            $password = substr MIME::Base64::encode_base64url($seed), 0, 11;
            $this->{SESSION}->param(password_is_randomized => $password);
        }
        my $ctx = Digest::MD5->new;
        $ctx->add($Sys->Get('SECURITY_KEY'), ':', $password);
        my $hash = $ctx->hexdigest;
        my $pw_file = "$ninDir/hash/password.cgi";

        # 古いハッシュエントリがあれば削除
		if (my $old = $this->{SESSION}->param('password_file_hash')) {
			DeleteHash($old, $pw_file);
		}

		# 新しい SID を登録
		SetHash($hash, $this->{SID}, time, $pw_file);
		$this->{SESSION}->param(password_file_hash => $hash);
    }

    # 有効期限設定
    if ($this->{SESSION}->param('password_is_randomized')) {
        $this->{SESSION}->expire($Sys->Get('PASS_EXPIRY') . 'd');
    } else {
        $this->{SESSION}->expire($Sys->Get('NIN_EXPIRY') . 'd');
    }
    $this->{SESSION}->flush;

    # パスワード生成時はフォームコマンド
    if ($password) {
        my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
        $Sys->Set('NIN_PASS', $password);
        $Sys->Set('TIME',    $now);
        return $ZP::E_FORM_SAVECOMMAND;
    }
}

# -----------------------------------------------------------------------------
# 指定ファイルが置かれるディレクトリを保証するヘルパー
# -----------------------------------------------------------------------------
sub _ensure_dir {
    my ($file) = @_;
    my $dir = dirname($file);
    mkpath($dir,0,0700) unless -d $dir;
}

# -----------------------------------------------------------------------------
# ハッシュテーブルをファイルから読み込む関数
# @param $key     検索キー
# @param $expiry  有効期限（秒）
# @param $file    ファイルパス
# @return 値または undef
# -----------------------------------------------------------------------------
sub GetHash {
    my ($key, $expiry, $file) = @_;

    # 存在すればロック付き読み込み、なければ空ハッシュ
    my $table = -e $file
              ? lock_retrieve($file)
              : {};

    # キーがあるか？
    if (exists $table->{$key}) {
        my $entry = $table->{$key};
        # 期限切れ判定
        if ($entry->{time} + $expiry < time) {
            delete $table->{$key};
            _ensure_dir($file);
            lock_nstore($table, $file);
            chmod 0600, $file;
            return undef;
        }
        # 有効期限内 → タイムスタンプ更新
        $entry->{time} = time;
        _ensure_dir($file);
        lock_nstore($table, $file);
        chmod 0600, $file;
        return $entry->{value};
    }

    return undef;
}

# -----------------------------------------------------------------------------
# ハッシュテーブルに key=>value を保存する関数
# @param $key    登録キー
# @param $value  登録値
# @param $time   登録時刻（time()）
# @param $file   ファイルパス
# @return 1=成功
# -----------------------------------------------------------------------------
sub SetHash {
    my ($key, $value, $time, $file) = @_;

    # 既存テーブル読み込み or 空ハッシュ
    my $table = -e $file
              ? lock_retrieve($file)
              : {};

    $table->{$key} = { value => $value, time => $time };

    _ensure_dir($file);
    lock_nstore($table, $file);
    chmod 0600, $file;

    return 1;
}

# -----------------------------------------------------------------------------
# 指定キーのエントリを削除する関数
# @param $key   削除キー
# @param $file  ファイルパス
# @return 1=削除した, 0=何もしなかった
# -----------------------------------------------------------------------------
sub DeleteHash {
    my ($key, $file) = @_;

    return 0 unless -e $file;

    my $table = lock_retrieve($file) || {};
    return 0 unless exists $table->{$key};

    delete $table->{$key};

    _ensure_dir($file);
    lock_nstore($table, $file);
    chmod 0600, $file;

    return 1;
}

# -----------------------------------------------------------------------------
# 値が一致するエントリをすべて削除する関数
# @param $target_value  削除対象の値
# @param $file          ファイルパス
# @return 削除件数 (0以上)
# -----------------------------------------------------------------------------
sub DeleteHashValue {
    my ($target_value, $file) = @_;

    return 0 unless -e $file;

    my $table   = lock_retrieve($file) || {};
    my $deleted = 0;

    foreach my $key (keys %$table) {
        my $val = $table->{$key}{value};
        next unless defined $val;
        if ($val eq $target_value) {
            delete $table->{$key};
            $deleted++;
        }
    }

    if ($deleted) {
        _ensure_dir($file);
        lock_nstore($table, $file);
        chmod 0600, $file;
    }

    return $deleted;
}


1;  # Module END
