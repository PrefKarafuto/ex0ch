#===============================================================================
#  dsl_engine.pl
#
#  DSL ルールファイル (例: dsl_rules.cgi) の読み込み・保存・全体編集・
#  個別関数単位での評価・文法チェックを行うモジュール。
#  「%ctx」は読み取り専用とし、出力用に「%out」を用意して呼び出し元に返す。
#
#  提供メソッド：
#    new, Load, Save, Set, Get, SetCtx, Check, GetOutResult, syntax_check
#
#  使い方例:
#    use lib '/path/to/this/script';
#    use DSL::Engine;
#
#    my $engine = DSL::Engine->new( file_path => '/path/to/dsl_rules.cgi' );
#    $engine->Load() or die "Load failed\n";
#
#    # 管理画面で編集するときはファイル全体を取り出し、編集後にまるごとセット
#    my $full_text = $engine->Get();
#    # …管理画面で $full_text を編集して $edited_text を得る…
#    $engine->Set($edited_text);
#    $engine->Save() or die "Save failed\n";
#
#    # コンテキストを設定して DSL を実行
#    $engine->SetCtx({
#      message    => 'こんにちは',
#      mail       => '',
#      name       => 'ユーザー',
#      subject    => '',
#      time       => time(),
#      thread_id  => '',
#      bbs        => 'testbbs',
#      fp         => '',
#      ip         => '127.0.0.1',
#      host       => 'localhost',
#      ua         => 'Mozilla/5.0',
#      session_id => 'ABC123',
#      setting    => { require_admin => 0 },
#      attr       => { is_admin => 0, is_locked => 0 },
#      user_info  => { last_post_time => time()-60, last_message => '' },
#      score      => 0,
#      unique     => {},
#    });
#    $engine->Check();
#
#    # 関数単位でエラーのあったルールを参照
#    if (my $errors = $engine->{_check_error}) {
#      foreach my $rule (keys %{$errors}) {
#        warn "Rule '$rule' error: $errors->{$rule}\n";
#      }
#    }
#
#    # DSL 実行後の出力用ハッシュを取得
#    my $out_ref = $engine->GetOutResult();
#    # 例: $out_ref->{message} に DSL がセットした文字列が入る
#
#    # DSL ファイル全体の構文チェック
#    $engine->syntax_check()
#      or warn "File syntax error: " . $engine->{_syntax_error};
#===============================================================================

package DSL::Engine;
use strict;
use warnings;
use utf8;
use open IO => ':encoding(cp932)';

use Safe;
use Carp;
use Storable qw(dclone);


#------------------------------------------------------------------------------#
# パッケージ変数: 
#   %ctx  - DSL 実行時の読み取り専用コンテキスト
#   %out  - DSL 実行時の出力用ハッシュ (呼び出し元に渡す)
#------------------------------------------------------------------------------#
our %ctx = ();
our %out = ();

#------------------------------------------------------------------------------#
# コンストラクタ: new
#------------------------------------------------------------------------------#
# 引数:
#   file_path => 'dsl_rules.cgi'   # DSL ルールファイルのパス (必須)
# 戻り値:
#   オブジェクト (ハッシュリファレンス)
sub new {
    my ($class, $Sys) = @_;
    my $self = {};

    $self->{file_path}      = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . "/info/dsl_rules.cgi";
    $self->{dsl_text}       = '';     # ファイル全体の文字列
    $self->{_check_error}   = {};     # Check() での各関数単位のエラーを格納
    $self->{_syntax_error}  = '';     # syntax_check() でのエラー

    # Safe コンパートメントを初期化
    my $comp = Safe->new('DSL::SafeCompartment');
    $comp->permit_only(
        ':base_core',
        ':base_loop',
        ':base_math',
        ':base_orig',
    );
    $self->{_safe}      = $comp;
    $self->{_coderefs}  = {};    # 成功した関数のコード参照を格納
    bless $self, $class;
    return $self;
}

#------------------------------------------------------------------------------#
# メソッド: Load
#  DSL ファイルを読み込み、内部キャッシュ (dsl_text) に保持する
# 戻り値: 成功 => 1, 失敗 => 0
#------------------------------------------------------------------------------#
sub Load {
    my ($self) = @_;
    my $path = $self->{file_path};

    open my $fh, '<', $path
      or do {
        carp "Load: cannot open '$path': $!";
        return 0;
      };
    local $/;    # スラープモード
    my $content = <$fh>;
    close $fh;

    $self->{dsl_text} = $content;
    return 1;
}

