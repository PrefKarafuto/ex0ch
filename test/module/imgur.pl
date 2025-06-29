package IMGUR;
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use MIME::Base64;
use JSON;
use Storable qw(lock_retrieve lock_nstore);
use File::Spec;
use Digest::MD5 qw(md5_hex);

#------------------------------------------------------------------------------------------------------------
# コンストラクタ
# @return IMGURオブジェクト
#------------------------------------------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $this = {
        client_id     => undef,
        client_secret => undef,
        access_token  => undef,
        refresh_token => undef,
        state_file    => undef,
        history       => [],
    };
    bless $this, $class;
    return $this;
}

#------------------------------------------------------------------------------------------------------------
# 設定と履歴読み込み
# @param $Sys SYSTEMオブジェクト
#------------------------------------------------------------------------------------------------------------
sub Load {
    my ($this, $Sys) = @_;
    # 設定取得
    $this->{client_id}     = $Sys->Get('IMGUR_ID');
    $this->{client_secret} = $Sys->Get('IMGUR_SECRET');
    # 状態ファイルパス
    $this->{state_file}    = File::Spec->catfile('.', $Sys->Get('INFO'), '/imgur_history.cgi');
    # 状態読み込み
    my $st = eval { lock_retrieve($this->{state_file}) };
    chmod($Sys->Get('PM-ADM'), $this->{state_file});
    if (ref $st eq 'HASH') {
        $this->{refresh_token} = $st->{refresh_token};
        $this->{access_token}  = $st->{access_token};
        $this->{history}       = $st->{history} || [];
    }
}

#------------------------------------------------------------------------------------------------------------
# 画像アップロード
# @param $this IMGURオブジェクト
# @param $upload_fh ファイルハンドル
# @param $title    タイトル (任意)
# @param $desc     説明 (任意)
# @return ($err_code, $link)
#------------------------------------------------------------------------------------------------------------
sub Upload {
    my ($this, $upload_fh, $title, $desc, $info) = @_;
    binmode $upload_fh;
    local $/;
    my $data = <$upload_fh>;
    # 重複検出用 MD5
    my $digest = md5_hex($data);
    if (my ($old) = grep { $_->{digest} eq $digest } @{$this->{history}}) {
        return (0, $old->{link});
    }

    # アクセストークンを更新（リフレッシュトークンから再取得）
    if ($this->{refresh_token}) {
        my $err = $this->_refresh_access_token();
        return $ZP::E_IMG_FAILEDGETTOKEN unless $err;
    }

    # 認証ヘッダ
    my $auth = $this->{access_token} ?
        "Bearer $this->{access_token}" :
        "Client-ID $this->{client_id}";

    # Base64 エンコード
    my $img64 = encode_base64($data, '');
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $res = $ua->post(
        'https://api.imgur.com/3/image',
        'Authorization' => $auth,
        Content => {
            image       => $img64,
            type        => 'base64',
            title       => $title // '',
            description => $desc  // '',
        },
    );
    return $ZP::E_IMG_FAIEDPOST unless $res->is_success;
    my $json = decode_json($res->decoded_content);
    return $ZP::E_IMG_FAILEDUPLOAD unless $json->{success};

    # 結果
    my $link       = $json->{data}{link};
    my $deletehash = $json->{data}{deletehash};

    # 履歴追加
    push @{$this->{history}}, {
        time       => time,
        mode       => $this->{access_token} ? 'oauth' : 'anonymous',
        link       => $link,
        deletehash => $deletehash,
        digest     => $digest,
        title      => $title // '',
        description=> $desc  // '',
        information=> $info  // '',
    };

    $this->Save();
    return (0, $link);
}

