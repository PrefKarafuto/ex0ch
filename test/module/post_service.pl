#============================================================================================================
#
#	掲示板書き込み支援モジュール
#
#============================================================================================================
package	POST_SERVICE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use LWP::UserAgent;
use Digest::MD5;
use JSON;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use Encode qw(encode);
use Storable qw(lock_store lock_retrieve);
use warnings;
no warnings 'once';

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {
		'SYS'		=> undef,
		'SET'		=> undef,
		'FORM'		=> undef,
		'THREADS'	=> undef,
		'CONV'		=> undef,
		'SECURITY'	=> undef,
		'PLUGIN'	=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM(必須)
#	@param	$Form	FORM(必須)
#	@param	$Set	SETTING
#	@param	$Thread	THREAD
#	@param	$Conv	DATA_UTILS
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	my ($Sys, $Form, $Set, $Threads, $Conv) = @_;
	
	$this->{'SYS'} = $Sys;
	$this->{'FORM'} = $Form;
	$this->{'SET'} = $Set;
	$this->{'THREADS'} = $Threads;
	$this->{'CONV'} = $Conv;
	
	# モジュールが用意されてない場合はここで生成する
	if (!defined $Set) {
		require './module/setting.pl';
		$this->{'SET'} = SETTING->new;
		$this->{'SET'}->Load($Sys);
	}
	if (!defined $Threads) {
		require './module/thread.pl';
		$this->{'THREADS'} = THREAD->new;
		$this->{'THREADS'}->Load($Sys);
	}
	if (!defined $Conv) {
		require './module/data_utils.pl';
		$this->{'CONV'} = DATA_UTILS->new;
	}
	
	# キャップ管理モジュールロード
	require './module/cap.pl';
	$this->{'SECURITY'} = CAP_SECURITY->new;
	$this->{'SECURITY'}->Init($Sys);
	$this->{'SECURITY'}->SetGroupInfo($Sys->Get('BBS'));
	
	# 拡張機能情報管理モジュールロード
	require './module/plugin.pl';
	$this->{'PLUGIN'} = PLUGIN->new;
	$this->{'PLUGIN'}->Load($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	書き込み処理 - WriteData
#	-------------------------------------------
#	引　数：なし
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Write
{
	my $this = shift;

	# 書き込み前準備
	$this->ReadyBeforeCheck();
	
	my $err = $ZP::E_SUCCESS;

	# キャプチャ
	$err = $this->CaptchaAuthentication();
	return $err if $err;
	
	# 入力内容チェック(名前、メール)
	$err = $this->NormalizationNameMail();
	return $err if $err;
	
	# 入力内容チェック(本文)
	$err = $this->NormalizationContents();
	return $err if $err;
	
	# 規制チェック
	$err = $this->IsRegulation();
	return $err if $err;
	

	# 管理モジュールを用意
	require './module/dat.pl';
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Form = $this->{'FORM'};
	my $Conv = $this->{'CONV'};
	my $Threads = $this->{'THREADS'};
	my $Sec = $this->{'SECURITY'};
	
	# 停止チェック
	my $threadid = $Sys->Get('KEY');
	$Threads->LoadAttr($Sys);
 	return $ZP::E_LIMIT_STOPPEDTHREAD if ($Threads->GetAttr($threadid,'stop'));
	return $ZP::E_LIMIT_MOVEDTHREAD if ($Threads->GetAttr($threadid,'pool'));
	
	#コマンドによる過去ログ送り用
	$this->ToKakoLog($Sys,$Set,$Threads);

	# SLIP
	my ($slip_result,$idEnd) = $this->MakeSlip($Sys,$Form,$Set,$Threads);

	# 忍法帖ロード
	require './module/ninpocho.pl';
	my $Ninja = NINPOCHO->new;
	my $SaveCom = 0;
	if ($Set->Get('BBS_NINJA')){
		$SaveCom = $this->LoadNinpocho($Sys, $Form, $Ninja);
	}

	#BANチェック
	$err = $this->BanCheck($Sys, $Form, $Threads, $Ninja, $Sec);
	return $err if $err;
	
	# 書き込み直前処理
	$err = $this->ReadyBeforeWrite($Ninja);
	return $err if $err;

	# 忍法帖
	if($Set->Get('BBS_NINJA')){
		# レベル制限
		$err = $this->LevelLimit($Sys, $Set, $Form, $Threads, $Ninja, $Sec);
		return $err if $err;

		# 本処理
		$this->Ninpocho($Sys,$Set,$Form,$Ninja);

		# 忍法帖保存
		$err = $Ninja->Save($Sys,$SaveCom);
		return $err if $err;
	}

	# Datに保存する一行データを生成
	my $line = $this->MakeDatLine($Sys, $Set,$Form, $Threads, $Sec, $Conv, $Ninja, $idEnd, $slip_result);

	# ログ書き込み
	$this->AddLog($Sys,$Set,$Form,$line);
	
	# リモートホスト保存(SETTING.TXT変更により、常に保存)
	SaveHost($Sys, $Form);
	
	# datファイルへ直接書き込み
	($err,my $resNum) = $this->AddDatFile($Sys,$Threads,$line);
	
	if ($err == $ZP::E_SUCCESS) {
		# タイムラインへ追加
		$this->AddTimeLine($Sys,$Set,$Threads, $Conv, $line) if $Set->Get('BBS_TL_MAX');

		# subject.txtの更新
		# スレッド作成モードなら新規に追加する
		if ($Sys->Equal('MODE', 1)) {
			$this->AddSubjectNewThread($Sys,$Set,$Form,$Threads,$line);
		}
		# 書き込みモードならレス数の更新
		else {
			$Threads->OnDemand($Sys, $threadid, $resNum, $Sys->Get('updown', ''));
		}
	}

	# 期限切れのファイルを削除
	$this->CleanUp($Sys);

	# 書き込み完了後に実行するプラグイン
	$this->ExecutePlugin(32);
	
	return $err;

}

#------------------------------------------------------------------------------------------------------------
#
#	前準備
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub ReadyBeforeCheck
{
	my ($this) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Form = $this->{'FORM'};
	
	# cookie用にオリジナルを保存する
	my $from = $Form->Get('FROM');
	my $mail = $Form->Get('mail');
	$from =~ s/[\r\n]//g;
	$mail =~ s/[\r\n]//g;
	$Form->Set('NAME', $from);
	$Form->Set('MAIL', $mail);
	
	# キャップパスの抽出と削除
	$Sys->Set('CAPID', '');
	if ($mail =~ s/(?:#|＃)(.+)//) {
		my $capPass = $1;
		
		# キャップ情報設定
		my $capID = $this->{'SECURITY'}->GetCapID($capPass);
		$Sys->Set('CAPID', $capID);
		$Form->Set('mail', $mail);
	}
	
	# datパスの生成
	my $datPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $Sys->Get('KEY') . '.dat';
	$Sys->Set('DATPATH', $datPath);
	
	# 本文禁則文字変換
	my $text = $Form->Get('MESSAGE');
	$this->{'CONV'}->ConvertCharacter1(\$text, 2);
	$Form->Set('MESSAGE', $text);
}

#------------------------------------------------------------------------------------------------------------
#
#	書き込み直前処理
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub ReadyBeforeWrite
{
	my $this = shift;
	my ($Ninja) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Form = $this->{'FORM'};
	my $Sec = $this->{'SECURITY'};
	my $capID = $Sys->Get('CAPID', '');
	my $sessionID = $Sys->Get('SID');
	my $bbs = $Form->Get('bbs');
	my $from = $Form->Get('FROM');
	my $koyuu = $Sys->Get('KOYUU');
	my $client = $Sys->Get('CLIENT');
	my $host = $ENV{'REMOTE_HOST'};
	my $addr = $ENV{'REMOTE_ADDR'};
	my $ua = $ENV{'HTTP_USER_AGENT'};
	my $Threads = $this->{'THREADS'};
	
	# 規制ユーザ・NGワードチェック
	{
		# 規制ユーザ
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NGUSER, $bbs)) {
			require './module/user.pl';
			my $vUser = USER->new;
			$vUser->Load($Sys);
			
			my $koyuu2 = ($client & $ZP::C_MOBILE_IDGET & ~$ZP::C_P2 ? $koyuu : undef);
			my $check = $vUser->Check($host, $addr, $koyuu2,$ua, $sessionID);
			$Sys->Set('HITS', '´・ω・｀') if $Sys->Get('HIDE_HITS');
			if ($check == 4) {
				return $ZP::E_REG_NGUSER;
			}
			elsif ($check == 2) {
				return $ZP::E_REG_NGUSER if ($from !~ /$host/i); # $hostは正規表現
				$Form->Set('FROM', "</b>[´・ω・｀] <b>$from");
			}
		}
		
		# NGワード
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NGWORD, $bbs)) {
			require './module/ng_word.pl';
			my $ngWord = NG_WORD->new;
			$ngWord->Load($Sys);
			my @checkKey = ('FROM', 'mail', 'MESSAGE','subject');
			
			my $check = $ngWord->Check($this->{'FORM'}, \@checkKey);
			if ($check == 3) {
				return $ZP::E_REG_NGWORD;
			}
			elsif ($check == 1) {
				$ngWord->Method($Form, \@checkKey);
			}
			elsif ($check == 2) {
				$Form->Set('FROM', "</b>[´+ω+｀] $host <b>$from");
			}
		}
	}
	
	my $CommandSet = $Set->Get('BBS_COMMAND');

	$Threads->LoadAttr($Sys);
	my $threadid = $Sys->Get('KEY');
	my $commandAuth = $Sec->IsAuthority($capID, $ZP::CAP_REG_COMMAND, $Form->Get('bbs'));
	my $noAttr = $Sec->IsAuthority($capID, $ZP::CAP_REG_NOATTR, $Form->Get('bbs'));
	my $noNinja = $Sec->IsAuthority($capID, $ZP::CAP_REG_NONINJA, $Form->Get('bbs'));

	# コマンド
	my ($min_level, $factor) = split(/-/, $Set->Get('NINJA_USE_COMMAND'));
	if($Ninja->Get('ban_command') ne 'on' && (($Set->Get('BBS_NINJA') && $Ninja->Get('ninLv') >= $min_level) || !$Set->Get('BBS_NINJA') || $commandAuth)){

		# Capの権限があった場合すべて許可
		$CommandSet = oct("0b11111111111111111111111111") if $commandAuth;		# 2^23

		if($Sys->Equal('MODE', 1)){
			# スレ立て
			Command($Sys,$Form,$Set,$Threads,$Ninja,$CommandSet,$noNinja);
		}
		else{
			# レス
			if($Form->Get('mail') =~ /!pass:(.{1,30})/){
				require Digest::SHA::PurePerl;
				my $ctx = Digest::SHA::PurePerl->new;
				$ctx->add(':', $Sys->Get('SERVER'));
				$ctx->add(':', $threadid);
				$ctx->add(':', $1);
				my $inputPass = $ctx->b64digest;

				my $threadPass = $Threads->GetAttr($threadid, 'pass');

				#メール欄からpass削除
				my $mail = $Form->Get('mail');
				$mail =~ s/!pass:(.{1,30})//;
				$Form->Set('mail',$mail);
				
				if($inputPass eq $threadPass && $threadPass){
					Command($Sys,$Form,$Set,$Threads,$Ninja,$CommandSet,$noNinja);
				}
			}
			elsif($commandAuth || (GetSessionID($Sys,$threadid,1)||$Threads->GetAttr($threadid,'sub')) eq $Sys->Get('SID')){
				Command($Sys,$Form,$Set,$Threads,$Ninja,$CommandSet,$noNinja);
			}

			# BAN投票用
			VoteBanCommand($Sys,$Form,$Set,$Threads) if $Set->Get('BBS_VOTE');
		}
	}
	
	my $text = $Form->Get('MESSAGE');
	$text =~ s/<br>/ <br> /g;
	$Form->Set('MESSAGE', " $text ");
	
	# 名無し設定
	$from = $Form->Get('FROM', '');
	if (($from eq ''||$Threads->GetAttr($threadid,'force774')) && !$noAttr) {
		if($Threads->GetAttr($threadid,'change774')){
			require HTML::Entities;
			$from = HTML::Entities::decode($Threads->GetAttr($threadid,'change774'));
		}
		else{
			$from = $this->{'SET'}->Get('BBS_NONAME_NAME');
		}
		$Form->Set('FROM', $from);
	}

	$this->OMIKUJI($Sys, $Form);	#おみくじ
	$this->tasukeruyo($Sys, $Form);	#IP+UA表示

	return 0;
}
# ログからセッションID取得
sub GetSessionID
{
	my ($Sys,$threadid,$resnum) = @_;
	require './module/log.pl';
	my $Logger = LOG->new;
	my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $threadid;
	$resnum--;
	$Logger->Open($logPath, 0, 1 | 2);

	# レス番が存在しない場合は空文字が返る
	my $log_entry = $Logger->Get($resnum) // '';
	my $sid = (split(/<>/, $log_entry))[9];
	$Logger->Close();

	if($resnum == 1 && !$sid){
		require './module/thread.pl';
		my $Threads = THREAD->new;
		$Threads->LoadAttr($Sys);
		$sid = $Threads->GetAttr($threadid,'owner');
	}

	return $sid;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザーコマンド
#	-------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub Command
{
	my ($Sys,$Form,$Set,$Threads,$Ninja,$setBitMask,$noNinja) = @_;
	$Threads->LoadAttr($Sys);
	my $threadid = $Sys->Get('KEY');
	my $Command = '';
	my $NinStat = $Set->Get('BBS_NINJA');

	#スレ主用パス(コマンド欄)/スレ立て時専用処理
	if($Sys->Equal('MODE', 1)){
		#passを取得・設定
		if($Form->Get('mail') =~ /!pass:(.{1,30})/ && ($setBitMask & 2 ** 0)){
			require Digest::SHA::PurePerl;
			my $ctx = Digest::SHA::PurePerl->new;
			$ctx->add(':', $Sys->Get('SERVER'));
			$ctx->add(':', $threadid);
			$ctx->add(':', $1);
			my $pass = $ctx->b64digest;

			$Threads->SetAttr($threadid, 'pass',$pass);

			my $mail = $Form->Get('mail');
			$mail =~ s/!pass:(.{1,30})//;
			$Form->Set('mail',$mail);
		}
		#最大レス数変更
		if ($Form->Get('MESSAGE') =~ /(^|<br>)!maxres:([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 1)) {
			my $resmin = 10;
			my $resmax = $Sys->Get('RESMAX') * 2;
			if ($2 && $2 >= $resmin && $2 <= $resmax) {
				$Threads->SetAttr($threadid, 'maxres', int $2);
				my $maxres = $Threads->GetAttr($threadid, 'maxres');
				$Command .= '※最大'.$2.'レス<br>';
			}else{
				if($2 > $resmax){
					$Command .= '値が過大<br>';
				}else{
					$Command .= '値が過小<br>';
				}
			}
		}
		#extendコマンド
		if ($Form->Get('MESSAGE') =~ /^!extend:(|on|default|none|checked):(|v{3,6}):([1-9][0-9]*):([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 20)) {
			my $resmin = 10;
			my $resmax = $Sys->Get('RESMAX') * 2;
			my $sizemin = 1;
			my $sizemax = $Set->Get('BBS_DATMAX') * 2;

			my $id = $1;
			my $slip = $2;
			my $line = $3;
			my $size = $4;

			my ($a,$b,$c,$d) = {'-','-','-','-'};

			if($id){
				$Threads->SetAttr($threadid, 'id', $id);
				#$a = '+';
			}
			if($slip){
				$Threads->SetAttr($threadid, 'slip',$slip);
				$b = '+';
			}
			if($line && $line >= $resmin && $line <= $resmax){
				$Threads->SetAttr($threadid, 'maxres', int $line);
				$c = '+';
			}
			if($size){
				$Threads->SetAttr($threadid, 'maxsize', int $size);
				#$d = '+';
			}
			$Command .= "VIPQ2_EXTDAT: $id:$slip:$line:$size:$a$b$c$d: EXT was configured<br>";
		}
		# スレッド属性引き継ぎ
		if ($Form->Get('MESSAGE') =~ /^!loadattr:([1-9][0-9]{9})(<br>|$)/ && ($setBitMask & 2 ** 23)) {
			my $Handover_threadid = $1;
			$Threads->LoadAttr($Sys,$Handover_threadid);
			my %Attr = %{$Threads->GetAttr($Handover_threadid,undef)};
			if(keys(%Attr)){
				$Threads->SetAttr($threadid,undef,\%Attr);
				$Command .= "スレッドID:${Handover_threadid}から設定を引き継ぎました。<br>";
			}else{
				$Command .= '引き継ぎ可能な設定項目なし。<br>';
			}
		}
	}

	##スレ中パスワード保持者のみ
	if(!$Sys->Equal('MODE', 1)){
		#スレスト
		if($Form->Get('MESSAGE') =~ /(^|<br>)!stop(<br>|$)/ && ($setBitMask & 2 ** 7)){
			my $ninLv = $Ninja->Get('ninLv');
			my ($min_level, $factor) = split(/-/, $Set->Get('NINJA_THREAD_STOP'));
			if(($NinStat && $ninLv >= $min_level)||!$NinStat||$noNinja){
				$Threads->SetAttr($threadid, 'stop',1);
				$Command .= '※スレスト<br>';
				$Ninja->Set('ninLv',$ninLv - $factor) unless $noNinja;
			}else{
				$Command .= '※レベル不足<br>';
			}
		}
		#過去ログ送り
		if($Form->Get('MESSAGE') =~ /(^|<br>)!pool(<br>|$)/ && ($setBitMask & 2 ** 9)){
			$Threads->SetAttr($threadid, 'pool',1);
			$Command .= '※過去ログ送り<br>';
		}
		#スレタイ変更
		if($Form->Get('MESSAGE') =~ /(^|<br>)!(changetitle|chtt):(.+)(<br>|$)/ && ($setBitMask & 2 ** 14)){
			my $newTitle = $2;
			if($Set->Get('BBS_SUBJECT_COUNT') >= length($newTitle) && $newTitle){
				require './module/dat.pl';
				my $Dat = DAT->new;
				my $Path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS').'/dat/'.$threadid.'.dat';
				if($Dat->Load($Sys,$Path,0)){
					my $line = $Dat->Get(0);
					$line = $$line;
					my @data = split(/<>/,$line);
					my $Title = $data[4];
					chomp($Title);
					if($Title ne $newTitle){
						my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
						$mon++;
						$year += 1900;
						$data[3] .= "<hr><font color=\"red\">※$year/$mon/$mday $hour:$min:$sec スレタイ変更</font><br>変更前：$Title";
						$data[4] = $newTitle;
						my $addMessage = '';	#[スレタイ変更]など
						$Dat->Set(0,(join('<>',@data)."$addMessage\n"));
						$Dat->Save($Sys);
						#subject.txt更新用
						$Threads->Load($Sys);
						$Threads->UpdateAll($Sys);
						$Threads->Save($Sys);
						$Command .= "※スレタイ変更：$Title → $newTitle<br>";
					}
					$Dat->Close();
				}
			}else{
				$Command .= "※スレタイ長すぎ" if $newTitle;
			}
		}
		#レス削除
		if($Form->Get('MESSAGE') =~ /(^|<br>)!delete:&gt;&gt;([1-9][0-9]*)-?([1-9][0-9]*)?(<br>|$)/ && ($setBitMask & 2 ** 19)){
			my $target = $2;
			my $target2 = $3;
			my $del = 'ユーザー削除';

			my $ninLv = $Ninja->Get('ninLv');
			my ($min_level, $factor) = split(/-/, $Set->Get('NINJA_RES_DEL'));

			if($target - 1){
				require './module/dat.pl';
				my $Dat = DAT->new;
				my $Path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS').'/dat/'.$threadid.'.dat';
				if($Dat->Load($Sys,$Path,0)){
					if($target2 && $target < $target2){
						my $cost = $factor * ($target2 - $target + 1);
						if(($NinStat && $ninLv >= $min_level && $ninLv - $min_level >= $cost) || !$NinStat || $noNinja){
							my $li = $Dat->Get($target2-1);
							$li = $$li;
							my $count = 0;
							if($li){
								my $i;
								for($i = $target-1;$i <= $target2-1;$i++){
									my $line = $Dat->Get($i);
									$line = $$line;
									chomp($line);
									if ((split(/<>/,$line))[4] eq ''){
										if($line){
											my $deleteMessage = "$del<>$del<>$del<>$del<>$del\n";
											$Dat->Set($i,$deleteMessage);
										}else{
											last;
										}
									}else{
										$count++;
									}
								}
								$Dat->Save($Sys);
								if($count == 0){
									$Command .= "※&gt;&gt;${target}-${target2}を削除<br>";
								}elsif($count < ($target2-$target) && $count){
									$Command .= "※&gt;&gt;${target}-${target2}の内削除済みの${count}レスを除き削除<br>";
								}else{
									$Command .= "※&gt;&gt;${target}-${target2}は削除済み<br>";
								}
								$Ninja->Set('ninLv',$ninLv - $factor*$count) unless $noNinja;
							}else{
								$Command .= "※範囲指定が変<br>";
							}
						}else{
							$Command .= "※レベル不足<br>";
						}

					}else{
						if(($NinStat && $ninLv >= $min_level)||!$NinStat||$noNinja){
							my $line = $Dat->Get($target-1);
							$line = $$line;
							chomp($line);
							if ((split(/<>/,$line))[4] eq ''){
								if($line){
									my $deleteMessage = "$del<>$del<>$del<>$del<>$del\n";
									$Dat->Set($target-1,$deleteMessage);
									$Dat->Save($Sys);
									$Command .= "※&gt;&gt;${target}を削除<br>";

									$Ninja->Set('ninLv',$ninLv - $factor) unless $noNinja;
								}else{
									$Command .= "※存在しません<br>";
								}
							}else{
								$Command .= "※削除済み<br>";
							}
						}else{
							$Command .= "※レベル不足<br>";
						}
					}
					$Dat->Close();
				}
			}else{
				$Command .= "※>>1は削除不可<br>";
			}
		}
		#追記
		if($Form->Get('MESSAGE') =~ /(^|<br>)!add:&gt;&gt;([1-9][0-9]*):?(.*)(<br>|$)/ && ($setBitMask & 2 ** 16)){
			my $addMessage = $3;
			my $targetNum = $2 - 1;
			if($addMessage && $targetNum + 1){
				if(GetSessionID($Sys,$threadid,1) eq GetSessionID($Sys,$threadid,$targetNum +1)){
					require './module/dat.pl';
					my $Dat = DAT->new;
					my $Path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS').'/dat/'.$threadid.'.dat';
					if($Dat->Load($Sys,$Path,0)){
						my $line = $Dat->Get($targetNum);
						if($line){
							$line = $$line;
							my @data = split(/<>/,$line);
							my $Message = $data[3];
							if($Set->Get('BBS_MESSAGE_COUNT') >= length($Message.$addMessage) && $addMessage){
								my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
								$mon++;
								$year += 1900;
								$data[3] .= "<hr><font color=\"red\">※$year/$mon/$mday $hour:$min:$sec 追記</font><br>$addMessage";
								$Dat->Set($targetNum,(join('<>',@data)));
								$Dat->Save($Sys);
								$Command .= "※&gt;&gt;$2に追記<br>";
							}else{
								$Command .= "※追記長すぎ<br>";
							}
						}else{
							$Command .= "※無効なレス番号<br>";
						}
						$Dat->Close();
					}
				}else{
					$Command .= "※他人のレスには追記不可<br>";
				}
			}
		}
		#副主
		if($Form->Get('MESSAGE') =~ /(^|<br>)!sub:&gt;&gt;([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 21)){
			my $sub_owner = GetSessionID($Sys,$threadid,$2);
			if($Sys->Get('SID') ne $Threads->GetAttr($threadid, 'sub')){
				if($sub_owner && GetSessionID($Sys,$threadid,1) ne $sub_owner){
					$Threads->SetAttr($threadid, 'sub',$sub_owner);
					$Command .= "※&gt;&gt;$2を副主に任命しました<br>";
				}else{
					$Command .= '※無効なレス番号<br>';
				}
			}else{
				$Command .= '※使用不可<br>';
			}
		}
		#BAN
		if($Form->Get('MESSAGE') =~ /(^|<br>)!ban:&gt;&gt;([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 12)){
			my $ban_attr_ref = $Threads->GetAttr($threadid,'ban');
			my %banuserAttr = ();

			# 戻り値がハッシュリファレンスか確認
			if (ref($ban_attr_ref) eq 'HASH') {
				%banuserAttr = %{$ban_attr_ref};
			}

			my $bannum = scalar keys %banuserAttr;
			my $bansid = GetSessionID($Sys,$threadid,$2);
			my $nusisid = GetSessionID($Sys,$threadid,1);

			my $ninLv = $Ninja->Get('ninLv');
			my ($min_level, $factor) = split(/-/, $Set->Get('NINJA_USER_BAN'));

			if(($NinStat && $ninLv >= $min_level) || !$NinStat || $noNinja){
				if($bansid){
					if($bansid ne $nusisid){
						if(defined $banuserAttr{$bansid} && $banuserAttr{$bansid} == 0){
							$Command .= "※既にBAN済<br>";
						} else {
							# BANの処理
							$banuserAttr{$bansid} = 0;
							$Threads->SetAttr($threadid, 'ban', \%banuserAttr);
							$Command .= "※BAN：&gt;&gt;$2<br>";
							$Ninja->Set('ninLv', $ninLv - $factor) unless $noNinja;
						}
					} else {
						$Command .= "※スレ主はBAN不可<br>";
					}
				} else {
					$Command .= "※無効なレス番号<br>";
				}
			} else {
				$Command .= "※レベル不足<br>";
			}
		}
	}

	##スレ立て時＆スレ中パスワード保持者のみ
	#強制sage
	if($Form->Get('MESSAGE') =~ /(^|<br>)!sage(<br>|$)/ && ($setBitMask & 2 ** 2)){
		$Threads->SetAttr($threadid, 'sagemode',1);
		$Command .= '※強制sage<br>';
	}
	#強制age
	if($Form->Get('MESSAGE') =~ /(^|<br>)!float(<br>|$)/ && ($setBitMask & 2 ** 17)){
		$Threads->SetAttr($threadid, 'float',1);
		$Command .= '※強制age<br>';
	}
	#不落
	if($Form->Get('MESSAGE') =~ /(^|<br>)!nopool(<br>|$)/ && ($setBitMask & 2 ** 18)){
		$Threads->SetAttr($threadid, 'nopool',1);
		$Command .= '※不落<br>';
	}
	#BBS_SLIP
	if($Form->Get('MESSAGE') =~ /(^|<br>)!slip:(v{3,6})(<br>|$)/ && ($setBitMask & 2 ** 11)){
		$Threads->SetAttr($threadid, 'slip',$2);
		$Command .= '※BBS_SLIP='.$2.'<br>';
	}
	#名無し強制
	if($Form->Get('MESSAGE') =~ /(^|<br>)!force774(<br>|$)/ && ($setBitMask & 2 ** 5)){
		$Threads->SetAttr($threadid, 'force774',1);
		$Command .= '※強制名無し<br>';
		#$Form->Set('FROM','');
	}
	#実況モード
	if($Form->Get('MESSAGE') =~ /(^|<br>)!live(<br>|$)/ && ($setBitMask & 2 ** 10)){
		$Threads->SetAttr($threadid, 'live',1);
		$Command .= '※実況スレ<br>';
	}
	#スレ主非表示
	if($Form->Get('MESSAGE') =~ /(^|<br>)!hidenusi(<br>|$)/ && ($setBitMask & 2 ** 15)){
		if(!$Set->Get('BBS_HIDENUSI')){
			$Threads->SetAttr($threadid, 'hidenusi',1);
			$Command .= '※スレ主非表示<br>';
		}
	}
	#名無し変更
	if($Form->Get('MESSAGE') =~ /(?:^|<br>\s*)!change774:(\S.*?\S|\S)\s*(?=<br>|$)/ && ($setBitMask & 2 ** 6)){
		my $new774 = $1;
		if($Set->Get('BBS_NAME_COUNT') => length($new774)){
			require HTML::Entities;
			my $new774 = $1;
			$new774 = HTML::Entities::encode_entities($new774);
			$Threads->SetAttr($threadid, 'change774',$new774);
			$new774 = HTML::Entities::decode($new774);
			$Command .= '※名無し：'.$new774.'<br>';
		}else{
			$Command .= '※名無し長すぎ<br>';
		}
	}
	#コマンド取り消し
	if($Form->Get('MESSAGE') =~ /(^|<br>)!delcmd:([0-9a-zA-Z&;]{4,20})(<br>|$)/ && ($setBitMask & 2 ** 8)){
		my $delCommand = $2;
		$delCommand =~ s/^sage$/sagemode/;
		if($Threads->GetAttr($threadid, $delCommand)){
			if($delCommand =~ /ban&gt;&gt;([1-9][0-9]*)/ ){
				# BAN取り消し用
				my $ban_attr_ref = $Threads->GetAttr($threadid,'ban');
				my %banuserAttr = ();

				# 戻り値がハッシュリファレンスか確認
				if (ref($ban_attr_ref) eq 'HASH') {
					%banuserAttr = %{$ban_attr_ref};
				}

				my $bannum = scalar keys %banuserAttr;
				my $bansid = GetSessionID($Sys,$threadid,$1);
				if($bannum){
					if($bansid){
						if(defined $banuserAttr{$bansid} && $banuserAttr{$bansid} == 0){
							# 変更があればスレッド属性を更新
							delete $banuserAttr{$bansid};
							$Threads->SetAttr($threadid, 'ban', \%banuserAttr);
							$Command .= "&gt;&gt;$1のBANを解除";
						} else {
							$Command .= "※対象はBANされていません<br>";
						}
					} else {
						$Command .= "※無効なレス番号<br>";
					}
				} else {
					$Command .= "※設定されていません<br>";
				}
			}else{
				$Threads->SetAttr($threadid, $delCommand,'');
				$delCommand =~ s/^sagemode$/sage/;
				$Command .= '※'.$delCommand.'取り消し<br>';
			}
		}
		else{
			$delCommand =~ s/^sagemode$/sage/;
			$Command .= '※'.$delCommand.'は設定されていません<br>';
		}
	}
	#ID無し若しくはIDをスレッドで変更（!noidと!changeidがあった場合は!noid優先）
	if($Form->Get('MESSAGE') =~ /(^|<br>)!noid(<br>|$)/ && ($setBitMask & 2 ** 3)){
		$Threads->SetAttr($threadid, 'noid',1);
		$Command .= '※ID無し<br>';
	}
	if(!$Threads->GetAttr($threadid, 'noid') && $Form->Get('MESSAGE') =~ /(^|<br>)!changeid(<br>|$)/ && ($setBitMask & 2 ** 4)){
		$Threads->SetAttr($threadid, 'changeid',1);
		$Command .= '※ID変更<br>';
	}

	#設定表示
	if($Form->Get('MESSAGE') =~ /(^|<br>)!attr(<br>|$)/){
		my %ThreadAttr = %{$Threads->GetAttr($threadid,undef)};
		my %allAttr = (
			'sagemode'  => { 'name' => 'sage進行', 'type' => 'bool' },
			'float'     => { 'name' => '浮上', 'type' => 'bool' },
			'pass'      => { 'name' => 'パスワード', 'type' => 'bool' },
			'maxres'    => { 'name' => '最大レス数', 'type' => 'str' },
			'slip'      => { 'name' => 'BBS_SLIP', 'type' => 'str' },
			'noid'      => { 'name' => 'IDなし', 'type' => 'bool' },
			'changeid'  => { 'name' => '独自ID', 'type' => 'bool' },
			'force774'  => { 'name' => '強制名無し', 'type' => 'bool' },
			'change774' => { 'name' => '名無し変更', 'type' => 'str' },
			'live'      => { 'name' => '実況モード', 'type' => 'bool' },
			'hidenusi'  => { 'name' => 'スレ主表示なし', 'type' => 'bool' },
			'nopool'    => { 'name' => '不落', 'type' => 'bool' },
			'ninlv'     => { 'name' => '忍法帖Lv制限', 'type' => 'str' },
			'ban'       => { 'name' => 'アクセス禁止', 'type' => 'elem' },
			'sub'    	=> { 'name' => '副主', 'type' => 'bool' },
		);
		$Command .= '[スレッドの設定]<br>';
		foreach my $attr (sort keys %ThreadAttr){
			my $type = $allAttr{$attr}->{'type'};
			my $value = $ThreadAttr{$attr};
			if(defined $value){
				if($type eq 'bool'){
					$Command .= $allAttr{$attr}->{'name'}.'<br>';
				}elsif($type eq 'str'){
					$Command .= $allAttr{$attr}->{'name'}.":$value<br>";
				}elsif($type eq 'elem'){
					my $count = scalar keys %{$value};
					$Command .= $allAttr{$attr}->{'name'}.":$count<br>";
				}
			}
		}
	}

	#忍法帖があった場合
	if($Set->Get('BBS_NINJA')){
		#忍法帖レベル制限
		if($Form->Get('MESSAGE') =~ /(^|<br>)!ninlv:([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 13)){
			my $lvmax = $Sys->Get('NINLVMAX');
			my $write_min = $Set->Get('NINJA_WRITE_MESSAGE');
			if($2 <= $lvmax){
				if($2 >= $write_min){
					$Threads->SetAttr($threadid, 'ninLv',$2);
					$Command .= "※忍法帖Lv$2未満は書き込み不可<br>";
				}else{
					$Command .= "※${write_min}未満は設定不可<br>";
				}
			}else{
				$Command .= "※値高すぎ<br>";
			}
		}
	}
	if($Command){
		$Threads->SaveAttr($Sys);
		$Command =~ s/<br>$//;
		$Form->Set('MESSAGE',$Form->Get('MESSAGE')."<hr><font color=\"red\">$Command</font>");
	}
}

# BAN投票
sub VoteBanCommand
{
	my ($Sys,$Form,$Set,$Threads,$setBitMask) = @_;
	my $threadid = $Sys->Get('KEY');
	$Threads->LoadAttr($Sys);
	my $Command = '';
	# 投票
	if($Form->Get('MESSAGE') =~ /(^|<br>)!vote:&gt;&gt;([1-9][0-9]*)(<br>|$)/ && ($setBitMask & 2 ** 22)){
		my $target = $2;
		my $target_id = GetSessionID($Sys,$threadid,$target);
		if($target_id){
			if($target_id ne GetSessionID($Sys,$threadid,1)){
				my $ban_attr_ref = $Threads->GetAttr($threadid,'ban');
				my %banuserAttr = ();

				# 戻り値がハッシュリファレンスか確認
				if (ref($ban_attr_ref) eq 'HASH') {
					%banuserAttr = %{$ban_attr_ref};
				}

				if(defined $banuserAttr{$target_id} && $banuserAttr{$target_id} == 0){
					$Command = "※既にBAN済<br>";
				} else {
					# $banuserAttr{$target_id} の値が未定義の場合に備えて初期化
					$banuserAttr{$target_id} = {} unless ref($banuserAttr{$target_id}) eq 'HASH' || $banuserAttr{$target_id} == 0;

					if(exists $banuserAttr{$target_id}->{$Sys->Get('SID')}){
						delete $banuserAttr{$target_id}->{$Sys->Get('SID')};
						$Threads->SetAttr($threadid,'ban', \%banuserAttr);
						$Command = "※投票取り消し<br>";
					} else {
						$banuserAttr{$target_id}->{$Sys->Get('SID')} = 1;
						# BAN処理
						my $vote_count = scalar keys %{ $banuserAttr{$target_id} };
						my $specified_num = $Set->Get('BBS_VOTE');
						if($vote_count >= $specified_num || $target_id eq $Sys->Get('SID')){
							# 規定数以上の票もしくはBAN対象による自己投票
							$banuserAttr{$target_id} = 0;
							$Command = "※BAN：&gt;&gt;$target<br>";
						} else {
							$Command = "※&gt;&gt;${target}に投票しました [$vote_count/$specified_num]<br>";
						}
						$Threads->SetAttr($threadid, 'ban', \%banuserAttr);
					}
				}
			} else {
				$Command = "※スレ主には投票できません";
			}   
		} else {
			$Command = "※無効なレス番号";
		}
	}


	if($Command){
		$Threads->SaveAttr($Sys);
		$Command =~ s/<br>$//;
		$Form->Set('MESSAGE',$Form->Get('MESSAGE')."<hr><font color=\"red\">$Command</font>");
	}
}

# 過去ログの移動や保存を行う
sub ToKakoLog {
	my $this = shift;
	my ($Sys, $Set, $Threads) = @_;
	
	require './module/file_utils.pl';
	require './module/bbs_service.pl';  # 一度だけ読み込む
	my $Pools = POOL_THREAD->new;
	my $BBSAid = BBS_SERVICE->new;  # 一度だけインスタンス化

	my $elapsed = 60 * 60;  # 1時間
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	my $BBSname = $Set->Get('BBS_KAKO');
	my $otherBBSpath = $Sys->Get('BBSPATH') . '/' . $BBSname;
	
	my @threadList = ();
	my $isUpdate = '';  # 更新が必要な場合
	
	$Threads->GetKeySet('ALL', '', \@threadList);
	$Threads->LoadAttrAll($Sys);

	foreach my $id (@threadList) {
		my $need_update = process_thread($Sys, $Set, $Threads, $Pools, $path, $otherBBSpath, $id, $elapsed, $BBSname);
		$isUpdate = 1 if $need_update;  # 更新が必要ならフラグをたてる
	}

	if ($isUpdate && $BBSname) {
		update_board($Sys, $Threads, $BBSAid,undef);
		update_board($Sys, $Threads, $BBSAid,$BBSname)
	}

	$Pools->Save($Sys);
	$Threads->Save($Sys);
}

# 各スレッドに対する処理
# 移動を行った場合は1を、そうでない場合は0を返す
sub process_thread {
	my ($Sys, $Set, $Threads, $Pools, $path, $otherBBSpath, $id, $elapsed, $BBSname) = @_;
	
	my $need_update = 0;

	my $attrLive = $Threads->GetAttr($id, 'live');
	my $attrPool = $Threads->GetAttr($id, 'pool');
	my $attrNoPool = $Threads->GetAttr($id, 'nopool');
	my $datPath = "$path/dat/$id.dat";
	my $lastmodif = (stat $datPath)[9];

	my $AttrResMax = $Threads->GetAttr($id,'maxres');
	my $resNum = DAT::GetNumFromFile($datPath);
	my $MAXRES = $AttrResMax ? $AttrResMax : $Sys->Get('RESMAX');

	# poolコマンドが入力された場合　or　実況モード/スレッド完走且つ最終更新から一時間以上経っていた場合、落とす
	my $is_enable = $Set->Get('BBS_AUTOFALL');
	my $is_complete = $resNum > $MAXRES;
	my $is_timeover = time - $lastmodif > $elapsed;
	if ($attrPool || ($attrLive&&$is_timeover) || ($is_complete&&$is_timeover&&$is_enable&&!$attrNoPool))  {
		$need_update = 1;
		if ($BBSname) {
			# 過去ログ保管先として掲示板を設定
			FILE_UTILS::Move($datPath, "$otherBBSpath/dat/$id.dat");
		} else {
			# 過去ログ保管先がプール
			$Pools->Add($id, $Threads->Get('SUBJECT', $id), $Threads->Get('RES', $id));
			FILE_UTILS::Move($datPath, "$path/pool/$id.cgi");
		}
		# subjectから除外
		$Threads->Delete($id);
		# 属性削除
		$Threads->LoadAttr($Sys);
		$Threads->DeleteAttr($id);
		$Threads->SaveAttr($Sys);
	}
	return $need_update;
}

# 掲示板を更新
sub update_board {
	my ($Sys, $Threads, $BBSAid,$BBSname) = @_;
	
	$Sys->Set('BBS', $BBSname) if $BBSname;
	
	#subject.txt更新
	$Threads->Load($Sys);
	$Threads->UpdateAll($Sys);
	$Threads->Save($Sys);
	
	#index.html&subback.html更新
	if(!$BBSname){
	$Sys->Set('MODE', 'CREATE');
	$BBSAid->Init($Sys, undef);
	$BBSAid->CreateIndex();
	$BBSAid->CreateSubback();
	}
	return 0;
}


#------------------------------------------------------------------------------------------------------------
#
#	プラグイン処理
#	-------------------------------------------------------------------------------------
#	@param	$type
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub ExecutePlugin
{
	my $this = shift;
	my ($type) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Form = $this->{'FORM'};
	my $Plugin = $this->{'PLUGIN'};
	
	# 有効な拡張機能一覧を取得
	my @pluginSet = ();
	$Plugin->GetKeySet('VALID', 1, \@pluginSet);
	foreach my $id (@pluginSet) {
		# タイプが先呼び出しの場合はロードして実行
		if ($Plugin->Get('TYPE', $id) & $type) {
			my $file = $Plugin->Get('FILE', $id);
			my $className = $Plugin->Get('CLASS', $id);
			
			require "./plugin/$file";
			my $Config = PLUGINCONF->new($Plugin, $id);
			my $command = $className->new($Config);
			$command->execute($Sys, $Form, $type);
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	規制チェック
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	規制通過なら0を返す
#			規制チェックにかかったらエラーコードを返す
#
#------------------------------------------------------------------------------------------------------------
sub IsRegulation
{
	my $this = shift;
	
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Sec = $this->{'SECURITY'};
	my $Threads = $this->{'THREADS'};
	
	my $bbs = $this->{'FORM'}->Get('bbs');
	my $from = $this->{'FORM'}->Get('FROM');
	my $capID = $Sys->Get('CAPID', '');
	my $datPath = $Sys->Get('DATPATH');
	my $client = $Sys->Get('CLIENT');
	my $mode = $Sys->Get('AGENT');
	my $koyuu = $Sys->Get('KOYUU');
	my $host = $ENV{'REMOTE_HOST'};
	my $addr = $ENV{'REMOTE_ADDR'};
	my $islocalip = 0;
	
	$islocalip = 1 if ($addr =~ /^(127|172|192|10)\./);

	require './module/dat.pl';
	$Threads->LoadAttr($Sys);
	my $threadid = $Sys->Get('KEY');

	# レス書き込みモード時のみ
	if ($Sys->Equal('MODE', 2)) {
		my $AttrResMax = $Threads->GetAttr($threadid,'maxres');
		my $MAXRES = $AttrResMax ? $AttrResMax : $Sys->Get('RESMAX');
		# 移転スレッド
		return $ZP::E_LIMIT_MOVEDTHREAD if (DAT::IsMoved($datPath));
		
		# レス最大数
		return $ZP::E_LIMIT_OVERMAXRES if ($MAXRES < DAT::GetNumFromFile($datPath));
		
		# datファイルサイズ制限
		if ($Set->Get('BBS_DATMAX')) {
			my $datSize = int((stat $datPath)[7] / 1024);
			if ($Set->Get('BBS_DATMAX') < $datSize) {
				return $ZP::E_LIMIT_OVERDATSIZE;
			}
		}
	}
	# REFERERチェック
	if ($Set->Equal('BBS_REFERER_CHECK', 'checked')) {
		if ($this->{'CONV'}->IsReferer($this->{'SYS'}, \%ENV)) {
			return $ZP::E_POST_INVALIDREFERER;
		}
	}
	# IP関係
	if (!$islocalip) {
		# 逆引き不可規制
		if ($ENV{'REMOTE_ADDR'} eq $ENV{'REMOTE_HOST'}){
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NOHOST, $bbs) && $Set->Equal('BBS_REVERSE_CHECK', 'checked')) {
				return $ZP::E_REG_NOHOST;
			}
		}
		# JPホスト以外規制
		if (!$this->{'CONV'}->IsJPIP($Sys)){
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NOTJPHOST, $bbs) && $Set->Equal('BBS_JP_CHECK', 'checked')) {
				return $ZP::E_REG_NOTJPHOST;
			}
			$Sys->Set('IPCOUNTRY','abroad');
		}
		# PROXYチェック
		if ($this->{'CONV'}->IsProxyDNSBL($this->{'SYS'}, $this->{'FORM'}, $from, $mode)) {			# DNSBLによるチェック
			#$this->{'FORM'}->Set('FROM', "</b> [—\{}\@{}\@{}-] <b>$from");
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_DNSBL, $bbs) && $Set->Equal('BBS_DNSBL_CHECK', 'checked')) {
				return $ZP::E_REG_DNSBL;
			}
			$Sys->Set('ISPROXY','bl');
		}elsif($Sys->Get('PROXYCHECK_APIKEY') && $this->{'CONV'}->IsProxyAPI($this->{'SYS'},1)){	# DNSBLに引っかからなかった場合に、設定されていたらProxy.ioへ
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_DNSBL, $bbs) && $Set->Equal('BBS_PROXY_CHECK', 'checked')) {
				return $ZP::E_REG_DNSBL;
			}
			$Sys->Set('ISPROXY','proxy');
		}
	}
	# 読取専用
	if (!$Set->Equal('BBS_READONLY', 'none')) {
		if (!$Sec->IsAuthority($capID, $ZP::CAP_LIMIT_READONLY, $bbs)) {
			return $ZP::E_LIMIT_READONLY;
		}
	}

	# スレッド作成モード
	if ($Sys->Equal('MODE', 1)) {
		# スレッドキーが重複しないようにする
		my $tPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/';
		my $key = $Sys->Get('KEY');
		$key++ while (-e "$tPath$key.dat");
		$Sys->Set('KEY', $key);
		$datPath = "$tPath$key.dat";
		
		# スレッド作成(携帯から)
		if (!$Set->Equal('BBS_THREADMOBILE', 'checked') && ($client & $ZP::C_MOBILE)) {
			if (!$Sec->IsAuthority($capID, $ZP::CAP_LIMIT_MOBILETHREAD, $bbs)) {
				return $ZP::E_LIMIT_MOBILETHREAD;
			}
		}
		# スレッド作成(キャップのみ)
		if ($Set->Equal('BBS_THREADCAPONLY', 'checked')) {
			if (!$Sec->IsAuthority($capID, $ZP::CAP_LIMIT_THREADCAPONLY, $bbs)) {
				return $ZP::E_LIMIT_THREADCAPONLY;
			}
		}
		# スレッド作成(スレッド立てすぎ)
		require './module/manager_log.pl';
		my $Log = MANAGER_LOG->new;
		$Log->Load($Sys, 'THR');
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_MANYTHREAD, $bbs)) {
			my $tateHour = $Set->Get('BBS_TATESUGI_HOUR', '0') - 0;
			my $tateCount = $Set->Get('BBS_TATESUGI_COUNT', '0') - 0;
			if ($tateHour != 0 && $tateCount != 0 && $Log->IsTatesugi($tateHour) >= $tateCount) {
				return $ZP::E_REG_MANYTHREAD;
			}
			my $tateClose = $Set->Get('BBS_THREAD_TATESUGI', '0') - 0;
			my $tateCount2 = $Set->Get('BBS_TATESUGI_COUNT2', '0') - 0;
			if ($tateClose != 0 && $tateCount2 != 0 && $Log->Search($koyuu, 3, $mode, $host, $tateClose) >= $tateCount2) {
				return $ZP::E_REG_MANYTHREAD;
			}
		}
		$Log->Set($Set, $Sys->Get('KEY'), $Sys->Get('VERSION'), $koyuu, undef, $mode);
		$Log->Save($Sys);
		
		# Sambaログ
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_SAMBA, $bbs) || !$Sec->IsAuthority($capID, $ZP::CAP_REG_NOTIMEPOST, $bbs)) {
			my $Logs = MANAGER_LOG->new;
			$Logs->Load($Sys, 'SMB');
			$Logs->Set($Set, $Sys->Get('KEY'), $Sys->Get('VERSION'), $koyuu);
			$Logs->Save($Sys);
		}
	}
	# レス書き込みモード
	else {
		require './module/manager_log.pl';
		
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_SAMBA, $bbs) || !$Sec->IsAuthority($capID, $ZP::CAP_REG_NOTIMEPOST, $bbs)) {
			my $Logs = MANAGER_LOG->new;
			$Logs->Load($Sys, 'SMB');
			
			my $Logh = MANAGER_LOG->new;
			$Logh->Load($Sys, 'SBH');
			
			my $n = 0;
			my $tm = 0;
			my $Samba = int($Set->Get('BBS_SAMBATIME', '') eq '' ? $Sys->Get('DEFSAMBA') : $Set->Get('BBS_SAMBATIME'));
			my $Houshi = int($Set->Get('BBS_HOUSHITIME', '') eq '' ? $Sys->Get('DEFHOUSHI') : $Set->Get('BBS_HOUSHITIME'));
			my $Holdtm = int($Sys->Get('SAMBATM'));

			#実況モードで連投規制緩和
			my $livenum = 2;
			if($Threads->GetAttr($threadid,'live')){
				$Samba = $Samba / $livenum;
				$Holdtm = $Holdtm / $livenum;
				$Houshi = $Houshi / $livenum;
			}
			
			# Samba
			if ($Samba && !$Sec->IsAuthority($capID, $ZP::CAP_REG_SAMBA, $bbs)) {
				if ($Houshi) {
					my ($ishoushi, $htm) = $Logh->IsHoushi($Houshi, $koyuu);
					if ($ishoushi) {
						$Sys->Set('WAIT', $htm);
						return $ZP::E_REG_SAMBA_STILL;
					}
				}
				
				($n, $tm) = $Logs->IsSamba($Samba, $koyuu);
			}
				
			# 短時間投稿 (Samba優先)
			if (!$n && $Holdtm && !$Sec->IsAuthority($capID, $ZP::CAP_REG_NOTIMEPOST, $bbs)) {
				$tm = $Logs->IsTime($Holdtm, $koyuu);
			}
			
			$Logs->Set($Set, $Sys->Get('KEY'), $Sys->Get('VERSION'), $koyuu);
			$Logs->Save($Sys);
			
			if ($n >= 6 && $Houshi) {
				$Logh->Set($Set, $Sys->Get('KEY'), $Sys->Get('VERSION'), $koyuu);
				$Logh->Save($Sys);
				$Sys->Set('WAIT', $Houshi);
				return $ZP::E_REG_SAMBA_LISTED;
			}
			elsif ($n) {
				$Sys->Set('SAMBATIME', $Samba);
				$Sys->Set('WAIT', $tm);
				$Sys->Set('SAMBA', $n);
				return ($n > 3 && $Houshi ? $ZP::E_REG_SAMBA_WARNING : $ZP::E_REG_SAMBA_CAUTION);
			}
			elsif ($tm > 0) {
				$Sys->Set('WAIT', $tm);
				return $ZP::E_REG_NOTIMEPOST;
			}
		}
		
		# レス書き込み(連続投稿)
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NOBREAKPOST, $bbs)) {
			if ($Set->Get('timeclose') && $Set->Get('timecount') ne '') {
				my $Log = MANAGER_LOG->new;
				$Log->Load($Sys, 'HST');
				my $cnt = $Log->Search($koyuu, 2, $mode, $host, $Set->Get('timecount'));
				if ($cnt >= $Set->Get('timeclose')) {
					return $ZP::E_REG_NOBREAKPOST;
				}
			}
		}
		# レス書き込み(二重投稿)
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_DOUBLEPOST, $bbs)) {
			if ($this->{'SYS'}->Get('KAKIKO') == 1) {
				my $Log = MANAGER_LOG->new;
				$Log->Load($Sys, 'WRT', $Sys->Get('KEY'));
				if ($Log->Search($koyuu, 1) - 2 == length($this->{'FORM'}->Get('MESSAGE'))) {
					return $ZP::E_REG_DOUBLEPOST;
				}
			}
		}
		
		#$Log->Set($Set, length($this->{'FORM'}->Get('MESSAGE')), $Sys->Get('VERSION'), $koyuu, $datas, $mode);
		#$Log->Save($Sys);
	}
	
	# パスを保存
	$Sys->Set('DATPATH', $datPath);
	
	return $ZP::E_SUCCESS;
}

