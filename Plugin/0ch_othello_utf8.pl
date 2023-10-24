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
#		'user_identification'	=> {
#			'default'		=> '1',
#			'valuetype'		=> 1,
#           'description'	=> 'ユーザ識別方法(0:ID+pass/1:IP&UA+pass/2:忍法帖ID)',
#		},
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
    my $message = $form->Get('MESSAGE');

    if($type & (16)){
        setCommand($sys,$Threads,$form,$threadid);
    }

	if (($type & (16)) && $Threads->GetAttr($threadid,'othello') && getOthelloCommand($message,'') && !($sys->Equal('MODE',1))) {
        use bigint;

        my $white_def = 0x0000001008000000;
        my $black_def = 0x0000000810000000;
        # 設定値取得
        my $master_info = $Threads->GetAttr($threadid,'othello_master'); #スレ主の情報
        my $opponent_info = $Threads->GetAttr($threadid,'othello_opp');  #対戦相手の情報
        my $first = $Threads->GetAttr($threadid,'othello_first'); #先攻が対戦相手なら1

        my $thMaster = GetYourInfo($sys,$threadid) eq $master_info ? 1 : 0 ;  #スレ主かどうか

        #oppコマンドで対戦相手を設定
        if(getOthelloCommand($message,'opp') && $thMaster){
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
        my $opponent = GetYourInfo($sys,$threadid) eq $opponent_info ? 1 : 0 ;  #対戦相手かどうか

        #startコマンドで初期化
        if(getOthelloCommand($message,'start') && $opponent_info && $thMaster){ 
            $Threads->SetAttr($threadid,'white_stone',$white_def);
            $Threads->SetAttr($threadid,'black_stone',$black_def);

            my $rand = int(rand(2));      #0:スレ主が先攻（黒）・1:スレ主が後攻（白）
            $Threads->SetAttr($threadid,'othello_first',$rand);            #先攻が対戦相手か 

            $form->Set('MESSAGE',$message.'<hr>ゲームスタート！<br>'
            .print_board($white_def,$black_def,1).'<br>NEXT:●');        #黒が先攻

            $form->Set('FROM',makeName($sys,$set,$form,$rand));
            $Threads->SaveAttr($sys);
            return 0;
        }
        my $white_stone = $Threads->GetAttr($threadid,'white_stone');   #白石の配置
        my $black_stone = $Threads->GetAttr($threadid,'black_stone');   #黒石の配置    
        my $whiteNum = popcount($white_stone);
        my $blackNum = popcount($black_stone);
        my $totalNum = $whiteNum + $blackNum - 4;

        #どちらが打つか(0:黒・1:白)
        my $turn = $totalNum % 2;

        #名前欄設定
        if(($thMaster || $opponent) && $white_stone && $black_stone){
            my $name_from = makeName($sys,$set,$form,$turn);
            $form->Set('FROM',$name_from);
        }

        #オセロの実行部分
        if ($white_stone && $black_stone && is_turn($turn, $first, $thMaster, $opponent)){
            my $result = '';

            if($totalNum <= 64){
                my $thisStone = $turn ? '○' : '●';
                my $nextStone = $turn ? '●' : '○';

                #putコマンドの場合
                if(getOthelloCommand($message,'put')){    
                    my $position = getOthelloCommand($message,'put');
                    my $positionNum = convert_position($position);
                    
                    #指定位置に置けるか調べる
                    my $put_result = play_move($white_stone, $black_stone,$turn, $positionNum);
                    if($put_result){
                        #置けるなら置いてひっくり返す
                        ($white_stone, $black_stone) = @$put_result;

                        #63番目の石を置き終わった時点で終了処理
                        if ($totalNum == 62){
                            my $positionLast = getPositionLast($white_stone, $black_stone, $turn);
                            my $opp_put_result = play_move($white_stone, $black_stone, !$turn, $positionLast);
                            if($opp_put_result){
                                #相手が置けるなら置く
                                ($white_stone, $black_stone) = @$opp_put_result;
                            }else{
                                #相手が置けないなら自分が置けるか確認
                                my $last_put_result = play_move($white_stone, $black_stone, $turn, $positionLast);
                                if($last_put_result){
                                    #自分が置けるなら置く
                                    ($white_stone, $black_stone) = @$last_put_result;
                                }
                            }

                            $whiteNum = popcount($white_stone);
                            $blackNum = popcount($black_stone);
                            $totalNum = $whiteNum + $blackNum;

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
                            .print_board($white_stone, $black_stone)
                            ."<br>" . $totalNum . "手目／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
                        }
                    }else{
                        $result = "${position}には${thisStone}を置けません。";
                    }
                }
                #passコマンドの場合
                elsif(getOthelloCommand($message,'pass')){
                    #passできるかどうか確認
                    if(legal_moves($white_stone, $black_stone, $turn)){
                        $result = "置ける場所があるためパスはできません。";
                    }else{
                        #passした場合に相手が置けるか確認
                        if(legal_moves($white_stone, $black_stone, !$turn)){
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
                            ."<br>合計" . $totalNum-4 . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
                            $Threads->SetAttr($threadid,'othello_first',undef);
                        }
                    }
                }
                #単純に譜面を表示する場合
                elsif(getOthelloCommand($message,'view')){
                    $result = "現在の譜面<br>".print_board($white_stone, $black_stone)
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
                    ."<br>合計" . $totalNum-4 . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
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
#対戦相手の情報取得
sub GetOppInfo
{
	my ($Sys,$threadid,$resNum) = @_;
    return 0 if $resNum == 0;
    require './module/log.pl';
    my $Logger = LOG->new;
    my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $threadid;
    $Logger->Open($logPath, 0, 1 | 2);

    my @log = split(/<>/,$Logger->Get($resNum-1));

	my $ip = defined $log[6];
	my $ua = defined $log[8];
    require Digest::MD5;
    my $ctx = Digest::MD5->new;
    $ctx->add('0ch+ ID Generation');
    $ctx->add(':', $ip);
    $ctx->add(':', $ua);
    $ctx->add(':', $threadid);

    my $oppInfo = $ctx->b64digest;
	return $oppInfo;
}

#書き込み者の情報取得
sub GetYourInfo
{
	my ($Sys,$threadid) = @_;

	my $ip = $ENV{'HTTP_CF_CONNECTING_IP'} // $ENV{'REMOTE_ADDR'};
	my $ua = $ENV{'HTTP_USER_AGENT'};
    require Digest::MD5;
    my $ctx = Digest::MD5->new;
    $ctx->add('0ch+ ID Generation');
    $ctx->add(':', $ip);
    $ctx->add(':', $ua);
    $ctx->add(':', $threadid);

    my $yourInfo = $ctx->b64digest;
	return $yourInfo;
}

#手番かどうか
sub is_turn {
    my ($turn, $first, $thMaster, $opponent) = @_;
    
    if (($thMaster == 1 && $turn == $first) || ($opponent == 1 && $turn != $first)) {
        return 1;  # 手番である
    } else {
        return 0;  # 手番ではない
    }
}

#石の数カウント
sub popcount {
    my ($n) = @_; 
    my $count = 0;
    while ($n) {
        $count += $n & 1;
        $n >>= 1;
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

use constant {
    SHIFT_MASK_LIST => [
        { shift => 1, mask => 0x7f7f7f7f7f7f7f7f },
        { shift => -1, mask => 0x7f7f7f7f7f7f7f7f },
        { shift => 8, mask => 0xffffffffffffffff },
        { shift => -8, mask => 0xffffffffffffffff },
        { shift => 7, mask => 0x7f7f7f7f7f7f7f7f },
        { shift => -7, mask => 0x7f7f7f7f7f7f7f7f },
        { shift => 9, mask => 0xffffffffffffffff },
        { shift => -9, mask => 0xffffffffffffffff },
    ],
};

sub reverse_stones {
    my ($own_board, $opponent_board, $position) = @_;
    my $flip_mask = 0;
    
    for my $shift_mask (@{+SHIFT_MASK_LIST}) {
        my $shift = $shift_mask->{shift};
        my $mask = $shift_mask->{mask};
        
        my $outflank = 0;
        my $current = $position;
        
        while (1) {
            $current += $shift;
            
            if (($current & $mask) == 0) {
                last;
            }
            
            if (($opponent_board & (1 << $current)) == 0) {
                last;
            }
            
            $outflank |= (1 << $current);
        }
        
        $current += $shift;
        
        if (($own_board & (1 << $current)) != 0) {
            $flip_mask |= $outflank;
        }
    }
    
    return ($own_board ^ ($flip_mask | (1 << $position)), $opponent_board ^ $flip_mask);
}

sub line_calc {
    my ($board, $mask, $shift) = @_;
    my $result = 0;

    while ($mask) {
        if ($shift > 0) {
            $board <<= $shift;
            $mask <<= $shift;
        } else {
            $board >>= -$shift;
            $mask >>= -$shift;
        }

        $result |= $board & $mask;
    }

    return $result;
}

sub play_move {
    my ($white_stone, $black_stone, $turn, $position) = @_;
    
    my ($own_board, $opponent_board) = $turn ? ($white_stone, $black_stone) : ($black_stone, $white_stone);

    # 合法手かどうか確認
    my $legal_moves = legal_moves($white_stone, $black_stone,$turn);
    if (($legal_moves & (1 << $position)) == 0) {
        return 0;
    }
    
    # 石をひっくり返す
    my ($new_own_board, $new_opponent_board) = reverse_stones($own_board, $opponent_board, $position);
    
    if ($turn == 0) {
        return [$new_opponent_board, $new_own_board];
    } else {
        return [$new_own_board, $new_opponent_board];
    }
}

sub calc {
    my ($tp, $ntp, $mask, $shift) = @_;
    my $line_l = ($tp << $shift) & ($ntp & $mask);
    my $line_r = ($tp >> -$shift) & ($ntp & $mask);
    return ($line_l >> $shift) | ($line_r >> -$shift);
}

sub legal_moves {
    my ($white_stone, $black_stone, $turn) = @_;
    my ($tp, $ntp) = $turn == 0 ? ($black_stone, $white_stone) : ($white_stone, $black_stone);
    
    my $blank_board = ~($tp | $ntp);
    my $possible = 0;

    foreach my $item (@{+SHIFT_MASK_LIST}) {
        $possible |= calc($tp, $ntp, $item->{mask}, $item->{shift});
    }
    
    return $possible & $blank_board;
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
sub getPositionLast
{
    my ($white_stone, $black_stone,$turn) = @_;
    my ($own_board, $opponent_board) = $turn ? ($white_stone, $black_stone) : ($black_stone, $white_stone);
    my $all_filled = $own_board | $opponent_board;

    # すべてのマスが埋まっている場合は-1を返す
    if ($all_filled == 0xFFFFFFFFFFFFFFFF) {
        return -1;
    }

    for my $i (0..63) {
        my $mask = 1 << $i;
        if (($all_filled & $mask) == 0) {
            return $i;
        }
    }
    return -1;  # 空きマスがない場合
}

sub print_board {
    my ($white_stone, $black_stone, $turn) = @_;
    my $result = "";

    $result .= "　│Ａ│Ｂ│Ｃ│Ｄ│Ｅ│Ｆ│Ｇ│Ｈ│<br>";
    $result .= "─"."┼─" x 8 . "┤<br>";

    for my $row (0..7) {
        for my $col (0..7) {
            my $pos = $row * 8 + $col;
            my $mask = 1 << $pos;  # 通常の整数でビットマスクを作成
            my $ch = $col == 0 ? $row+1 : '';
            $ch =~ tr/1-9/１-９/;

            $result .= "$ch│";
            if ($white_stone & $mask) {  # ビット演算を通常の整数で行う
                $result .= "○";
            } elsif ($black_stone & $mask) {
                $result .= "●";
            } else {
                    $result .= "　";
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
	my ($sys,$Threads,$form,$threadid) = @_;
    my $message = $form->Get('MESSAGE');
	
	my $Command = '';

	#オセロスレモード
	if($message =~ /(^|<br>)[ \t]*!othello[ \t]*(<br>|$)/){
		$Threads->SetAttr($threadid, 'othello', 1);
        $Threads->SetAttr($threadid, 'othello_master', GetYourInfo($sys,$threadid));
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
    #$exp .= '!othello:hint・・・石を置ける場所を明示します。<br>';
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