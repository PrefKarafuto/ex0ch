package DSL_ENGINE;

use strict;
use warnings;
use utf8;
use open IO => ':encoding(cp932)';
use Fcntl qw(:flock);
use Carp;
use Time::Piece;
use Time::Seconds;
use Regexp::Grammars;
use LWP::UserAgent;
use JSON;
use File::stat;

# 最大再帰数
use constant MAX_DEPTH => 5;

# --- 定数・グローバル ---
our @RULES;    # パース済ルールAST

# --- DSL 文法定義 (Regexp::Grammars) ---
# <rule_file> 本体は下記のDSL_BODYで定義
my $DSL_BODY = qr{
  <rule_file>
    <[comment]>* <[rule_line]>* <[comment]>*
  <rule_file>

  <comment>
    (?: \# [^\n]* )
  | (?: '//' [^\n]* )
  | (?: '/\*' (?: .*? ) '\*/' )
  >x

  <rule_line>
    (?<raw>
      <name> ':' <ws>
      <list_type>? <ws>
      <cond: <group> ( <ws> <logic_op> <ws> <group> )* > <ws>
      '=>' <ws>
      <action: BLOCK|ALLOW_IP|REPLACE|SCORE_ADD|SCORE_SUB|SCORE_CLEAR|SCORE_GT|SET|USE > <ws>
      (<params: WITH <param_list> >)? <ws>
      ( ';' <ws> ERROR <ws> <error_code:\d+> )? <ws>
      (<meta>
         ';' <ws> (EXPIRE <ws> AT <ws> ".*?" | EXPIRE <ws> AFTER <ws> \( .*? \) | NOTIFY_ADMIN <ws> WITH <ws> code=\d+ | LOG_IF <ws> (?:true|false))
      >)* <ws>
    )
    ( <comment> )?
  <rule_line>

  <name:       /[A-Za-z_]\w*/ >
  <list_type:  /BLACKLIST|WHITELIST/ >

  <group>
    <expr>
  | '\(' <ws> <cond> <ws> '\)'
  >

  <expr>
    <field> <ws> <op> <ws> <value>
  >

  <field:
     message
   | mail
   | name
   | title
   | ip
   | ua
   | session_id
   | user_info\.[A-Za-z0-9_]+
   | unique\.[A-Za-z0-9_]+
  >

  <op:
       HAS|NOT_HAS|MATCH|EQ|NEQ|IN|NOT_IN|LT|GT|LE|GE
     | COUNT_WITHIN|UNIQUE_WITHIN|SCORE_ADD|SCORE_SUB|SCORE_CLEAR|SCORE_GT|API_CHECK|SET
  >

  <value>
    /"(?:[^"\\]|\\.)*"/s      # ダブルクォート文字列
  | /\[(?:[^\]\[]|\\.)*\]/s   # 配列リテラル
  | /\/(?:[^\/\\]|\\.)*\/[ismx]*/  # 正規表現
  | /\d+/                         # 数値
  | /\S+/                         # その他トークン
  >

  <logic_op: AND|OR >
  <param_list: <param> ( <ws> ',' <ws> <param> )* >
  <param: /[A-Za-z_]\w*/ '=' ( /"(?:[^"\\]|\\.)*"/ | /\d+/ ) >
  <error_code: /\d+/>  
  <ws: \s* >
}xms;
# 全文アンカー付き文法
my $DSL_GRAMMAR = qr{\A $DSL_BODY \z}xms;

#------------------------------------------------------------------------------
# split_rules: テキストをルールブロック単位に分割
#------------------------------------------------------------------------------
sub _split_rules {
    my ($text) = @_;
    my @lines = split /\n/, $text;
    my @blocks;
    my $cur = '';
    for my $line (@lines) {
        if ($line =~ /^\s*[A-Za-z_]\w*\s*:/) {
            push @blocks, $cur if $cur ne '';
            $cur = $line . "\n";
        } else {
            $cur .= $line . "\n";
        }
    }
    push @blocks, $cur if $cur ne '';
    return @blocks;
}

#------------------------------------------------------------------------------
# コンストラクタ
#------------------------------------------------------------------------------
sub new {
    my ($class) = @_;
    return bless { RULES => [], rule_file => undef }, $class;
}