#------------------------------------------------------------------------------#
# メソッド: Save
#  内部キャッシュ (dsl_text) をファイルに上書き保存する
# 戻り値: 成功 => 1, 失敗 => 0
#------------------------------------------------------------------------------#
sub Save {
    my ($self) = @_;
    my $path    = $self->{file_path};
    my $content = $self->{dsl_text};

    open my $fh, '>', $path
      or do {
        carp "Save: cannot open '$path': $!";
        return 0;
      };
    print $fh $content;
    close $fh;

    return 1;
}

#------------------------------------------------------------------------------#
# メソッド: Get
#  引数なし。DSL ファイル全体のテキストを返す
#------------------------------------------------------------------------------#
sub Get {
    my ($self) = @_;
    return $self->{dsl_text};
}

#------------------------------------------------------------------------------#
# メソッド: Set
#  引数: $new_text
#  DSL ファイル全体をまるごと置き換える
# 戻り値: 成功 => 1
#------------------------------------------------------------------------------#
sub Set {
    my ($self, $new_text) = @_;
    croak "Set: new_text is required" unless defined $new_text;
    $self->{dsl_text} = $new_text;
    return 1;
}

#------------------------------------------------------------------------------#
# メソッド: SetCtx
#  引数: $hashref (参照)
#  メイン側で処理すべきコンテキストを設定する（読み取り専用）
# 戻り値: 成功 => 1
#------------------------------------------------------------------------------#
sub SetCtx {
    my ($self, $ctx_ref) = @_;
    croak "SetCtx: hashref required" unless ref($ctx_ref) eq 'HASH';

    # グローバル %ctx を上書き（読み取り専用として使う）
    %ctx = %{$ctx_ref};
    return 1;
}