#------------------------------------------------------------------------------------------------------------
#
#	名前・メール欄（コマンド欄）の正規化
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	規制通過なら0を返す
#			規制チェックにかかったらエラーコードを返す
#
#------------------------------------------------------------------------------------------------------------
sub NormalizationNameMail
{
	my $this = shift;
	
	my $Sys = $this->{'SYS'};
	my $Form = $this->{'FORM'};
	my $Sec = $this->{'SECURITY'};
	my $Set = $this->{'SET'};
	
	my $name = $Form->Get('FROM');
	my $mail = $Form->Get('mail');
	my $subject = $Form->Get('subject');
	my $bbs = $Form->Get('bbs');
	my $host = $ENV{'REMOTE_HOST'};
	
	# キャップ情報取得
	my $capID = $Sys->Get('CAPID', '');
	my $capName = '';
	my $capColor = '';
	if ($capID && $Sec->IsAuthority($capID, $ZP::CAP_DISP_HANLDLE, $bbs)) {
		$capName = $Sec->Get($capID, 'NAME', 1, '');
		$capColor = $Sec->Get($Sec->{'GROUP'}->GetBelong($capID), 'COLOR', 0, '');
		$capColor = $Set->Get('BBS_CAP_COLOR', '') if ($capColor eq '');
	}
	
	# ＃ -> #
	$this->{'CONV'}->ConvertCharacter0(\$name);
	
	# トリップ変換
	my $trip = '';
	if ($name =~ /(?<!&)\#(.*)$/x) {
		my $key = $1;
		$trip = $this->{'CONV'}->ConvertTrip(\$key, $Set->Get('BBS_TRIPCOLUMN'), $Sys->Get('TRIP12'));
	}
	
	# 特殊文字変換 フォーム情報再設定
	$this->{'CONV'}->ConvertCharacter1(\$name, 0);
	$this->{'CONV'}->ConvertCharacter1(\$mail, 1);
	$this->{'CONV'}->ConvertCharacter1(\$subject, 3);
	$Form->Set('FROM', $name);
	$Form->Set('mail', $mail);
	$Form->Set('subject', $subject);
	$Form->Set('TRIPKEY', $trip);
	
	# プラグイン実行 フォーム情報再取得
	$this->ExecutePlugin($Sys->Get('MODE'));
	return $ZP::E_REG_SPAMKILL if($this->SpamBlock($Set,$Form));
	
	$name = $Form->Get('FROM', '');
	$mail = $Form->Get('mail', '');
	$subject = $Form->Get('subject', '');
	$bbs = $Form->Get('bbs');
	$host = $Form->Get('HOST');
	$trip = $Form->Get('TRIPKEY', '???');
	
	# 2ch互換
	$name =~ s/^ //;
	
	# 禁則文字変換
	$this->{'CONV'}->ConvertCharacter2(\$name, 0);
	$this->{'CONV'}->ConvertCharacter2(\$mail, 1);
	$this->{'CONV'}->ConvertCharacter2(\$subject, 3);
	
	# トリップと名前を結合する
	$name =~ s|(?<!&)\#.*$| </b>◆$trip <b>|x if ($trip ne '');
	
	# fusiana変換 2ch互換
	$this->{'CONV'}->ConvertFusianasan(\$name, $host);
	
	# キャップ名結合
	if ($capName ne '') {
		$name = ($name ne '' ? "$name＠" : '');
		if ($capColor eq '') {
			$name .= "$capName ★";
		}
		else {
			$name .= "<font color=\"$capColor\">$capName ★</font>";
		}
	}
	
	
	# スレッド作成時
	if ($Sys->Equal('MODE', 1)) {
		return $ZP::E_FORM_NOSUBJECT if ($subject eq '');
		return $ZP::E_REG_SAMETITLE if ($this->SameTitleCheck($subject) && $Set->Get('BBS_SAMETHREAD') eq 'checked');
		# サブジェクト欄の文字数確認
		if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_LONGSUBJECT, $bbs)) {
			if ($Set->Get('BBS_SUBJECT_COUNT') < length($subject)) {
				return $ZP::E_FORM_LONGSUBJECT;
			}
		}
	}
	
	# 名前欄の文字数確認
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_LONGNAME, $bbs)) {
		if ($Set->Get('BBS_NAME_COUNT') < length($name)) {
			return $ZP::E_FORM_LONGNAME;
		}
	}
	# メール欄の文字数確認
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_LONGMAIL, $bbs)) {
		if ($Set->Get('BBS_MAIL_COUNT') < length($mail)) {
			return $ZP::E_FORM_LONGMAIL;
		}
	}
	# 名前欄の入力確認
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_NONAME, $bbs)) {
		if ($Set->Equal('NANASHI_CHECK', 'checked') && $name eq '') {
			return $ZP::E_FORM_NONAME;
		}
	}
	
	# 正規化した内容を再度設定
	$Form->Set('FROM', $name);
	$Form->Set('mail', $mail);
	$Form->Set('subject', $subject);
	
	return $ZP::E_SUCCESS;
}