#------------------------------------------------------------------------------
# Load: ファイルから読み込み、分割してパース
#------------------------------------------------------------------------------
sub Load {
    my ($this, $Sys) = @_;
    my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/dsl_rules.cgi';
    $this->{rule_file} = $path;
    local $/ = undef;
    open my $fh, '<', $path or return 1;
    my $text = <$fh>;
    close $fh;
    # ファイル更新時刻を created として利用
    my $created = Time::Piece->new( stat($path)->mtime );
    # ルールブロック分割
    my @blocks = _split_rules($text);
    $this->{RULES} = \@blocks;
    # ASTパース
    _load_rules_from_string($text, $created);
    return 0;
}

#------------------------------------------------------------------------------
# Save: 現在のRULESをファイルへ保存（ブロック単位）
#------------------------------------------------------------------------------
sub Save {
    my ($this, $Sys) = @_;
    croak 'No rule_file' unless $this->{rule_file};
    open my $fh, '>', $this->{rule_file} or croak $!;
    flock($fh, LOCK_EX);
    print $fh $_ for @{ $this->{RULES} };
    close $fh;
    return 0;
}

#------------------------------------------------------------------------------
# Add: 新規ブロックを文法検証後に追加
#------------------------------------------------------------------------------
sub Add {
    my ($this, $block) = @_;
    my ($ok, $errs) = validate_rule_syntax($block);
    croak "Validation error: @$errs" unless $ok;
    push @{ $this->{RULES} }, $block;
    my $all = join '', @{ $this->{RULES} };
    # 新規追加は現在時刻を created に設定
    _load_rules_from_string($all, Time::Piece->new);
    return 1;
}

#------------------------------------------------------------------------------
# Update: 名前でブロックを置換
#------------------------------------------------------------------------------
sub Update {
    my ($this, $name, $newblk) = @_;
    my $found = 0;
    for my $i (0..$#{ $this->{RULES} }) {
        if ($this->{RULES}[$i] =~ /^\s*\Q$name\E\s*:/) {
            $this->{RULES}[$i] = $newblk;
            $found = 1;
            last;
        }
    }
    croak "Rule '$name' not found" unless $found;
    my $all = join '', @{ $this->{RULES} };
    # 更新はロード時刻を preserved created には使わない
    _load_rules_from_string($all);
    return 1;
}

#------------------------------------------------------------------------------
# Delete: ブロック単位で削除
#------------------------------------------------------------------------------
sub Delete {
    my ($this, $name) = @_;
    my $before = @{ $this->{RULES} };
    @{ $this->{RULES} } = grep { $_ !~ /^\s*\Q$name\E\s*:/ } @{ $this->{RULES} };
    croak "Rule '$name' not found" if @{ $this->{RULES} } == $before;
    my $all = join '', @{ $this->{RULES} };
    _load_rules_from_string($all);
    return 1;
}

#------------------------------------------------------------------------------
# Clear: 全ブロッククリア
#------------------------------------------------------------------------------
sub Clear {
    my ($this) = @_;
    $this->{RULES} = [];
    @RULES = ();
    return 1;
}

#------------------------------------------------------------------------------
# List: ブロック名一覧
#------------------------------------------------------------------------------
sub List {
    my ($this) = @_;
    return map { /^\s*([A-Za-z_]\w*)/; $1 } @{ $this->{RULES} };
}

