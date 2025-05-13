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

use File::Path qw(make_path);
use POSIX qw(strftime);
use CGI::Session;
use CGI::Cookie;
use Digest::MD5;
use Storable qw(lock_store lock_retrieve);
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

    # ディレクトリ確実に作成
    unless (-d $ninDir) {
        make_path($ninDir, "$ninDir/hash");
    }

    my $sid = $Sys->Get('SID');
    my $sid_before;

    # パスワード指定時
    if ($password) {
        # 期限（日数）
        my $exp_days    = $Sys->Get('PASS_EXPIRY') || 1;
        my $long_expiry = 60 * 60 * 24 * $exp_days;

        # パスワードダイジェスト（キー）
        my $ctx  = Digest::MD5->new;
        $ctx->add($Sys->Get('SECURITY_KEY'), ':', $password);
        my $hash = $ctx->hexdigest;

        # 管理ファイル
        my $pw_file = "$ninDir/hash/password.cgi";
        # 既存テーブル読み込み or 空ハッシュ
        my $table = (-e $pw_file) ? lock_retrieve($pw_file) : {};

        if (exists $table->{$hash}) {
            my $entry = $table->{$hash};

            # 有効期限内？
            if ($entry->{time} + $long_expiry >= time) {
                # タイムスタンプ更新して保存
                $entry->{time} = time;
                lock_store($table, $pw_file);

                # 保存済 SID を取得
                my $saved = $entry->{value};
                if ($saved ne $sid) {
                    $sid_before = $sid;
                    $sid        = $saved;
                }
            } else {
                # 期限切れ→削除してエラー
                delete $table->{$hash};
                lock_store($table, $pw_file);
                return undef;
            }
        } else {
            # キーなし→エラー
            return undef;
        }
    }

    # セッション読み込み or 新規作成
    my $session = CGI::Session->new(
        "driver:file;serializer:storable", $sid,
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
        "driver:file;serializer:storable", $sid,
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

#------------------------------------------------------------------------------------------------------------
#   admin 用: セッション削除
#------------------------------------------------------------------------------------------------------------
sub Delete {
    my ($this, $Sys, $sid_array_ref) = @_;
    my $ninDir = "." . $Sys->Get('INFO') . "/.ninpocho/";
    my $count = 0;
    foreach my $sid (@$sid_array_ref) {
        my $session = CGI::Session->load(
            "driver:file;serializer:storable", $sid,
            { Directory => $ninDir }
        );
        next unless $session;
        # 期限切れ判定
        if ($session->is_expired) {
            $session->delete;
            $session->flush;
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
        lock_store($table, $file);
        chmod 0600, $file;
    }
    return $count;
}

sub DeleteOnly {
    my $this = shift;
    return unless $this->{SESSION};
    $this->{SESSION}->delete;
    $this->{SESSION}->flush;
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
        my $file = "$ninDir/hash/pw-$hash.cgi";

        # 既存パスワード削除
        if (my $old = $this->{SESSION}->param('password_file_hash')) {
            unlink "$ninDir/hash/pw-$old.cgi" if -e "$ninDir/hash/pw-$old.cgi";
        }

        # テーブルに書き込み
        my $table = -e $file ? lock_retrieve($file) : {};
        $table->{sid} = { value => $this->{SID}, time => time };
        lock_store($table, $file);
        chmod 0600, $file;
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
    return 1;
}

1;  # Module END
