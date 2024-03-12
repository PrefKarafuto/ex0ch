#============================================================================================================
#
#	拡張機能 - オセロ
#	0ch_othello_utf8.pl
#	---------------------------------------------------------------------------
#	2023.10.20 start
#
#============================================================================================================
package ZPL_othello;
use utf8;
use Math::BigInt;
use warnings;
use strict;
use open IO =>':encoding(cp932)';
#------------------------------------------------------------------------------------------------------------
#	コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($Config) = @_;
	my ($obj);
	
	$obj = {};
	bless $obj, $this;
	
	if (defined $Config) {
		$obj->{'PLUGINCONF'} = $Config;
		$obj->{'is0ch+'} = 1;
	}
	else {
		$obj->{'CONFIG'} = $this->getConfig();
		$obj->{'is0ch+'} = 0;
	}
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能名称取得
#	-------------------------------------------------------------------------------------
#	@return	名称文字列
#------------------------------------------------------------------------------------------------------------
sub getName
{
	my	$this = shift;
	return 'オセロ';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return 'コマンドでオセロが出来ます。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ(スレ立て:1, レス:2, read:4, index:8, 書き込み前処理:16)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return (16);
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	設定ハッシュリファレンス
#		\%config = (
#			'設定名'	=> {
#				'default'		=> 初期値,			# 真偽値の場合は on/true: 1, off/false: 0
#				'valuetype'		=> 値のタイプ,		# 数値: 1, 文字列: 2, 真偽値: 3
#				'description'	=> '設定の説明',	# 無くても構いません
#			},
#		);
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	my	$this = shift;
	my	%config;
	
	%config = (
		'bbs_directry'	=> {
			'default'		=> '',
			'valuetype'		=> 2,
			'description'	=> 'オセロを有効にする掲示板のディレクトリ名',
		},
	);
	
	return \%config;
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$sys	SYSTEM
#	@param	$form	FORM
#	@param	$type	実行タイプ
#	@return	正常終了の場合は0
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my	$this = shift;
	my	($sys, $form, $type) = @_;

	my $is_bbs = $this->GetConf('bbs_directry');
	my $this_bbs = $sys->Get('BBS');
	return 0 if ($is_bbs ne $this_bbs);

	my $CGI = $sys->Get('MainCGI');
	my $Threads = $CGI->{'THREADS'} || $sys->Get('_THREAD_');
	$Threads->LoadAttr($sys);
	my $set = $CGI->{'SET'};
	$set->Load($sys);
	my $threadid = $sys->Get('KEY');
    my $sid = $sys->Get('SID');
	my $message = $form->Get('MESSAGE');

	if($type & (16)){
		setCommand($sys,$Threads,$form,$threadid,$sid);
	}

	if (($type & (16)) && $Threads->GetAttr($threadid,'othello') && getOthelloCommand($message,'') && !($sys->Equal('MODE',1))) {

		my $white_def = Math::BigInt->new('0x0000001008000000');
		my $black_def = Math::BigInt->new('0x0000000810000000');
		# 設定値取得
		my $master_info = $Threads->GetAttr($threadid,'othello_master'); #スレ主の情報
		my $opponent_info = $Threads->GetAttr($threadid,'othello_opp');  #対戦相手の情報
		my $this_turn = $Threads->GetAttr($threadid,'othello_turn'); #このターンが0：白か1：黒か

		my $is_master = $sid eq $master_info ? 1 : 0 ;  #スレ主かどうか

		#oppコマンドで対戦相手を設定
		if(getOthelloCommand($message,'opp') && $is_master){
			my $oppNum = getOthelloCommand($message,'opp');
			my $selOpp = GetOppInfo($sys,$threadid,$oppNum);
			if($selOpp && $oppNum > 1 && $master_info ne $selOpp){
				$Threads->SetAttr($threadid,'othello_opp',$selOpp);
				$opponent_info = $Threads->GetAttr($threadid,'othello_opp');
				$form->Set('MESSAGE',$message.'<hr>対戦相手として&gt;&gt;'.$oppNum.'を登録しました。');
			}else{
				$form->Set('MESSAGE',$message.'<hr>対戦相手の設定に失敗しました。');
			}
		}
		my $opponent = $sid eq $opponent_info ? 1 : 0 ;  #対戦相手かどうか

		#startコマンドで初期化
		if(getOthelloCommand($message,'start') && $opponent_info && $is_master){ 
			$Threads->SetAttr($threadid,'white_stone',$white_def);
			$Threads->SetAttr($threadid,'black_stone',$black_def);
			$Threads->SetAttr($threadid,'othello_turn',1);

			$form->Set('MESSAGE',$message.'<hr>ゲームスタート！<br>'
			.print_board($white_def,$black_def).'<br>NEXT:○');		#黒が先攻

			$form->Set('FROM',makeName($sys,$set,$form,0));
			$Threads->SaveAttr($sys);
			return 0;
		}
		my $white_stone = $Threads->GetAttr($threadid,'white_stone');   #白石の配置
		my $black_stone = $Threads->GetAttr($threadid,'black_stone');   #黒石の配置	
		my $whiteNum = popcount($white_stone);
		my $blackNum = popcount($black_stone);
		my $totalNum = $whiteNum + $blackNum - 4;

		#名前欄設定
		if(($is_master || $opponent) && $white_stone && $black_stone){
			my $name_from = makeName($sys,$set,$form,$this_turn);
			$form->Set('FROM',$name_from);
		}

		#オセロの実行部分
		if ($white_stone && $black_stone && is_turn($this_turn, $is_master, $opponent)){
			my $result = '';

			if($totalNum <= 64){
				my $thisStone = $this_turn ? '○' : '●';
				my $nextStone = $this_turn ? '●' : '○';
				my $moves;
				if ($this_turn) {
					$moves = valid_moves($black_stone, $white_stone);
				} else {
					$moves = valid_moves($white_stone, $black_stone);
				}

				#putコマンドの場合
				if(getOthelloCommand($message,'put')){	
					my $position = getOthelloCommand($message,'put');
					my $positionNum = convert_position($position);
					
					#指定位置に置けるか調べる
					if($moves & (1 << $positionNum)){
						#置けるなら置いてひっくり返す
						if($this_turn){
							($black_stone, $white_stone) = make_move($black_stone, $white_stone, $positionNum);
						}else{
							($white_stone, $black_stone) = make_move($white_stone, $black_stone, $positionNum);
						}

						#63番目の石を置き終わった時点で終了処理
						if ($totalNum == 62){
							my $positionLast = getPositionLast($white_stone, $black_stone, $this_turn);
							if ($this_turn) {
								$moves = valid_moves($black_stone, $white_stone);
							} else {
								$moves = valid_moves($white_stone, $black_stone);
							}

							if($moves & (1 << $positionLast)){
								#相手が置けるなら置く
								if($this_turn){
									($black_stone, $white_stone) = make_move($black_stone, $white_stone, $positionNum);
								}else{
									($white_stone, $black_stone) = make_move($white_stone, $black_stone, $positionNum);
								}
							}else{
								#相手が置けないなら自分が置けるか確認
								if (!$this_turn) {
									$moves = valid_moves($black_stone, $white_stone);
								} else {
									$moves = valid_moves($white_stone, $black_stone);
								}
								if($moves & (1 << $positionLast)){
									#自分が置けるなら置く
									if(!$this_turn){
										($black_stone, $white_stone) = make_move($black_stone, $white_stone, $positionNum);
									}else{
										($white_stone, $black_stone) = make_move($white_stone, $black_stone, $positionNum);
									}
								}
							}

							#対戦終了画面
							my $game_result = ($blackNum == $whiteNum) ? '両者引き分けです。' : ($blackNum < $whiteNum) ? '○の勝利です。' : '●の勝利です。';
							if($blackNum < $whiteNum){
								$whiteNum += 64 - $totalNum;
							}elsif($blackNum > $whiteNum){
								$blackNum += 64 - $totalNum;
							}
							$result = "ゲーム終了！${game_result}<br>".print_board($white_stone, $black_stone)
							."<br>合計" . $totalNum-4 . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
							$Threads->SetAttr($threadid,'othello_first',undef);
						}
						else{
							#置いた結果の表示を生成
							$whiteNum = popcount($white_stone);
							$blackNum = popcount($black_stone);
							$totalNum = $whiteNum + $blackNum -4;
							$result = "${position}に${thisStone}を置きました。<br>"
							.print_board($white_stone, $black_stone,$moves)
							."<br>" . $totalNum . "手目／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
						}
					}else{
						if($moves){
							#まだ置ける場所があるなら
							$result = "${position}には${thisStone}を置けません。";
						}else{
							#もう置ける場所がないなら
							$result = "置ける場所がないのでパスされます。";
							$Threads->SetAttr($threadid,'othello_turn',!$this_turn);
						}
					}
				}
				#passコマンドの場合
				elsif(getOthelloCommand($message,'pass')){
					#passできるかどうか確認
					if ($this_turn) {
						$moves = valid_moves($black_stone, $white_stone);
					} else {
						$moves = valid_moves($white_stone, $black_stone);
					}
					if($moves){
						$result = "置ける場所があるためパスはできません。";
					}else{
						#passした場合に相手が置けるか確認
						if (!$this_turn) {
							$moves = valid_moves($black_stone, $white_stone);
						} else {
							$moves = valid_moves($white_stone, $black_stone);
						}
						if($moves){
							#置けるならpass
							$result = "パスしました。<br>NEXT:${nextStone}";
						}else{
							#置けないならゲーム終了
							my $game_result = ($blackNum == $whiteNum) ? '両者引き分けです。' : ($blackNum < $whiteNum) ? '○の勝利です。' : '●の勝利です。';
							if($blackNum < $whiteNum){
								$whiteNum += 64 - $totalNum;
							}elsif($blackNum > $whiteNum){
								$blackNum += 64 - $totalNum;
							}
							$result = "ゲーム終了！${game_result}<br>".print_board($white_stone, $black_stone)
							."<br>合計" . $totalNum . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
						}
					}
				}
				#単純に譜面を表示する場合
				elsif(getOthelloCommand($message,'view')){
					$result = "現在の譜面<br>".print_board($white_stone, $black_stone)
					."<br>". ${totalNum}."手／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
				}
				elsif(getOthelloCommand($message,'hint')){
					if ($this_turn) {
						$moves = valid_moves($black_stone, $white_stone);
					} else {
						$moves = valid_moves($white_stone, $black_stone);
					}
					$result = "ヒント<br>".print_board($white_stone, $black_stone,$moves)
					."<br>". ${totalNum}."手／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
				}

				$Threads->SetAttr($threadid,'white_stone',$white_stone);
				$Threads->SetAttr($threadid,'black_stone',$black_stone);
			}else{
				#終了後にリザルト表示する場合
				if(getOthelloCommand($message,'result')){
					my $game_result = ($blackNum == $whiteNum) ? '両者引き分けです。' : ($blackNum < $whiteNum) ? '○の勝利です。' : '●の勝利です。';
					if($blackNum < $whiteNum){
						$whiteNum += 64 - $totalNum;
					}elsif($blackNum > $whiteNum){
						$blackNum += 64 - $totalNum;
					}
					$result = ${game_result}."<br>".print_board($white_stone,$black_stone)
					."<br>合計" . $totalNum . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
				}
			}

			if($result){
				#リザルトを画面に出力
				$form->Set('MESSAGE',$message.'<hr>'.$result);
			}
		}
	}

	$Threads->SaveAttr($sys);
	return 0;
}

