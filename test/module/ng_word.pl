#============================================================================================================
#
#	NGワード管理モジュール
#
#============================================================================================================
package	NG_WORD;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use HTML::Entities;
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {
		'METHOD'	=> undef,
		'SUBSTITUTE'=> undef,
		'NGWORD'	=> undef,
		'REPLACE'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード読み込み - Load
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'NGWORD'} = [];
	$this->{'REPLACE'} = [];
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/ngwords.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @datas = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @datas;
		
		my @head = split(/<>/, shift @datas);
		$this->{'METHOD'} = $head[0];
		$this->{'SUBSTITUTE'} = $head[1];
		
		foreach (@datas) {
			my ($word, $repl) = split(/<>/, $_, -1);
			next if (!defined $word || $word eq '');
			push @{$this->{'NGWORD'}}, $word;
			if (defined $repl) {
				$this->{'REPLACE'}->[$#{$this->{'NGWORD'}}] = $repl;
			}
		}
		return 0;
	}
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード書き込み - Save
#	-------------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：0
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . "/info/ngwords.cgi";
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		print $fh "$this->{'METHOD'}<>$this->{'SUBSTITUTE'}\n";
		foreach my $i (0 .. $#{$this->{'NGWORD'}}) {
			print $fh $this->{'NGWORD'}->[$i];
			print $fh '<>'.$this->{'REPLACE'}->[$i] if (defined $this->{'REPLACE'}->[$i]);
			print $fh "\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $path);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード追加 - Set
#	-------------------------------------------
#	引　数：$key : NGワード
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($word, $repl) = @_;
	
	return if (!defined $word || $word eq '');
	if($word !~ /^!reg:/){
		$word =~ s/</&lt;/g;
		$word =~ s/>/&gt;/g;
	}
	push @{$this->{'NGWORD'}}, $word;
	if (defined $repl) {
		$repl =~ s/</&lt;/g;
		$repl =~ s/>/&gt;/g;
		$this->{'REPLACE'}->[$#{$this->{'NGWORD'}}] = $repl;
	}
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワードデータ取得 - Get
#	-------------------------------------------
#	引　数：$key : 取得キー
#			$default : デフォルト
#	戻り値：データ
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($key, $default) = @_;
	
	my $val = $this->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワードデータ設定 - SetData
#	-------------------------------------------
#	引　数：$key  : 設定キー
#			$data : 設定データ
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($key, $data) = @_;
	
	$this->{$key} = $data;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワードクリア - Clear
#	-------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Clear
{
	my $this = shift;
	
	$this->{'NGWORD'} = [];
	$this->{'REPLACE'} = [];
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード調査 - Check
#	-------------------------------------------
#	引　数：$Form  : FORM
#			$pList : チェックリスト(リファレンス)
#			$List  : NGワードチェック用(リファレンス)
#	戻り値：検知番号
#
#------------------------------------------------------------------------------------------------------------
sub Check {
    my $this  = shift;
    my ($Form, $pList, $cList) = @_;
	my @hList;
	my @List = $cList ? @$cList : @{$this->{'NGWORD'}} ;
    foreach my $word (@List) {
        next if $word eq '';

        foreach my $key (@$pList) {
            my $work         = $Form->Get($key) // '';

            # 「!reg:」付きなら正規表現モード
            if ($word =~ /^!reg:(.*)$/) {
                my $pattern_str = $1;
                # 実行コード挿入は拒否
                next if (index($pattern_str, '(?{') >= 0 or index($pattern_str, '(??{') >= 0);

                # コンパイルを試みる
                my $pat = eval { qr/$pattern_str/ };
                next if $@;    # エラーがあればスキップ

                # マッチしたら即規制
				$work =~ s/<br>/\n/g;
                if (decode_entities($work) =~ $pat) {
					return 3 unless $cList;
					push @hList,$word;
				}
			}
            else {
                # リテラルマッチ用に \Q…\E でコンパイル
                my $pat = eval { qr/\Q$word\E/ };
                next if $@;    # エラーがあればスキップ

                if (decode_entities($work) =~ $pat) {
                    return $this->{'METHOD'} eq 'host'    ? 2
                         : $this->{'METHOD'} eq 'disable' ? 3
                         : 1 unless $cList;
					push @hList,$word;
                }
            }
        }
    }

    return $cList ? \@hList : 0;
}


#------------------------------------------------------------------------------------------------------------
#
#	NGワード処理 - Method
#	-------------------------------------------
#	引　数：$Form  : FORM
#			$pList : チェックリスト(リファレンス)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Method
{
	my $this = shift;
	my ($Form, $pList) = @_;
	
	# 処理種別が代替か削除の場合のみ処理
	return unless ($this->{'METHOD'} eq 'delete' || $this->{'METHOD'} eq 'substitute');
	
	# 代替用文字列を設定
	my $substitute = '';
	if ($this->{'METHOD'} eq 'delete') {
		$substitute = '';
	}
	else {
		$substitute = $this->{'SUBSTITUTE'};
		$substitute = '' if (!defined $substitute);
	}
	
	foreach my $i (0 .. $#{$this->{'NGWORD'}}) {
		my $word = $this->{'NGWORD'}->[$i];
		next if ($word eq '');
		foreach my $key (@$pList) {
			my $work = $Form->Get($key);
			# ここでデコード
			my $decoded_work = decode_entities($work);

			my $subst = $substitute;
			$subst = $this->{'REPLACE'}->[$i] if (defined $this->{'REPLACE'}->[$i]);
			if ($decoded_work =~ s/\Q$word\E/$subst/g) {
				# 変更があった場合だけ値を更新
				$Form->Set($key, $decoded_work);
			}
		}
	}
}


#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
