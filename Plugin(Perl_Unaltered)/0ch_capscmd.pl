#============================================================================================================
#
#	拡張機能 - キャップ用コマンド
#	0ch_capscmd.pl
#
#============================================================================================================
package ZPL_capscmd;

use CGI::Session;
use Digest::MD5 qw(md5_hex);


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
	return 'キャップ用コマンド';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return 'キャップ用のコマンドを追加';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ(スレ立て:1, レス:2, read:4, index:8, 書き込み前処理:16)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return 32;
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
	return {};
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$Sys	MELKOR
#	@param	$Form	SAMWISE
#	@param	$type	実行タイプ
#	@return	正常終了の場合は0
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my	$this = shift;
	my	($Sys, $Form, $type) = @_;
	
	# 0ch本家では実行しない
	return 0 if (!$this->{'is0ch+'});

	if ($type == 32) {
		# キャップ表示名を取得
		my $Sec = SECURITY->new;
		$Sec->Init($Sys);
		my $bbs = $Sys->Get('BBS');
		$Sec->SetGroupInfo($bbs);
		my $capID = $Sys->Get('CAPID', '');
		$capName = $Sec->Get($capID, 'NAME', 1, '');

		if ($capName) {
			# 各値を設定
			my $CGI = $Sys->Get('MainCGI');
			my $Threads = $CGI->{'THREADS'} || $Sys->Get('_THREAD_');
			$Threads->Load($Sys);
			my $threadid = $Sys->Get('KEY');
			my $modified = 0;
			my $bbsPath = $Sys->Get('BBSPATH') . "/${bbs}";
			my $datPath = $Sys->Get('DATPATH');
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $logPath	= $Sys->Get('BBSPATH') . "/${bbs}/log/cmd-del.cgi";
			my $ninDir = '.'. $Sys->Get('INFO') . '/.nin/';
			my $idDir = $Sys->Get('BBSPATH') . "/${bbs}/id/";
			my $sid = '';
			$msg = $Form->Get('MESSAGE');
			$idpart = $Form->Get('idpart');
			require './module/isildur.pl';
			my $bbsSet = ISILDUR->new;
			$bbsSet->Load($Sys);

			# 時刻を取得
			$ENV{'TZ'} = "JST-9";
			my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
			my @week = qw/日 月 火 水 木 金 土/;
			my $time = sprintf("%04d/%02d/%02d(${week[$wday]}) %02d:%02d:%02d", $year + 1900, $mon +1, $mday, $hour, $min, $sec);

			# BAN
			if ($msg =~ /!dstry:((?:,?(?:[0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+))+)(:.+)?/) {
				my @ids = split /,/, $1;
				for my $id (@ids) {
					# 削除メッセージ
					my $delmsg = $2 ? $2 : '';
					$delmsg = '<br>理由： ' . substr($delmsg, 1, -1) if $delmsg;
					# sid取得
					$sid = GetSID($id, $idDir, $ninDir, $logPath);
					# BAN処理
					if ($sid) {
						my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
						$session->param('ninpocho', -2);
						# ログファイルに記録
						if (open(my $fh, ">>", $logPath)) {
							# flock($fh, 2);
							print $fh "$idpart : !dstry : $time : $id : $sid\n";
							close($fh);
						}
					}
					if ($id =~ /^ID:/) {
						# レス削除
						$id =~ s/(\+|\/|\.|\?)/\\$1/g;
						my $lnum = 0;
						my @delnums;
						if (open(my $fh, "<", $datPath)) {
							while(my $line = readline $fh){ 
								chomp $line;
								$lnum++;
								push(@delnums, $lnum) if $line =~ /${id}(?=(.*?<>){2})/;
							}
							close($fh);
						}
						# 削除処理
						for my $delnum (@delnums) {
							DelRes($Sys, $delnum, $capName, $idpart, $time, $datPath, $logPath, $delmsg, 0);
						}
					}
				}
			}

			# レス削除コマンド
			if ($msg =~ /!del((?:[1-9]\d*,?)+)(:.+)?/) {
				# 削除レス番
				my @delnums = split /,/, $1;
				# 削除メッセージ
				my $delmsg = $2 ? $2 : '';
				$delmsg = '<br>理由： ' . substr($delmsg, 1, -1) if $delmsg;
				# 削除処理
				for my $delnum (@delnums) {
					DelRes($Sys, $delnum, $capName, $idpart, $time, $datPath, $logPath, $delmsg, 0);
				}
			}

			# レス範囲削除コマンド
			if ($msg =~ /!delrng(\d+):(\d+)(:.+)?/) {
				if ($2 >= $1) {
					# 削除レス番
					my @delnums = ($1 .. $2);
					# 削除メッセージ
					my $delmsg = $3 ? $3 : '';
					$delmsg = '<br>理由： ' . substr($delmsg, 1, -1) if $delmsg;
					# 削除処理
					for my $delnum (@delnums) {
						DelRes($Sys, $delnum, $capName, $idpart, $time, $datPath, $logPath, $delmsg, 0);
					}
				}
			}

			# レス範囲削除コマンド（透明削除）
			if ($msg =~ /!delrng-tp(\d+):(\d+)/) {
				# 削除レス番
				my $delst = $1;
				my $delend = $2;
				if ($delend >= $delst) {
					my $queue = $delend - $delst + 1;
					# 削除処理
					while ($queue) {
						DelRes($Sys, $delst, $capName, $idpart, $time, $datPath, $logPath, '', 1);
						$queue--;
					}
				}
			}

			# レス削除コマンド（スレ内ID全削除）
			if ($msg =~ /!del(ID:.{8})(:.+)?/) {
				my $targetID = $1;
				$targetID =~ s/(\+|\/|\.|\?)/\\$1/g;
				my $lnum = 0;
				my @delnums;
				if (open(my $fh, "<", $datPath)) {
					while(my $line = readline $fh){ 
						chomp $line;
						$lnum++;
						push(@delnums, $lnum) if $line =~ /${targetID}(?=(.*?<>){2})/;
					}
					close($fh);
				}
				# 削除メッセージ
				my $delmsg = $2 ? $2 : '';
				$delmsg = '<br>理由： ' . substr($delmsg, 1, -1) if $delmsg;
				# 削除処理
				for my $delnum (@delnums) {
					DelRes($Sys, $delnum, $capName, $idpart, $time, $datPath, $logPath, $delmsg, 0);
				}
			}

			# dat落ちコマンド
			if ($msg =~ /!(pool|old|delth)/) {
				my $tt = $Threads->Get('SUBJECT', $threadid);
				my $cmd = $1;
				my $id = '';
				if ($msg =~ /!(?:pool|delth)/) {
					# スレ立て人のBEを取得
					$id = $1 if $tt =~ /\[.*([0-9a-zA-Z.\/]{4}).*\]$/ && $bbsSet->Get('BBS_SLIP') =~ /^v{5,}/;
					if (!$id && open(my $fh, "<", $datPath)) {
						$content = <$fh>;
						$id = $1 if $content =~ /^.+?(ID:.{8})/;
						close($fh);
					}
					$sid = GetSID($id, $idDir, $ninDir) if $id;
					if ($sid) {
						# LvをSaku
						my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
						my $ninlv = $session->param('ninpocho') || 0;
						$ninlv = $ninlv ? 1 : 0;
						$session->param('ninpocho', $ninlv);
						$session->param('count', 1);
						$session->param('gold', 1);
						my $lvdn = $session->param('lvdn') || 0;
						$lvdn++;
						$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
					}
				}
				if ($msg =~ /!(?:pool|old)/) {
					my $Pools = FRODO->new;
					$Pools->Load($Sys);
					$Pools->Add($threadid, $Threads->Get('SUBJECT', $threadid), $Threads->Get('RES', $threadid));
					$Pools->Save($Sys);
					require './module/earendil.pl';
					EARENDIL::Copy("$bbsPath/dat/$threadid.dat", "$bbsPath/pool/$threadid.cgi");
				}
				$Threads->Delete($threadid);
				$modified = 1;
				unlink "$bbsPath/dat/$threadid.dat";
				# ログファイルに記録
				if (open(my $fh, ">>", $logPath)) {
					# flock($fh, 2);
					print $fh "$idpart : !$cmd : $time : $id : $sid : $datPath\n$tt\n";
					close($fh);
				}

			# スレストコマンド
			} elsif ($msg =~ /!stop/) {
				# スレ立て人のBEを取得
				my $tt = $Threads->Get('SUBJECT', $threadid);
				my $id = $1 if $tt =~ /\[.*([0-9a-zA-Z.\/]{4}).*\]$/ && $bbsSet->Get('BBS_SLIP') =~ /^v{5,}/;
				if (!$id && open(my $fh, "<", $datPath)) {
					$content = <$fh>;
					$id = $1 if $content =~ /^.+?(ID:.{8})/;
					close($fh);
				}
				$sid = GetSID($id, $idDir, $ninDir) if $id;
				if ($sid) {
					# LvをSaku
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					my $ninlv = $session->param('ninpocho') || 0;
					if ($ninlv) {
						$ninlv -= 3;
						$ninlv = 1 if $ninlv < 1;
					}
					$session->param('ninpocho', $ninlv);
					$session->param('count', 1);
					my $gold = $session->param('gold');
					$gold = $gold < 501 ? 1 : $gold - 500;
					$session->param('gold', $gold);
					my $lvdn = $session->param('lvdn') || 0;
					$lvdn++;
					$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
				}
				my $Thread = ARAGORN->new();
				$Thread->Load($Sys, $datPath, 0);
				$Thread->Stop($Sys);
				$Thread->Save($Sys);
				$Thread->Close();
				# スレタイにタグ
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.+)|[stop] $1|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
				# ログファイルに記録
				if (open(my $fh, ">>", $logPath)) {
					# flock($fh, 2);
					print $fh "$idpart : !stop : $time : $datPath\n$tt\n";
					close($fh);
				}
			
			# 強制sage
			} elsif ($msg =~ /!sage/) {
				if (!$Threads->GetAttr($threadid, 'capsage')) {
					# スレ立て人のBEを取得
					my $tt = $Threads->Get('SUBJECT', $threadid);
					my $id = $1 if $tt =~ /\[.*([0-9a-zA-Z.\/]{4}).*\]$/ && $bbsSet->Get('BBS_SLIP') =~ /^v{5,}/;
					if (!$id && open(my $fh, "<", $datPath)) {
						$content = <$fh>;
						$id = $1 if $content =~ /^.+?(ID:.{8})/;
						close($fh);
					}
					$sid = GetSID($id, $idDir, $ninDir) if $id;
					if ($sid) {
						# LvをSaku
						my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
						my $ninlv = $session->param('ninpocho') || 0;
						$ninlv-- if $ninlv > 1;
						$session->param('ninpocho', $ninlv);
						$session->param('count', 1);
						my $gold = $session->param('gold');
						$gold = $gold < 101 ? 1 : $gold - 100;
						$session->param('gold', $gold);
						my $lvdn = $session->param('lvdn') || 0;
						$lvdn++;
						$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
					}
					# スレ主が解除できないように
					$Threads->SetAttr($threadid, 'capsage', 1);
					$Threads->SaveAttr($Sys);
					# スレタイにタグ
					my $subjectsData = '';
					if (open(my $fh, "<", $subjects)) {
						my $content = do { local $/; <$fh> };
						$content =~ s|(?<=${threadid}\.dat<>)(.+)|[↓] $1|;
						$subjectsData = $content;
						close($fh);
					}
					if (open(my $fh, '>', $subjects)) {
						print $fh $subjectsData;
						close($fh);
					}
					# ログ
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !sage : $time : $datPath\n$tt\n";
						close($fh);
					}
				}

			# kuso
			} elsif ($msg =~ /!kuso/ && $bbs ne 'kuso' && $bbs eq 'news1') {
				# スレ立て人のBEを取得
				my $tt = $Threads->Get('SUBJECT', $threadid);
				my $id = $1 if $tt =~ /\[.*([0-9a-zA-Z.\/]{4}).*\]$/ && $bbsSet->Get('BBS_SLIP') =~ /^v{5,}/;
				if (!$id && open(my $fh, "<", $datPath)) {
					$content = <$fh>;
					$id = $1 if $content =~ /^.+?(ID:.{8})/;
					close($fh);
				}
				$sid = GetSID($id, $idDir, $ninDir) if $id;
				if ($sid) {
					# LvをSaku
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					my $ninlv = $session->param('ninpocho') || 0;
					$ninlv-- if $ninlv > 1;
					$session->param('ninpocho', $ninlv);
					$session->param('count', 1);
					my $gold = $session->param('gold');
					$gold = $gold < 101 ? 1 : $gold - 100;
					$session->param('gold', $gold);
					my $lvdn = $session->param('lvdn') || 0;
					$lvdn++;
					$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
				}
				# kuso板に移動
				my $Pools = FRODO->new;
				$Pools->Load($Sys);
				$Pools->Add($threadid, $Threads->Get('SUBJECT', $threadid), $Threads->Get('RES', $threadid));
				$Pools->Save($Sys);
				$Threads->Delete($threadid);
				$modified = 1;
				require './module/gondor.pl';
				my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
				require './module/earendil.pl';
				my $bbsPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
				EARENDIL::Copy("$bbsPath/dat/$threadid.dat", "$bbsPath/pool/$threadid.cgi");
				my $kusoPath = $Sys->Get('BBSPATH') . "/kuso";
				my $kusoDat = "$kusoPath/dat/$threadid.dat";
				EARENDIL::Copy("$bbsPath/dat/$threadid.dat", $kusoDat);
				unlink "$bbsPath/dat/$threadid.dat";
				my $sbjtxt = "$kusoPath/subject.txt";
				my $content;
				if (open(my $fh, '<', $sbjtxt)) {
					$content = do { local $/; <$fh> };
					close $fh;
				}
				if (open(my $fh, '>', $sbjtxt)) {
					print $fh "${threadid}.dat<>${tt} (${resNum})\n${content}";
					close $fh;
				}
				# ログファイルに記録
				if (open(my $fh, ">>", $logPath)) {
					# flock($fh, 2);
					print $fh "$idpart : !kuso : $time : $datPath\n$tt\n";
					close($fh);
				}
			}

			# レベル変更
			if ($msg =~ /!nlv:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):(\d+)/) {
				my $id = $1;
				my $lv = $2;
				$lv =~ s/^0+//;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# レベル変更処理
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					$session->param('ninpocho', $lv);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !nlv$lv : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# レベルダウン
			elsif ($msg =~ /!lvdn:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):([1-9]\d*)/) {
				my $id = $1;
				my $amount = $2;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# レベル変更処理
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					my $ninlv = $session->param('ninpocho') || 0;
					$ninlv -= $amount;
					$ninlv = 1 if $ninlv < 1;
					$session->param('ninpocho', $ninlv);
					my $lvdn = $session->param('lvdn') || 0;
					$lvdn++;
					$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
					my $gold = $session->param('gold');
					$gold -= $amount * 100;
					$gold = 1 if $gold < 1;
					$session->param('gold', $gold);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !lvdn$lvdn : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# gold変更
			if ($msg =~ /!gold:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):([1-9]\d*)/) {
				my $id = $1;
				my $amount = $2;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# レベル変更処理
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					$session->param('gold', $amount);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !gold$amount : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# chkid
			if ($msg =~ /!chkid:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+)/) {
				my $id = $1;
				$sid = GetSID($id, $idDir, $ninDir);
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					my $ninid = $session->param('ninid') || '';
					my $be = $session->param('be') || '';
					my $ninlv = $session->param('ninpocho') || 0;
					my $gold = $session->param('gold') || 1;
					my $ban = $session->param('ban');
					my $absnz = $session->param('absnz');
					my $lvdn = $session->param('lvdn');
					my $badip = $session->param('badip');
					$ban = 'NO' if !defined $ban;
					$absnz = 'NO' if !defined $absnz;
					$lvdn = 'NO' if !defined $lvdn;
					$badip = 'NO' if !defined $badip;
					my $prevremoho = $session->param('prevremoho') || '';
					my $prevua = $session->param('prevua') || '';
					my $bbslim = $session->param($bbs) | '';
					my $bbslim_news1 = $session->param('news1') | '';
					my $bbslim_livegalileo = $session->param('livegalileo') | '';
					my $bbslim_lv = 0;
					my $bbslim_tm = 0;
					my $ttmark = $session->param('ttmark') | '';
					my $bbslim_notice = 0;
					if ($bbslim =~ /^([0-3])-([1-9]\d+)/) {
						$bbslim_lv = $1;
						$bbslim_tm = $2 - time();
						$bbslim_tm = $bbslim_tm / (3600 * 24);
						$bbslim_tm =~ s/(?<=\.\d\d)\d+//;
						if ($bbslim_lv) {
							$bbslim_notice_lv = '強制コテ';
							$bbslim_notice_lv = '強制コテ(スレ立て禁止)' if $bbslim_lv == 2;
							$bbslim_notice_lv = '書き込み禁止' if $bbslim_lv == 3;
							$bbslim_notice_tm = int($bbslim_tm + 1);
							$bbslim_notice = "\n\n\n\n---【規制告知用】---\n規制忍法帖:$ninid\n規制内容:$bbslim_notice_lv\n期間:${bbslim_notice_tm}日\n対象板:$bbs\n理由:";
						}
					}
					my $capsChkidLogDir = $Sys->Get('BBSPATH') . "/caps/chkid/";
					mkdir $capsChkidLogDir if ! -d  $capsChkidLogDir;
					my @files	= glob "${capsChkidLogDir}*";
					for my $file (@files) {
						$file =~ s|${capsChkidLogDir}||;
					}
					@files = sort {$b <=> $a} @files;
					my $num = $files[0] ? $files[0] + 1 : 1;
					my $chkidLogPath = $capsChkidLogDir . $num;
					my $bbs = $Sys->Get('BBS');
					my $threadid = $Sys->Get('KEY');
					my $targetid = substr($id, -5, 5);
					$targetid = '****' . $targetid if $id !~ /^ID:\?\?\?/;
					my $chkidLstData = "---【chkid】---\n使用者:$capName\n時刻:${hour}時${min}分${sec}秒\n対象ID:$targetid\n\n---【基本情報】---\nレベル:$ninlv\n忍法帖ID:$ninid\n主ID:$be\n\n---【前科】---\nban:$ban\nabsnz:$absnz\nlvdn:$lvdn\n\n---bbslim---\nbbslim_lv_$bbs:$bbslim_lv\nbbslim_tm_$bbs:$bbslim_tm\nbbslim_full:$bbslim\nbbslim_full_news1:$bbslim_news1\nbbslim_full_livegalileo:$bbslim_livegalileo\n\n---【環境】---\nbadip:$badip\nprevremoho:$prevremoho\nprevua:$prevua\n\n---【その他】---\ngold:${gold}\n\nttmark:${ttmark}${bbslim_notice}";
					if (open(my $fh, ">", $chkidLogPath)) {
						print $fh $chkidLstData;
						close($fh);
					}
					my $fIdx = 0;
					while ($fIdx < 4) {
						$file = $capsChkidLogDir . $files[$fIdx];
						last if ! -f $file;
						$chkidLstData .= "\n\n\n\n---------------過去のchkid履歴${fIdx}---------------\n\n";
						if (open(my $fh, "<", $file)) {
							$content = do { local $/; <$fh> };
							$chkidLstData .= $content;
							close($fh);
						}
						$fIdx++;
					}
					my $chkidLstPath = $Sys->Get('BBSPATH') . '/caps/chkid.txt';
					if (open(my $fh, ">", $chkidLstPath)) {
						print $fh $chkidLstData;
						close($fh);
					}
				}
			}

			# 前科カウント
			if ($msg =~ /!znk:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):(\d+):(\d+):(\d+)/) {
				my $id = $1;
				my $ban = $2;
				my $absnz = $3;
				my $lvdn = $4;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# レベル変更処理
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					$session->param('ban', $ban);
					$session->param('absnz', $absnz);
					$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !znk$ban:$absnz:$lvdn : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# ttmark
			if ($msg =~ /!ttmark:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):([a-zA-Z0-9_\s\.\-,;()]+)/) {
				my $id = $1;
				my $str = $2;
				$str =~ s/\s$//;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# ttmark設定
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					$session->param('ttmark', $str);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !ttmark : $str : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# ttmark
			if ($msg =~ /!ttmark:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+):([a-zA-Z0-9_\s\.\-,;()]+)/) {
				my $id = $1;
				my $str = $2;
				$str =~ s/\s$//;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# ttmark設定
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					$session->param('ttmark', $str);
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !ttmark : $str : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			# envban
			if ($msg =~ /!envban:([a-zA-Z0-9\.\-]{2,}):([a-zA-Z0-9_\-]{2,})(:A)?/) {
				my $remoho = $1;
				my $ua = $2;
				my $bbs = $3 ? 'ALL' : $Form->Get('bbs'); 
				# envban.txt
				my $envban_txt = $Sys->Get('BBSPATH') . '/caps/envban.txt';
				if (open(my $fh, ">>", $envban_txt)) {
					# flock($fh, 2);
					print $fh "$remoho:$ua:$bbs\n";
					close($fh);
				}
				# ログファイルに記録
				if (open(my $fh, ">>", $logPath)) {
					# flock($fh, 2);
					print $fh "$idpart : !envban : $remoho : $ua : $bbs\n";
					close($fh);
				}
			}

			# 板ごとの規制
			if ($msg =~ /!bbslim:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+)(:[0-3])?(:[1-9]\d?)?(:[a-zA-Z0-9_\s\.\-,;()]+)?(:[0-9a-z]+)?/) {
				my $id = $1;
				my $lv = $2 ? $2 : 1; 
				my $day = $3 ? $3 : 1; 
				my $kote = $4 ? $4 : ''; 
				$kote =~ s/\s$//;
				my $bbs = $5 ? $5 : $Form->Get('bbs'); 
				$lv =~ s/^://;
				$day =~ s/^://;
				$bbs =~ s/^://;
				# 制限時間
				my $tm = time() + 86400 * $day;
				# sid取得
				$sid = GetSID($id, $idDir, $ninDir);
				# 規制処理
				if ($sid) {
					my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;
					if ($lv > 0) {
						$session->param($bbs, "${lv}-${tm}${kote}");
						my $ninlv = $session->param('ninpocho') || 0;
						$ninlv = $ninlv ? 1 : 0;
						$session->param('ninpocho', $ninlv);
						$session->param('count', 1);
						my $gold = $session->param('gold') || 1;
						$session->param('gold', 1);
						my $znk_param = $lv == 3 ? 'ban' : 'absnz';
						my $znk_cnt = $session->param($znk_param) || 0;
						$znk_cnt++;
						$session->param($znk_param, $znk_cnt);
						my $lvdn = $session->param('lvdn') || 0;
						$lvdn++;
						$session->param('lvdn', $lvdn);
            $session->param('alert', 1);
					} else {
						$session->param($bbs, 0);
					}
					# ログファイルに記録
					if (open(my $fh, ">>", $logPath)) {
						# flock($fh, 2);
						print $fh "$idpart : !bbslim:$lv:$day : $time : $id : $sid\n";
						close($fh);
					}
				}
			}

			if ($msg =~ /!report/ && $bbs eq 'unsaku') {
				$Threads->SetAttr($threadid, 'report', 1);
				$Threads->SaveAttr($Sys);
			}

			# スレッド情報を再保存
			if ($modified) {
				$Threads->Save($Sys);
			} else {
				$Threads->Close();
			}

		}
	}

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	SID取得
#------------------------------------------------------------------------------------------------------------
sub GetSID {
  my($id, $idDir, $ninDir, $logPath) = @_;
	my $sid;
	my $idPath;
	if ($id =~ /^ID:(?:\?){3}-(\d+)$/) {
		my $time_id = $1;
		$idPath = $idDir . "NOID-${time_id}";
	} elsif ($id =~ /^ID:.{8}$/) {
		$idPath = $idDir . md5_hex($id);
	} else {
		$idPath = "${ninDir}id/$id" if $id =~ /[0-9a-f]{6}|[0-9a-zA-Z.\/]{4}/;
	}
	if ($id && open(my $fh, '<', $idPath)) {
		$sid = <$fh>;
		$sid =~ s/\n//g;
		close($fh);
	}
	# ログファイルに記録
	# if (open(my $fh, ">>", $logPath)) {
	# 	# flock($fh, 2);
	# 	print $fh "$idpart : !getsid : $time : $id : $idPath : $sid\n";
	# 	close($fh);
	# }
	return $sid;
}