# SLIP生成
sub MakeSlip
{
	my $this = shift;
	my ($Sys,$Form,$Set,$Threads) = @_;
	require './module/slip.pl';
	my $slip = SLIP->new;

	$Form->Get('FROM') =~ /(^|<br>)!slip:(v){3,6}(<br>|$)/;
	my $comSlip = $2;	# ユーザーコマンドで設定されたSLIP
	my $threadSlip = $Threads->GetAttr($Sys->Get('KEY'),'slip');	# スレッド属性で設定されたSLIP
	my $bbsSlip = $Set->Get('BBS_SLIP');	# 掲示板設定のSLIP
	$bbsSlip =~ s/checked/v/;
	$bbsSlip =~ s/feature/vv/;
	#$bbsSlip =~ s/verbose/vv/;

	if($threadSlip){
		if(length($bbsSlip) < length($threadSlip)){
			$bbsSlip = $threadSlip;
		}
	}
	if($comSlip){
		if(length($bbsSlip) < length($comSlip)){
			$bbsSlip = $comSlip;
		}
	}
	
	# BBS_SLIPとID末尾取得
	my $chid = substr($Sys->Get('SECURITY_KEY'),0,8);
	my ($slip_nickname,$slip_aa,$slip_bb,$slip_cccc,$idEnd) = $slip->BBS_SLIP($Sys, $chid);

	# slip文字列とID末尾
	my $slip_result = '';
	my $ipAddr = $ENV{'REMOTE_ADDR'};
	if($bbsSlip eq 'vvv'){
		$slip_result = ${slip_nickname};
	}
	elsif($bbsSlip eq 'vvvv'){
		$slip_result = "${slip_nickname} [$ipAddr]";
	}
	elsif($bbsSlip eq 'vvvvv'){
		$slip_result = "${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc}";
	}
	elsif($bbsSlip eq 'vvvvvv'){
		$slip_result = "${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc} [${ipAddr}]";
	}
	$idEnd = $Set->Get('BBS_SLIP') eq 'checked' ? $Sys->Get('AGENT') : $idEnd;

	return ($slip_result,$idEnd);
}