#------------------------------------------------------------------------------------------------------------
# 画像削除
# @param $this IMGURオブジェクト
# @param $deletehash 削除ハッシュ
# @return $success
#------------------------------------------------------------------------------------------------------------
sub Delete {
    my ($this, $deletehash) = @_;
    return 0 unless $deletehash;

    # アクセストークンを更新（リフレッシュトークンから再取得）
    if ($this->{refresh_token}) {
        my $err = $this->_refresh_access_token();
        return 0 unless $err;
    }

    my $auth = $this->{access_token} ?
        "Bearer $this->{access_token}" :
        "Client-ID $this->{client_id}";
    
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $res = $ua->delete(
        "https://api.imgur.com/3/image/$deletehash",
        'Authorization' => $auth,
    );
    return 0 unless $res->is_success;
    my $json = decode_json($res->decoded_content);
    return 0 unless $json->{success};

    # 履歴から除外
    my @new = grep { $_->{deletehash} ne $deletehash } @{$this->{history}};
    $this->{history} = \@new;

    $this->Save();
    return 1;
}

#------------------------------------------------------------------------------------------------------------
# 履歴取得
# @param $this IMGURオブジェクト
#------------------------------------------------------------------------------------------------------------
sub GetHist {
    my $this = shift;
    return @{ $this->{history} };
}

#------------------------------------------------------------------------------------------------------------
# 履歴保存
# @param $this IMGURオブジェクト
#------------------------------------------------------------------------------------------------------------
sub Save {
    my $this = shift;
    my $st = {
        access_token  => $this->{access_token},
        refresh_token => $this->{refresh_token},
        history       => $this->{history},
    };
    lock_nstore($st, $this->{state_file});
}

#------------------------------------------------------------------------------------------------------------
# リンク存在チェック
# @param $this IMGURオブジェクト
# @param $link チェック対象リンク
# @return 履歴エントリ (存在時) / undef (未存在)
#------------------------------------------------------------------------------------------------------------
sub ExistsLink {
    my ($this, $link) = @_;
    for my $entry (@{$this->{history}}) {
        return $entry if defined $entry->{link} && $entry->{link} eq $link;
    }
    return;
}

#------------------------------------------------------------------------------------------------------------
# アップロード一覧取得＆ローカル履歴更新
# @param $this IMGURオブジェクト
# @return 更新件数
#------------------------------------------------------------------------------------------------------------
sub Refresh {
    my $this = shift;
    return 0 unless $this->{access_token};

    # アクセストークン更新
    if ($this->{refresh_token}) {
        my $ok = eval { $this->_refresh_access_token() };  
        return 0 if $@;
    }

    my $auth = "Bearer $this->{access_token}";
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $res = $ua->get(
        'https://api.imgur.com/3/account/me/images',
        'Authorization' => $auth,
    );
    return 0 unless $res->is_success;
    my $json = decode_json($res->decoded_content);
    return 0 unless $json->{success};

    # APIから全画像を取得
    my @imgs = @{ $json->{data} };
    # 既存履歴コピー
    my @old_hist = @{$this->{history}};

    # 新履歴生成
    my @new_history = map {
        my $img = $_;
        # 同じdeletehashの既存エントリを探す
        my ($old) = grep { $_->{deletehash} eq $img->{deletehash} } @old_hist;
        {
            time        => $img->{datetime},
            mode        => 'oauth',
            link        => $img->{link},
            deletehash  => $img->{deletehash},
            digest      => $old ? $old->{digest} : undef,
            title       => $img->{title}       || '',
            description => $img->{description} || '',
            information => $old ? $old->{information} : undef,
        }
    } @imgs;
    $this->{history} = \@new_history;
    $this->Save();
    return scalar @new_history;
}

#------------------------------------------------------------------------------------------------------------
# アクセストークン更新
# @param $this IMGURオブジェクト
#------------------------------------------------------------------------------------------------------------
sub _refresh_access_token {
    my $this = shift;
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $res = $ua->post(
        'https://api.imgur.com/oauth2/token',
        Content => {
            client_id     => $this->{client_id},
            client_secret => $this->{client_secret},
            grant_type    => 'refresh_token',
            refresh_token => $this->{refresh_token},
        },
    );
    return 0 unless $res->is_success;
    my $json = decode_json($res->decoded_content);
    return 0 unless $json->{access_token};

    # 新しいトークンを設定
    $this->{access_token}  = $json->{access_token};
    $this->{refresh_token} = $json->{refresh_token} // $this->{refresh_token};
    
    return 1;
}

1;
