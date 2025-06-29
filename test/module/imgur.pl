package IMGUR;
use strict;
use warnings;
use utf8;
use open IO => ':encoding(cp932)';
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET DELETE);
use MIME::Base64;
use JSON;
use Storable qw(lock_retrieve lock_nstore);
use Digest::MD5 qw(md5_hex);

#------------------------------------------------------------------------------------------------------------
# コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = {
        client_id     => undef,
        client_secret => undef,
        access_token  => undef,
        refresh_token => undef,
        expires_at    => 0,          # トークン有効期限タイムスタンプ
        username      => undef,      # OAuth 時のアカウント名
        state_file    => undef,
        history       => [],         # { time, mode, link, deletehash, digest, title, description, information }
    };
    return bless $self, $class;
}

#------------------------------------------------------------------------------------------------------------
# 設定と履歴読み込み
#------------------------------------------------------------------------------------------------------------
sub Load {
    my ($self, $Sys) = @_;

    $self->{client_id}     = $Sys->Get('IMGUR_ID');
    $self->{client_secret} = $Sys->Get('IMGUR_SECRET');

    # 先頭スラッシュを外して相対パスに
    $self->{state_file} = '.' . $Sys->Get('INFO') . '/imgur_history.cgi';

    # 状態ファイル読み込み
    my $st = eval { lock_retrieve($self->{state_file}) };
    if ($@) {
        warn "IMGUR: state_file read error: $@";
    }
    if (ref $st eq 'HASH') {
        $self->{access_token}  = $st->{access_token};
        $self->{refresh_token} = $st->{refresh_token};
        $self->{expires_at}    = $st->{expires_at}    // 0;
        $self->{username}      = $st->{username};
        $self->{history}       = $st->{history}       || [];
    }

    # パーミッション設定
    chmod $Sys->Get('PM-ADM'), $self->{state_file};
}

#------------------------------------------------------------------------------------------------------------
# 履歴保存
#------------------------------------------------------------------------------------------------------------
sub Save {
    my $self = shift;
    my $st = {
        access_token  => $self->{access_token},
        refresh_token => $self->{refresh_token},
        expires_at    => $self->{expires_at},
        username      => $self->{username},
        history       => $self->{history},
    };
    eval { lock_nstore($st, $self->{state_file}) }
      or warn "IMGUR: state_file write error: $@";
}

#------------------------------------------------------------------------------------------------------------
# 最初の OAuth 認可用 URL を返す
#------------------------------------------------------------------------------------------------------------
sub GetAuthorizationUrl {
    my ($self, $redirect_uri, $state) = @_;
    return unless $self->{client_id};
    return sprintf
      "https://api.imgur.com/oauth2/authorize?client_id=%s&response_type=code&state=$state&redirect_uri=%s",
      $self->{client_id}, $redirect_uri;
}

#------------------------------------------------------------------------------------------------------------
# OAuth Code からアクセストークンを取得（最初の一度だけ）
#------------------------------------------------------------------------------------------------------------
sub ObtainAccessToken {
    my ($self, $code) = @_;
    my $ua = LWP::UserAgent->new( timeout => 10 );
    my $res = $ua->post(
        'https://api.imgur.com/oauth2/token',
        Content => {
            client_id     => $self->{client_id},
            client_secret => $self->{client_secret},
            grant_type    => 'authorization_code',
            code          => $code,
        },
    );
    return 0 unless $res->is_success;
    my $json = eval { decode_json($res->decoded_content) };
    return 0 unless $json && $json->{access_token};

    $self->{access_token}  = $json->{access_token};
    $self->{refresh_token} = $json->{refresh_token};
    $self->{expires_at}    = time + ($json->{expires_in} || 0);
    return 1;
}

#------------------------------------------------------------------------------------------------------------
# アクセストークン有効期限チェック＆必要時リフレッシュ
#------------------------------------------------------------------------------------------------------------
sub _ensure_access_token {
    my $self = shift;
    # OAuth 未設定 or anonymous 時はスキップ
    return 1 unless $self->{refresh_token};

    if (!$self->{access_token} || time >= $self->{expires_at}) {
        return $self->_refresh_access_token();
    }
    return 1;
}

#------------------------------------------------------------------------------------------------------------
# リフレッシュトークンからアクセストークン更新
#------------------------------------------------------------------------------------------------------------
sub _refresh_access_token {
    my $self = shift;
    my $ua = LWP::UserAgent->new( timeout => 10 );
    my $res = $ua->post(
        'https://api.imgur.com/oauth2/token',
        Content => {
            client_id     => $self->{client_id},
            client_secret => $self->{client_secret},
            grant_type    => 'refresh_token',
            refresh_token => $self->{refresh_token},
        },
    );
    return 0 unless $res->is_success;
    my $json = eval { decode_json($res->decoded_content) };
    return 0 unless $json && $json->{access_token};

    $self->{access_token}  = $json->{access_token};
    $self->{refresh_token} = $json->{refresh_token} // $self->{refresh_token};
    $self->{expires_at}    = time + ($json->{expires_in} || 0);
    return 1;
}