sub LoadNinpocho
{
	my $this = shift;
	my ($Sys,$Form,$Ninja) = @_;
	my $is_save = 0;

	$Ninja->Load($Sys,undef);

	# 忍法帖パスがあったらロード
	my $ninmail = $Form->Get('mail');
	if($ninmail=~ /!load:([A-Za-z0-9\-_]+)/){
		my $password = $1;
		$ninmail =~ s/!load:([A-Za-z0-9\-_]+)//;
		$Form->Set('mail',$ninmail);
		$Ninja->Load($Sys,$password);	#ロード
	}elsif($ninmail =~ /!save/){
		$is_save = 1;
		$ninmail =~ s/!save//;
		$Form->Set('mail',$ninmail);
		# 後でセーブするときに$passwordを使う
	}
	return $is_save;
}

# BANチェック
sub BanCheck
{
    my $this = shift;
    my ($Sys, $Form, $Threads, $Ninja, $Sec) = @_;

    my $noAttr = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NOATTR, $Form->Get('bbs'));
    my $noNinja = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NONINJA, $Form->Get('bbs'));

    my $threadid = $Sys->Get('KEY');
    my $sid = $Sys->Get('SID');

    # NinjaのBAN状態をチェック
    return $ZP::E_REG_BAN if (!$noNinja && ($Ninja->Get('ban') eq 'ban' || ($Ninja->Get('ban_mthread') eq 'thread' && $Sys->Equal('MODE', 1))));

    if (!$noAttr) {
		# スレッド単位でBAN
        my $ban_attr_ref = $Threads->GetAttr($threadid, 'ban');

        # 戻り値がハッシュリファレンスか確認
        if (ref($ban_attr_ref) eq 'HASH') {
            if (defined $ban_attr_ref->{$sid} && $ban_attr_ref->{$sid} == 0) {
                return $ZP::E_REG_BAN;
            }
        }
    }
}