####################各種関数####################
my @directions = (-1, 1, -8, 8, -7, 7, -9, 9);
#対戦相手の情報取得
sub GetOppInfo
{
	my ($Sys,$threadid,$resNum) = @_;
	return 0 if $resNum == 0;
	require './module/log.pl';
	my $Logger = LOG->new;

	my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $threadid;
	$Logger->Open($logPath, 0, 1 | 2);
    
    return (split(/<>/,$Logger->Get($resNum-1)))[9];
}

#手番かどうか
sub is_turn {
	my ($turn, $is_master, $opponent) = @_;
	
	if (($is_master == 1 && $turn == 0) || ($opponent == 1 && $turn == 1)) {
		return 1;  # 手番である
	} else {
		return 0;  # 手番ではない
	}
}

#石の数カウント
sub popcount {
    my ($n) = @_;

    my $count = 0;
    my $zero = Math::BigInt->new(0);
    my $one = Math::BigInt->new(1);

    while ($n->bcmp($zero) > 0) {
        $count += $n->copy()->band($one)->bstr();
        $n = $n->copy()->brsft($one);
    }
    return $count;
}

#名前欄設定
sub makeName
{
	my ($sys,$set,$form,$next) = @_;
	my $FROM = $form->Get('FROM');
	my $defName = $set->Get('BBS_NONAME_NAME');
	my $yourStone = $next ? '&#9898;' : '&#9899;';

	my $yourName = "";
	if($FROM eq $defName){
		$yourName = $yourStone;
	}else{
		$yourName = $yourStone."（$FROM）";
	}
	return $yourName;
}