#------------------------------------------------------------------------------#
# メソッド: Check
#
#   引数:
#     $timeout  - ルール実行ごとのタイムアウト秒 (省略可)
#     $mode     - 'syntax' を渡すと「構文チェック（ルール単位）」、それ以外は「DSL 評価」
#
#  戻り値:
#   - $mode eq 'syntax' のとき => ルールごとのステータスを格納したハッシュリファレンス
#         (例) { RuleA => 0, RuleB => 2, RuleC => 4, … }
#   - それ以外 (評価モード) のとき => 0 (_DENY_) または 1 (_ACCEPT_)
#
#  内部で行うこと:
#   1) %ctx をディープコピーして %out に初期化
#   2) Safe に %ctx, %out, _DENY_/_ACCEPT_ 定数, ZP::* 定数 を共有
#   3) トップレベルコードを一度 Safe で評価
#   4) 各ルールを個別に Safe で定義し、$self->{_coderefs} に格納
#   5) $mode eq 'syntax' の場合は「ルール毎に eval だけ行い文法エラー or 正規表現エラー or 重複チェック」を実施し、
#      $self->{_rule_status}, $self->{_rule_error} に結果をセットしてハッシュリファレンスを返す
#   6) 評価モードの場合は「各ルールのコードリファレンスを呼び出し、最初に _DENY_ を返したら即座に 0 を返し、
#      すべて _ACCEPT_ なら最終的に 1 を返す」
#------------------------------------------------------------------------------#
sub Check {
    my ($self, $timeout_arg, $mode) = @_;

    # (A) エラー情報・コード参照をクリア
    $self->{_check_error} = {};
    $self->{_coderefs}   = {};
    $self->{_rule_status} = {};   # 構文チェックモード用
    $self->{_rule_error}  = {};   # 構文チェックモード用

    # (B) %ctx をディープコピーして %out に初期化
    #     → DSL 評価モードでは %out に結果を書き込む。構文チェックモードでも初期化だけ行う
    %out = %{ dclone(\%ctx) };

    # (C) Safe に %ctx, %out を共有
    $self->{_safe}->share_from('DSL::Engine', ['%ctx', '%out']);
    my $comp = $self->{_safe};

    # (D) Safe 名称空間に定数 _DENY_ / _ACCEPT_ を定義
    $comp->reval(<<'CONST');
        package DSL::SafeCompartment;
        use constant _DENY_   => 0;
        use constant _ACCEPT_ => 1;
        use constant _PASS_   => 2;
CONST

    # (E) さらに、ZP パッケージに定義された our スカラ変数を自動列挙して共有
    {
        no strict 'refs';
        my @zp_scalars;
        foreach my $symbol (keys %ZP::) {
            if (defined *{"ZP::$symbol"}{SCALAR}) {
                push @zp_scalars, '$' . $symbol;
            }
        }
        use strict 'refs';
        $comp->share_from('ZP', \@zp_scalars);
    }

    # (F) トップレベルコード（サブルーチンヘルパー定義や my 変数定義など）を Safe 上で評価
    my $dsl        = $self->{dsl_text};
    my $top_level  = $dsl;
    foreach my $rule (_parse_all_rules($dsl)) {
        my $raw = $rule->{raw};
        $top_level =~ s/\Q$raw\E//g;
    }
    my $wrapped_top = "package DSL::SafeCompartment;\n" . $top_level;
    $comp->reval($wrapped_top);
    if (my $err = $@) {
        chomp $err;
        $self->{_check_error}{_TOPLEVEL_} = $err;
        # トップレベルに構文エラーがあっても、続行して個別ルール定義を試みる
    }

    # (G) 各ルールブロックを個別に Safe で定義 → コード参照を取得して保持
    #     定義時に文法エラーが起きたルールは $self->{_check_error}{$name} にエラーを記録
    my @all_rules = _parse_all_rules($dsl);
    foreach my $rule (@all_rules) {
        my $name = $rule->{name};
        my $raw  = $rule->{raw};   # 例: "RuleFoo sub { … }"

        # "sub { … }" 部分だけ抽出
        my ($inner) = $raw =~ /^\s*\Q$name\E\s+(sub\s*\{.*\})\s*$/s;
        unless (defined $inner) {
            $self->{_check_error}{$name} = "Malformed block for rule '$name'";
            next;
        }

        # 本文を取り出して "sub $name { … }" に変換
        my ($body) = $inner =~ /^sub\s*\{(.*)\}\s*$/s;
        unless (defined $body) {
            $self->{_check_error}{$name} = "Cannot extract body for rule '$name'";
            next;
        }
        my $named = "sub $name { $body }";

        # Safe 上で評価してサブルーチン定義
        $comp->reval("package DSL::SafeCompartment;\n$named");
        if (my $err2 = $@) {
            chomp $err2;
            $self->{_check_error}{$name} = $err2;
            next;
        }

        # 定義済みの CODE リファレンスを取得して保持
        no strict 'refs';
        my $coderef = $comp->reval(qq{
            package DSL::SafeCompartment;
            $named
            \\&$name;
        });
        use strict 'refs';
        if (defined $coderef && ref($coderef) eq 'CODE') {
            $self->{_coderefs}{$name} = $coderef;
        }
        else {
            $self->{_check_error}{$name} = "Failed to locate sub $name in Safe";
        }
    }

    # (H) ここからモード別に分岐
    if (defined $mode && $mode eq 'syntax') {
        # ----------------------------
        # 【構文チェックモード】ルール単位で文法・正規表現・重複をチェック
        # ----------------------------
        # (H-1) ルール名の重複チェック
        my %count_name;
        $count_name{ $_->{name} }++ foreach @all_rules;

        foreach my $rule (@all_rules) {
            my $name = $rule->{name};

            # (H-1-a) 重複チェック
            if ($count_name{$name} > 1) {
                $self->{_rule_status}{$name} = 4;    # 4 = 重複ルール名
                $self->{_rule_error}{$name}  = "Duplicate rule name '$name'";
                next;
            }

            # (H-1-b) まず「Safe 上に定義するだけ」で構文エラー／正規表現エラーを検出
            #         ※ 既に定義時に Safe->reval() で文法エラーを _check_error に入れている可能性アリ
            if (exists $self->{_check_error}{$name}) {
                # 定義時点でエラーがあった場合
                my $e = $self->{_check_error}{$name};
                # 正規表現エラーか文法エラーかを判別
                if ($e =~ /Unmatched|regex|\\Q.*\\E.*doesn't match/ ) {
                    $self->{_rule_status}{$name} = 3;    # 3 = 正規表現文法エラー
                } else {
                    $self->{_rule_status}{$name} = 2;    # 2 = ルール文法エラー
                }
                $self->{_rule_error}{$name} = $e;
                next;
            }

            # (H-1-c) 定義自体は成功しているので「正常完了」
            $self->{_rule_status}{$name} = 0;    # 0 = OK
            $self->{_rule_error}{$name}  = '';
        }

        # 最終的に「ルール名 => ステータス」のハッシュリファレンスを返す
        return $self->{_rule_status};
    }
    else {
        # ----------------------------
        # 【評価モード】各ルールを Safe 上で呼び出し、最初に _DENY_ (=0) が返ったら 0、最後まで OK なら 1
        # ----------------------------
        my $timeout = defined $timeout_arg ? $timeout_arg : $self->{timeout};

        foreach my $rule (@all_rules) {
            my $name = $rule->{name};
            next unless exists $self->{_coderefs}{$name};
            my $coderef = $self->{_coderefs}{$name};

            # タイムアウト設定
            local $SIG{ALRM} = sub { die "DSL_TIMEOUT\n" };
            alarm $timeout;

            my $result;
            eval {
                $result = $coderef->(\%ctx);
                alarm 0;  # 正常終了したらすぐにアラーム解除
            };
            alarm 0;  # 念のためここでも解除

            if (my $e = $@) {
                chomp $e;
                if ($e eq 'DSL_TIMEOUT') {
                    $self->{_check_error}{$name} = "Timeout in rule '$name'";
                }
                else {
                    $self->{_check_error}{$name} = "Runtime error in rule '$name': $e";
                }
                next;
            }

            # 返り値に応じて振り分ける
            if (!defined $result) {
                # undefined もパスとみなす
                next;
            }
            elsif ($result == 0) {
                # _DENY_ -> 即座に拒否
                return 0;
            }
            elsif ($result == 1) {
                # _ACCEPT_ -> 即座に許可
                return 1;
            }
            elsif ($result == 2) {
                # _PASS_ -> 明示的に次のルールへ
                next;
            }
            else {
                # それ以外（想定外）はパス扱い
                next;
            }
        }
        # すべてのルールが _ACCEPT_ (=1) を返した場合
        return 1;  # _ACCEPT_
    }
}