# レベル制限
sub LevelLimit
{
	my $this = shift;
	my ($Sys, $Set, $Form, $Threads, $Ninja, $Sec) = @_;

	my $noAttr = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NOATTR, $Form->Get('bbs'));
	my $noNinja = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NONINJA, $Form->Get('bbs'));
	my $makeThread = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_LIMIT_THREADCAPONLY, $Form->Get('bbs'));

	my $write_min = $Set->Get('NINJA_WRITE_MESSAGE') // '';
	my $lvLim = $Threads->GetAttr($Sys->Get('KEY'),'ninLv') || 0;
	my $ninLv = $Ninja->Get('ninLv');

	my ($min_level, $factor) = split(/-/, $Set->Get('NINJA_MAKE_THREAD'));
	if(!$noNinja){
		if($Sys->Equal('MODE', 1)){
			# スレ立てモード
			if(!$makeThread){
				if($ninLv < $min_level){
					return $ZP::E_REG_NINLVLIMIT;
				}else{
					$Ninja->Set('ninLv',$ninLv - $factor);
				}
			}
		}else{
			# 書き込みモード
			if ($ninLv < $write_min){
				return $ZP::E_REG_NINLVLIMIT;
			}else{
				return $ZP::E_REG_NINLVLIMIT if($ninLv < $lvLim && $write_min <= $lvLim && !$noAttr);
			}
		}
	}
	return 0;
}