sub is_valid_move {
    my ($player, $opponent, $pos) = @_;
    my $mask = Math::BigInt->new(1)->blsft($pos);
    return 0 if ($player->bior($opponent))->band($mask)->is_zero();

    foreach my $dir (@directions) {
        if (check_direction($player, $opponent, $pos, $dir)) {
            return 1;
        }
    }
    return 0;
}

sub check_direction {
    my ($player, $opponent, $pos, $dir) = @_;
    my $mask = Math::BigInt->new(1);
    $mask->blsft($pos); # 左シフト演算

    my $left_edge = Math::BigInt->new('0xFEFEFEFEFEFEFEFE');
    my $right_edge = Math::BigInt->new('0x7F7F7F7F7F7F7F7F');
    my $top_edge = Math::BigInt->new('0xFFFFFFFFFFFFFF00');
    my $bottom_edge = Math::BigInt->new('0x00FFFFFFFFFFFFFF');
    my $edge_mask = Math::BigInt->new('0xFFFFFFFFFFFFFFFF');

    if ($dir == -1 || $dir == 7) {
        $edge_mask->band($right_edge); # AND演算
    } elsif ($dir == 1 || $dir == -7) {
        $edge_mask->band($left_edge); # AND演算
    } elsif ($dir == 8) {
        $edge_mask->band($bottom_edge); # AND演算
    } elsif ($dir == -8) {
        $edge_mask->band($top_edge); # AND演算
    }

    $mask->blsft($dir); # 左シフト演算
    while ($mask->band($edge_mask)->bcmp(Math::BigInt->bzero()) != 0 && $mask->band($opponent)->bcmp(Math::BigInt->bzero()) != 0) {
        $mask->blsft($dir); # 左シフト演算
        if ($mask->band($player)->bcmp(Math::BigInt->bzero()) != 0) {
            return 1;
        }
    }
    return 0;
}