#------------------------------------------------------------------------------#
# メソッド: GetOutResult
#  Check() 実行後の %out をそのままハッシュリファレンスで返す
#  たとえばDSL内で $out{message} = $ctx{message} . 'test'; と書くと、
#  呼び出し元では GetOutResult()->{message} に '...test' が入る。
#------------------------------------------------------------------------------#
sub GetOutResult {
    my ($self) = @_;
    return { %out };  # 元ハッシュをコピーして返す
}

#------------------------------------------------------------------------------#
# メソッド: syntax_check
#  DSL ファイル全体を Perl -c で構文チェックする
#  失敗時は _syntax_error にエラーメッセージをセット
# 戻り値: 正常 => 1, エラー => 0
#------------------------------------------------------------------------------#
sub syntax_check {
    my ($self) = @_;
    $self->{_syntax_error} = '';
    my $path = $self->{file_path};

    # perl -c をバッククォートで呼び出し、その出力とステータスを確認
    my $output = `perl -c $path 2>&1`;
    my $status = $? >> 8;
    if ($status != 0) {
        chomp $output;
        $self->{_syntax_error} = $output;
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------#
# 内部サブルーチン: _parse_all_rules
#  引数: $dsl_text
#  DSL テキスト全体から、すべての "RuleName sub { … }" ブロックを検出し、
#  名前、ブロック本体、raw（元の文字列）を配列として返す。
#  戻り値: @rules = ( { name => 'RuleName', body => "sub { … }", raw => "RuleName sub { … }" }, … )
#------------------------------------------------------------------------------#
sub _parse_all_rules {
    my ($dsl) = @_;
    my @results;
    
    # pos() を最初にリセットしておく
    pos($dsl) = 0;

    # 「ルール名 sub {」に相当する箇所をグローバル検索
    RULE:
    while ( $dsl =~ /\b([A-Za-z_][A-Za-z0-9_]*)\b\s*sub\s*\{/g ) {
        my $name      = $1;
        # 全体文字列中で「'{' の位置」 = $+[0] - 1 になる
        my $open_brace_pos = $+[0] - 1;

        # ここから、ネストを数えて対応する '}' を探す
        my $nest = 1;  # この時点で '{' を１つ見つけたことにする
        my $i    = $open_brace_pos;
        my $length = length($dsl);
        my $end_pos;

        # 文字列を１文字ずつ走査し、ネストが 0 になる位置を探す
        for ( $i = $open_brace_pos + 1; $i < $length; ++$i ) {
            my $ch = substr($dsl, $i, 1);
            if ( $ch eq '{' ) {
                $nest++;
            }
            elsif ( $ch eq '}' ) {
                $nest--;
                if ( $nest == 0 ) {
                    $end_pos = $i;
                    last;
                }
            }
        }

        # 対応する '}' が見つからなかった場合はここで終了
        unless ( defined $end_pos ) {
            last;  # 以降のルールも探せないとみなし抜ける
        }

        # raw_block: ルール名から終端 '}' までの文字列を切り出す
        my $raw_block = substr( $dsl, $-[0], $end_pos - $-[0] + 1 );

        # サブルーチン部分 (body)（"sub { … }"）を抽出
        # raw_block の先頭には "RuleName sub { ... }" なので、正規表現で "sub { … }" 部分だけを取り出す
        my ($body) = $raw_block =~ /^\s*\Q$name\E\s+(sub\s*\{.*\})\s*$/s;
        # もしマッチしないなら構文が想定外である可能性があるので省く
        unless ( defined $body ) {
            next RULE;
        }

        push @results, {
            name => $name,
            body => $body,
            raw  => $raw_block,
        };

        # ループを継続するときは、pos($dsl) を「このルールの末尾」すなわち $end_pos + 1 にセットしておく
        pos($dsl) = $end_pos + 1;
    }

    return @results;
}

1;