sub MakeDatLine
{
	my $this = shift;
	my ($Sys, $Set,$Form, $Threads, $Sec, $Conv, $Ninja, $idEnd, $slip_result) = @_;

	my $threadid = $Sys->Get('KEY');
	my $sid = $Sys->Get('SID');

	my $noAttr = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NOATTR, $Form->Get('bbs'));
	my $handle = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_DISP_HANLDLE, $Form->Get('bbs'));
	my $noslip = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_DISP_NOSLIP, $Form->Get('bbs'));
	my $noid = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_DISP_NOID, $Form->Get('bbs'));
	my $noNinja = $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NONINJA, $Form->Get('bbs'));

	my $idpart = 'ID:???';
	my $threadkey = $Threads->GetAttr($threadid,'changeid') ? $threadid : '';
	my $id = $Conv->MakeIDnew($Sys, 8, undef, $threadkey);
	if (!$Threads->GetAttr($threadid,'noid')){
		$idpart = $Conv->GetIDPart($Set, $Form, $Sec, $id, $Sys->Get('CAPID'), $Sys->Get('KOYUU'), $idEnd);
	}
	my $datepart = $Conv->GetDate($Set, $Sys->Get('MSEC'));
	my $bepart = '';
	my $extrapart = '';
	$Form->Set('datepart', $datepart);
	$Form->Set('idpart', $idpart);
	#$Form->Set('BEID', ''); # type=1|2
	$Form->Set('extrapart', $extrapart);
	
	# age/sage
	my $updown = 'top';
	$updown = '' if ($Form->Contain('mail', 'sage'));
	$updown = '' if ($Threads->GetAttr($threadid, 'sagemode'));
	$updown = '' if ($Ninja->Get('force_sage') && !$noNinja);
	$updown = '' if ($Set->Get('NINJA_FORCE_SAGE') >= $Ninja->Get('ninLv') && $Set->Get('BBS_NINJA') && !$noNinja);
	$Sys->Set('updown', $updown);

	# pluginに渡す値を設定
	$Sys->Set('_ERR', 0);
	$Sys->Set('_NUM_', DAT::GetNumFromFile($Sys->Get('DATPATH')) + 1);
	$Sys->Set('_THREAD_', $this->{'THREADS'});
	$Sys->Set('_SET_', $this->{'SET'});
	# プラグイン実行
	$this->ExecutePlugin(16);

	# レス要素の取得
	my $subject = $Form->Get('subject', '');
	my $name = $Form->Get('FROM', '');
	my $mail = $Form->Get('mail', '');
	my $text = $Form->Get('MESSAGE', '');
	#SLIPがあった場合は付加する
	$name .= "</b> (${slip_result})" if (($slip_result && !$noslip) && (!$handle || !$noAttr));

	# 無意味なタグを除去
	$name =~ s|<b></b>||g;

	$datepart = $Form->Get('datepart', '');
	$idpart = $Form->Get('idpart', '');
	if (!$Set->Get('BBS_HIDENUSI') && !$Threads->GetAttr($threadid,'hidenusi') && !$handle){
		$idpart .= '(主)' if (($sid eq GetSessionID($Sys,$threadid,1)) || $Sys->Equal('MODE', 1));
	}

	$bepart = $Form->Get('BEID', '');
	$extrapart = $Form->Get('extrapart', '');
	my $info = $datepart;
	$info .= " $idpart" if ($idpart ne '');
	$info .= " $bepart" if ($bepart ne '');
	$info .= " $extrapart" if ($extrapart ne '');

	if($subject && $Set->Get('BBS_TITLEID') && $Sys->Equal('MODE', 1) && !$noid){
		# スレ立て時にスレタイにID付加
		if($handle){
			my $capName = $Sec->Get($Sys->Get('CAPID'), 'NAME', 1, '');
			$subject = $subject." [$capName★]";
		}else{
			$subject = $subject." [$id★]";
		}
	}
	
	return "$name<>$mail<>$info<>$text<>$subject\n";
}

sub AddDatFile
{
	my $this = shift;
	my ($Sys,$Threads,$line) = @_;

	my $resNum = 0;
	my $err = 0;
	my $datPath = $Sys->Get('DATPATH');
	my $err2 = DAT::DirectAppend($Sys, $datPath, $line);
	my $AttrResMax = $Threads->GetAttr($Sys->Get('KEY'),'maxres');
	if ($err2 == 0) {
		# レス数が最大数を超えたらover設定をする
		$resNum = DAT::GetNumFromFile($datPath);
		my $MAXRES = $AttrResMax ? $AttrResMax : $Sys->Get('RESMAX');
		if ($resNum >= $MAXRES) {
			# datにOVERスレッドレスを書き込む
			Get1001Data($Sys, \$line,$MAXRES);
			DAT::DirectAppend($Sys, $datPath, $line);
			$resNum++;
		}
		$err = $ZP::E_SUCCESS;
	}
	# datファイル追記失敗
	elsif ($err2 == 1) {
		$err = $ZP::E_POST_NOTEXISTDAT;
	}
	elsif ($err2 == 2) {
		$err = $ZP::E_LIMIT_STOPPEDTHREAD;
	}
	
	return ($err,$resNum);
}

sub AddLog
{
	my $this = shift;
	my ($Sys,$Set,$Form,$data) = @_;

	chomp($data);
	require './module/manager_log.pl';
	my $Log = MANAGER_LOG->new;
	$Log->Load($Sys, 'WRT', $Sys->Get('KEY'));
	$Log->Set($Set, length($Form->Get('MESSAGE')), $Sys->Get('VERSION'), $Sys->Get('KOYUU'), $data, $Sys->Get('AGENT', 0),$Sys->Get('SID'));
	$Log->Save($Sys);
}

sub AddSubjectNewThread
{
	my $this = shift;
	my ($Sys,$Set,$Form,$Threads,$line) = @_;

	require './module/file_utils.pl';
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	my $Pools = POOL_THREAD->new;
	$Pools->Load($Sys);
	$Threads->Add($Sys->Get('KEY'), $Form->Get('subject', ''), 1);

	# スレ主情報保存
	$Threads->SetAttr($Sys->Get('KEY'),'owner',$Sys->Get('SID'));
	$Threads->SaveAttr($Sys);
	
	# スレッド数限界によるdat落ち処理
	my $submax = $Sys->Get('SUBMAX');
	my @tlist;
	$Threads->GetKeySet('ALL', undef, \@tlist);
	$Threads->LoadAttrAll($Sys);
	foreach my $lid (reverse @tlist) {
		last if ($Threads->GetNum() <= $submax);
		
		# 不落属性あり
		next if ($Threads->GetAttr($lid, 'nopool'));
		if(!$Set->Get('BBS_KAKO')){
			$Pools->Add($lid, $Threads->Get('SUBJECT', $lid), $Threads->Get('RES', $lid));
			FILE_UTILS::Copy("$path/dat/$lid.dat", "$path/pool/$lid.cgi");
			$Threads->Delete($lid);
		}
		#別の掲示板に移す場合
		else{
			FILE_UTILS::Move("$path/dat/$lid.dat", $Set->Get('BBS_KAKO')."/dat/$lid.dat");	
			require './module/bbs_service.pl';
			my $BBSAid = BBS_SERVICE -> new;

			#$Sysで指すBBS名を一時変更するため保存
			my $originalBBSname = $Sys->Get('BBS');
			my $originalMODE = $Sys->Get('MODE');
			$Sys->Set('BBS', $Set->Get('BBS_KAKO'));
			$Sys->Set('MODE','CREATE');

			# subject.txt更新
			$Threads->Load($Sys);
			$Threads->UpdateAll($Sys);
			$Threads->Save($Sys);
			# index.html更新
			#$BBSAid->Init($Sys,undef);
			#$BBSAid->CreateIndex();
			#$BBSAid->CreateSubback();

			#$Sysの内容を元に戻す
			$Sys->Set('BBS', $originalBBSname);
			$Sys->Set('MODE',$originalMODE);
		}
		unlink "$path/dat/$lid.dat";
	}
	$Pools->Save($Sys);
	$Threads->Save($Sys);
}
#------------------------------------------------------------------------------------------------------------
#
#	テキスト欄の正規化
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	規制通過なら0を返す
#			規制チェックにかかったらエラーコードを返す
#
#------------------------------------------------------------------------------------------------------------
sub NormalizationContents
{
	my $this = shift;
	
	my $Form = $this->{'FORM'};
	my $Sec = $this->{'SECURITY'};
	my $Set = $this->{'SET'};
	my $Sys = $this->{'SYS'};
	my $Conv = $this->{'CONV'};
	
	my $bbs = $Form->Get('bbs');
	my $text = $Form->Get('MESSAGE');
	my $host = $Form->Get('HOST');
	my $capID = $this->{'SYS'}->Get('CAPID', '');
	
	# 禁則文字変換
	$Conv->ConvertCharacter2(\$text, 2);
	
	my ($ln, $cl) = $Conv->GetTextInfo(\$text);
	
	# 本文が無い
	return $ZP::E_FORM_NOTEXT if ($text eq '');
	
	# 本文が長すぎ
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_LONGTEXT, $bbs)) {
		if ($Set->Get('BBS_MESSAGE_COUNT') < length($text)) {
			return $ZP::E_FORM_LONGTEXT;
		}
	}
	# 改行が多すぎ
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_MANYLINE, $bbs)) {
		if (($Set->Get('BBS_LINE_NUMBER') * 2) < $ln) {
			return $ZP::E_FORM_MANYLINE;
		}
	}
	# 1行が長すぎ
	if (!$Sec->IsAuthority($capID, $ZP::CAP_FORM_LONGLINE, $bbs)) {
		if ($Set->Get('BBS_COLUMN_NUMBER') < $cl) {
			return $ZP::E_FORM_LONGLINE;
		}
	}
	# アンカーが多すぎ
	if ($Sys->Get('ANKERS')) {
		if ($Conv->IsAnker(\$text, $Sys->Get('ANKERS'))) {
			return $ZP::E_FORM_MANYANCHOR;
		}
	}
	
	# 本文ホスト表示
	#if (!$Sec->IsAuthority($capID, $ZP::CAP_DISP_NOHOST, $bbs)) {
	#	if ($Set->Equal('BBS_RAWIP_CHECK', 'checked') && $Sys->Equal('MODE', 1)) {
	#		$text .= ' <hr> <font color=tomato face=Arial><b>';
	#		$text .= ($ENV{'REMOTE_ADDR'}) , $host , </b></font><br>";
	#	}
	#}
	
	$Form->Set('MESSAGE', $text);
	
	return $ZP::E_SUCCESS;
}

