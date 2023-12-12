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
	
	# 入力内容チェック(名前、メール)
	return $err if (($err = $this->NormalizationNameMail()) != $ZP::E_SUCCESS);
	
	# 入力内容チェック(本文)
	return $err if (($err = $this->NormalizationContents()) != $ZP::E_SUCCESS);
	
	# 規制チェック
	return $err if (($err = $this->IsRegulation()) != $ZP::E_SUCCESS);
	

	# データの書き込み
	require './module/dat.pl';
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Form = $this->{'FORM'};
	my $Conv = $this->{'CONV'};
	my $Threads = $this->{'THREADS'};
	my $Sec = $this->{'SECURITY'};
	# Cookie管理モジュールを用意
	require './module/ninpocho.pl';
	my $Ninja = NINPOCHO->new;
	my $sid = $Ninja->Load($Sys);

	# 改造版で追加
	# hCaptcha認証
	if ($Set->Get('BBS_HCAPTCHA')){
		$err = $this->Certification_hCaptcha($Sys,$Form);
		return $err if $err != $ZP::E_SUCCESS;
	}
	
	my $threadid = $Sys->Get('KEY');
	$Threads->LoadAttr($Sys);
 	my $idSet = $Threads->GetAttr($threadid,'noid');
 	return $ZP::E_LIMIT_STOPPEDTHREAD if ($Threads->GetAttr($threadid,'stop'));
	return $ZP::E_LIMIT_MOVEDTHREAD if ($Threads->GetAttr($threadid,'pool'));

	#コマンドによる過去ログ送り用（猶予のため）
	ToKakoLog($Sys,$Set,$Threads);
	my $isNinja = $Set->Get('BBS_NINJA');#忍法帖が設定されていたらID生成に使用
	
	# 情報欄
 	my $idpart = 'ID:none';
	my $id = $Conv->MakeIDnew($Sys, 8, $sid);
	if (!$idSet){
		$idpart = $Conv->GetIDPart($Set, $Form, $Sec, $id, $Sys->Get('CAPID'), $Sys->Get('KOYUU'), $Sys->Get('AGENT'));
	}
	my $datepart = $Conv->GetDate($Set, $Sys->Get('MSEC'));
	my $bepart = '';
	my $extrapart = '';
	$Form->Set('datepart', $datepart);
	$Form->Set('idpart', $idpart);
	#$Form->Set('BEID', ''); # type=1|2
	$Form->Set('extrapart', $extrapart);
	
	my $updown = 'top';
	$updown = '' if ($Form->Contain('mail', 'sage'));
	$updown = '' if ($Threads->GetAttr($threadid, 'sagemode'));
	$Sys->Set('updown', $updown);
	
	# 書き込み直前処理
	$err = $this->ReadyBeforeWrite(DAT::GetNumFromFile($Sys->Get('DATPATH')) + 1);
	$this->Ninpocho($Sys,$Form,$Ninja,$sid) if $isNinja;
	return $err if ($err != $ZP::E_SUCCESS);
	
	# レス要素の取得
	my $subject = $Form->Get('subject', '');
	my $name = $Form->Get('FROM', '');
	my $mail = $Form->Get('mail', '');
	my $text = $Form->Get('MESSAGE', '');

	$datepart = $Form->Get('datepart', '');
	$idpart = $Form->Get('idpart', '');
	$bepart = $Form->Get('BEID', '');
	$extrapart = $Form->Get('extrapart', '');
	my $info = $datepart;
	$info .= " $idpart" if ($idpart ne '');
	$info .= " $bepart" if ($bepart ne '');
	$info .= " $extrapart" if ($extrapart ne '');

	if($subject && $Set->Get('BBS_TITLEID') && $Sys->Equal('MODE', 1)){
		# スレ立て時にスレタイにID付加
		$subject = $subject." [$id★]";
	}
	
	my $data = "$name<>$mail<>$info<>$text<>$subject";
	my $line = "$data\n";
	
	my $datPath = $Sys->Get('DATPATH');
	
	# ログ書き込み
	require './module/manager_log.pl';
	my $Log = MANAGER_LOG->new;
	$Log->Load($Sys, 'WRT', $threadid);
	$Log->Set($Set, length($Form->Get('MESSAGE')), $Sys->Get('VERSION'), $Sys->Get('KOYUU'), $data, $Sys->Get('AGENT', 0),$sid);
	$Log->Save($Sys);
	
	# リモートホスト保存(SETTING.TXT変更により、常に保存)
	SaveHost($Sys, $Form);
	
	# datファイルへ直接書き込み
	my $resNum = 0;
	my $err2 = DAT::DirectAppend($Sys, $datPath, $line);
	my $AttrResMax = $Threads->GetAttr($threadid,'maxres');
	if ($err2 == 0) {
		# レス数が最大数を超えたらover設定をする
		$resNum = DAT::GetNumFromFile($datPath);
		my $MAXRES = $AttrResMax ? $AttrResMax : $Sys->Get('RESMAX');
		if ($resNum >= $MAXRES) {
			return $ZP::E_LIMIT_OVERMAXRES if ($resNum > $MAXRES);
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
	
	if ($err == $ZP::E_SUCCESS) {
		# subject.txtの更新
		# スレッド作成モードなら新規に追加する
		if ($Sys->Equal('MODE', 1)) {
			require './module/file_utils.pl';
			my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $Pools = POOL_THREAD->new;
			$Pools->Load($Sys);
			$Threads->Add($threadid, $subject, 1);
			
			# スレッド数限界によるdat落ち処理
			my $submax = $Sys->Get('SUBMAX');
			my @tlist;
			$Threads->GetKeySet('ALL', undef, \@tlist);
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
		# 書き込みモードならレス数の更新
		else {
			$updown = $Sys->Get('updown', '');
			$Threads->OnDemand($Sys, $threadid, $resNum, $updown);
		}
	}
	$Ninja->Save($Sys);
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
#	@param	$res
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub ReadyBeforeWrite
{
	my $this = shift;
	my ($res) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $Form = $this->{'FORM'};
	my $Sec = $this->{'SECURITY'};
	my $capID = $Sys->Get('CAPID', '');
	my $bbs = $Form->Get('bbs');
	my $from = $Form->Get('FROM');
	my $koyuu = $Sys->Get('KOYUU');
	my $client = $Sys->Get('CLIENT');
	my $host = $ENV{'REMOTE_HOST'};
	my $addr = $ENV{'REMOTE_ADDR'};
	my $Threads = $this->{'THREADS'};
	
	# 規制ユーザ・NGワードチェック
	{
		# 規制ユーザ
		if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NGUSER, $bbs)) {
			require './module/user.pl';
			my $vUser = USER->new;
			$vUser->Load($Sys);
			
			my $koyuu2 = ($client & $ZP::C_MOBILE_IDGET & ~$ZP::C_P2 ? $koyuu : undef);
			my $check = $vUser->Check($host, $addr, $koyuu2);
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
	
	# pluginに渡す値を設定
	$Sys->Set('_ERR', 0);
	$Sys->Set('_NUM_', $res);
	$Sys->Set('_THREAD_', $this->{'THREADS'});
	$Sys->Set('_SET_', $this->{'SET'});
	
	my $CommandSet = $Set->Get('BBS_COMMAND');

	$Threads->LoadAttr($Sys);
	my $threadid = $Sys->Get('KEY');
	my $commandAuth = $Sec->IsAuthority($capID, $ZP::CAP_REG_COMMAND, $Form->Get('bbs'));
	my $noAttr = $Sec->IsAuthority($capID, $ZP::CAP_REG_NOATTR, $Form->Get('bbs'));

	#スレ立て時用コマンド
	my $ipua = $addr.$ENV{'HTTP_USER_AGENT'};
	my $is1 = $ipua eq Get1IPUA($Sys,$threadid) ? 1 : 0;

	if($Sys->Equal('MODE', 1)){
		Command($Sys,$Form,$Threads,$CommandSet,1);
	}
	else{
		if($Form->Get('mail') =~ /!pass:(.){1,30}/){
			require Digest::SHA::PurePerl;
			my $ctx = Digest::SHA::PurePerl->new;
			$ctx->add(':', $Sys->Get('SERVER'));
			$ctx->add(':', $threadid);
			$ctx->add(':', $1);
			my $inputPass = $ctx->b64digest;

			my $threadPass = $Threads->GetAttr($threadid, 'pass');

			#メール欄からpass削除
			my $mail = $Form->Get('mail');
			$mail =~ s/!pass:(.){1,30}//;
			$Form->Set('mail',$mail);
			
			if($inputPass eq $threadPass){
				Command($Sys,$Form,$Threads,$CommandSet,0);
			}
		}
		elsif($commandAuth){
			Command($Sys,$Form,$Threads,$CommandSet,0);
		}
	}
	
	my $text = $Form->Get('MESSAGE');
	$text =~ s/<br>/ <br> /g;
	$Form->Set('MESSAGE', " $text ");
	
	# 名無し設定
	$from = $Form->Get('FROM', '');
	if (($from eq ''||$Threads->GetAttr($threadid,'force774')) && !$noAttr) {
		if($Threads->GetAttr($threadid,'change774')){
			$from = $Threads->GetAttr($threadid,'change774');
		}
		else{
			$from = $this->{'SET'}->Get('BBS_NONAME_NAME');
		}
		$Form->Set('FROM', $from);
	}
	$this->ExecutePlugin(16);

	my $isSlip = $Threads->GetAttr($threadid,'slip');
	my $bbsslip = $isSlip ? $isSlip : $Set->Get('BBS_SLIP');

	$this->addSlip($Sys, $Form, $bbsslip) if (!$Sec->IsAuthority($capID, $ZP::CAP_DISP_HANLDLE, $bbs) || !$noAttr);

	$this->OMIKUJI($Sys, $Form);	#おみくじ
	$this->tasukeruyo($Sys, $Form);	#IP+UA表示

	return 0;
}
sub Get1IPUA
{
	my ($Sys,$threadid) = @_;
	require './module/log.pl';
	my $Logger = LOG->new;
	my $logPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/' . $threadid;
	$Logger->Open($logPath, 0, 1 | 2);

	my @log = split(/<>/,$Logger->Get(0));
	my $ip = $log[6];
	my $ua = $log[8];

	return $ip.$ua;
}
#ユーザーコマンド
sub Command
{
	my ($Sys,$Form,$Threads,$setBitMask,$mode) = @_;
	$Threads->LoadAttr($Sys);
	my $threadid = $Sys->Get('KEY');
	my $Command = '';

	#スレ主用パス(メール欄)/スレ立て時専用処理
	if($mode){
		#passを取得・設定
		if($Form->Get('mail') =~ /!pass:(.){1,30}/ && ($setBitMask & 1)){
			require Digest::SHA::PurePerl;
			my $ctx = Digest::SHA::PurePerl->new;
			$ctx->add(':', $Sys->Get('SERVER'));
			$ctx->add(':', $threadid);
			$ctx->add(':', $1);
			my $pass = $ctx->b64digest;

			$Threads->SetAttr($threadid, 'pass',$pass);
			$Threads->SaveAttr($Sys);

			my $mail = $Form->Get('mail');
			$mail =~ s/!pass:(.){1,30}//;
			$Form->Set('mail',$mail);
		}
		#最大レス数変更
		if ($Form->Get('MESSAGE') =~ /(^|<br>)!maxres:([0-9]{3,4})(<br>|$)/ && ($setBitMask & 2)) {
			if ($2 && $2 >= 100 && $2 <= 2000) {
				$Threads->SetAttr($threadid, 'maxres', int $2);
				my $maxres = $Threads->GetAttr($threadid, 'maxres');
				$Command .= '※最大'.$2.'レス<br>';
			}
			$Threads->SaveAttr($Sys);
		}
	}

	##スレ中パスワード保持者のみ
	if(!$mode){
		#コマンド取り消し
		if($Form->Get('MESSAGE') =~ /(^|<br>)!delcmd:([0-9a-zA-Z]{4,10})(<br>|$)/ && ($setBitMask & 256)){
			my $delCommand = $2;
			$delCommand =~ s/^sage$/sagemode/;
			if($Threads->GetAttr($threadid, $delCommand)){
				$Threads->SetAttr($threadid, $delCommand,'');
				$Threads->SaveAttr($Sys);
				$delCommand =~ s/^sagemode$/sage/;
				$Command .= '※'.$delCommand.'取り消し<br>';
			}
			else{
				$delCommand =~ s/^sagemode$/sage/;
				$Command .= '※'.$delCommand.'の取り消しに失敗しました<br>';
			}
		}
		#スレスト
		if($Form->Get('MESSAGE') =~ /(^|<br>)!stop(<br>|$)/ && ($setBitMask & 128)){
			$Threads->SetAttr($threadid, 'stop',1);
			$Threads->SaveAttr($Sys);
			$Command .= '※スレスト<br>';
		}
		#過去ログ送り
		if($Form->Get('MESSAGE') =~ /(^|<br>)!pool(<br>|$)/ && ($setBitMask & 512)){
			$Threads->SetAttr($threadid, 'pool',1);
			$Threads->SaveAttr($Sys);
			$Command .= '※過去ログ送り<br>';
		}
		#スレタイ変更
#		if($Form->Get('MESSAGE') =~ /(^|<br>)!changetitle:(.*?)(<br>|$)/ && ($setBitMask & )){
#			my $newTitle = $2;
#			if($newTitle){
#				$newTitle =~ s/"/&quot;/g;
#				$newTitle =~ s/&/&amp;/g;
#				$newTitle =~ s/</&lt;/g;
#				$newTitle =~ s/>/&gt;/g;
#				$newTitle =~ s/(\r\n|\r|\n)//g;
#			}
#			$Threads->SetAttr($threadid, 'changetitle',$newTitle);
#			$Threads->SaveAttr($Sys);
#			$Command .= '※スレタイ変更：'.$newTitle.'<br>';
#		}
	}

	##スレ立て時＆スレ中パスワード保持者のみ
	#強制sage
	if($Form->Get('MESSAGE') =~ /(^|<br>)!sage(<br>|$)/ && ($setBitMask & 4)){
		$Threads->SetAttr($threadid, 'sagemode',1);
		$Threads->SaveAttr($Sys);
		$Command .= '※強制sage<br>';
	}
	#強制age
#	if($Form->Get('MESSAGE') =~ /(^|<br>)!float(<br>|$)/ && ($setBitMask & )){
#		$Threads->SetAttr($threadid, 'float',1);
#		$Threads->SaveAttr($Sys);
#		$Command .= '※強制age<br>';
#	}
	#不落
#	if($Form->Get('MESSAGE') =~ /(^|<br>)!nopool(<br>|$)/ && ($setBitMask & )){
#		$Threads->SetAttr($threadid, 'nopool',1);
#		$Threads->SaveAttr($Sys);
#		$Command .= '※不落<br>';
#	}
	#BBS_SLIP
	if($Form->Get('MESSAGE') =~ /(^|<br>)!slip:(v{3,6})(<br>|$)/ && ($setBitMask & 2048)){
		$Threads->SetAttr($threadid, 'slip',$2);
		$Threads->SaveAttr($Sys);
		$Command .= '※BBS_SLIP='.$2.'<br>';
	}
	#名無し強制
	if($Form->Get('MESSAGE') =~ /(^|<br>)!force774(<br>|$)/ && ($setBitMask & 32)){
		$Threads->SetAttr($threadid, 'force774',1);
		$Threads->SaveAttr($Sys);
		$Command .= '※強制名無し<br>';
		$Form->Set('FROM','');
	}
	#実況モード
	if($Form->Get('MESSAGE') =~ /(^|<br>)!live(<br>|$)/ && ($setBitMask & 1024)){
		$Threads->SetAttr($threadid, 'live',1);
		$Threads->SaveAttr($Sys);
		$Command .= '※実況スレ<br>';
	}
	#名無し変更
	if($Form->Get('MESSAGE') =~ /(^|<br>)!change774:(.*?)(<br>|$)/ && ($setBitMask & 64)){
		use HTML::Entities;
		my $new774 = $2;
		$new774 = encode_entities($new774);
		$new774 =~ s/&amp;/&/g;
		$Threads->SetAttr($threadid, 'change774',$new774);
		$Threads->SaveAttr($Sys);
		$Command .= '※名無し：'.$new774.'<br>';
	}
	#ID無し若しくはIDをスレッドで変更（!noidと!changeidがあった場合は!noid優先）
	if($Form->Get('MESSAGE') =~ /(^|<br>)!noid(<br>|$)/ && ($setBitMask & 8)){
		$Threads->SetAttr($threadid, 'noid',1);
		$Threads->SaveAttr($Sys);
		$Command .= '※ID無し<br>';
	}
	if(!$Threads->GetAttr($threadid, 'noid') && $Form->Get('MESSAGE') =~ /(^|<br>)!changeid(<br>|$)/ && ($setBitMask & 16)){
		$Threads->SetAttr($threadid, 'changeid',1);
		$Threads->SaveAttr($Sys);
		$Command .= '※ID変更<br>';
	}
	
	if($Command){
		$Command =~ s/<br>$//;
		$Form->Set('MESSAGE',$Form->Get('MESSAGE')."<hr><font color=\"red\">$Command</font>");
	}
}

# 過去ログの移動や保存を行う
sub ToKakoLog {
    my ($Sys, $Set, $Threads) = @_;
    
    require './module/file_utils.pl';
    require './module/bbs_service.pl';  # 一度だけ読み込む
    my $Pools = POOL_THREAD->new;
    my $BBSAid = BBS_SERVICE->new;  # 一度だけインスタンス化

    my $elapsed = 60 * 60;  # 1時間
    my $nowtime = time;
    
    my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
    my $BBSname = $Set->Get('BBS_KAKO');
    my $otherBBSpath = $Sys->Get('BBSPATH') . '/' . $BBSname;
    
    my @threadList = ();
    my $isUpdate = '';  # 更新が必要な場合
    
    $Threads->GetKeySet('ALL', '', \@threadList);
    $Threads->LoadAttr($Sys);

    foreach my $id (@threadList) {
        my $need_update = process_thread($Sys, $Set, $Threads, $Pools, $path, $otherBBSpath, $id, $nowtime, $elapsed, $BBSname);
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
# 更新が必要な場合は1を、そうでない場合は0を返す
sub process_thread {
    my ($Sys, $Set, $Threads, $Pools, $path, $otherBBSpath, $id, $nowtime, $elapsed, $BBSname) = @_;
    
    my $need_update = 0;

    my $attrLive = $Threads->GetAttr($id, 'live');
    my $attrPool = $Threads->GetAttr($id, 'pool');
    my $lastmodif = (stat "$path/dat/$id.dat")[9];
    
    if (($attrLive && ($nowtime - $lastmodif > $elapsed)) || $attrPool) {
        $need_update = 1;

        if ($BBSname) {
            FILE_UTILS::Move("$path/dat/$id.dat", "$otherBBSpath/dat/$id.dat");
        } else {
            $Pools->Add($id, $Threads->Get('SUBJECT', $id), $Threads->Get('RES', $id));
			FILE_UTILS::Move("$path/dat/$id.dat", "$path/pool/$id.cgi");
        }
		$Threads->Delete($id);
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
	# PROXYチェック
	if (!$islocalip && $Set->Equal('BBS_PROXY_CHECK', 'checked')) {
		if ($this->{'CONV'}->IsProxy($this->{'SYS'}, $this->{'FORM'}, $from, $mode)) {
			#$this->{'FORM'}->Set('FROM', "</b> [—\{}\@{}\@{}-] <b>$from");
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_DNSBL, $bbs)) {
				return $ZP::E_REG_DNSBL;
			}
		}
	}
	# 読取専用
	if (!$Set->Equal('BBS_READONLY', 'none')) {
		if (!$Sec->IsAuthority($capID, $ZP::CAP_LIMIT_READONLY, $bbs)) {
			return $ZP::E_LIMIT_READONLY;
		}
	}
	# JPホスト以外規制
	if (!$islocalip && $Set->Equal('BBS_JP_CHECK', 'checked')) {
		if ($host !~ /\.jp$/i) {
			if (!$Sec->IsAuthority($capID, $ZP::CAP_REG_NOTJPHOST, $bbs)) {
				return $ZP::E_REG_NOTJPHOST;
			}
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
#	名前・メール欄の正規化
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

#------------------------------------------------------------------------------------------------------------
#
#	改造版で追加
#	hCaptchaの認証
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	規制通過なら0を返す
#			規制チェックにかかったらエラーコードを返す
#
#------------------------------------------------------------------------------------------------------------
sub Certification_hCaptcha {
    my $this = shift;
    my ($Sys,$Form) = @_;

    my $secretkey = $Sys->Get('HCAPTCHA_SECRETKEY');
    my $sitekey = $Sys->Get('HCAPTCHA_SITEKEY');

    my $url = 'https://api.hcaptcha.com/siteverify';
    my $ua = LWP::UserAgent->new();
    my $recaptcha_response = $Form->Get('h-captcha-response');
    my $remote_ip = $ENV{REMOTE_ADDR};
        
    my $response = $ua->post($url,{
			secret => $secretkey,
			response => $recaptcha_response,
			remoteip => $remote_ip
           });
    if ($response->is_success()) {
        my $json_text = $response->decoded_content();
           
        # JSON::decode_json関数でJSONテキストをPerlデータ構造に変換
        my $out = decode_json($json_text);
           
        if ($out->{success}) {
           return $ZP::E_SUCCESS;
        } else {
           return $ZP::E_FORM_NOCAPTCHA;
        }
    } else {
		#captchaを素通りする場合はHTTPS関連のエラーの疑いあり
		#ここの返り値を$ZP::E_SYSTEM_ERRORに変えればエラーがあるか確認可能
    	return $ZP::E_SUCCESS;
    }
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
sub addSlip
{
	my $this = shift;
	my ($Sys, $Form,$bbsslip) = @_;
	my $Set = $this->{'SET'};

	use Socket;
	require './module/slip.pl';

	#IP・リモホ・UAを取得
	my $ip_addr = $ENV{'REMOTE_ADDR'};
	my $remoho  = $ENV{'REMOTE_HOST'};
	my $ua =  $ENV{'HTTP_SEC_CH_UA'} // $ENV{'HTTP_USER_AGENT'};

	#BBS_SLIP機能呼び出し
	if ($bbsslip =~ /^v{3,6}$/){
		#名前欄にワッチョイもどきを追加
		my $from = $Form->Get('FROM');
		if ($from eq '') {
			$from = $Set->Get('BBS_NONAME_NAME');
		}
		my $res = SLIP::BBS_SLIP_OLD($ip_addr, $remoho, $ua, $bbsslip);
		$from = "${from} </b>(${res})<b> </b>";
		$Form->Set('FROM',$from);
	}

	return 0;
}
sub Ninpocho
{
	my $this = shift;
	my ($Sys, $Form, $Ninja, $sid) = @_;

    # セッションから忍法帖Lvを取得
    my $ninLv = $Ninja->Get('ninLv') || 1;

	# セッションから書き込み数を取得
	my $count = $Ninja->Get('count') || 0;

    # 書き込んだ時間を取得
	my $resTime = time();
    # 書き込んだ時間の23時間後を取得
	my $time23h = time() + 82800;
	# セッションから前回レベルアップしたときの時間を取得
	my $lvUpTime = $Ninja->Get('lvuptime') || $time23h;

    # 書き込み数をカウント
	$count++;

	# レベルの上限
	my $lvLim = 40;

    # 前回のレベルアップから23時間以上経過していればレベルアップ
    if ($resTime >= $lvUpTime && $ninLv < $lvLim) {
      $ninLv++;
      $lvUpTime = $time23h;
    }

	# セッションに記録
	if ($Ninja) {
		$Ninja->Set('count', $count);
		$Ninja->Set('ninLv', $ninLv);
		$Ninja->Set('lvuptime', $lvUpTime);
	}

	# 名前欄取得
	my $name = $Form->Get('FROM');

	# 現在の時刻を取得
	my $currentTime = time();
	# 現在の時刻と$lvUpTimeとの差を計算
	my $timeDiff = $lvUpTime - $currentTime;
	# 差分を時間単位と分単位で計算
	my $hoursDiff = int($timeDiff / 3600); # 1時間 = 3600秒
	my $minutesDiff = int(($timeDiff % 3600) / 60); # 残りの秒数を分に変換

	# 残り時間表示用
	my $timeDisplay = "";
	$timeDisplay .= "${hoursDiff}時間" if $hoursDiff > 0;
	$timeDisplay .= "${minutesDiff}分" if $minutesDiff > 0 || $hoursDiff == 0; # 分が0でも時間が0の場合は表示する

	my $minutes = int($lvUpTime / 60);
	#セッションハイジャック防止用
	my $length = length($sid);
	my $half = int($length / 2);
	substr($sid, $half) = '*' x ($length - $half);

	# 名前欄書き換え
	$name =~ s|!id|</b>【忍法帖ID:$sid】<b>|g;
	$name =~ s|!time|</b>【LvUPまで${timeDisplay}】<b>|g;
	$name =~ s|!ninja|</b>【忍法帖Lv.$ninLv】<b>|g;
	$name =~ s|!total|</b>【総カキコ数:$count】<b>|g;

	# 名前欄再設定
	$Form->Set('FROM', $name);

	return 0;
}
#SPAMBLOCK
sub SpamBlock
{
	my	$this = shift;
	my	($Setting, $form) = @_;
	
	my $name_ascii_point	= $Setting->Get('BBS_SPAMKILLI_ASCII');		#名前欄がASCIIのみ
	my $mail_atsign_point	= $Setting->Get('BBS_SPAMKILLI_MAIL');		#メール欄に半角\@を含む
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
	if ($text =~ m|http://|) {
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
						($text =~ m|http://([a-z0-9\-\.]+)|gi)} };
		
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

#============================================================================================================
#	Module END
#============================================================================================================
1;