#------------------------------------------------------------------------------
# Check: ルール適用チェック
#------------------------------------------------------------------------------
sub Check {
    my ($ctx, $depth) = @_;
    $depth ||= 0;
    if ($depth > MAX_DEPTH) {
        return { action => 'allow', score => $ctx->{score} // 0 };
    }
    $ctx->{user_info}//={};
    $ctx->{unique}//={};
    $ctx->{score}//=0;
    my $now = Time::Piece->new;
    RULE: for my $r (@RULES) {
        next RULE if $r->{meta}{expire_at}    && $now > $r->{meta}{expire_at};
        next RULE if $r->{meta}{expire_after} && time > $r->{created}->epoch + $r->{meta}{expire_after};
        my $hit = eval_condition($r->{cond}, $ctx);
        if ($r->{list_type} && $r->{list_type} eq 'WHITELIST') {
            if ($hit) { notify($r); return { action => 'allow', by => $r->{name} } }
            next RULE;
        }
        if ($hit) {
            notify($r);
            my $act = $r->{action};
            if ($act eq 'BLOCK') {
                return { action => 'block', code => $r->{error_code}, by => $r->{name} };
            }
            elsif ($act eq 'ALLOW_IP') {
                return { action => 'allow_ip', msg => $r->{params}{code}, by => $r->{name} };
            }
            elsif ($act eq 'REPLACE') {
                my $pat_spec = $r->{params}{pattern}
                  or croak "REPLACE requires a 'pattern' parameter";
                my $pat = ref($pat_spec) eq 'Regexp'
                        ? $pat_spec
                        : qr/\Q$pat_spec\E/;
                my $to = $r->{params}{replace_to} // '';
                $ctx->{message} =~ s/$pat/$to/g;
            }
            elsif ($act eq 'SCORE_ADD') {
                $ctx->{score} += ($r->{params}{number} // 1);
            }
            elsif ($act eq 'SCORE_SUB') {
                $ctx->{score} -= ($r->{params}{number} // 1);
            }
            elsif ($act eq 'SCORE_CLEAR') {
                $ctx->{score} = 0;
            }
            elsif ($act eq 'SCORE_GT') {
                if ($ctx->{score} > ($r->{params}{number} // 0)) {
                    return { action => 'block', code => $r->{error_code}, by => $r->{name} };
                }
            }
            elsif ($act eq 'SET') {
                for my $k (keys %{ $r->{params} }) {
                    next unless $k =~ /^(user_info|unique)\.(.+)$/;
                    my ($ns,$key) = ($1,$2);
                    $ctx->{$ns}{$key} = $r->{params}{$k};
                }
            }
            elsif ($act eq 'USE') {
                Check($ctx, $depth + 1);
            }
            next RULE;
        }
    }
    return { action => 'allow', score => $ctx->{score} };
}

#------------------------------------------------------------------------------
# match_rules: 与えられたコンテキストでASTの@RULESを評価
#------------------------------------------------------------------------------
sub match_rules {
    my ($this, $ctx) = @_;
    $ctx->{user_info}//={};
    $ctx->{unique}//={};
    $ctx->{score}//=0;
    my @hits;
    for my $r (@RULES) {
        next if $r->{meta}{expire_at}    && Time::Piece->new > $r->{meta}{expire_at};
        next if $r->{meta}{expire_after} && time > $r->{created}->epoch + $r->{meta}{expire_after};
        push @hits, $r->{name} if eval_condition($r->{cond}, $ctx);
    }
    return @hits;
}

#------------------------------------------------------------------------------
# validate_rule_syntax: 文法と正規表現チェック
#------------------------------------------------------------------------------
sub validate_rule_syntax {
    my ($blk) = @_;
    $blk =~ s{//.*$}{}mg;
    $blk =~ s/#.*$//mg;
    $blk =~ s{/\*.*?\*/}{}gs;
    return (1, []) unless $blk =~ /\S/;
    unless ($blk =~ /^\A$DSL_BODY\z/ms) {
        return (0, ["DSL syntax error"]);
    }
    while ($blk =~ m{/(?:[^/\\]|\\.)+/[ismx]*}g) {
        my $pat = $&;
        my ($body,$flags) = $pat =~ m{^/(.*)/([ismx]*)$};
        eval { qr/$body/$flags };
        return (0, ["Regex error: $pat - $@"])
            if $@;
    }
    return (1, []);
}

#------------------------------------------------------------------------------
# decode_value: 配列リテラル中のカンマを正しく扱う
#------------------------------------------------------------------------------
sub decode_value {
    my ($raw) = @_;
    if ($raw =~ /^"(.*)"$/s) {
        return $1;
    }
    if ($raw =~ /^\[(.*)\]$/s) {
        my $inner = $1;
        my @vals;
        while ($inner =~ /\G\s*"((?:[^"\\]|\\.)*)"\s*(?:,|$)/g) {
            push @vals, $1;
        }
        return \@vals;
    }
    if ($raw =~ m{^/(.*)/([ismx]*)$}) {
        return eval { qr/$1/$2 };
    }
    return $raw =~ /^\d+$/ ? 0+$raw : $raw;
}

#------------------------------------------------------------------------------
# _load_rules_from_string: コメント除去後にDSLをパースし@RULESにセット
#------------------------------------------------------------------------------
sub _load_rules_from_string {
    my ($src, $created) = @_;
    $created //= Time::Piece->new;
    $src =~ s{//.*$}{}mg;
    $src =~ s/#.*$//mg;
    $src =~ s{/\*.*?\*/}{}gs;
    if ($src =~ $DSL_GRAMMAR) {
        my $parsed = {%/};
        @RULES = ();
        for my $r (@{ $parsed->{rule_file}{rule_line} || [] }) {
            my $meta = {};
            for my $m (@{ $r->{meta}||[] }) {
                if ($m =~ /EXPIRE\s+AT\s+"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})"/) {
                    $meta->{expire_at} = Time::Piece->strptime("$1 $2", "%Y-%m-%d %H:%M:%S");
                }
                elsif ($m =~ /EXPIRE\s+AFTER\s+\(\s*(\d+)(sec|min|h|d)\s*\)/) {
                    my ($n,$u)=($1,$2);
                    $meta->{expire_after} = $n * { sec=>1, min=>60, h=>3600, d=>86400 }->{$u};
                }
                elsif ($m =~ /NOTIFY_ADMIN\s+WITH\s+code=(\d+)/) {
                    $meta->{notify_admin} = $1;
                }
                elsif ($m =~ /LOG_IF\s+(true|false)/) {
                    $meta->{log_if} = $1 eq 'true';
                }
            }
            push @RULES, { %$r, meta=>$meta, created=>$created };
        }
    } else {
        croak "DSL parse failed";
    }
}

#------------------------------------------------------------------------------ 
# _check_duplicate_names: RULES 配列中のルール名重複チェック
#------------------------------------------------------------------------------ 
sub _check_duplicate_names {
    my ($blocks_ref) = @_;
    my %seen;
    my @dups;
    for my $blk (@$blocks_ref) {
        if ($blk =~ /^\s*([A-Za-z_]\w*)\s*:/) {
            push @dups, $1 if $seen{$1}++;
        }
    }
    if (@dups) {
        croak "Duplicate rule names found: " . join(', ', @dups);
    }
}


#------------------------------------------------------------------------------
# 条件評価ロジック
#------------------------------------------------------------------------------
sub eval_condition {
    my ($cond, $ctx) = @_;
    my $res = eval_expr_node($cond->{group}[0], $ctx);
    for my $i (0..$#{$cond->{logic_op}||[]}) {
        my $op   = $cond->{logic_op}[$i];
        my $next = eval_expr_node($cond->{group}[$i+1], $ctx);
        $res    = $op eq 'AND' ? ($res && $next) : ($res || $next);
    }
    return $res;
}

sub eval_expr_node {
    my ($node, $ctx) = @_;
    return $node->{expr}
      ? eval_expr($node->{expr}[0], $ctx)
      : eval_condition($node->{cond}[0], $ctx);
}

sub eval_expr {
    my ($e, $ctx) = @_;
    my $field = $e->{field}[0];
    my $val   = decode_value($e->{value}[0]);
    my $op    = $e->{op}[0];
    my $tgt =
       $field =~ /^user_info\.(.+)$/ ? ($ctx->{user_info}{$1}//'')
     : $field =~ /^unique\.(.+)$/    ? ($ctx->{unique}{$1}//'')
     :                               ($ctx->{$field}//'');
    my %ops = (
        HAS     => sub { index($tgt,$val) != -1 },
        NOT_HAS => sub { index($tgt,$val) == -1 },
        MATCH   => sub { $tgt =~ $val },
        EQ      => sub { $tgt eq $val },
        NEQ     => sub { $tgt ne $val },
        IN      => sub { grep { $tgt eq $_ } @$val },
        NOT_IN  => sub { !grep { $tgt eq $_ } @$val },
        LT      => sub { $tgt < $val },
        GT      => sub { $tgt > $val },
        LE      => sub { $tgt <= $val },
        GE      => sub { $tgt >= $val },
    );
    return $ops{$op}->() if $ops{$op};
    return 0;
}

#------------------------------------------------------------------------------
# notify: ログ・通知
#------------------------------------------------------------------------------
sub notify {
    my ($r) = @_;
    warn "[LOG] rule=$r->{name}\n"           if $r->{meta}{log_if};
    warn "[NOTIFY] rule=$r->{name} code=$r->{meta}{notify_admin}\n"
         if $r->{meta}{notify_admin};
}

1;