#------------------------------------------------------------------------------------------------------------
#	ファイル全文検索
#------------------------------------------------------------------------------------------------------------
sub FSEARCH {
  my($dir, $word) = @_;
	my $result = '';
  opendir(DIR, $dir);
  my @dir = sort { $a cmp $b } readdir(DIR);
  closedir(DIR);
  foreach my $file (@dir) {
    if ($file eq '.' or $file eq '..') {
      next;
    }
    my $target = "$dir$file";
    if (-d $target) {
      &FSEARCH("$target/", $word);
    } else {
      my $flag = 0;
      open(FH, $target);
      while (my $line = <FH>) {
        if (index(lc($line), lc($word)) >= 0) {
          $flag = 1;
        }
      }
      close(FH);
      if ($flag) {
        $result = $target;
				last;
      }
    }
  }
  return $result;
}

#------------------------------------------------------------------------------------------------------------
#	削除
#	-------------------------------------------------------------------------------------
#	@param	$delnums	削除するレス番
#------------------------------------------------------------------------------------------------------------
sub DelRes {
	my ($Sys, $delnum, $capName, $idpart, $time, $datPath, $logPath, $delmsg, $transparent) = @_;
	# あぼ〜ん時は削除名を取得
	my $Setting;
	require './module/isildur.pl';
	$Setting = ISILDUR->new;
	$Setting->Load($Sys);
	my $abone	= $Setting->Get('BBS_DELETE_NAME');
	# 削除処理
	my $data = '';
	if (open(my $fh, "<", $datPath)) {
		# flock($fh, 2);
		my $cnt = 0;
		while(my $line = <$fh>) {
			$cnt++;
			# datを編集して削除
			if ($cnt == $delnum) {
				# 削除後の表示
				my $content = $transparent ? '' : "$abone<>${capName} ★<>${capName} ★<>削除日時： $time$delmsg <>$abone\n";
				$data .= $content;
				# ログファイルに記録（板別）
				if (open(my $fh, ">>", $logPath)) {
					print $fh "$idpart : !del : $time : $datPath\n$delnum : $line\n";
					close($fh);
				}
				# ログファイルに記録（全体）
				my $capsDelLogDir = $Sys->Get('BBSPATH') . "/caps/del/";
				mkdir $capsDelLogDir if ! -d  $capsDelLogDir;
				my @files	= glob "${capsDelLogDir}*";
				for my $file (@files) {
					$file =~ s|${capsDelLogDir}||;
				}
				@files = sort {$b <=> $a} @files;
				my $num = $files[0] ? $files[0] + 1 : 1;
				my $delLogPath = $capsDelLogDir . $num;
				my $bbs = $Sys->Get('BBS');
				my $threadid = $Sys->Get('KEY');
				my $delLstData = "$capName\n$time\nhttps://sannan.nl/test/read.cgi/$bbs/$threadid/$delnum\n\n$line";
				if (open(my $fh, ">", $delLogPath)) {
					print $fh $delLstData;
					close($fh);
				}
				for my $file (@files) {
					$file = $capsDelLogDir . $file;
					$delLstData .= "\n----------------------------------------------------------------------------------------------------\n";
					if (open(my $fh, "<", $file)) {
						$content = do { local $/; <$fh> };
						$delLstData .= $content;
						close($fh);
					}
				}
				my $delLstPath = $Sys->Get('BBSPATH') . '/caps/del.txt';
				if (open(my $fh, ">", $delLstPath)) {
					print $fh $delLstData;
					close($fh);
				}
			} else {
				$data .= $line;
			}
		}
	}
	if (open(my $fh, ">", $datPath)) {
		print $fh $data;
		close($fh);
	}
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