#------------------------------------------------------------------------------------------------------------
# 画像アップロード
# @return ($err_code, $link)
#------------------------------------------------------------------------------------------------------------
sub Upload {
    my ($self, $upload_fh, $title, $desc, $info) = @_;
    binmode $upload_fh;
    local $/;
    my $data = <$upload_fh>;

    # 重複 MD5 チェック
    my $digest = md5_hex($data);
    if (my ($old) = grep { $_->{digest} eq $digest } @{ $self->{history} }) {
        return (0, $old->{link});
    }

    # トークン有効性チェック
    unless ($self->_ensure_access_token()) {
        return ($ZP::E_IMG_FAILEDGETTOKEN, undef);
    }

    # 認証ヘッダ
    my $auth = $self->{access_token}
      ? "Bearer $self->{access_token}"
      : "Client-ID $self->{client_id}";

    # Base64
    my $img64 = encode_base64($data, '');

    # リクエスト作成
    my $req = POST 'https://api.imgur.com/3/image',
      Content_Type => 'application/x-www-form-urlencoded',
      Content      => {
        image       => $img64,
        type        => 'base64',
        title       => $title // '',
        description => $desc  // '',
      };
    $req->header( Authorization => $auth );

    my $ua  = LWP::UserAgent->new( timeout => 10 );
    my $res = $ua->request($req);
    return ($ZP::E_IMG_FAILEDPOST, undef) unless $res->is_success;

    my $json = eval { decode_json($res->decoded_content) };
    return ($ZP::E_IMG_FAILEDUPLOAD, undef) unless $json && $json->{success};

    my $link       = $json->{data}{link};
    my $deletehash = $json->{data}{deletehash};

    # 履歴追加
    push @{ $self->{history} }, {
        time        => time,
        mode        => $self->{access_token} ? 'oauth' : 'anonymous',
        link        => $link,
        deletehash  => $deletehash,
        digest      => $digest,
        title       => $title // '',
        description => $desc  // '',
        information => $info  // '',
    };
    $self->Save;
    return (0, $link);
}

#------------------------------------------------------------------------------------------------------------
# 画像削除
# @return $success
#------------------------------------------------------------------------------------------------------------
sub Delete {
    my ($self, $deletehash) = @_;
    return 0 unless $deletehash;

    unless ($self->_ensure_access_token()) {
        warn "IMGUR: token refresh failed";
        return 0;
    }

    my $auth = $self->{access_token}
      ? "Bearer $self->{access_token}"
      : "Client-ID $self->{client_id}";

    my $ua = LWP::UserAgent->new( timeout => 10 );
    my $url;

    if ($self->{access_token}) {
        # OAuth 時は /account/{username}/image/{deletehash}
        unless ($self->{username}) {
            # username が未取得なら一度取得
            my $req0 = GET 'https://api.imgur.com/3/account/me',
              Authorization => $auth;
            my $res0 = $ua->request($req0);
            if ($res0->is_success) {
                my $j = eval { decode_json($res0->decoded_content) };
                $self->{username} = $j->{data}{url} if $j && $j->{data}{url};
                $self->Save;
            }
        }
        $url = sprintf "https://api.imgur.com/3/account/%s/image/%s",
          $self->{username}, $deletehash;
    }
    else {
        # 匿名アップロード
        $url = "https://api.imgur.com/3/image/$deletehash";
    }

    my $req = HTTP::Request->new( DELETE => $url );
    $req->header( Authorization => $auth );
    my $res = $ua->request($req);
    return 0 unless $res->is_success;

    my $json = eval { decode_json($res->decoded_content) };
    return 0 unless $json && $json->{success};

    # 履歴から除去
    $self->{history} = [
        grep { $_->{deletehash} ne $deletehash } @{ $self->{history} }
    ];
    $self->Save;
    return 1;
}

#------------------------------------------------------------------------------------------------------------
# 自分のアカウント画像一覧取得＆ページネーション対応
# @return 更新件数
#------------------------------------------------------------------------------------------------------------
sub Refresh {
    my $self = shift;
    return 0 unless $self->{access_token};
    return 0 unless $self->_ensure_access_token();

    my $auth = "Bearer $self->{access_token}";
    my $ua   = LWP::UserAgent->new( timeout => 10 );
    my @all_imgs;
    my $page = 0;

    while (1) {
        my $url = "https://api.imgur.com/3/account/me/images?page=$page";
        my $req = GET $url, Authorization => $auth;
        my $res = $ua->request($req);
        last unless $res->is_success;

        my $json = eval { decode_json($res->decoded_content) };
        last unless $json && $json->{success};

        my $data = $json->{data};
        last unless ref $data eq 'ARRAY' && @$data;
        push @all_imgs, @$data;
        $page++;
    }

    # 新履歴生成
    my @old = @{ $self->{history} };
    my @new = map {
        my $img = $_;
        my ($old_ent) = grep { $_->{deletehash} eq $img->{deletehash} } @old;
        {
            time        => $img->{datetime},
            mode        => 'oauth',
            link        => $img->{link},
            deletehash  => $img->{deletehash},
            digest      => $old_ent ? $old_ent->{digest} : undef,
            title       => $img->{title}       || '',
            description => $img->{description} || '',
            information => $old_ent  ? $old_ent->{information} : undef,
        }
    } @all_imgs;

    $self->{history} = \@new;
    $self->Save;
    return scalar @new;
}

#------------------------------------------------------------------------------------------------------------
# 履歴取得
#------------------------------------------------------------------------------------------------------------
sub GetHist {
    my $self = shift;
    return @{ $self->{history} };
}

#------------------------------------------------------------------------------------------------------------
# リンク存在チェック
#------------------------------------------------------------------------------------------------------------
sub ExistsLink {
    my ($self, $link) = @_;
    for my $e (@{ $self->{history} }) {
        return $e if defined $e->{link} && $e->{link} eq $link;
    }
    return;
}

1;