sub make_move {
    my ($player, $opponent, $pos) = @_;
    my $mask = Math::BigInt->new(1)->blsft($pos);

    foreach my $dir (@directions) {
        if (check_direction($player, $opponent, $pos, $dir)) {
            my $tmp = $pos + $dir;
            while ($opponent->band(Math::BigInt->new(1)->blsft($tmp))->is_zero() == 0) {
                $player->bior(Math::BigInt->new(1)->blsft($tmp));
                $opponent->band(Math::BigInt->new('0xFFFFFFFFFFFFFFFF')->bxor(Math::BigInt->new(1)->blsft($tmp)));  # 相手のビットをクリア
                $tmp += $dir;
            }
        }
    }
    $player->bior($mask);

    return ($player, $opponent);
}

sub valid_moves {
    my ($player, $opponent) = @_;
    my $moves = Math::BigInt->new(0);
    for my $pos (0..63) {
        if (is_valid_move($player, $opponent, $pos)) {
            my $bit = Math::BigInt->new(1)->blsft($pos);
            $moves->bior($bit);
        }
    }
    return $moves;
}

# グリッド名から数字に変換
sub convert_position {
	my ($position) = @_;
	return undef unless length($position) == 2;

	my ($col, $row) = split(//,$position);

	# A-Hを0-7に変換
	my $col_index = ord(uc($col)) - ord('A');

	# 1-8を0-7に変換
	my $row_index = $row - 1;

	# 0-63のインデックスに変換
	my $index = $row_index * 8 + $col_index;

	return $index;
}
sub reverse_convert_position {
	my ($index) = @_;

	# 0-63のインデックスから行と列のインデックス（0-7）を得る
	my $row_index = int($index / 8);
	my $col_index = $index % 8;

	# 0-7を1-8に変換
	my $row = $row_index + 1;

	# 0-7をA-Hに変換
	my $col = chr($col_index + ord('A'));

	return $col.$row;
}

#最後に残った場所を取得
sub getPositionLast {
    my ($white_stone, $black_stone, $turn) = @_;
    my ($own_board, $opponent_board) = $turn ? ($white_stone, $black_stone) : ($black_stone, $white_stone);
    my $all_filled = $own_board->bior($opponent_board);

    if ($all_filled == Math::BigInt->new('0xFFFFFFFFFFFFFFFF')) {
        return -1;
    }

    for my $i (0..63) {
        my $mask = Math::BigInt->new(1)->blsft($i);
        if ($all_filled->band($mask)->is_zero()) {
            return $i;
        }
    }
    return -1;
}

sub print_board {
    my ($white_stone, $black_stone, $hint) = @_;
    my $result = "";

    $result .= "　│Ａ│Ｂ│Ｃ│Ｄ│Ｅ│Ｆ│Ｇ│Ｈ│<br>";
    $result .= "─"."┼─" x 8 . "┤<br>";

    for my $row (0..7) {
        $result .= ($row + 1) . "│";  # 数字を日本語の数字に変換しないで直接使用
        for my $col (0..7) {
            my $pos = $row * 8 + $col;
            my $mask = Math::BigInt->new(1)->blsft($pos);  # BigIntでビットマスクを作成

            if ($white_stone->band($mask)->is_zero() == 0) {  # ビット演算をBigIntで行う
                $result .= "○";
            } elsif ($black_stone->band($mask)->is_zero() == 0) {
                $result .= "●";
            } else {
                if ($hint && $hint->band($mask)->is_zero() == 0) {
                    $result .= "可";
                } else {
                    $result .= "　";
                }
            }
        }
        $result .= "│<br>";
        $result .= "─"."┼─" x 8 . "┤<br>" unless $row == 7;
    }

    $result .= "─"."┴─" x 8 . "┘<br>";

    return '<div class="aaview">'.$result.'</div>';
}

# オセロ用のコマンドを本文から取得
sub getOthelloCommand
{
	my ($message,$command) = @_;
	if($message =~ /(^|<br>)[ \t]*!othello:([a-zA-Z0-9&;>:]*)[ \t]*(<br>|$)/){
		my $str = $2;
		if($command eq 'opp' && $str =~ /opp:&gt;&gt;([0-9]+)/){
			return int($1);
		}elsif($command eq 'put' &&$str =~ /put:([a-hA-H][1-8])/){
			return $1;
		}elsif($command eq 'put' &&$str =~ /put:([1-8][a-hA-H])/){
			return reverse($1);
		}elsif($str eq $command){
			return 1;
		}elsif($command eq ''){
			return 1;
		}
		return 0;
	}
	return 0;
}


# コマンドを設定
sub setCommand
{
	my ($sys,$Threads,$form,$threadid,$sid) = @_;
	my $message = $form->Get('MESSAGE');
	
	my $Command = '';

	#オセロスレモード
	if($message =~ /(^|<br>)[ \t]*!othello[ \t]*(<br>|$)/){
		$Threads->SetAttr($threadid, 'othello', 1);
		$Threads->SetAttr($threadid, 'othello_master', $sid);
		$Threads->SaveAttr($sys);
		$Command = "※オセロスレ<br>";
	}

	if($Command){
		$Command =~ s/<br>$//;
		$form->Set('MESSAGE',$message."<hr><font color=\"red\">$Command</font><br>".explanation());
	}
}

# オセロに関する説明
sub explanation
{
	my $exp = '';
	$exp .= 'オセロスレにようこそ！<br>このスレでは、スレ主とオセロで対戦することが出来ます。<br><br>';
	$exp .= 'オセロ用コマンド一覧(スレ主専用)<br>';
	$exp .= '!othello・・・スレ立て時にスレッドをオセロスレに設定します。スレの途中での変更はできません。<br>';
	$exp .= '!othello:opp:&gt;&gt;[レス番号]・・・対戦相手をレス番で指定します。未来のレスは指定できません。<br>';
	$exp .= '!othello:start・・・相手を指定したら、ゲームを開始します。この時先攻後攻がランダムに決定されます。名前欄に&#9898;か&#9899;が表示され、&#9899;が先攻です。<br><br>';
	$exp .= '以下は対戦相手も使用可能です。<br>';
	$exp .= '!othello:put:[A-H][1-8]・・・石を置く位置を指定します。8x8盤面の列を英字、行を数字で記入してください。<br>';
	$exp .= '!othello:pass・・・石を置けない場合にパスします。どこかに置ける場所があると、パスはできません。<br>';
	$exp .= '!othello:hint・・・石を置ける場所を明示します。<br>';
	$exp .= '!othello:view・・・その時点での譜面を表示します。<br><br>ゲーム終了後のみ<br>';
	$exp .= '!othello:result・・・対戦結果を表示します。<br>';
	$exp .= '<br>一スレに付き一試合可能です。また、途中でサレンダーはできません。最後まで頑張りましょう。';

	return $exp;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@return	設定値
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my	$this = shift;
	my	($key) = @_;
	my	($val);
	
	if ($this->{'is0ch+'}) {
		$val = $this->{'PLUGINCONF'}->GetConfig($key);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$val = $this->{'CONFIG'}->{$key}->{'default'};
		}
		else {
			$val = undef;
		}
	}
	
	return $val;
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@param	$val	設定値
#	@return	なし
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my	$this = shift;
	my	($key, $val) = @_;
	
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$this->{'CONFIG'}->{$key}->{'default'} = $val;
		}
		else {
			$this->{'CONFIG'}->{$key} = { 'default' => $val };
		}
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;