#------------------------------------------------------------------------------------------------------------
#
#	1001のレスデータを設定する
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$data	1001レス格納バッファ
#
#------------------------------------------------------------------------------------------------------------
sub Get1001Data
{
	
	my ($Sys, $data, $resmax) = @_;
	my $this = shift;
	my $endPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/1000.txt';
	
	# 1000.txtが存在すればその内容、無ければデフォルトの1001を使用する
	if (open(my $fh, '<', $endPath)) {
		flock($fh, 2);
		$$data = <$fh>;
		close($fh);
	}
	else {
		my $resmax1 = $resmax + 1;
		my $resmaxz = $resmax;
		my $resmaxz1 = $resmax1;
		$resmaxz =~ tr/([0-9])/([０-９])/; # 全角数字
		$resmaxz1 =~ tr/([0-9])/([０-９])/; # 全角数字
		
		$$data = "$resmaxz1\<><>Over $resmax Thread<>このスレッドは$resmaxz\を超えました。<br>";
		$$data .= 'もう書けないので、新しいスレッドを立ててくださいです。。。<>' . "\n";
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ホストログを出力する
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$data	1001レス格納バッファ
#
#------------------------------------------------------------------------------------------------------------
sub SaveHost
{
	
	my ($Sys, $Form) = @_;
	
	my $bbs = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	
	my $host = $ENV{'REMOTE_HOST'};
	my $agent = $Sys->Get('AGENT');
	my $koyuu = $Sys->Get('KOYUU');
	
	if ($agent ne '0') {
		if ($agent eq 'P') {
			$host = "$host($koyuu)($ENV{'REMOTE_ADDR'})";
		}
		else {
			$host = "$host($koyuu)";
		}
	}
	
	require './module/log.pl';
	my $Logger = LOG->new;
	
	if ($Logger->Open("$bbs/log/HOST", $Sys->Get('HSTMAX'), 2 | 4) == 0) {
		$Logger->Put($host, $Sys->Get('KEY'), $Sys->Get('MODE'));
		$Logger->Write();
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖に関する処理
#	-------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub Ninpocho
{
	my $this = shift;
	my ($Sys, $Set, $Form, $Ninja) = @_;

	my $sid = $Sys->Get('SID');

	# セッションから忍法帖Lvを取得
	my $ninLv = $Ninja->Get('ninLv') || 1;

	# セッションから書き込み数を取得
	my $count = $Ninja->Get('count') || 0;
	my $today_count = $Ninja->Get('today_count') || 0;
	my $thread = $Ninja->Get('thread_count') || 0; 

	# 書き込んだ時間を取得
	my $resTime = time();
	# 書き込んだ時間の23時間後を取得
	my $time23h = $resTime + 82800;
	# セッションから前回レベルアップしたときの時間を取得
	my $lvUpTime = $Ninja->Get('lvuptime') || 0;

	# レベルの上限
	my $lvLim = $Sys->Get('NINLVMAX');

	# 一日の書き込み数が現在のレベル以上で、前回のレベルアップから23時間以上経過していればレベルアップ
	if ($today_count >= $ninLv && $resTime >= $lvUpTime && $ninLv < $lvLim) {
		$ninLv++;
		$lvUpTime = $time23h;
	}

	# 書き込み数をカウント
	$count++;
	# 一日の書き込み数カウント
	my $last_wtime = $Ninja->Get('last_wtime') || $resTime;
	if (int($resTime / (60 * 60 * 24)) == int($last_wtime / (60 * 60 * 24))) {
		$today_count++;
	} else {
		$today_count = 1;
	}

	# セッションに記録
	if ($Ninja) {
		$Ninja->Set('count', $count);
		$Ninja->Set('today_count', $today_count);
		$Ninja->Set('ninLv', $ninLv);
		$Ninja->Set('lvuptime', $lvUpTime);

		$Ninja->Set('last_addr',$ENV{'REMOTE_ADDR'});
		$Ninja->Set('last_host',$ENV{'REMOTE_HOST'});
		$Ninja->Set('last_ua',$ENV{'HTTP_USER_AGENT'});
		$Ninja->Set('last_wtime',$resTime);
		if($Sys->Equal('MODE', 1)){
			$thread++;
			$Ninja->Set('thread_count',$thread);
			$Ninja->Set('last_mthread_time',time);
			$Ninja->Set('thread_title',substr($Form->Get('subject'), 0, 30));
		}

		my $mes = $Form->Get('MESSAGE');
		$mes =~ s/<(b|h)r>//g;
		$Ninja->Set('last_message',substr($mes, 0, 30));
		$Ninja->Set('last_bbsdir',$Sys->Get('BBS'));
		$Ninja->Set('last_threadkey',$Sys->Get('KEY'));

	}

	# 名前欄取得
	my $name = $Form->Get('FROM');
	# 現在の時刻と$lvUpTimeとの差を計算
	my $timeDiff = $lvUpTime - $resTime;
	# 差分を時間単位と分単位で計算
	my $hoursDiff = int($timeDiff / 3600); # 1時間 = 3600秒
	my $minutesDiff = int(($timeDiff % 3600) / 60); # 残りの秒数を分に変換

	# 残り時間表示用
	my $timeDisplay = "";
	$timeDisplay .= "${hoursDiff}時間" if $hoursDiff > 0;
	$timeDisplay .= "${minutesDiff}分" if $minutesDiff > 0 || $hoursDiff == 0; # 分が0でも時間が0の場合は表示する

	my $minutes = int($lvUpTime / 60);

	# 名前欄書き換え
	my $ninID = crypt($sid,$sid);
	my $BitMask = $Set->Get('BBS_COMMAND');
	my $MakeThread = $Set->Get('BBS_THREADCAPONLY');
	$name = $Ninja->Get('force_kote') if $Ninja->Get('force_kote');
	$name = $Set->Get('BBS_NONAME_NAME') if $Ninja->Get('force_774');

	my $B = (split(/-/, $Set->Get('NINJA_USER_BAN')))[0] <= $ninLv && ($BitMask & 4096) ? 'B':'x';		# BAN可
	my $C = (split(/-/, $Set->Get('NINJA_USE_COMMAND')))[0] <= $ninLv && $BitMask ? 'C':'x';	# コマンド可
	my $D = (split(/-/, $Set->Get('NINJA_RES_DELETE')))[0] <= $ninLv && ($BitMask & 524288)? 'D':'x';		# レス削除可
	my $P = 'P';					# レス可
	my $T = (split(/-/, $Set->Get('NINJA_MAKE_THREAD')))[0] <= $ninLv && !$MakeThread ? 'T':'x';	# スレたて可

	$name =~ s|!ninja|</b> 忍法帖【Lv=$ninLv,$B$C$D$P$T,ID:$ninID】<b>|;
	$name =~ s|!id|</b>【忍法帖ID:$ninID】<b>|;
	$name =~ s|!time|</b>【LvUPまで${timeDisplay}】<b>|;
	$name =~ s|!lv|</b>【忍法帖Lv.$ninLv】<b>|;
	$name =~ s|!total|</b>【総カキコ数:$count】<b>|;
	$name =~ s|!donguri|</b> 忍法帖[Lv.$ninLv][団栗]<b>|;

	# 名前欄再設定
	$Form->Set('FROM', $name);

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	タイムラインにレス追加
#	-------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub AddTimeLine {
    my $this = shift;
    my ($Sys, $Set, $Threads, $Conv, $line) = @_;

    my $TLpath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/timeline';
    my $title = $Threads->Get('SUBJECT', $Sys->Get('KEY'));
    my $url = $Conv->CreatePath($Sys, 0, $Sys->Get('BBS'), $Sys->Get('KEY'), 'l10');

	require './module/file_utils.pl';
	FILE_UTILS::CreateDirectory("$TLpath", $Sys->Get('PM-ADIR'));	# 無かったら作成
    
    # タイムラインファイルの作成
	chomp($line);
	my @lines = split(/<>/,$line);
	
	# sageなら反映しない
	$Threads->LoadAttr($Sys);
	if($lines[1] =~ /^sage$/ || $Threads->GetAttr($Sys->Get('KEY'),'sagemode')){
		return;
	}

    my $crypt_filename = crypt(encode('UTF-8', $lines[3]), $Sys->Get('KEY'));
    $crypt_filename =~ tr/./_/;
    $crypt_filename =~ tr/\//-/;
    if(open(my $fh, '>', $TLpath .'/'. $crypt_filename . ".cgi")){
		flock($fh, 2);
		chmod 0600, $fh;
		$lines[4] //= $title;
		$lines[5] //= $url;
		$line = join('<>',@lines);
		print $fh "$line";
		close $fh;
		
	}else{
		warn "Could not open file [$TLpath]: $!";
	}

    # タイムラインフォルダ内の .cgi ファイル数を取得
    my $max_files = $Set->Get('BBS_TL_MAX');  # 保存するタイムラインファイルの最大数
    opendir(my $dir, $TLpath) or die "Cannot open directory: $!";
    my @files = grep { /\.cgi$/ && -f "$TLpath/$_" } readdir($dir);
    closedir($dir);

    # 規定数を超えている場合、差を計算して削除する
    my $excess_files = scalar @files - $max_files;

    if ($excess_files > 0) {
        # ファイルを最終更新時刻でソート
        @files = sort { (stat("$TLpath/$a"))[9] <=> (stat("$TLpath/$b"))[9] } @files;
        
        # 規定数以上の古いファイルを削除
        for (my $i = 0; $i < $excess_files; $i++) {
            my $file_to_delete = shift @files;
            unlink "$TLpath/$file_to_delete" or warn "Could not delete $file_to_delete: $!";
        }
    }
}


#SPAMBLOCK
sub SpamBlock
{
	my	$this = shift;
	my	($Setting, $form) = @_;
	
	my $name_ascii_point	= $Setting->Get('BBS_SPAMKILLI_ASCII');		#名前欄がASCIIのみ
	my $mail_atsign_point	= $Setting->Get('BBS_SPAMKILLI_MAIL');		#メール欄（コマンド欄）に半角\@を含む
	my $nohost_point		= $Setting->Get('BBS_SPAMKILLI_HOST');		#ホスト名が逆引き不可
	my $text_ahref_point	= $Setting->Get('BBS_SPAMKILLI_URL');		#本文に<;a href=か[url=を含む
	my $text_ascii_ratio	= $Setting->Get('BBS_SPAMKILLI_MESSAGE');	#本文のASCIIの割合
	my $text_url_point		= $Setting->Get('BBS_SPAMKILLI_LINK');		#本文にリンクを含む
	my $text_ascii_point	= $Setting->Get('BBS_SPAMKILLI_MESPOINT');	#本文のASCIIの割合加点
	my $tldomain_setting	= $Setting->Get('BBS_SPAMKILLI_DOMAIN');	#本文中リンクのTLドメインの種類
	my $threshold_point		= $Setting->Get('BBS_SPAMKILLI_POINT');		#閾値
	
	my $name = $form->Get('FROM');
	my $mail = $form->Get('mail');
	my $text = $form->Get('MESSAGE');
	
	my $point = 0;
	
	if ($ENV{'REMOTE_HOST'} eq ($ENV{'REMOTE_ADDR'})) {
		$point += $nohost_point;
	}
	if ($name ne '' && $name !~ /[^\x09\x0a\x0d\x20-\x7e]/) {
		$point += $name_ascii_point;
	}
	if ($mail =~ /@/) {
		$point += $mail_atsign_point;
	}
	if ($text =~ /&lt;a href=|\[url=/i) {
		$point += $text_ahref_point;
	}
	if ($text =~ m|https?://|) {
		$point += $text_url_point;
	}
	
	if ('ASCII text') {
		$text =~ s/<br>//gi;
		$text =~ s/[\x00-\x1f\x7f\s]//g;
		my $c_asc = @_ = $text =~ /[\x20-\x7e]/g;
		my $c_nasc = @_ = $text =~ /[^\x20-\x7e]/g;
		if ($c_asc * 100 >= ($c_asc + $c_nasc) * $text_ascii_ratio) {
			$point += $text_ascii_point;
		}
	}
	
	if ('TLD of links' && $text_url_point == 0) {
		my %tld2pt = ('*' => 0);
		my $r_num = '^-?[0-9]+$';
		my $r_tld = '^[a-z](?:[a-z0-9\-](?:[a-z0-9])?)?$|^\*$';
		
		# 設定文を解釈し点数マップを作成
		foreach (split(/[^0-9a-zA-Z\-=,\*]/, $tldomain_setting)) {
			my @buf = split(/[=,]/, $_);
			my @num = grep { /$r_num/ } @buf;
			if (scalar(@num) == 1) {
				map { $tld2pt{$_} = $num[0] } grep { /$r_tld/i } @buf;
			} elsif (scalar(@num) > 1) {
				foreach (split(/,/, $_)) {
					my @buf2 = split(/=/, $_);
					next if (!defined (my $p = pop @{[grep { /$r_num/ } @buf2]}));
					map { $tld2pt{$_} = $p } grep { /$r_tld/i } @buf2;
				}
			}
		}
		
		# 本文リンクからTLDを抽出し重複排除
		my @tldlist = keys %{ {map { pop(@{[split(/\./, $_)]}), 1 }
						($text =~ m|https?://([a-z0-9\-\.]+)|gi)} };
		
		# TLDの種類ごとに加点
		foreach my $tld (@tldlist) {
			$tld = '*' if (!defined $tld2pt{$tld});
			$point += $tld2pt{$tld};
		}
	}
	
	if ($point >= $threshold_point) {
		return 1;
	}
	
	return 0;
}
#UA開示
sub tasukeruyo
{
	my	$this = shift;
	my	($sys, $form) = @_;
	
	my	($from, $koyuu, $agent, $tasuke, $mes, $ua, $addr);
	$from	= $form->Get('FROM');
	$koyuu	= $sys->Get('KOYUU');
	$koyuu	= $sys->Get('HOST') if (! defined $koyuu);
	$agent	= $sys->Get('AGENT');
	$mes	= $form->Get('MESSAGE');
	$ua		= $ENV{'HTTP_USER_AGENT'};
	$addr	= ($ENV{'REMOTE_ADDR'});
	
	if ( $from =~ /^.*tasukeruyo/ ) {
		if ( $agent eq 'O' || $agent eq 'P' || $agent eq 'i' ) {
			$tasuke = "$ENV{'REMOTE_HOST'}($koyuu)";
		}
		else {
			$tasuke = "$ENV{'REMOTE_HOST'}($addr)";
		}
		
		$from =~ s#^.*tasukeruyo#$1</b>$tasuke<b>#g;
		$form->Set('FROM', $from);
		
		$ua =~ s/</&lt;/g;
		$ua =~ s/>/&gt;/g;
		$form->Set('MESSAGE',"$mes<br> <hr> <font color=\"blue\">$ua</font>");
	}

return 0;
}
#おみくじ
sub OMIKUJI
{
	my $this = shift;
	my ($Sys, $Form) = @_;
	
	my $name = $Form->Get('FROM');
	
	if ($name =~ /!omikuji/) {
		
		my $board = $Sys->Get('BBS');
		my $today = sprintf('%d-%d-%d', (localtime)[3,4,5]);
		my $koyuu = $Sys->Get('KOYUU');
		
		my $ctx = Digest::MD5->new;
		$ctx->add('omikuji');
		$ctx->add($board);
		$ctx->add($today);
		$ctx->add($koyuu);
		my $rnd = hex(substr($ctx->hexdigest, 0, 8));

		my @kuji = qw(大吉 中吉 小吉 吉 末吉 凶 大凶);
		my $result = $kuji[$rnd%@kuji];
		
		$name =~ s|!omikuji|</b>【$result】<b>|g;
		$Form->Set('FROM', $name);
	}
	
	return 0;
}

#スレッド乱立防止
sub SameTitleCheck
{
	my $this = shift;
	my ($subject) = @_;
	my @threadSet = ();
	$this->{'THREADS'}->GetKeySet('ALL', '', \@threadSet);
	foreach my $key (@threadSet) {
		my $name = $this->{'THREADS'}->Get('SUBJECT', $key);
		return 1 if ($subject eq $name);
		}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	ワンタイムパスワード認証
#
#------------------------------------------------------------------------------------------------------------
sub CaptchaAuthentication
{
	my	$this = shift;
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Form = $this->{'FORM'};
	my $Sec = $this->{'SECURITY'};
	my ($auth_code,$authed_sid,$saved_info,$saved_code,$status);

	# Captchaが設定されていない場合は処理しない
	return 0 unless $Set->Get('BBS_CAPTCHA') && $Sys->Get('CAPTCHA') && $Sys->Get('CAPTCHA_SECRETKEY') && $Sys->Get('CAPTCHA_SITEKEY');

	# キャップ権限でキャプチャをパスできる場合
	return 0 if $Sec->IsAuthority($Sys->Get('CAPID'), $ZP::CAP_REG_NOCAPTCHA, $Sys->Get('BBS'));

	my $sid = $Sys->Get('SID');
	my $auth_expiry = $Sys->Get('AUTH_EXPIRY') * 60*60*24;
	my $Dir = "." . $Sys->Get('INFO') . "/.auth";
	my $mail = $Form->Get('mail');

	my $fileExpiry = 60 * 5;

	# Captcha認証
	my $err = $this->Certification_Captcha($Sys, $Form);
	if($Set->Get('BBS_CAPTCHA') eq 'force'){
		# 毎回強制Captcha
	}elsif ($mail =~ /^!auth(:([0-9a-fA-F]{6}))?/) {
		#ワンタイムパス
		$auth_code = $2;
		my $codeFile = "$Dir/code-$auth_code.cgi";	# 認証コードとsidを紐付け
		if($auth_code && -e $codeFile){
			# !auth:xxxxxx
			$authed_sid = lock_retrieve($codeFile);
			if (time - ($authed_sid->{'crtime'}) >= $fileExpiry) {
				# 有効期限切れ
				$err = $ZP::E_FORM_FAILEDAUTH;
			}else{
				# 成功
				my $authed_ip = $authed_sid->{'ip_addr'};
				if($ENV{'REMOTE_ADDR'} eq $authed_ip){
					# 認証時とIP一致
					$sid = $authed_sid->{'sid'};
					$Sys->Set('SID',$sid);
					lock_store({'crtime'=>time}, "$Dir/sid-$sid.cgi");
					chmod 0600, "$Dir/sid-$sid.cgi";
					unlink $codeFile;

					# mailフォームクリア
					$Form->Set('mail','success');
					
					# 期限切れファイルのクリア
					# ClearExpiredFiles($Dir,qr/^code-[\x20-\x7E]+\.cgi$/,$fileExpiry);

					$err = $ZP::E_SUCCESS;
				}else{
					# IP不一致
					$err = $ZP::E_FORM_FAILEDAUTH;
				}
			}
		}elsif(!defined($auth_code)){
			# !auth
			unless($err){
				# Captcha成功
				my $ctx = Digest::MD5->new;
				$ctx->add('auth');
				$ctx->add($Sys->Get('BBS'));
				$ctx->add(time);
				$ctx->add($ENV{'REMOTE_ADDR'});

				$auth_code = substr($ctx->hexdigest, 0, 6);
				my $issueCodeFile = "$Dir/code-$auth_code.cgi";

				lock_store({'sid'=>$sid,'ip_addr'=>$ENV{'REMOTE_ADDR'},'crtime'=>time}, $issueCodeFile);
				chmod 0600, $issueCodeFile;
				$Sys->Set('PASSWORD', $auth_code);

				$err = $ZP::E_FORM_AUTHCOMMAND;		# パスワード発行画面
			}
		}else{
			# 認証パスがあるが、紐付けファイルが無い
			$err = $ZP::E_FORM_FAILEDAUTH;
		}

	}elsif(-e "$Dir/sid-$sid.cgi"){
		# 認証済みユーザー
		$saved_info = lock_retrieve("$Dir/sid-$sid.cgi");
		my $elapsed_time = time - ($saved_info->{'crtime'});
		if ($elapsed_time >= $auth_expiry) {
			# 認証有効期限切れ
			$err = $ZP::E_FORM_EXPIREDUSERAUTH;
		}else{
			# 成功
			$err = $ZP::E_SUCCESS;
		}
	}
	return $err;
}

#------------------------------------------------------------------------------------------------------------
#
#	Captchaの認証
#	-------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub Certification_Captcha {
	my	$this = shift;
	my ($Sys,$Form) = @_;
	my ($captcha_response,$url);

	my $captcha_kind = $Sys->Get('CAPTCHA');
	my $captcha_leniency = $Sys->Get('CAPTCHA_LENIENCY');
	my $secretkey = $Sys->Get('CAPTCHA_SECRETKEY');
	my $page = $Form->Get('page');
	
	if($captcha_kind eq 'h-captcha'){
		$captcha_response = $Form->Get('h-captcha-response');
		$url = 'https://api.hcaptcha.com/siteverify';
	}elsif($captcha_kind eq 'g-recaptcha'){
		$captcha_response = $Form->Get('g-recaptcha-response');
		$url = 'https://www.google.com/recaptcha/api/siteverify';
	}elsif($captcha_kind eq 'cf-turnstile'){
		$captcha_response = $Form->Get('cf-turnstile-response');
		$url = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
	}else{
		return 0;
	}

	if($page eq 'captcha' && $captcha_response){
		my $ua = LWP::UserAgent->new();
		my $response = $ua->post($url,{
			secret => $secretkey,
			response => $captcha_response,
			remoteip => $ENV{'REMOTE_ADDR'},
			remoteip_leniency => $captcha_leniency,
		   });
		if ($response->is_success()) {
			my $json_text = $response->decoded_content();
			
			# JSON::decode_json関数でJSONテキストをPerlデータ構造に変換
			my $out = decode_json($json_text);
			
			if ($out->{success} eq 'true') {
				return 0;
			}else{
				return $ZP::E_FORM_FAILEDCAPTCHA;
			}
		} else {
			# Captchaを素通りする場合、HTTPS関連のエラーの疑いあり
			# LWP::Protocol::httpsおよびNet::SSLeayが入っているか確認
			return $ZP::E_SYSTEM_CAPTCHAERROR;
		}
	}elsif($page ne 'captcha'){
		# Captchaページ以外から来た場合
		# 認証ページへ
		return $ZP::E_PAGE_CAPTCHA;
	}else{
		# Captchaページから来て、Captcha認証してない場合(専ブラ等)
		return $ZP::E_FORM_NOCAPTCHA;
	}
	
}

# ファイルクリーンアップ
sub CleanUp
{
	my $this = shift;
	my ($Sys) = @_;
	my $last_flush = $Sys->Get('LAST_FLUSH');
	my $span = 60 * 60 * 24 * 7;
	my $auth_expiry = $Sys->Get('AUTH_EXPIRY') * 60 * 60 * 24;
	my $ip_expiry = 60 * 60 * 24;
	my $code_expiry = 60 * 5;
	require './module/file_utils.pl';

	if(time - $last_flush > $span){
		# IP-SID紐付けファイル
		FILE_UTILS::ClearExpiredFiles('.'.$Sys->Get('INFO').'/.ninpocho/hash',qr/^ip-[\x20-\x7E]+\.cgi$/,$ip_expiry);
		# ユーザー認証情報保存ファイル
		FILE_UTILS::ClearExpiredFiles('.'.$Sys->Get('INFO').'/.auth',qr/^sid-[\x20-\x7E]+\.cgi$/,$auth_expiry);
		# ワンタイムパス認証用ファイル
		FILE_UTILS::ClearExpiredFiles('.'.$Sys->Get('INFO').'/.auth',qr/^code-[\x20-\x7E]+\.cgi$/,$code_expiry);

		$Sys->Set('LAST_FLUSH',time);
	}
	
}
#============================================================================================================
#	Module END
#============================================================================================================
1;