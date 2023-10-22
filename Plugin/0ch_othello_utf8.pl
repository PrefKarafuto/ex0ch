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
    my $Set = $CGI->{'SET'};
    $Set->Load($sys);
	my $threadid = $sys->Get('KEY');
    my $message = $form->Get('MESSAGE');

    if($type & (16)){
        setCommand($sys,$Threads,$form,$threadid);
    }

	if (($type & (16)) && $Threads->GetAttr($threadid,'othello') && getOthelloCommand($message,'') && !($sys->Equal('MODE',1))) {
        # 設定値取得
        my $master_info = $Threads->GetAttr($threadid,'othello_master'); #スレ主の情報
        my $opponent_info = $Threads->GetAttr($threadid,'othello_opp'); #対戦相手の情報
        my $first = $Threads->GetAttr($threadid,'othello_first');       #0:スレ主が先攻（黒）・1:スレ主が後攻（白）
        my $turn = $Threads->GetAttr($threadid,'othello_next');         #どちらが打つか(0:黒・1:白)

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
            $Threads->SetAttr($threadid,'white_stone',"0x0000001008000000");
            $Threads->SetAttr($threadid,'black_stone',"0x0000000810000000");
            $Threads->SetAttr($threadid,'othello_first',int(rand(2)));      #0:スレ主が先攻（黒）・1:スレ主が後攻（白）

            $first = $Threads->GetAttr($threadid,'othello_first'); 
            $Threads->SetAttr($threadid,'othello_next',$First);
            $turn = $Threads->GetAttr($threadid,'othello_next');

            $form->Set('MESSAGE',$message.'<hr>ゲームスタート！<br>'
            .print_board(Math::BigInt->from_hex("0x0000001008000000"),Math::BigInt->from_hex("0x0000000810000000")).'<br>NEXT:●');#黒が先攻

            return 0;
        }
        my $white_stone = Math::BigInt->from_hex($Threads->GetAttr($threadid,'white_stone'));   #白石の配置
        my $black_stone = Math::BigInt->from_hex($Threads->GetAttr($threadid,'black_stone'));   #黒石の配置      

        #名前欄設定
        if($thMaster || $opponent){
            my $name_from = makeName($sys,$set,$form,$turn);
            $form->Set('FROM',$name_from);
        }

        #オセロの実行部分
        if ($white_stone && $black_stone && is_turn($turn, $first, $thMaster, $opponent)){
            my $whiteNum = popcount($white_stone);
            my $blackNum = popcount($black_stone);
            my $totalNum = $whiteNum + $blackNum;
            my $result = '';

            if($totalNum <= 64){
                my $thisStone = $turn ? '○' : '●';
                my $nextStone = $turn ? '●' : '○';

                #スレ主と対戦相手のどちらが置いたかに応じて白黒を自陣か敵陣かに設定
                my ($own_board, $opponent_board) = assign_boards($white_stone, $black_stone, $turn);

                #putコマンドの場合
                if(getOthelloCommand($message,'put')){    
                    my $position = getOthelloCommand($message,'put');
                    my $positionNum = convert_position($position);
                    
                    #指定位置に置けるか調べる
                    if(can_place_stone($own_board, $opponent_board, $positionNum)){
                        #置けるなら置いてひっくり返す
                        ($own_board, $opponent_board) = place_and_flip($own_board, $opponent_board, $positionNum);

                        #63番目の石を置き終わった時点で終了処理
                        if ($totalNum == 62){
                            my $positionLast = getPositionLast($opponent_board, $own_board);
                            if(can_place_stone($opponent_board, $own_board, $positionLast)){
                                #相手が置けるなら置く
                                ($opponent_board, $own_board) = place_and_flip($opponent_board, $own_board, $positionLast);
                            }else{
                                #相手が置けないなら自分が置けるか確認
                                if(can_place_stone($own_board, $opponent_board, $positionNum)){
                                    ($own_board, $opponent_board) = place_and_flip($own_board, $opponent_board, $positionNum);
                                }
                            }
                            ($white_stone, $black_stone) = reverse_assign_boards($own_board, $opponent_board,$turn);

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
                            $result = "ゲーム終了！${game_result}<br>".print_board(reverse_assign_boards($own_board, $opponent_board,$turn))
                            ."<br>合計" . $totalNum-4 . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
                            $Threads->SetAttr($threadid,'othello_next',undef);
                        }
                        else{
                            #置いた結果の表示を生成
                            $result = "${position}に${thisStone}を置きました。<br>"
                            .print_board(reverse_assign_boards($own_board, $opponent_board,$turn))
                            ."<br>" . $totalNum-4 . "手目／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
                            $Threads->SetAttr($threadid,'othello_next',!$turn);
                        }
                    }else{
                        $result = "${position}には${thisStone}を置けません。";
                    }
                }
                #passコマンドの場合
                elsif(getOthelloCommand($message,'pass')){
                    #passできるかどうか確認
                    if(isPass($own_board, $opponent_board)){
                        $result = "置ける場所があるためパスはできません。";
                    }else{
                        #passした場合に相手が置けるか確認
                        if(isPass($opponent_board, $own_board)){
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
                            $result = "ゲーム終了！${game_result}<br>".print_board(reverse_assign_boards($own_board, $opponent_board,$turn))
                            ."<br>合計" . $totalNum-4 . "手<br>Final Score:●->$blackNum  ○->$whiteNum";
                            $Threads->SetAttr($threadid,'othello_next',undef);
                        }
                    }
                }
                #単純に譜面を表示する場合
                elsif(getOthelloCommand($message,'view')){
                    $result = print_board($white_stone, $black_stone)
                    ."<br>" . $totalNum-4 . "手目／NEXT:${nextStone}<br>Score:●->$blackNum  ○->$whiteNum";
                }
                #自陣と敵陣の情報を白石黒石に戻す
                ($white_stone, $black_stone) = reverse_assign_boards($own_board, $opponent_board,$turn);

                $Threads->SetAttr($threadid,'white_stone',Math::BigInt->as_hex($white_stone));
                $Threads->SetAttr($threadid,'black_stone',Math::BigInt->as_hex($black_stone));
            }else{
                #終了後にリザルト表示する場合
                if(getOthelloCommand($message,'result')){
                    my $game_result = ($blackNum == $whiteNum) ? '両者引き分けです。' : ($blackNum < $whiteNum) ? '○の勝利です。' : '●の勝利です。';
                    if($blackNum < $whiteNum){
                        $whiteNum += 64 - $totalNum;
                    }elsif($blackNum > $whiteNum){
                        $blackNum += 64 - $totalNum;
                    }
                    $result = ${game_result}."<br>".print_board(reverse_assign_boards($own_board, $opponent_board,$turn))
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
    my $n = @_;
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

#黒側白側交換
sub assign_boards {
    my ($white_stone, $black_stone, $next) = @_;
    my ($own_board, $opponent_board);

    if ($next == 1) {
        $own_board = $white_stone;
        $opponent_board = $black_stone;
    } else {
        $own_board = $black_stone;
        $opponent_board = $white_stone;
    }

    return ($own_board, $opponent_board);
}
sub reverse_assign_boards {
    my ($own_board, $opponent_board, $next) = @_;
    my ($white_stone, $black_stone);

    if ($next == 1) {
        $white_stone = $own_board;
        $black_stone = $opponent_board;
    } else {
        $black_stone = $own_board;
        $white_stone = $opponent_board;
    }

    return ($white_stone, $black_stone);
}

# ビットマスクを引数にとり、指定した位置に石を置けるかを返す
sub can_place_stone {
    my ($own_board, $opponent_board, $position) = @_;
    
    # すでに石が置かれているか確認
    return 0 if ($own_board | $opponent_board) & (1 << $position);
    
    # 8方向を調べる
    my @directions = (-1, 1, -8, 8, -7, 7, -9, 9);
    
    foreach my $dir (@directions) {
        my $current = $position + $dir;
        my $found_opponent = 0;
        
        while ($current >= 0 && $current < 64) {
            # 枠外かどうか
            if (($current % 8 - $position % 8) ** 2 > 1) {
                last;
            }
            
            # 相手の石があるか
            if ($opponent_board & (1 << $current)) {
                $found_opponent = 1;
            } elsif ($own_board & (1 << $current)) {
                if ($found_opponent) {
                    return 1;
                }
                last;
            } else {
                last;
            }
            
            $current += $dir;
        }
    }
    
    return 0;
}

# 石を置いてひっくり返す
sub place_and_flip {
    my ($own_board, $opponent_board, $position) = @_;
    
    # 石を置く
    $own_board |= (1 << $position);
    
    # 8方向を調べる
    my @directions = (-1, 1, -8, 8, -7, 7, -9, 9);
    
    foreach my $dir (@directions) {
        my $current = $position + $dir;
        my $found_opponent = 0;
        
        my @to_flip = ();
        
        while ($current >= 0 && $current < 64) {
            # 枠外かどうか
            if (($current % 8 - $position % 8) ** 2 > 1) {
                last;
            }
            
            # 相手の石があるか
            if ($opponent_board & (1 << $current)) {
                $found_opponent = 1;
                push @to_flip, $current;
            } elsif ($own_board & (1 << $current)) {
                if ($found_opponent) {
                    # 石をひっくり返す
                    foreach my $flip (@to_flip) {
                        $own_board |= (1 << $flip);
                        $opponent_board &= ~(1 << $flip);
                    }
                }
                last;
            } else {
                last;
            }
            
            $current += $dir;
        }
    }
    
    return ($own_board, $opponent_board);
}

# グリッド名から数字に変換
sub convert_position {
    my ($col, $row) = @_;

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

# 置ける場所があるか調べる
sub isPass
{
    my ($own_board, $opponent_board) = @_;
    for my $num (0..63){
        return 1 if can_place_stone($own_board, $opponent_board, $num);
    }
    return 0;
}

#最後に残った場所を取得
sub getPositionLast
{
    my ($own_board, $opponent_board) = @_;
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

# 盤面を生成
sub print_board {
    my ($white_stone, $black_stone) = @_;
    my $result = "";

    $result .= "　│Ａ│Ｂ│Ｃ│Ｄ│Ｅ│Ｆ│Ｇ│Ｈ│<br>";
    $result .= "─"."┼─" x 8 . "┤<br>";

    for my $row (0..7) {
        for my $col (0..7) {
            my $pos = $row * 8 + $col;
            my $mask = Math::BigInt->bone->blsft($pos);  # equivalent to (1 << $pos)
            my $ch = $col == 0 ? $row+1 : '';
            $ch =~ tr/0-9/０-９/;

            $result .= "$ch│";
            if ($white_stone->copy->band($mask)->is_zero() == 0) {  # if white_stone & (1 << pos) is not zero
                $result .= "○";
            } elsif ($black_stone->copy->band($mask)->is_zero() == 0) {  # if black_stone & (1 << pos) is not zero
                $result .= "●";
            } else {
                $result .= "　";
            }
        }
        $result .= "│<br>";
        $result .= "─"."┼─" x 8 . "┤<br>" unless $row == 7;
    }

    $result .= "─"."┴─" x 8 . "┘<br>";

    return $result;
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
