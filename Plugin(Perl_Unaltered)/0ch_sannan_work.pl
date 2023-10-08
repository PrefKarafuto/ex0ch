#===========================================================================================================#
#	拡張機能 - 三男拡張
#	0ch_sannan.pl
#
# ============================================================================================================
package ZPL_sannan;

use Socket;
use Digest::MD5 qw(md5_hex);
use Net::Whois::Raw;
use Geo::IP;
use Net::DNS;
use CGI::Cookie;
use CGI::Session;
use LWP::UserAgent;
use JSON qw/encode_json decode_json/;


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
	return '三男拡張';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	return '三男拡張';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ(スレ立て:1, レス:2, read:4, index:8, 書き込み前処理:16)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	return (16|32);
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
	return {
		'enable_stop'	=> {
			'default'		=> 1,
			'valuetype'		=> 3,
			'description'	=> 'スレストコマンド「!stop」を有効にする',
		},
		'enable_pool'	=> {
			'default'		=> 1,
			'valuetype'		=> 3,
			'description'	=> 'dat落ちコマンド「!pool」を有効にする',
		},
	};
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$sys	MELKOR
#	@param	$form	SAMWISE
#	@param	$type	実行タイプ
#	@return	正常終了の場合は0
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my $this = shift;
	my ($Sys, $Form, $type) = @_;

	# 0ch本家では実行しない
	return 0 if (!$this->{'is0ch+'});

	if ($type & (16 | 32)) {
		# キャップ情報の読み込み
		my $Sec = SECURITY->new;
		$Sec->Init($Sys);
		$Sec->SetGroupInfo($Sys->Get('BBS'));

		# スレッド情報
		my $CGI = $Sys->Get('MainCGI');
		my $Threads = $CGI->{'THREADS'} || $Sys->Get('_THREAD_');
		my $threadid = $Sys->Get('KEY');
		$Threads->LoadAttr($Sys);

		if ($type&16) {

			# 板設定の読み込み
			require './module/setting.pl';
			my $bbsSet = SETTING->new;
			$bbsSet->Load($Sys);

			# IPアドレスを取得
			my $ipAddr = "$ENV{'REMOTE_ADDR'}";
			# リモホを取得
			my $remoho = Resolver($ipAddr);
			# UAを取得
			my $ua = "$ENV{'HTTP_USER_AGENT'}";

			# infodir
			my $infoDir = $Sys->Get('INFO');

			# denyip
			my $denyIP = is_denied_ip($ipAddr, $infoDir);

			PrintBBSError_Ninja($Sys, 10045) if $denyIP;

			# 国を判定
			my $country= get_country_by_ip($ipAddr);
			# モバイル判定
			my $ismobile = is_mobile($country, $ipAddr, $remoho, $Form);
			# 公衆Wi-Fi判定
			my $isFwifi = = is_public_wifi($country, $remoho, $ipAddr);
			# 匿名化判定
			my $isAnon = = is_anonymous($isFwifi, $country, $remoho, $ipAddr, $infoDir);

			# Cookie管理モジュールを用意
			my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};

			# 忍法帖セッションを取得
			my $delIP = $ismobile || $isFwifi || $country ne 'JP' || $remoho =~ /^(?:(?:flh|FL).*\.mesh\.ad\.jp|.*\.shared\.user\.transix\.jp|.*\.v4\.enabler\.ne.jp)$/ ? 1 : 0;
			$session = $bbsSet->Get('BBS_NINJA') eq 'checked' && $Form->Get('idpart') ne 'ID:BOT' ? NinSS($Sys, $Form, $Cookie, $ipAddr, $remoho, $ua, $delIP, $ismobile) : '';


			# 数値文字参照
			my $msg = $Form->Get('MESSAGE');
			$msg =~ s/(&#\d+)/$1;/g;
			$msg =~ s/(&#\d+;);/$1/g;
			$Form->Set('MESSAGE', $msg);

			# news1 時限ール
			if ( $Sys->Equal('BBS', 'news1') && $Sys->Equal('MODE', 1) ) {
				my $fpath = $Sys->Get('BBSPATH') . '/news1/info/pool-queue.txt';
				if (open(my $fh, '>>', $fpath)) {
					my $bbs = $Form->Get('bbs');
					print $fh "${threadid}\n";
					close($fh);
				}
			}

			# スレ主機能(レス前処理)
			$Threads->SetAttr($threadid, 'sid', 0) if $Sys->Equal('MODE', 1) && $Sys->Get('CAPID', '');
			Nusi16($this, $Sys, $Form, $Threads, $threadid, $session, $bbsSet, $ismobile);

			# BBS_SLIP
			if (!$Sys->Get('CAPID', '')) {
				# 板のBBS_SLIP設定
				my $bbs_slip = $bbsSet->Get('BBS_SLIP');
				# スレのSLIP設定を取得
				my $thslip = $Threads->GetAttr($threadid, 'slip');
				# 名前欄の情報を取得
				my $name = $Form->Get('FROM');
				my $noname = '';
				my $bbs_noname = $bbsSet->Get('BBS_NONAME_NAME');
				my $th_noname = $Threads->GetAttr($threadid, 'noname');
				$noname = $th_noname ? $th_noname : $bbs_noname;
				$name = $noname if $name eq '';

				# SLIPが有効なら実行
				my $absnz = 1 if $session->param($Sys->Get('BBS'));
				if ($bbs_slip =~ /^(?:v{3,6}|verbose)$/ || $thslip =~ /^(?:v{3,6}|verbose)$/ || ($name =~ /!slip:v(?:{3,6}|verbose)/ && !$Threads->GetAttr($threadid, 'ngk')) || $absnz) {
					# BBS_SLIP機能を呼び出し
					my $name = generate_name_field($Sys, $Form, $Threads, $threadid, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $session, $bbs_slip, $thslip, $name, $absnz);
					$Form->Set('FROM', $name);
				}

			# 忍法帖処理
			Ninpocho($Sys, $Form, $Cookie, $Threads, $threadid, $Sec, $session, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $delIP) if $session;
		} else {
			# スレ主機能(レス後処理)
			Nusi32($this, $Sys, $Form, $Threads, $threadid);
		}
	}

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	SLIP生成
#------------------------------------------------------------------------------------------------------------
sub generate_name_field {
    my ($Sys, $Form, $Threads, $threadid, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $session, $bbs_slip, $thslip, $name, $absnz) = @_;

    # BBS_SLIP機能を呼び出し
    my $onedayslip = $bbs_slip !~ /^v{5,6}/ && $thslip !~ /^v{5,6}/ && $name !~ /!slip:v{5,6}/ ? 1 : 0;
    my $res = BBS_SLIP($Sys, $Form, $Threads, $threadid, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $session, $onedayslip);

    my $zero = 1;
    if ($bbs_slip !~ /^v{3,6}/ && $thslip !~ /^v{3,6}/ && $name !~ /!slip:v{3,6}/ && !$absnz) {
        if ($res =~ /^\s(<\/b>\s\(.\)<b>)/) {
            $res = $1;
            $zero = 0;
        } else {
            $res = '';
        }
    } else {
        $zero = 0 if $res =~ /^\s<\/b>\s\(.\)<b>/;
    }

    # 名前欄にワッチョイもどきを追加
    $res =~ s/\s.{4}-.{4}// if $bbs_slip !~ /^v{4,6}/ && $thslip !~ /^v{4,6}/ && $name !~ /!slip:v{4,6}/ && !$absnz && $zero;
    if ($name =~ /!slip:v{3,6}/) {
        $name = $bbs_noname . $1 if $name =~ /^(!slip:v+)$/;
        $name =~ s/!slip:v{3,6}.*/${res}/;
    } else {
        $name = "${name}${res}";
    }

    return $name;
}

#------------------------------------------------------------------------------------------------------------
#	各種判定
#------------------------------------------------------------------------------------------------------------
# 拒否IP
sub is_denied_ip {
    my ($ipAddr, $infoDir) = @_;
    my $denyIP = 0;

    my $denyIP_txt = "$infoDir/denyip.txt";
    if (open(my $fh, "<", $denyIP_txt)) {
        while (my $line = readline $fh) {
            chomp $line;
            if ($ipAddr eq $line) {
                $denyIP = 1;
                last;
            }
        }
        close($fh);
    }

    return $denyIP;
}

# 匿名化判定
sub is_anonymous {
    my ($isFwifi, $country, $remoho, $ipAddr, $infoDir) = @_;
    my $isAnon = 0;

    if (!$isFwifi && $country eq 'JP' && $remoho ne $ipAddr) {
        my @anon_remoho = (
            '^.*\\.(vpngate\\.v4\\.open\\.ad\\.jp|opengw\\.net)$',
            '^.*\\.(?:ablenetvps\\.ne\\.jp|amazonaws\\.com|arena\\.ne\\.jp|akamaitechnologies\\.com|cdn77\\.com|cnode\\.io|datapacket\\.com|digita-vm\\.com|googleusercontent\\.com|hmk-temp\\.com||kagoya\\.net|linodeusercontent\\.com|sakura\\.ne\\.jp|vultrusercontent\\.com|xtom\\.com)$',
            '^.*\\.(?:tsc-soft\\.com|53ja\\.net)$'
        );

        for my $name (@anon_remoho) {
            if ($remoho =~ /(?:${name})/) {
                $isAnon = 1;
                last;
            }
        }
    }

    my $vpngate_ip_txt = "$infoDir/vpngate-ip.txt";
    if (open(my $fh, "<", $vpngate_ip_txt)) {
        while (my $line = readline $fh) {
            chomp $line;
            if ($ipAddr eq $line) {
                $isAnon = 1;
                last;
            }
        }
        close($fh);
    }

    return $isAnon;
}

# 公衆Wifi判定
sub is_public_wifi {
    my ($country, $remoho, $ipAddr) = @_;
    my $isFwifi = '';

    if ($country eq 'JP' && $remoho ne $ipAddr) {
        my @fwifi_remoho = (
            '.*\\.m-zone\\.jp',
            '\\d+\\.wi-fi\\.kddi\\.com',
            '.*\\.wi-fi\\.wi2\\.ne\\.jp',
            '.*\\.ec-userreverse\\.dion\\.ne\\.jp',
            '210\\.227\\.19\\.[67]\\d',
            '222-229-49-202.saitama.fdn.vectant.ne.jp'
        );
        my @fwifi_nicknames = ("mz", "auw", "wi2", "dion", "lson", "vectant");

        my $isFwifi_nickname_idx = 0;
        for my $name (@fwifi_remoho) {
            if ($remoho =~ /^${name}$/) {
                $isFwifi = $fwifi_nicknames[$isFwifi_nickname_idx];
                last;
            }
            $isFwifi_nickname_idx++;
        }
    }

    return $isFwifi;
}

# IPから国を判定
sub get_country_by_ip {
    my ($ipAddr) = @_;
    my $country;

    if ($ipAddr !~ /:/) {
        my $gi_dat = './datas/GeoIPCity.dat';
        if (-f $gi_dat) {
            my $gi = Geo::IP->open($gi_dat, GEOIP_STANDARD) || 0;
            if ($gi) {
                my $record = $gi->record_by_addr($ipAddr);
                $country = $record->country_code if $record;
            }
        }
    } else {
        my $res = whois($ipAddr);  # 'whois'関数の実装が必要
        for my $line (split /\n/, $res) {
            if ($line =~ /country:.*([A-Z]{2})/i) {
                $country = $1;
                last;
            }
        }
    }

    return $country;
}

# モバイル判定
sub is_mobile {
    my ($country, $ipAddr, $remoho, $Form) = @_;

	my $ismobile = '';
	if ($country eq 'JP') {
		# モバイル回線のニックネーム
		my $isSlipName5ch = $Form->Get('bbs') !~ /^(?:news1|unsaku)/ ? 1 : 0;
		my @mobile_nicknames = (
			"om1",
			"om2",
			"om3",
			"om4",
			"pw1",
			"pw2",
			"pw3",
			"pw4",
			"sb",
			"au1",
			"au2",
			"au3",
			"au4",
			"au5",
			"au6",
			"au7",
			"sp1",
			"sp2",
			"sp3",
			"sp4",
			"sp5",
			"sp6",
			"sp7",
			"sp8",
			"pera1",
			"pera2",
			"vm",
			"bm",
			"mineo",
			"one1",
			"one2",
			"ocn1",
			"ocn2",
			"raku1",
			"raku2",
			"uq",
			"mesh",
			"dndn",
			"tone",
			"ame",
			"nif",
			"lib",
			"mkun",
			"lmate",
			"ftel"
			);
		@mobile_nicknames = (
			"オッペケー",
			"オッッペケ",
			"オッペケエ",
			"オッペケケ",
			"ササクッテロラ",
			"ササクッテロリ",
			"ササクッテロル",
			"ササクッテロレ",
			"ハゲ",
			"アウアウアー",
			"アウアウイー",
			"アウアウウー",
			"アウアウエー",
			"アウアウオー",
			"アウアウカー",
			"アウアウケー",
			"スプー",
			"スプッッ",
			"スップ",
			"スッップ",
			"スププ",
			"スフッ",
			"スップー",
			"スププー",
			"ペラペラ",
			"エアペラ",
			"ブーイモ",
			"ベーイモ",
			"オイコラミネオ",
			"ワントンキン",
			"ワンミングク",
			"バットンキン",
			"バッミングク",
			"ラクッペペ",
			"ラクラッペ",
			"アウアウクー",
			"ドコグロ",
			"ドナドナ",
			"トンモー",
			"アメ",
			"ニフモ",
			"リブモ",
			"イルクン",
			"ゲマー",
			"フリッテル"
			) if $isSlipName5ch;
		if ($remoho ne $ipAddr) {
			my @mobile_remoho = (
				'om1260.*\\.openmobile\\.ne\\.jp',
				'om1261.*\\.openmobile\\.ne\\.jp',
				'om1262.*\\.openmobile\\.ne\\.jp',
				'.*\\.openmobile\\.ne\\.jp',
				'pw1260.*\\.panda-world\\.ne\\.jp',
				'pw1261.*\\.panda-world\\.ne\\.jp',
				'pw1262.*\\.panda-world\\.ne\\.jp',
				'.*\\.panda-world\\.ne\\.jp',
				'softbank(?:036|11[14])\\d+\\.bbtec\\.net',
				'KD027.*\\.au-net\\.ne\\.jp',
				'KD036.*\\.au-net\\.ne\\.jp',
				'KD106.*\\.au-net\\.ne\\.jp',
				'KD111.*\\.au-net\\.ne\\.jp',
				'KD119.*\\.au-net\\.ne\\.jp',
				'KD182.*\\.au-net\\.ne\\.jp',
				'K.*\\.au-net\\.ne\\.jp',
				'.*\\.msa\\.spmode\\.ne\\.jp',
				'.*\\.msb\\.spmode\\.ne\\.jp',
				'.*\\.msc\\.spmode\\.ne\\.jp',
				'.*\\.msd\\.spmode\\.ne\\.jp',
				'.*\\.mse\\.spmode\\.ne\\.jp',
				'.*\\.msf\\.spmode\\.ne\\.jp',
				'.*\\.smd\\d+\\.spmode\\.ne\\.jp',
				'.*\\.spmode\\.ne\\.jp',
				'.*\\.fix\\.mopera\\.net',
				'.*\\.air\\.mopera\\.net',
				'.*\\.vmobile\\.jp',
				'.*\\.bmobile\\.ne\\.jp',
				'.*\\.mineo\\.jp',
				'.*omed01\\.tokyo\\.ocn\\.ne\\.jp',
				'.*omed01\\.osaka\\.ocn\\.ne\\.jp',
				'.*mobac01\\.tokyo\\.ocn\\.ne\\.jp',
				'.*mobac01\\.osaka\\.ocn\\.ne\\.jp',
				'.*\\.mvno\\.rakuten\\.jp',
				'pl\\d+\\.mas\\d+\\..*\\.nttpc\\.ne\\.jp',
				'UQ.*au-net\\.ne\\.jp',
				'dcm\\d(?:-\\d+){4}\\.tky\\.mesh\\.ad\\.jp',
				'neoau\\d(?:-\\d+){4}\\.tky\\.mesh\\.ad\\.jp',
				'.*\\.ap\\.dream\\.jp',
				'.*\\.ap\\.mvno\\.net',
				'fenics\\d+\\.wlan\\.ppp\\.infoweb\\.ne\\.jp',
				".*\\.libmo\\.jp"
			);
			if (!$ismobile) {
				my $idx = 0;
				for my $name (@mobile_remoho) {
					if ($remoho =~ /^${name}$/) {
						$ismobile = $mobile_nicknames[$idx];
						last;
					}
					$idx++;
				}
			}
		} else {
			my @rakuten_mno_ip = (
				'101\\.102\\.(?:\\d|[1-5]\\d|6[0-3])\\.\\d{1,3}',
				'103\\.124\\.[0-3]\\.\\d{1,3}',
				'110\\.165\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}',
				'119\\.30\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}',
				'119\\.31\\.1(?:2[89]|[3-5]\\d)\\.\\d{1,3}',
				'133\\.106\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}',
				'133\\.106\\.(?:1[6-9]|2\\d|3[01])\\.\\d{1,3}',
				'133\\.106\\.(?:3[2-9]|[45]\\d|6[0-3])\\.\\d{1,3}',
				'133\\.106\\.(?:6[4-9]|[7-9]\\d|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}',
				'133\\.106\\.(?:[89]|1[0-5])\\.\\d{1,3}',
				'157\\.192(?:\\.\\d{1,3}){2}',
				'193\\.114\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}',
				'193\\.114\\.(?:3[2-9]|[45]\\d|6[0-3])\\.\\d{1,3}',
				'193\\.114\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}',
				'193\\.115\\.(?:\\d|[12]\\d|3[01])\\.\\d{1,3}',
				'193\\.117\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}',
				'193\\.118\\.(?:\\d|[12]\\d|3[01])\\.\\d{1,3}',
				'193\\.118\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}',
				'193\\.119\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}',
				'193\\.82\\.1(?:[6-8]\\d|9[01])\\.\\d{1,3}',
				'194\\.193\\.2(?:2[4-9]|[34]\\d|5[0-5])\\.\\d{1,3}',
				'194\\.193\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}',
				'194\\.223\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}',
				'202\\.176\\.(?:1[6-9]|2\\d|3[01])\\.\\d{1,3}',
				'202\\.216\\.(?:\\d|1[0-5])\\.\\d{1,3}',
				'210\\.157\\.(?:19[2-9]|2(?:[01]\\d|2[0-3]))\\.\\d{1,3}',
				'211\\.133\\.(?:[6-8]\\d|9[01])\\.\\d{1,3}',
				'211\\.7\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}',
				'219\\.105\\.1(?:4[4-9]|5\\d)\\.\\d{1,3}',
				'219\\.105\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}',
				'219\\.106\\.(?:\\d{1,2}|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}'
				);
			if (!$ismobile) {
				for my $name (@rakuten_mno_ip) {
					if ($ipAddr =~ /${name}/) {
						$ismobile = $isSlipName5ch ? 'テテンテンテン' : 'ten';
						last;
					}
				}
			}
			my @mobile_whois = (
				'Plus One marketing',
				'LogicLinks',
				'SORASIM'
				);
			if (!$ismobile) {
				my $res = whois($ipAddr);
				my $idx = 0;
				for my $name (@mobile_whois) {
					$idx--;
					if ($res =~ /.*${name}.*/) {
						$ismobile = $mobile_nicknames[$idx];
						last;
					}
				}
			}
		}
	}

    return $ismobile;
}

#------------------------------------------------------------------------------------------------------------
#	忍法帖セッション取得
#	-------------------------------------------------------------------------------------
sub NinSS
{
	my ($Sys, $Form, $Cookie, $ipAddr, $remoho, $ua, $delIP, $ismobile) = @_;

	# infoディレクトリ
	my $infoDir = $Sys->Get('INFO');

	# CookieからセッションIDを取得
	my $sid = $Cookie->Get('countsession');
	if (!$sid) {
		%cookies = fetch CGI::Cookie;
		if (exists $cookies{'countsession'}) {
			$sid = $cookies{'countsession'}->value;
			$sid =~ s/"//g;
		}
	}

	# 忍法帖データディレクトリを設定
	my $ninDir = ".$infoDir/.nin/";
	mkdir $ninDir if ! -d $ninDir;

	# IPアドレスで引き継ぎ
	my $sidData = '';
	my $ipPath = "${ninDir}ip_${ipAddr}";
	if (!$delIP) {
		if (open(my $fh, "<", $ipPath)) {
			$sidData = <$fh>;
			$sid = $1 if $sidData =~ /([0-9a-f]{32})/;
			close($fh);
		}
		my $ssPath = "${ninDir}cgisess_${sid}";
		$sid = '' if ! -f $ssPath;
		unlink $ipPath if !$sid && -f $ipPath;
	}

	# パスワードで引き継ぎ
	my $ninPass = '';
	my $isSave = 0;
	my $isLoad = 0;
	my $name = $Form->Get('FROM');
	PrintBBSError_Ninja($Sys, 10035) if $name =~ /(?<!#!)(?:save|load|nin):/;
	PrintBBSError_Ninja($Sys, 10035) if $name =~ /#!(?:save|load|nin)(?!:)/;
	my $isFail = 0;
	my $isFail_log = "${ninDir}ISFAIL.log";
	if (open(my $fh, '<', $isFail_log)) {
		$isFail = <$fh>;
		close($fh);
	}
	PrintBBSError_Ninja($Sys, 10044) if $isFail > 100;
	if ($name =~ s/#!((?:save|load):[^#:]*):?//) {
		$Form->Set('FROM', $name);
		my $cmd = $1;
		$isSave = 1 if $cmd =~ /^save:[a-zA-Z0-9_\s\.\-,;()]{6}/;
		$isLoad = 1 if $cmd =~ /^load:[a-zA-Z0-9_\s\.\-,;()]{6}/;
		if ($cmd =~ s/^(?:save|load)://) {
			PrintBBSError_Ninja($Sys, 10002) if $cmd =~ /^(?:.{0,7}|(.{1,5})\1+|.*(?:pas+w[o0]rd|pasuwa|0{4}.*|10+20+30|(?:1|i(?:chi|ti)?|[o0]ne)(?:2|n[i1]|tw[o0])(?:2|san|three)(?:4|y[o0]n|f[o0]ur)|qwer|aiue|akasa|hamaya|abcd|asdf|zxcv|321ewq|1234?abc|abcd?123|un+(?:ch[i1]|ko)|o?(?:(?:t|ch)[i1][nm]){1,2}(?:[kp]o)?|poop|penis|o?manko|pussy|[o0]ppa[i1]|pa[i1]zur[i1]|kur[i1]tor[i1]su|ana(?:l|ru)|se(?:x|kku)|sukatoro|masterba|masutabe|[1i]+(?:4|sh?[i1]|y[o0](?:n+)?|f[o0]ur)(?:5|g[o0]|ko|f[i1]ve)[1i]+(?:4|sh?[i1]|y[o0](?:n+)?|f[o0]ur)|[0o](?:7|na+)(?:2|n[i1]+)[1i]|(?:[1i](?:9|ku)){2,}|(?:abe.{0,5})?sh?[i1]n|abesh?[i1]ne|wa+kuni|yama[gk]am[i1]|yume(?:ch|ty)an|puyuyu|pun[i1]n[i1]|ke[nm]+m[o0]men|bo[uo](?:dan|mo)|bou?(?:da?)n??[guj]|live[guj]|unsaku|news1|sannan|privex|karasawa|krsw|s[o0]nsh?[i1]|k[o0]r[o0]su|k[i1]ll|test|e-?mail|karaage3tar0u).*)$/i;
			$ninPass = "pass_$cmd";
			my $ninPassPath = "${ninDir}${ninPass}";
			if ($isSave) {
				if ($sid && open(my $fh, '>', $ninPassPath)) {
					print $fh $sid;
					close($fh);
				}
				if ($sid && -f $ipPath) {
					open(my $fh, '>', $ipPath);
					print $fh $sid;
					close($fh);
				}
			} elsif ($isLoad) {
				PrintBBSError_Ninja($Sys, 10002) if $remoho =~ /^((?:flh|FL).*\.tky\.mesh\.ad\.jp)$/ && $isFail > 15;
				PrintBBSError_Ninja($Sys, 10002) if $remoho =~ /spmode/ && $isFail > 30;
				if (! -f $ninPassPath) {
					$isFail++;
					PrintBBSError_Ninja($Sys, 10044) if $isFail > 100;
					if (open(my $fh, '>', $isFail_log)) {
						print $fh $isFail;
						close($fh);
					}
					my $isFail_remoho_log = "${ninDir}ISFAIL_remoho.log";
					if (open(my $fh, '>>', $isFail_remoho_log)) {
						print $fh "${remoho}\n${ua}\n${ninPassPath}\n";
						close($fh);
					}
				} else {
					if (open(my $fh, "<", $ninPassPath)) {
						my $data = <$fh>;
						$data =~ s/\n//;
						$sid = $data if $data;
						close($fh);
					}
					$ssPath = "${ninDir}cgisess_${sid}";
					$sid = '' if ! -f $ssPath;
					unlink $ninPassPath if !$sid && -f $ninPassPath;
					if ($sid && -f $ipPath) {
						open(my $fh, '>', $ipPath);
						print $fh $sid;
						close($fh);
					}
					if (open(my $fh, '>', $isFail_log)) {
						print $fh 0;
						close($fh);
					}
				}
			} else {
				PrintBBSError_Ninja($Sys, 10036);
			}
		}
	}
	my $mail = $Form->Get('mail');
	PrintBBSError_Ninja($Sys, 10035) if $mail =~ /(?:save|load):/;
	if ($mail =~ s/nin:([a-zA-Z0-9 \-_.,]{6,})://g) {
		PrintBBSError_Ninja($Sys, 10033);
	}	elsif ($mail =~ s/save:([a-zA-Z0-9 \-_.,]{6,})://g) {
		PrintBBSError_Ninja($Sys, 10035);
	}	elsif ($mail =~ s/load:([a-zA-Z0-9 \-_.,]{6,})://g) {
		PrintBBSError_Ninja($Sys, 10035);
	}	elsif ($mail =~ /(?:nin|save|load):?[a-zA-Z0-9 \-_.,]+(?!:)/) {
		PrintBBSError_Ninja($Sys, 10020, $koyuu);
	}

	# セッションを読み込む
	my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;

	# 日時を取得
	$ENV{'TZ'} = "JST-9";
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);

	# American
	$sid = 'b5ff798ee3ec6a4ae7e2cb3ce931c28b' if $session->param('ninpocho') < 5 &&  $ua =~ /A202ZT/ && $remoho =~ /^.*\.spmode\.ne\.jp$/ && $yday < 260;
	$session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;

	# セッションに環境を記録
	$session->param('previp', $ipAddr);
	if ($remoho ne $ipAddr && $remoho !~ /au-net|spmode|openmobile|panda-world/) {
		my $prevremoho = $remoho;
		$prevremoho =~ s/^.*?[0-9\.\-]+//;
		$prevremoho =~ s/^.*?([0-9a-zA-Z\.\-]+)$/$1/;
		$prevremoho =~ s/^[\.\-]//;
		$session->param('prevremoho', $prevremoho);
	}
	my $prevua = $ua;
	$prevua =~ s/^mo(?:na)?zilla\/[0-9\s\.]+//i;
	$session->param('prevua', $prevua);

	# パスワード確認
	$ninPass =~ s/^pass_//;
	my $ninPass_latest = $session->param('pass') || 0;
	PrintBBSError_Ninja($Sys, 10034, $koyuu) if $isLoad && $ninPass_latest && $ninPass ne $ninPass_latest;
	if ($isSave) {
		$session->param('pass', $ninPass);
		unlink "${ninDir}pass_{$ninPass_latest}";
	}

	# SID取得
	$sid = $session->id();

	# SIDをクッキーに出力
	$Cookie->Set('countsession', $sid);

	# SIDをIpファイルに出力
	if ( !$sidData && !$delIP && open(my $fh, '>', $ipPath) ) {
		print $fh $sid;
		close($fh);
	}


	#タイムスタンプ
	@flst = ("$ssPath", "$ipPath");
	utime time, time, @flst;

	return $session;
}

#------------------------------------------------------------------------------------------------------------
#	BBS_SLIP生成
#------------------------------------------------------------------------------------------------------------
sub BBS_SLIP
{
	my ($Sys, $Form, $Threads, $threadid, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $session, $onedayslip) = @_;
	my ($slip_ip, $slip_remoho, $slip_ua);

	# bbs
	my $bbs = $Sys->Get('BBS');

	# infoディレクトリ
	my $infoDir = $Sys->Get('INFO');

	# 忍法帖ディレクトリ
	my $ninDir = ".$infoDir/.nin/";
	mkdir $ninDir if ! -d $ninDir;

	# bbs_slipに使用する文字
	my @slip_chars = (0..9, 'a'..'z', 'A'..'Z', '.', '/');

	# 日時を取得
	$ENV{'TZ'} = "JST-9";
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);

	# 一週間で文字列変更
	my $fpath = ".$infoDir/slip_change";
	if (! -f $fpath && open(my $fh, '>', $fpath)) {
		my $randnum1 = int(rand 1000000);
		my $randnum2 = int(rand 1000000);
		my $randnum3 = int(rand 1000000);
		my $randnum4 = int(rand 1000000);
		print $fh "$yday:$randnum1:$randnum2:$randnum3:$randnum4";
		close($fh);
	}
	my $data = '';
	if (open(my $fh, "<", $fpath)) {
		$data = <$fh>;
	}
	my $chnum1 = 0;
	my $chnum2 = 0;
	my $chnum3 = 0;
	my $chnum4 = 0;
	if ($data =~ /^(\d+):(\d+):(\d+):(\d+):(\d+)$/) {
		$yday2 = $1;
		$chnum1 = $2;
		$chnum2 = $3;
		$chnum3 = $4;
		$chnum4 = $5;
	}
	if ($yday == $yday2 + 7) {
		if (open(my $fh, '>', $fpath)) {
			my $randnum1 = int(rand 1000000);
			my $randnum2 = int(rand 1000000);
			my $randnum3 = int(rand 1000000);
			my $randnum4 = int(rand 1000000);
			$chnum1 = $randnum1;
			$chnum2 = $randnum2;
			$chnum3 = $randnum3;
			$chnum4 = $randnum4;
			print $fh "$yday:$randnum1:$randnum2:$randnum3:$randnum4";
			close($fh);
		}
	}

	# idを取得
	my $id = $Form->Get('idpart');
	#idの末尾
	my $idEnd = '0';


	#ID
	my $sid = $session->param('_SESSION_ID') || 0;
	my $chid = 0;
	if ($sid) {
		require Digest::SHA::PurePerl;
		my $ctx = Digest::SHA::PurePerl->new;
		$ctx->add('0ch+ ID Generation');
		$ctx->add(':', $Sys->Get('SERVER'));
		$ctx->add(':', $bbs);
		$ctx->add(':', join('-', (localtime)[3,4,5]));
		$ctx->add(':', $sid);
		# chid
		if ( $Threads->GetAttr($threadid, 'chid') && ($Sys->Equal('MODE', 2) || !$Sys->Equal('BBS', 'news1')) ) {
			my $chkey = $Threads->GetAttr($threadid, 'chkey');
			$chid = $chkey ? hex(substr(md5_hex($chkey), 0, 8)) : $threadid;
			$ctx->add(':', $chid);
			$ctx->add(':', int rand(10000)) if $Sys->Equal('MODE', 1) && $Form->Get('MESSAGE') =~ /!hidenusi/;
		}
		$id = $ctx->b64digest;
		$id = 'ID:' . substr($id, 0, 8);
	}
	$chid += $yday ** 2 + 14 if $onedayslip;

	# slip_ip生成
	my $fo = '';
	my $so = '';
	$ipAddr =~ /^(\d{1,4})\.(\d{1,4})/;
	$fo = $1 + $chnum1 + $chid;
	$so = $2 + $chnum2 + $chid;

	my $ip_char1 = $slip_chars[$fo % 64];
	my $ip_char2 = $slip_chars[$so % 64];
	$slip_ip = $remoho =~ /^KD.*au-net\.ne\.jp$/ ? $ip_char1 . $ip_char1 : $ip_char1 . $ip_char2;

	# slip_remoho生成
	$remoho =~ /^.*?[.\d\-]([^.\d\-].+\.[a-z]{2,})$/;
	my $remoho_name = $1;
	my $remoho_dig = md5_hex($remoho_name);
	$remoho_dig =~ /^(.{4})(.{4})/;
	my $remoho_char1 = $slip_chars[(hex($1) + ($mon + $year) ** 2 + $chid) % 64];
	my $remoho_char2 = $slip_chars[(hex($2) + ($mon + $year) ** 2 + $chid) % 64];
	$slip_remoho = $remoho_char1 . $remoho_char2;

	# slip_ua生成
	my $ua_dig = md5_hex($ua);
	$ua_dig =~ /^(.{4})(.{4})(.{4})(.{4})/;
	my $ua_char1 = $slip_chars[(hex($1) + $chnum3 + $chid) % 64];
	my $ua_char2 = $slip_chars[(hex($2) + $chnum1 + $chnum2 + $chid) % 64];
	my $ua_char3 = $slip_chars[(hex($3) + $chnum4 + $chid) % 64];
	my $ua_char4 = $slip_chars[(hex($4) + $chnum3 + $chnum4 + $chid) % 64];
	$slip_ua = $ua_char1 . $ua_char2 . $ua_char3 . $ua_char4;

	# スマホ・タブレット判定
	my $fixed_nickname_end = '';
	my $mobile_nickname_end = '';
	if ($ua =~ /.*(iphone|ipad|android|mobile).*/i) {
		$fixed_nickname_end = 'W';
		$mobile_nickname_end = 'M';
	}else {
		$mobile_nickname_end = 'T';
	}

	# 公衆判定
	$fixed_nickname_end .= '[公衆]' if $isFwifi;

	# bbs_slipの初期設定
	my $slip_id = '';
	my $slip_nickname = "ワ${fixed_nickname_end}";
	my $slip_aa = $slip_ip;
	my $slip_bb = $slip_remoho;
	my $slip_cccc = $slip_ua;

	# 特殊回線のリモホ
	my @special_remoho = (
		'.*\\.ac\\.jp',
    '.*\\.ed\\.jp',
    '.*\\.(?:co\\.jp|com)',
    '.*\\.go\\.jp'
		);
	# 特殊回線のニックネーム
	my @special_nicknames = (
		"大学${fixed_nickname_end}",
    "学校${fixed_nickname_end}",
    "会社${fixed_nickname_end}",
    "役所${fixed_nickname_end}"
		);
	my @special_idEnd = (
		'6',
		'7',
		'C',
		'G'
	);

	# 逆引き判定
	if (!$slip_remoho || $ipAddr eq $remoho) { # 逆引きできない場合
		my $unknown = 1;

		# モバイル回線判定
		if ($unknown && $ismobile) {
			$slip_id = 'MM';
			$idEnd = substr($slip_id, -1, 1);
			$slip_nickname = "${ismobile}${mobile_nickname_end}";
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
			$unknown = 0;
		}
		if ($unknown && $ua =~ /DoCoMo\//) { #ガラケー
			$slip_id = 'KK';
			$idEnd = substr($slip_id, -1, 1);
			$slip_nickname = "fph${mobile_nickname_end}";
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
			$unknown = 0;
		}

		# 国を判定
		if ($unknown && $country) {
			$idEnd = 'H';
			$slip_nickname = "${country}${fixed_nickname_end}";
			$slip_aa = $country;
			$slip_bb = $slip_ip;
			$unknown = 0;
		}

		# 逆引き不可能
		if ($unknown) {
			$slip_id = 'hh';
			$idEnd = 'h';
			$slip_nickname = "unk${fixed_nickname_end}";
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
		}

	} else { # 逆引きできる場合
		my $remoho_checked = 0;

		# 国を判定
		if (!$remoho_checked && $country && $country ne 'JP') {
			$idEnd = 'H';
			$slip_nickname = "${country}${fixed_nickname_end}";
			$slip_aa = $country;
			$slip_bb = $slip_ip;
			$remoho_checked = 1;
		}

		# 匿名判定
		if (!$remoho_checked && $isAnon) {
			$idEnd = '8';
			$slip_nickname = $Sys->Get('BBS') =~ /^live/ ? 'コンニチハ' : 'anon';	
			$slip_nickname .= $fixed_nickname_end;
			$remoho_checked = 1;
		}

		# モバイル回線判定
		if (!$remoho_checked && $ismobile) {
				# モバイル回線のslip_id
				$slip_id = 'MM';
				$slip_id = 'Sr' if $ismobile =~ /^(?:om|オッ|sb|ハゲ)/;
				$slip_id = 'Sp' if $ismobile =~ /^(?:pw|ササ)/;
				$slip_id = 'Sa' if $ismobile =~ /^(?:au|アウアウ)/;
				$slip_id = 'Sd' if $ismobile =~ /^(?:sp|ス)/;
				$slip_id = 'SD' if $ismobile =~ /pera|ペラ/;
				$idEnd = substr($slip_id, -1, 1);
				$slip_nickname = "${ismobile}${mobile_nickname_end}";
				$slip_aa = $slip_id;
				$slip_bb = $slip_ip;
				$remoho_checked = 1;
		}

		# 公衆判定
		if (!$remoho_checked && $isFwifi) {
			$slip_nickname = "${isFwifi}${fixed_nickname_end}";
			$slip_id = 'FF';
			$idEnd = substr($slip_id, -1, 1);
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
			$remoho_checked = 1;
		}

		# 特殊回線判定
		if (!$remoho_checked) {
			my $special_idx = 0;
			for my $name (@special_remoho) {
				if ($remoho =~ /^(?:${name})$/) {
					$idEnd = $special_idEnd[$special_idx];
					$slip_nickname = $special_nicknames[$special_idx];
					$remoho_checked = 1;
					last;
				}
				$special_idx++;
			}
		}
	}

	# noid
	$noid = $Threads->GetAttr($threadid, 'noid') || 0;
	$noid = 1 if $bbs eq 'noid';
	#idを設定
	$id = $Form->Set('idpart', $id) if !$noid;

	# bbs_slipを生成
	my $kaisen = $idEnd ne '0' && !$noid ? " </b> ($idEnd)<b>" : '';
	my $slip_result = "$kaisen </b>(${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc})<b>";

	return $slip_result;
}

#------------------------------------------------------------------------------------------------------------
#	忍法帖機能
#------------------------------------------------------------------------------------------------------------
sub Ninpocho
{
	my ($Sys, $Form, $Cookie, $Threads, $threadid, $Sec, $session, $bbsSet, $ipAddr, $remoho, $ua, $country, $ismobile, $isFwifi, $isAnon, $delIP) = @_;

	# セッションID
	my $sid = $session->param('_SESSION_ID') || 0;

	# infoディレクトリ
	my $infoDir = $Sys->Get('INFO');

	# 忍法帖データディレクトリを設定
	my $ninDir = ".$infoDir/.nin/";
	mkdir $ninDir if ! -d $ninDir;
	my $idDir	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/id/';
	mkdir $idDir if ! -d $idDir;

	# レベル関係
	my $ninlv = $session->param('ninpocho') || 0;
	my $exp = $session->param('count') || 0;
	my $time = $session->param('time') || 0;
	my $gold = $session->param('gold') || 1;
	my $lvUpCnt = 0;

	# キャップ情報
	my $capID = $Sys->Get('CAPID', '');

	#書き込んだ日時を取得
	$ENV{'TZ'} = "JST-9";
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);

	# フォーム情報
	my $name = $Form->Get('FROM');
	my $msg = $Form->Get('MESSAGE');
	my $mail = $Form->Get('mail');
	my $bbs = $Sys->Get('BBS');
	my $id = $Form->Get('idpart');

	# スレタイ取得
	my $tt = $Form->Get('subject');
	$tt = $Threads->Get('SUBJECT', $threadid) if $tt eq '';

	# id 
	my $noid = $Threads->GetAttr($threadid, 'noid') || 0;
	$noid = 1 if $bbs eq 'noid';
	my $chid = $Threads->GetAttr($threadid, 'chid') || 0;
	my $hidenusi = $Threads->GetAttr($threadid, 'hidenusi');

	# newmode
	my $newmode = $Threads->GetAttr($threadid, 'new') || 0;
	$newmode = 1 if $bbs eq 'livejupiter' || $bbs eq 'hinan';
	$newmode = 1 if $tt =~ /\s\[新\]/;

	# スレ主判定
	my $isowner = 0;
	if ($Sys->Equal('MODE', 1) && !$capID) {
		# スレ主の忍法帖IDを記録
		$Threads->SetAttr($threadid, 'sid', $sid);
		$isowner = 1;
		$Threads->SaveAttr($Sys);
	} else {
		my $ownerSID = $Threads->GetAttr($threadid, 'sid');
		my $sid = $session->param('_SESSION_ID') || 0;
		my $isSub = $Threads->GetAttr($threadid, "sub-$sid") || 0;
		if ($sid eq $ownerSID || $isSub) {
			$isowner = 1;
			my $nusimark = !$isSub ? '主' : '副';
			if (!$noid && !$hidenusi && !$capID) {
				$name .= " </b> ($nusimark)<b>";
				$Form->Set('FROM', $name);
			}
		}
	}

	# koyuu
	my $koyuu = $Sys->Get('KOYUU');

	# tairyo
	my $tairyoCnt = $session->param('tairyo') || 0;

	# bbslim
	my $bbslim = $session->param($bbs) || 0;

	# 認証
	my $auth = $session->param('auth') || 0;

	# ninnum
	my $ninnum = '0000';

	# slip
	my $bbs_slip = '';
	my $thslip = '';


	# 規制処理
	if (!$capID) {
		my $limlv = 0;

		# BANメッセージ
		if ($ninlv < 0) {
			PrintBBSError_Ninja($Sys, 10007, $koyuu);
		}

		# 時限BAN
		$banTm = $session->param('bantm');
		if (time() < $banTm) {
			PrintBBSError_Ninja($Sys, 10011, $koyuu);
		}

		# 違反数BAN
		if ($ninlv < 15) {
			if ($tairyoCnt > 10) {
				$ninlv = $ninlv ? 1 : 0;
				$session->param('ninpocho', $ninlv);
				$session->param('time', time() + 82800);
			}
			if ($tairyoCnt > 20) {
				$session->param('ninpocho', -1);
				my $ban = "${ninDir}BAN.log";
				if (open(my $fh, '>>', $ban)) {
					print $fh "${ipAddr}(${remoho})\n${msg}\n";
					close($fh);
				}
				PrintBBSError_Ninja($Sys, 10007, $koyuu);
			}
		}

		# 板ごとの規制
		if ($bbslim =~ /^([0-3])-([1-9]\d+)(:[^:]*)?/) {
			my $bbslim_lv = $1;
			my $bbslim_tm = $2;
			my $kote_extra = $3 ? "'$3' " : '';
			# 規制レベル1以上は強制コテ
			if ($bbslim_lv > 0 && time() < $bbslim_tm) {
				# noabe
				PrintBBSError_Ninja($Sys, 10026, $koyuu) if $Threads->GetAttr($threadid, 'noabe') && !$isowner;
				# noid・chid無効
				$noid = 0;
				$chid = 0;
				# 強制コテ
				my $bbs_noname = $bbsSet->Get('BBS_NONAME_NAME');
				$bbs_noname =~ s/(\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
				$name =~ s/${bbs_noname}//;
				my $absnz = $bbslim_lv == 1 ? "'警告ユーザ'＠アフィ転載禁止 " : "''警告ユーザ''＠アフィ転載禁止 ";
				$absnz = $bbslim_lv == 1 ? "'安倍晋三'＠アフィ転載禁止 " : "''安倍晋三''＠アフィ転載禁止 " if $bbs =~ /^(?:news1|kuso|abeshinzo|livetulip)$/;
				$kote_extra =~ s/HTT/\x8b\x67\x93\x63\x8f\x72\x8d\xc6/;
				my $kote = $kote_extra . $absnz;
				$name = $kote . $name;
				# 規制レベル1
				if ($Sys->Equal('MODE', 1) && $bbslim_lv == 1) {
					# スレ属性を強制sageに
					$Threads->SetAttr($threadid, 'sagemode', 1);
					# レスに設定メッセージを追加
					$msg .= "<hr><font color='red'>※! sage ! kisei</font>";
					$Form->Set('MESSAGE', $msg);
					# スレ主が解除できないように
					$Threads->SetAttr($threadid, 'capsage', 1);
					# スレの属性を設定し保存
					$Threads->SaveAttr($Sys);
					# スレタイ
					$tt = "[↓] " . $tt;
					$Form->Set('subject', $tt);
				}
				my $limDay = ($bbslim_tm - time()) / 86400;
				$limDay =~ s/\.(\d)\d+/\.$1/;
				# 規制レベル2
				PrintBBSError_Ninja($Sys, 10003, $koyuu, $limDay) if $Sys->Equal('MODE', 1) && $bbslim_lv == 2;
				# 規制レベル3
				PrintBBSError_Ninja($Sys, 10009, $koyuu, $limDay) if $bbslim_lv == 3;
			} else {
				$session->param($bbs, 0);
				$bbslim = 0;
			}
		}

		# proxycheckCnt
		my $proxycheckCnt = 0;
		my $proxycheckCnt_log = ".$infoDir/proxycheckCnt.log";
		if (open(my $fh, "<", $proxycheckCnt_log)) {
			$proxycheckCnt = <$fh>;
			close($fh);
		}

		# badIP
		my $badIP = $session->param('badip') || 0;
		my $previsbadip = $badIP;
		my $prevremoho = $session->param('prevremoho');
		$badIP = 1 if $country ne 'JP' || $isAnon || $isFwifi | ($remoho eq $ipAddr && !$ismobile && !$prevremoho);

		# livemode
		my $livemode = $Threads->GetAttr($threadid, 'live') || 0;
		$livemode = 1 if $bbs =~ /^live(?:jupiter|hell)/;
		$livemode = 1 if $tt =~ /\s\[実\]/;

		# 認証
		my $authTm = $session->param('authTm') || 0;
		if (!$authTm) {
			$authTm = time();
			$session->param('authTm', $authTm);
		}
		$auth = 0 if time() > $authTm + 864000;
		my $captcha = ( ( ( ($bbsSet->Get('BBS_CAPTCHA') eq 'checked' || ( $Threads->GetAttr($threadid, 'auth')) || $tt =~ /\s\[認\]/ ) && $ninlv < 15 ) || $Sys->Equal('BBS', 'auth') || ( ( !$exp || ($exp && !$ninlv && !$bbslim) ) && (!$badIP && !$isFwifi && !$ismobile && $proxycheckCnt > 60) ) ) && !$newmode ) ? 1 : 0;
		if ($captcha) {
			my $authDir = ".$infoDir/.auth/";
			mkdir $authDir if ! -d $authDir;
			my $authID;
			my $ua = "$ENV{'HTTP_USER_AGENT'}";
			if ($ua =~ /^Mozilla\/\d\.\d\s\(Windows\sNT\s\d{2}\.\d;\sTrident\/\d\.\d;\srv:\d{2}.\d\)\slike\sGecko|monazilla/i) {
				$authID = md5_hex($remoho);
			} else {
				$authID = $Cookie->Get('authid');
				if (!$authID) {
					%cookies = fetch CGI::Cookie;
					if (exists $cookies{'authid'}) {
						$authID = $cookies{'authid'}->value;
						if ($authID) {
							$authID =~ s/"//g if $authID;
						} else {
							$authID = md5_hex($remoho);
						}
					}
				}
			}
			$authPath = "${authDir}${authID}";
			my $reward = $ninlv;
			if (!$auth) {
				if (-f $authPath) {
					$auth = 1;
					$session->param('auth', $auth);
					$authTm = time();
					$session->param('authTm', $authTm);
					$gold += $reward;
				} elsif ($Sys->Equal('MODE', 1) || ($Sys->Equal('MODE', 2) && !$isowner)) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					PrintBBSError_Ninja($Sys, 10016, $koyuu);
				}
			} elsif ($bbs ne 'exp1' && $ninlv < 15) {
				my $authCnt = 0;
				if ($livemode) {
					$authCnt = $session->param('authCntL') || 0;
				} else {
					$authCnt = $session->param('authCnt') || 0;
				}
				$authCnt++;
				my $checkCnt = $ninlv ? 20 : 6;
				$checkCnt *= 2 if $ninlv >= 2;
				$checkCnt *= 2 if $ninlv >= 5;
				$checkCnt *= 4 if $livemode;
				if (($authCnt > $checkCnt) || ($ninlv == 0 && $tairyoCnt > 3)) {
					unlink $authPath if -f $authPath;
					$auth = 0;
					$session->param('auth', $auth);
					$session->param('authCnt', 0);
					$session->param('authCntL', 0);
					$gold -= $reward;
				} else {
					if ($livemode) {
						$session->param('authCntL', $authCnt);
					} else {
						$session->param('authCnt', $authCnt);
					}
				}
			}
		}
		$session->param('auth', $auth);

		# proxycheck
		my $previp = $session->param('previp') || '';
		my $checkKey = '';
		if ( ( !$exp || ($ninlv < 5 && $delIP && $ipAddr ne $previp) ) && (!$ismobile && !$badIP && !$isFwifi && !$bbslim) ) {
			my $url = "http://proxycheck.io/v2/${ipAddr}?key=${checkKey}";
			my $ua = LWP::UserAgent->new();
			my $response = $ua->post($url);
			if ( $response->is_success() ) {
				my $json = $response->decoded_content();
				my $out = decode_json($json);
				my $isProxy = $out->{$ipAddr}->{"proxy"};
				if ($isProxy eq 'yes') {
					$badIP = 1;
				} elsif (!$ninlv && $delIP) {
					$ninlv = 1;
				}
				$proxycheckCnt++;
				if (open(my $fh, ">", $proxycheckCnt_log)) {
					print $fh $proxycheckCnt;
					close($fh);
				}
			} else {
				PrintBBSError_Ninja($Sys, 10022, $koyuu) if !$auth && !$newmode;
			}
		}

		# 匿名化規制
		$ninlv = 0 if $badIP && !$previsbadip && $ninlv < 5;
		$session->param('badip', $badIP) if $badIP;
		$limlv = 1;
		if ( $ninlv < $limlv && $badIP && $bbs ne 'auth') {
			PrintBBSError_Ninja($Sys, 10019, $koyuu, $limlv);
		}

		# NG回避対策
		$limlv = 15;
		PrintBBSError_Ninja($Sys, 10051, $koyuu, $limlv) if $ninlv < $limlv && !$isowner && !$newmode && $Threads->GetAttr($threadid, 'gobi') !~ /!rmj/ && $msg =~ /!rmj/ && $bbs ne 'exp1';
		PrintBBSError_Ninja($Sys, 10052, $koyuu, $limlv) if $ninlv < $limlv && $msg =~ /&#8238;/ && $bbs ne 'exp1';

		# coincheck
		if ($ninlv < 2 && $msg =~ /ttp.*coincheck.*inv/i) {
			$session->param('ninpocho', -1);
			PrintBBSError_Ninja($Sys, 10007, $koyuu);
		}

		# 有害ネームド追放
		# fax
		my $fax = $session->param('fax') || 0;
		$fax = 1 if $ua !~ /^mo(?:na)?zilla/i;
		$fax = 1 if $ua =~ /JaneStyle_Android|(?:Live5ch|2chMate).*Edg\/\d+|BingSapphire/i;
		$fax = 1 if $name =~ /MivqMJ8\/oTPh/;
		$fax = 1 if $remoho =~ /vps/;
		$limlv = 0;
		if ( ($limlv && $ninlv < $limlv ) || $badIP ) {
			my $isMultipleAnker = 1 if $msg =~ /(?:(?:&gt|&#(?:0*62|x0*3e));){2}(?:[1-9]|&#(?:0*(?:49|5[0-7])|x0*3[1-9]);)(?:(?:[0-9]|&#(?:0*4[89]|0*5[0-7]|x0*3\d);)*(?:-|&#(?:0*4[45]|x0*2c))(?:[1-9]|&#(?:0*49|0*5[0-7]|x0*3[1-9]);)|(?:.*?(?:(?:&gt|&#(?:0*62|x0*3e));){2}(?:[1-9]|&#(?:0*(?:49|5[0-7])|x0*3[1-9]);)){3})/i;
			my $isFaxRegex = 1 if $msg =~ /(?:f|&#(?:(?:0*(?:70|102))|x0*[46]6);)([\.\/]|(?:\s|&#(?:0*(?:32|12288)|x0*(?:20|3000));)+)(?:a|&#(?:0*(?:65|97)|x0*[46]1))$1(?:x|&#(?:0*(?:88|120)|x0*[57]8))/i;
			my $isImg = 1 if $msg =~ /(?:(?:n|&#(?:0*(?:110|78)|x0*[46]e);)(?:i|&#(?:0*105|x0*69);)(?:c|&#(?:0*99|x0*63);)(?:o|&#(?:0*111|x0*6f);)(?:(?:v|&#(?:0*118|x0*76);)(?:i|&#(?:0*105|x0*69);)(?:d|&#(?:0*100|x0*64);)(?:e|&#(?:0*101|x0*65);)(?:o|&#(?:0*111|x0*6f);))?(?:\.|&#(0*46|x0*2e))|(?:y|&#(?:0*121|x0*79);)(?:o|&#(?:0*111|x0*6f);)(?:u|&#(?:0*117|x0*75);)(?:t|&#(?:0*116|x0*74);)(?:u|&#(?:0*117|x0*75);)(?:(?:b|&#(?:0*98|x0*62);)(?:e|&#(?:0*101|x0*65);))?(?:\.|&#(0*46|x0*2e))|(?:t|&#(?:0*116|x0*74);)(?:w|&#(?:0*119|x0*77);)(?:i|&#(?:0*105|x0*69);)(?:m|&#(?:0*109|x0*6d);)(?:g|&#(?:0*103|x0*67);)(?:\.|&#(0*46|x0*2e);)|(?:i|&#(?:0*105|x0*69);)(?:m|&#(?:0*109|x0*6d);)(?:g|&#(?:0*103|x0*67);)(?:u|&#(?:0*117|x0*75);)(?:r|&#(?:0*114|x0*72);)(?:\.|&#(0*46|x0*2e);)|(?:\.|&#(?:0*46|x0*2e);)(?:(?:j|&#(?:0*(?:106|74)|x0*[46]a);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:e|&#(?:0*(?:101|69)|x0*[46]5);)?(?:g|&#(?:0*(?:103|71)|x0*[46]7);)|(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:n|&#(?:0*(?:110|78)|x0*[46]e);)(?:g|&#(?:0*(?:103|71)|x0*[46]7);)|(?:g|&#(?:0*(?:103|71)|x0*[46]7);)(?:i|&#(?:0*(?:105|73)|x0*[46]9);)(?:f|&#(?:0*(?:102|70)|x0*[46]6);)|(?:w|&#(?:0*(?:119|87)|x0*[57]7);)(?:e|&#(?:0*(?:101|69)|x0*[46]5);)(?:b|&#(?:0*(?:98|66)|x0*[46]2);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)|(?:m|&#(?:0*109|x0*6d);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:4|&#(?:0*52|x0*34);)))/i;
			if ($delIP && $ninlv < $limlv && !$newmode) {
				my $ctlv2 = $bbsSet->Get('BBS_CTLV2') || 0;
				PrintBBSError_Ninja($Sys, 10001, $koyuu, $limlv) if $Sys->Equal('MODE', 1) && $ctlv2 && $ninlv < $ctlv2;
				my $nonew = $Threads->GetAttr($threadid, 'nonew') || 0;
				PrintBBSError_Ninja($Sys, 10046, $koyuu, $limlv) if $nonew;
				my $kote = '';
				$kote = "'新規biglobe'@転載禁止" if $remoho =~ /^(?:flh|FL).*\.mesh\.ad\.jp$/;
				$kote = "'新規transix'@転載禁止" if $remoho =~ /^.*\.shared\.user\.transix\.jp$/;
				$kote = "'新規enabler'@転載禁止" if $remoho =~ /^.*\.v4\.enabler\.ne\.jp$/;
				if ($kote) {
					my $bbs_noname = $bbsSet->Get('BBS_NONAME_NAME');
					$bbs_noname =~ s/(\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
					$name =~ s/${bbs_noname}//;
				}
			}
			my $checkstr = $Sys->Equal('MODE', 1) ? $tt : $msg;
			my $isHiho = 1 if $checkstr =~ /(?:【|&#(?:0*12304|x0*3010)).*(?:悲|&#(?:0*24754|x0*60[bB]2)).*(?:報|&#(?:0*22577|x0*5831))/i;
			my $isShogeki = 1 if $checkstr =~ /(?:【|&#(?:0*12304|x0*3010)).*(?:衝|&#(?:0*34909|x0*885d)).*(?:撃|&#(?:0*25731|x0*6483))/i;
			my $isBakusho = 1 if $checkstr =~ /(?:【|&#(?:0*12304|x0*3010)).*(?:爆|&#(?:0*29190|x0*7206)).*(?:笑|&#(?:0*31505|x0*7b11))/i;
			my $isKusa = 1 if $checkstr =~ /(し|&#(0*12375|x0*3057);)(?:(?:て|&#(?:0*12390|x0*3066);)\1)?(?:ま|&#(?:0*12414|x0*307e);)(?:う|&#(?:0*12358|x0*3046);)(?:(?:w|ｗ|W|v|ｖ|y|ｙ)|&#(0*(?:119|65367|87|118|65366|121|65369)|x0*(?:77|ff57|57|76|ff56|79|ff59));)/i;
			my $isAfi = 1 if $isHiho || $isShogeki || $isBakusho || $isKusa;
			$fax = 1 if ( $isMultipleAnker && ($isFaxRegex || $isAfi) ) || ($isFaxRegex && ($isImg || $isAfi) );
			$fax = 1 if $isAfi && !$isHiho && $Sys->Equal('MODE', 1) && $bbs ne 'livegalileo';
			$fax = 1 if $msg =~ /FAX氏|ノレカス|鼻ゴミ/;
			$fax = 1 if $isMultipleAnker && $isImg && !$newmode && $ninlv < 5;
			if ($ninlv < 3 && !$newmode) {
				my $faxcnt = $session->param('faxcnt') || 0;
				$faxcnt++ if $msg =~ /だな(?:w|ｗ|W|v|ｖ|y|ｙ){4}/;
				$session->param('faxcnt', $faxcnt) || 0;
				$fax = 1 if $faxcnt >= 3;
			}
		}
		$limlv = 0;
		if ($limlv && $ninlv < $limlv) {
			PrintBBSError_Ninja($Sys, 10048, $koyuu) if $ua =~ /CriOS/;
			PrintBBSError_Ninja($Sys, 10048, $koyuu) if $delIP && $ua =~ /Jane|Live5ch|Windows|Android\s[1-7](?!\d)|^Mozilla/;
			my $danger = 0;
			$danger = 1 if $ua =~ /iPhone\sOS\s1[0-5]|Mac\sOS\sX\s10/ && $remoho =~ /^KD106\d+\.au-net\.ne\.jp$/;
			$danger = 1 if $ua =~ /Mac\sOS\sX\s10/ && $remoho =~ /^(?:(?:flh|FL).*\.tky\.mesh\.ad\.jp|.*\.spmode\.ne\.jp)$/ && $bbs eq 'livegalileo';
			$danger = 1 if $ua =~ /Mac\sOS\sX\s10|iPad|X11|SC-02K|SC51Aa|SH-51A|Mozilla.*Android\s10\;K/ && $remoho =~ /^(?:(?:flh|FL).*\.tky\.mesh\.ad\.jp|.*\.spmode\.ne\.jp)$/ && $bbs eq 'unsaku';
			if ($danger && $newmode && $ninlv == -1) {
				$ninlv = 0;
				my $lvsec = 108000;
				$time = time() + $lvsec;
				$session->param('time', $time);
			}
			$fax = 1 if $danger && !$newmode;
		}
		if ($fax) {
			$session->param('ninpocho', -1);
			my $logPath = ".$infoDir/FAX.log";
			if (open(my $fh, '>>', $logPath)) {
				my $post_title = $Sys->Equal('MODE', 1) ? $tt : '';
				print $fh "${ipAddr}(${remoho})\n${ua}\n${sid}\nninlv:${ninlv}\n${post_title}\n${msg}\n";
			PrintBBSError_Ninja($Sys, 10007, $koyuu);
			}
		}

		# zachan
		if ($ninlv < 5 && $bbs eq 'livegalileo' && $livemode && $hour =~ /^(?:2[0-3]|[0-5])$/) {
			my $zachan = 0;
			$zachan = 1 if $remoho =~ /^(KD111.*au-net\.ne\.jp|.*spmode\.ne\.jp)$/ && ($ua =~ /d-02H|SO-41B|SCG13|SH-53C/i || $msg =~ /声豚.*死ね|バンドリ(?:ガイジ|豚)/);
			if ($zachan) {
				$session->param('ninpocho', -1);
				my $logPath = ".$infoDir/Zachan.log";
				if (open(my $fh, '>>', $logPath)) {
					my $post_title = $Sys->Equal('MODE', 1) ? $tt : '';
					print $fh "${ipAddr}(${remoho})\n${ua}\n${sid}\nninlv:${ninlv}\n${post_title}\n${msg}\n";
					close($fh);
				}
				PrintBBSError_Ninja($Sys, 10007, $koyuu);
			}
			PrintBBSError_Ninja($Sys, 10048, $koyuu) if $remoho =~ /^(KD111.*au-net\.ne\.jp|.*spmode\.ne\.jp)$/ && $ua =~ /Windows\sNT\s10|Jane|Live5ch|Mozilla.*Android/i;
		}

		# Orca
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 10 && $remoho =~ /dion\.ne\.jp/ && $ua =~ /SOG03|X11/i && $bbs eq 'livegalileo';

		#zaq
		# PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 1 && $remoho =~ /\.spmode\.ne\.jp/ && $ua =~ /2chMate.*Android\s13.*SO-53C/ && $bbs eq 'livegalileo';
		# PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 2 && $remoho =~ /\.rev\.zaq\.ne\.jp/ && $ua =~ /2chMate.*Android\s13.*SO-53C/ && $bbs eq 'livegalileo';

		# kintama 
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 3 && $remoho =~ /mobac01\.(?:tokyo|osaka)\.ocn\.ne\.jp|v4\.enabler\.ne\.jp/ && $ua =~ /MAR-LX2J/ && $bbs eq 'livegalileo';

		# game sp kisei-kaihi
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 5 && $remoho =~ /spmode\.ne\.jp/ && $ua =~ /PHK110|HT-01/i && $bbs eq 'game';

		# game GR2-30 スタレ
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 5 && $ismobile eq 'テテンテンテン' && $ua =~ /2201116SR/ && $bbs eq 'game';

		# game 静岡
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 5 && ($ismobile eq 'テテンテンテン' || $remoho =~ /tubecm00.ap.so-net.ne.jp/) && $ua =~ /SM-G973C/ && $bbs eq 'game';

		#game モコ爺
		#PrintBBSError_Ninja($Sys, 10007, $koyuu) if $ninlv < 10 && $remoho =~ /hkd\.mesh\.ad\.jp|spmode\.ne\.jp/ && $ua =~ /SO-52B|Android\s12/ && ($bbs eq 'game' || $bbs eq 'unsaku');

		# envban
		if ($ninlv < 3) {
			my $envban = 0;
			my $envban_txt = $Sys->Get('BBSPATH') . '/caps/envban.txt';
			if (open(my $fh, "<", $envban_txt)) {
				while(my $line = readline $fh){ 
					chomp $line;
					if ($line =~ /([^:]+):([^:]+):([^:]+)/) {
						my $target_remoho = $1;
						$target_remoho =~ s/\./\\./g;
						my $target_ua = $2;
						my $target_bbs = $3;
						$remoho_match = $remoho =~ /${target_remoho}/ ? 1 : 0;
						$remoho_match = 1 if $target_remoho eq 'TETEN' && ($ismobile eq 'テテンテンテン' | $ismobile eq 'ten');
						$envban = 1 if $remoho_match && $ua =~ /${target_ua}/ && ($bbs eq $target_bbs || $target_bbs eq 'ALL');
						last if $envban;
					}
				}
				close($fh);
			}
			PrintBBSError_Ninja($Sys, 10007, $koyuu) if $envban;
		}

		# 忍法帖の新規発行処理
		if (!$exp && $ninlv < 2) {
			# Lv0タイム
			my $lvsec = $badIP ? 144000 : 600;
			$time = time() + $lvsec;
			$session->param('time', $time);
			# 経験値を1に
			$exp = 1;
			$session->param('count', $exp);
			# グループ
			$session->param('group', "$year-$yday-$hour");
		}

		# NinID
		if ($sid) {
			my $sid_hex = md5_hex($sid);
			# 週ごとにNinIDを変更
			my $weekID = $session->param('weekid') || $sid_hex;
			my $fpath = ".$infoDir/slip_change";
			my $data = '';
			if (open(my $fh, "<", $fpath)) {
				$data = <$fh>;
				close($fh);
			}
			my $chnum = $weekID;
			my $yday2 = 0;
			if ($data =~ /^(\d+):(\d+):(\d+):(\d+):(\d+)$/) {
				$yday2 = $1;
				$chnum = $2;
			}
			if ($weekID != $chnum) {
				$session->param('weekid', $chnum);
				$weekID = $chnum;
			}
			my $weekID_hex = md5_hex($sid_hex . $weekID);
			$ninnum = $1 if $weekID_hex =~ /^(.{6})/;
		}
		$session->param('ninid', "$ninnum");

		# 低レベル制限が有効か確認
		my $bbslll = $bbsSet->Get('BBS_LLL') || '';

		# スレ立て制限
		if ($Sys->Equal('MODE', 1)) {

			# Lvがctlv未満の場合はエラー
			my $ctlv = $bbsSet->Get('BBS_CTLV') || 0;
			PrintBBSError_Ninja($Sys, 10001, $koyuu, $ctlv) if $ctlv && $ninlv < $ctlv;
			my $ctlv2 = $bbsSet->Get('BBS_CTLV2') || 0;
			PrintBBSError_Ninja($Sys, 10001, $koyuu, $ctlv) if $ctlv2 && $ninlv < $ctlv2 && $ismobile;

			# 数値文字参照制限
			PrintBBSError_Ninja($Sys, 10032, $koyuu) if $ninlv < 5 && $tt =~ /(?:.*?&#(?:\d+|[xX][0-9a-fA-F]+)){10}/;

			# rmj制限
			PrintBBSError_Ninja($Sys, 10051, $koyuu) if $ninlv < 15 && $msg =~ /!rmj/;

			# 連続スレ立て制限
			if ($bbslll eq 'checked') {
				my $prevCT	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/ninja-prevCT.cgi';
				if (! -f $prevCT) {
					open(my $fh, '>', $prevCT);
					close($fh);
				}
				my $data = '';
				if (open(my $fh, "<", $prevCT)) {
					$data = <$fh>;
					close($fh);
				}
				if ($data !~ /^$ninnum/ && open(my $fh, '>', $prevCT)) {
					print $fh "$ninnum:1";
					close($fh);
				} else {
					my $limCnt = 1;
					my $ninCnt = $1 if $ninnum && $data =~ /^${ninnum}:(\d+)/;
					my $limLv = 9;
					if ($ninlv <= $limLv && $ninCnt > $limCnt) {
						$tairyoCnt++;
						$session->param('tairyo', $tairyoCnt);
						$session->param('auth', 0);
						$gold -= $ninlv;
						$gold = 1 if $gold < 1;
						$session->param('gold', $gold);
						PrintBBSError_Ninja($Sys, 10017, $koyuu, $limLv);
					} else {
						$ninCnt++;
						if (open(my $fh, '>', $prevCT)) {
							print $fh "$ninnum:$ninCnt";
							close($fh);
						}
					}
				}
			}

			#スレ立て間隔
			if ($ninlv < 15) {
				my $lastCT = $session->param('lastct') || 0;
				# 制限時間(分)
				my $limMin = $ninlv < 5 ? 10 : 3;

				if (time() < $lastCT) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$session->param('auth', 0);
					$gold -= $ninlv;
					$gold = 1 if $gold < 1;
					$session->param('gold', $gold);
					PrintBBSError_Ninja($Sys, 10013, $koyuu, $limMin);
				} else {
					$session->param('lastct', time() + $limMin * 60);
				}
			}

			# TATESUGI
			if ($ninnum) {
				my $tatesugiLog	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/ninja-tatesugi.cgi';
				my $tateClose = $bbsSet->Get('BBS_THREAD_TATESUGI', '0');
				my $tateCount2 = $bbsSet->Get('BBS_TATESUGI_COUNT2', '0');
				my $data = '';
				if (open(my $fh, "<", $tatesugiLog)) {
					# flock($fh, 2);
					$data = <$fh>;
					close($fh);
				}
				$data .= ":$ninnum";
				$tateCount2++ if $tateCount2;
				my $limLv = 10;
				if ($ninlv <= $limLv && $tateClose && $tateCount2 && $data =~ /^(?:.*?:${ninnum}){$tateCount2}.*$/) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					PrintBBSError($Sys, 500);
				}
				if ($ninnum && open(my $fh, '>', $tatesugiLog)) {
					# flock($fh, 2);
					$data =~ s/^(?::[^:]+)+((?::[^:]+){$tateClose})$/$1/;
					print $fh $data;
					close($fh);
				}
			}

			# 低レベル制限
			if ($bbslll eq 'checked') {
				my $limLv = 4;
				my $limCnt = 2;
				my $limLvDataPath	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/ninja-ct-lll.cgi';
				my $limLvCnt = 0;
				if (open(my $fh, "<", $limLvDataPath)) {
					# flock($fh, 2);
					$limLvCnt = <$fh>;
					close($fh);
				}
				$limLvCnt = $ninlv > $limLv + 1 ? 0 : $limLvCnt + 1;
				if ($ninlv <= $limLv && $limLvCnt > $limCnt) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					PrintBBSError_Ninja($Sys, 10012, $koyuu, $limLv);
				} else {
					if (open(my $fh, '>', $limLvDataPath)) {
						# flock($fh, 2);
						print $fh $limLvCnt;
						close($fh);
					}
				}
			}

			# ゴールド消費
			if ($bbs !~ /^(?:exp|kuso|livejupiter|news)/) {
				my $ctCnt = $session->param('ct') || 0;
				$ctCnt++;
				my $freeCnt = $ninlv < 15 ? $ninlv : 24;
				$freeCnt = int($freeCnt / 2) if $bbslim;
				$freeCnt = 1 if !$freeCnt;
				if ($ctCnt > $freeCnt) {
					$cost = 100 * ($ctCnt - $freeCnt) ** ($ctCnt - $freeCnt);
					$gold -= $cost;
					PrintBBSError_Ninja($Sys, 10040, $koyuu) if $gold < 1 && !$capID;
				}
				$session->param('ct', $ctCnt);
			}

			# news1スレ立て報酬
			if ($bbs eq 'news1') {
				my $rndnum = int(rand 100);
				my $reward = $rndnum % 10 == 0 ? 30 : 3;
				$reward = 300 if $rndnum == 3;
				$gold += $reward if $msg !~ /!pool/;
			}

		} else {

			# tulip
			PrintBBSError_Ninja($Sys, 10004, $koyuu, 40) if $ninlv < 40 && $bbs eq 'livetulip';

			# for global board
			PrintBBSError_Ninja($Sys, 10042, $koyuu) if $bbs eq 'global' && ($msg =~ /\x82[\x9f-\xf1]|\x83[\x40-\x96]/ || $name =~ /\x82[\x9f-\xf1]|\x83[\x40-\x96]/ || $mail =~ /[\x82-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc]/);
			
			# news1 tulip
			$gold -= 30 if $bbs eq 'news1' && $isowner && $msg =~ /!pool/;

			# 数値文字参照・リンク制限
			if ($ninlv < 10 && $bbslll eq 'checked' && !$isowner && !$newmode) {
				my $isSansho = 1 if $msg =~ /(?:.*?&#(?:\d+|[xX][0-9a-fA-F]+)){10}/;
				my $isImg = 1 if $msg =~ /(?:\.|&#(?:0*46|[xX]0*2[eE]);)(?:(?:[jJ]|&#(?:0*(?:106|74)|[xX]0*[46][aA]);)(?:[pP]|&#(?:0*(?:112|80)|[xX]0*[57]0);)(?:[eE]|&#(?:0*(?:101|69)|[xX]0*[46]5);)?(?:[gG]|&#(?:0*(?:103|71)|[xX]0*[46]7))|(?:[pP]|&#(?:0*(?:112|80)|[xX]0*[57]0);)(?:[nN]|&#(?:0*(?:110|78)|[xX]0*[46][eE]);)(?:[gG]|&#(?:0*(?:103|71)|[xX]0*[46]7))|(?:[gG]|&#(?:0*(?:103|71)|[xX]0*[46]7);)(?:[iI]|&#(?:0*(?:105|73)|[xX]0*[46]9);)(?:[fF]|&#(?:0*(?:102|70)|[xX]0*[46]6))|(?:[wW]|&#(?:0*(?:119|87)|[xX]0*[57]7);)(?:[eE]|&#(?:0*(?:101|69)|[xX]0*[46]5);)(?:[bB]|&#(?:0*(?:98|66)|[xX]0*[46]2);)(?:[pP]|&#(?:0*(?:112|80)|[xX]0*[57]0)))/;
				my $isLink = 1 if $msg =~ /(?:t|&#(?:0*116|[xX]74);){2}(?:p|&#(?:0*112|[xX]0*70);)(?:s|&#(?:0*115|[xX]0*73);)?(?::|&#(?:0*58|[xX]3[aA]))/ && $msg !~ /sannan\.nl/;
				if ($isSansho) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					PrintBBSError_Ninja($Sys, 10032, $koyuu);
				}
				PrintBBSError_Ninja($Sys, 10031, $koyuu) if $ninlv < 3 && $isImg;
				PrintBBSError_Ninja($Sys, 10027, $koyuu) if $ninlv < 2 && $isLink;
				if ($isSansho && ($isImg || $isLink) && $ninlv < 5) {
					$session->param('ninpocho', -1);
					my $logPath = "${ninDir}sansho.log";
					if (open(my $fh, '>>', $logPath)) {
						print $fh "${ipAddr}(${remoho})\n${msg}\n";
						close($fh);
					}
					PrintBBSError_Ninja($Sys, 10007, $koyuu);
				}
			}

			# 改行・文字数制限
			if ($ninlv < 15 && !$isowner && !$newmode) {
				$msg =~ s/&#0*10;|&#x0*[aA];//g;
				$Form->Set('MESSAGE', $msg);
				require './module/data_utils.pl';
				$conv = DATA_UTILS;
				my ($ln, $cl) = $conv->GetTextInfo(\$msg);
				my $lnlim = $ninlv ?  10 : 5;
				$lnlim = 15 if $ninlv >= 2;
				$lnlim = 25 if $ninlv >= 5;
				$lnlim = 50 if $ninlv >= 10;
				my $lenlim = $ninlv ? 512 : 256;
				$lenlim = 1024 if $ninlv > 2;
				$lenlim = 2048 if $ninlv > 5;
				$lenlim = 4096 if $ninlv > 10;
				PrintBBSError_Ninja($Sys, 10005, $koyuu) if $ln > $lnlim || length($msg) > $lenlim;
			}

			#連投規制
			if ($ninlv < 15 && !$isowner && !$livemode) {
				my $Set = $Sys->Get('SET');
				my $tm = 0;
				my $nintm = $ninlv ? 30 : 60;
				$nintm = 20 if $ninlv >= 2;
				$nintm = 10 if $ninlv >= 5;
				$nintm = int($nintm / 2) if $bbs =~/^live/;
				my $Holdtm = int($Sys->Get('SMB') + $nintm);
				require './module/manager_log.pl';
				my $Log = MANAGER_LOG->new;
				$Log->Load($Sys, 'HST');
				$tm = $Log->IsTime($Holdtm, $koyuu);
				$Log->Set($Set, $Sys->Get('KEY'), $Sys->Get('VERSION'), $koyuu);
				$Log->Save($Sys);
				if ($tm > 0) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$session->param('auth', 0);
					$gold -= $ninlv;
					$gold = 1 if $gold < 1;
					$session->param('gold', $gold);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					$Sys->Set('WAIT', $tm);
					PrintBBSError($Sys, 503);
				}
			}

			# ゴンタクレ
			if ($ninnum && !$isowner && !$livemode) {
				my $gntkrLog	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/ninja-gntkr.cgi';
				my $timecount = $bbsSet->Get('timecount', '0');
				my $timeclose = $bbsSet->Get('timeclose', '0');
				my $data = '';
				if (open(my $fh, "<", $gntkrLog)) {
					# flock($fh, 2);
					$data = <$fh>;
					close($fh);
				}
				$data .= ":$ninnum";
				$timeclose++ if $timeclose;
				my $limLv = 10;
				if ($ninlv <= $limLv && $timecount && $timeclose && $data =~ /^(?:.*?:${ninnum}){$timeclose}.*$/) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					PrintBBSError($Sys, 501);
				}
				if ($ninnum && open(my $fh, '>', $gntkrLog)) {
					# flock($fh, 2);
					$data =~ s/^(?::[^:]+)+((?::[^:]+){$timecount})$/$1/;
					print $fh $data;
					close($fh);
				}
			}

			# 低レベルの連続投稿を制限（スレッド）
			if ($bbslll eq 'checked' && !$newmode) {
				my $limLvCnt = int $Threads->GetAttr($threadid, 'limlvcnt') || 0;
				my $limLv = 1;
				my $limCnt = 20;
				$limCnt *= 2 if $ninlv;
				$limCnt *= 2 if $livemode;
				$limLvCnt = ($ninlv > $limLv + 1 || $isowner) ? 0 : $limLvCnt + 1;
				if ($ninlv <= $limLv && $limLvCnt > $limCnt && !$auth) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					PrintBBSError_Ninja($Sys, 10010, $koyuu, $limLv);
				}
				$Threads->SetAttr($threadid, 'limlvcnt', $limLvCnt) if $Threads->GetAttr($threadid, 'limlvcnt');
				$Threads->SaveAttr($Sys);
			}

			# 短時間の投稿回数
			if ($ninlv < 15 && !$isowner && !$newmode) {
				my $minLimitTime = $session->param('min_limit_time') || 0;
				if (time() < $minLimitTime) {
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$ninlv = $ninlv < 1 ? 0 : $ninlv - 1;
					$session->param('ninpocho', $ninlv);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					PrintBBSError_Ninja($Sys, 10014, $koyuu, $minLimitTime - time());
				}
				my $minLimit = $ninlv ? 15 : 6;
				$minLimit = 22 if $ninlv >= 2;
				$minLimit = 30 if $ninlv >= 4;
				$minLimit = 60 if $ninlv >= 5;
				my $minCntTm = $session->param('min_cnt_time') || 0;
				if (!$minCntTm) {
					$minCntTm = time() + 1800;
					$session->param('min_cnt_time', $minCntTm);
				}
				if (time() < $minCntTm) {
					my $minCnt = $session->param('min_cnt') || 0;
					$minCnt++;
					if ($minCnt > $minLimit) {
						$tairyoCnt++;
						$session->param('tairyo', $tairyoCnt);
						$session->param('auth', 0);
						$gold -= $ninlv;
						$gold = 1 if $gold < 1;
						$session->param('gold', $gold);
						$session->param('min_limit_time', $minCntTm - time());
						PrintBBSError_Ninja($Sys, 10014, $koyuu, $minCntTm - time());
					}
					$session->param('min_cnt', $minCnt);
				} else {
					$session->param('min_cnt', 1);
					$session->param('min_cnt_time', time() + 1800);
				}
			}

			# マルチポスト制限
			if ($ninlv < 15 && !$isowner && !$livemode) {
				my $mpCnt = $session->param('mp') || 0;
				my $banCnt = 4;
				$banCnt = $ninlv * 2 if $ninlv >= 5;
				if ($mpCnt > $banCnt) {
					$session->param('ninpocho', -1);
					my $logPath = "${ninDir}MP.log";
					if (open(my $fh, '>>', $logPath)) {
						print $fh "${ninnum}\n${ipAddr}(${remoho})\n${msg}\n";
						close($fh);
					}
					PrintBBSError_Ninja($Sys, 10007, $koyuu);
				}
				my $prevmsg = $session->param('prevmsg') || '';
				my $startIdx = length($msg) >= 90 ? 30 : 0;
				my $currentmsg = substr($msg, $startIdx, 30);
				$currentmsg =~ s/\s|　|&#(?:0*(?:32|12288)|[xX]0*(?:20|3000));|//g;
				$currentmsg =~ s/<br>|&#0*10(?![0-9])|&#x0*[aA](?![0-9a-fA-F])//g;
				$currentmsg =~ s/[,_;\.\/\-]|&#(?:0*46|[xX]0*2[eE]);//g;
				$currentmsg = md5_hex($currentmsg);
				if ($currentmsg eq $prevmsg) {
					$mpCnt++;
					$session->param('mp', $mpCnt);
					$tairyoCnt++;
					$session->param('tairyo', $tairyoCnt);
					$exp = $exp < 6 ? 1 : $exp - 5;
					$session->param('count', $exp);
					PrintBBSError_Ninja($Sys, 10028, $koyuu);
				}
				$session->param('prevmsg', $currentmsg);
			}

		}

		#alert
		$alert = $session->param('alert') || 0;
		if ($alert) {
			$session->param('alert', 0);
			PrintBBSError_Ninja($Sys, 10038);
		}

	}

	# レベルアップ
	if ($capID) {
		$ninlv = 100 if $ninlv < 100;
		$gold = 1000 if $gold < 1000;
	} else {
		my $islvup = 0;
		my $lvsec = $ninlv ? 10800 : 3600;
		if ($ninlv < 4) {
			if ($exp >= 2 && time() >= $time) {
				$islvup = 1;
			}
		} else {
			$lvUpCnt = int( ($ninlv / 2) * (int(($ninlv + 1) / 100) ** 2 + 1) );
			if (time() >= $time && $exp >= $lvUpCnt && $auth) {
				$islvup = 1;
				$lvsec = 82800;
			}
		}
		if ($islvup) {
			$ninlv++;
			$exp = 0;
			$lvsec *= int(($ninlv + 1) / 100) ** 2 + 1 if $ninlv >= 99;
			$time = time() + $lvsec;
			my $lvdn = $session->param('lvdn') || 0;
			my $amount = 1 + 0.25 * int($ninlv / 10) + 5 * int($ninlv / 100);
			if (!$lvdn && !$bbslim) {
				$amount += $ninlv / 2 if $ninlv % 10 == 0;
				$amount += $ninlv * 10 if $ninlv % 100 == 0;
			}
			if ($ninlv % 100 == 0 && $lvdn) {
				$lvdn--;
				$session->param('lvdn', $lvdn);
			}
			$gold += $amount;
		}
	}

	# スレ主ID
	my $benum = $session->param('be') || '';
	if ($Sys->Equal('MODE', 1) && $benum !~ /[0-9a-zA-Z.\/]{4}/) {
		my @beChars = (0..9, 'a'..'z', 'A'..'Z', '.', '/');
		$benum = $beChars[int(rand 64)] . $beChars[int(rand 64)] . $beChars[int(rand 64)] . $beChars[int(rand 64)];
		$session->param('be', "$benum");
	}

	if (!$capID) {

		# id -> sid
		if ($id =~ /^ID:/) {
			my $idPath;
			if ($id =~ /^ID:(?:\?){3}-(\d+)$/) {
				my $time_id = $1;
				$idPath = $idDir . "NOID-${time_id}";
			} elsif ($id =~ /^ID:.{8}$/) {
				$idPath = $idDir . md5_hex($id);
			}
			if (! -f $idPath && open(my $fh, '>', $idPath)) {
				print $fh $sid;
				close($fh);
			}
		}
		if ($ninnum) {
			my $ninidDir = "${ninDir}id";
			if (! -d $ninidDir) {
				mkdir $ninidDir;
			}
			my $idPath = "${ninidDir}/${ninnum}";
			if (! -f $idPath && open(my $fh, '>', $idPath)) {
				print $fh $sid;
				close($fh);
			}
		}
		if ($benum) {
			my $benumDir = "${ninDir}id";
			if (! -d $benumDir) {
				mkdir $benumDir;
			}
			my $idPath = "${benumDir}/${benum}";
			if (! -f $idPath && open(my $fh, '>', $idPath)) {
				print $fh $sid;
				close($fh);
			}
		}

	}

	# アイコン
	if ($msg ne "" ) {
		my @icoNames = (
			'001.gif'
			#ファイル名のリスト
		);
		my $icoIdx = 0;
		my $length = @icoNames;
		if ($sid =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-z]{2})/) {
			my $num = hex($1) * hex($2);
			$icoIdx = $num % $length;
		}
		my $ico = $icoNames[$icoIdx];
		my $sico = $session->param('ico') || '';
		$ico = $sico if $sico;
		if ($name =~ /!ico:([^!]+?):/) {
			if ($noid) {
				$name =~ s/!ico:([^!]+?)://;
				$Form->Set('FROM', $name);
			} elsif ($1 eq 'RANDOM') {
				$ico = 'RANDOM';
			} elsif (grep { $_ eq "$1.gif" } @icoNames) {
				$ico = "$1.gif";
			}
			$session->param('ico', $ico);
		}
		$ico = $icoNames[int rand($length)] if $ico eq 'RANDOM';
		if (!$noid && (($Sys->Equal('MODE', 1) && $bbs eq 'news1') || $name =~ /!ico/)) {
			$msg = "sssp://img.5ch.net/ico/$ico<br>" . $msg;
			$Form->Set('MESSAGE', $msg);
		}
	}

	# pay
	my $thpaycnt = $Threads->GetAttr($threadid, 'pay') || 0;
	my $unlockthrow = $Threads->GetAttr($threadid, 'unlockthrow') || ( ($isowner || $capID) && $msg =~ /!unlockthrow/ ) || $thpaycnt > 300 ? 1 : 0;
	if ($msg =~ /!(?:pay|send|throw)/ && $name !~ /!nocmd/) {
		my $isSuccess = 0;
		my $isLim = 0;
		$thpaycnt++;
		PrintBBSError_Ninja($Sys, 10037, $koyuu) if $Threads->GetAttr($threadid, 'nopoop') && !$isowner;
		my @ary = split /<br>/, $msg;
		for my $cmd (@ary) {
			last if $isLim;
			if ($cmd =~ /!(?:pay|send|throw):([1-9]\d*(?:\.\d?[1-9])?|0\.\d?[1-9]):((?:[a-f0-9]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+)(?:,(?:[a-f0-9]{6}|ID:.{8}|ID:(?:\?){3}-\d+))*)/) {
				my $minlv = 10;
				if ($ninlv < $minlv) {
					$msg .= "<hr><font color='red'>【失敗】レベルが足りません。(${minlv}必要。)</font>";
					$Form->Set('MESSAGE', $msg);
					last;
				}
				my $mingold = 10;
				if ($gold < $mingold) {
					$msg .= "<hr><font color='red'>【失敗】最低${mingold}g所持してないと使用できません。</font>";
					$Form->Set('MESSAGE', $msg);
					last;
				}
				my $cost = $1;
				my $mincost = 0.1;
				if ($cost < $mincost) {
					$msg .= "<hr><font color='red'>最低${mincost}g以上を指定してください</font>";
					$Form->Set('MESSAGE', $msg);
					last;
				}
				my @payids = split /,/, $2;
				for my $payid (@payids) {
					$cost = $gold - 1 if $cost > $gold - 1;
					my $sendSID = '';
					my $idPath = '';
					if ($payid =~ /^ID:(?:\?){3}-(\d+)$/) {
						my $time_id = $1;
						$idPath = $idDir . "NOID-${time_id}";
					} elsif ($payid =~ /^ID:.{8}$/) {
						$idPath = $idDir . md5_hex($payid);
					} else {
						$idPath = "${ninDir}id/$payid";
					}
					if (open(my $fh, '<', $idPath)) {
						$sendSID = <$fh>;
						$sendSID =~ s/\n//g;
						close($fh);
					}
					PrintBBSError_Ninja($Sys, 10029, $koyuu) if !$sendSID;
					if ($sendSID && $sid ne $sendSID) {
						if ($thpaycnt > 500) {
							$thpaycnt = 0;
							$Threads->SetAttr($threadid, 'unlocksend', 0);
							$Threads->SetAttr($threadid, 'unlockthrow', 0);
							$Threads->SaveAttr($Sys);
						}
						my $unlocksend = $Threads->GetAttr($threadid, 'unlocksend') || $unlockthrow || ( ($isowner || $capID) && $msg =~ /!unlocksend/ ) ? 1 : 0;
						if ($thpaycnt > 10 && !$unlocksend && $bbs ne 'livejupiter' && $bbs ne 'livetulip') {
							$msg .= "<hr><font color='red'>【失敗】このスレでの上限に達しました。スレ主は、&#33;unlocksendで上限を無効にできます。(100g消費します。）</font>";
							$Form->Set('MESSAGE', $msg);
							$isLim = 1;
							last;
						}
						$isSuccess = 1;
						$gold -= $cost;
						my $sendSS = CGI::Session->new('driver:file;serializer:default', $sendSID, { Directory => $ninDir }) || 0;
						my $sendSS_ninlv = $sendSS->param('ninlv') || 0;
						my $sendSS_gold = $sendSS->param('gold') || 1;
						$sendSS->param('gold', $sendSS_gold + $cost);
						my $sendmsg = !$unlockthrow ? "${cost}&#x1f337;を送りました。" : "&#x1f4a9;を${cost}g投げつけました。";
						$msg .= "<hr><font color='red'>★${payid}に${sendmsg}</font>";
						$Form->Set('MESSAGE', $msg);
						my $logPath = "${ninDir}pay.log";
						if (open(my $fh, '>>', $logPath)) {
							my $datPath = $Sys->Get('DATPATH');
							print $fh "lv${ninlv}:${cost}G:${ipAddr}(${remoho}):$datPath\n";
							close($fh);
						}
					}
				}
			}
		}
		if ($isSuccess) {
			$Threads->SetAttr($threadid, 'pay', $thpaycnt);
			$Threads->SaveAttr($Sys);
		}
	}
	my $goldName = $unlockthrow ? '宿便' : 'チューリップ';

	#dcnt
	if ($name =~ /!dcnt:([a-zA-Z]+)(:[1-9]\d{0,3})?/) {
		my $dcnt_name = $1;
		my $today = time() - $hour * 3600 - $min * 60 - $sec;
		my $startDay = $session->param("DCNT:STARTDAY:$dcnt_name") || $today;
		my $startOption = $2 ? $2 : 0;
		if ($startOption) {
			$startOption =~ s/^://;
			$startDay = $today - 3600 * 24 * ($startOption - 1);
		}
		my $dcnt = 1 + int(($today - $startDay) / 86400); 
		$session->param("DCNT:$dcnt_name", $dcnt);
		$session->param("DCNT:STARTDAY:$dcnt_name", $startDay);
		$name =~ s|!dcnt:[a-zA-Z]+(?::[1-9]\d*)?|</b>【$dcnt日目】<b>|g;
	}

	if (!$capID) {
		$bbs_slip = $bbsSet->Get('BBS_SLIP') || '';
		$thslip = $Threads->GetAttr($threadid, 'slip') || '';

		# 忍法帖IDを名前欄に追加
		if ( ( ($bbs_slip =~ /v{5,6}/ || $thslip =~ /v{5,6}/ || ( ($bbs_slip =~ /v{3,6}/ || $thslip =~ /v{3,6}/) && $noid && $Sys->Equal('MODE', 2) ) ) && ( !$chid || $Sys->Equal('MODE', 1) ) ) || $bbslim ) {
			# 表示レベル
			my $lvnum = $ninlv < 20 ? "L${ninlv}-" : '';
			# noidの場合
			if ($noid && $Sys->Equal('MODE', 2)) {
				my $newnum = $1 if $ninnum =~ /^([0-9a-f]{6})/;
				$newnum = md5_hex($newnum . $threadid . $year . $yday . $hour);
				$newnum = $1 if $newnum =~ /^([0-9a-f]{4})/;
				#安倍晋三ガチャ
				my $abegacha = $bbs =~ /^(?:news1|exp1|kuso|abeshinzo|livetulip|auth)$/ ? 1 : 0;
				if ($mon == 6 && $mday == 8 && $hour =~ /^1[147]$/ && $abegacha) {
					my $hjhCnt = $session->param('hjh') || 0;
					$session->param('hjh', 1);
					$newnum = '0123' if $newnum =~ /^01/ && !$hjhCnt;
					$newnum = '456f' if $newnum =~ /^45/ && !$hjhCnt;
				}
				my $islucky = $abegacha && ($newnum eq '0123' || $newnum eq '456f') ? 1 : 0;
				$islucky = 1 if $bbs eq 'vip' && ($newnum eq '0121' || $newnum eq '3444');
				my $prize = $bbs ne 'vip' ? 7814 : 20000;
				$gold += $prize if !$session->param('lucky') && $ninlv > 5 && $islucky;
				$session->param('lucky', 1) if $islucky;
				$newnum =~ s|0|　|g if $bbs eq 'vip';
				$newnum =~ s|1|＾|g if $bbs eq 'vip';
				$newnum =~ s|2|ω|g if $bbs eq 'vip';
				$newnum =~ s|3|⊂|g if $bbs eq 'vip';
				$newnum =~ s|4|二|g if $bbs eq 'vip';
				$newnum =~ s|5|´|g if $bbs eq 'vip';
				$newnum =~ s|6|`|g if $bbs eq 'vip';
				$newnum =~ s|7|・|g if $bbs eq 'vip';
				$newnum =~ s|8|∀|g if $bbs eq 'vip';
				$newnum =~ s|9|д|g if $bbs eq 'vip';
				$newnum =~ s|a|＜|g if $bbs eq 'vip';
				$newnum =~ s|b|＞|g if $bbs eq 'vip';
				$newnum =~ s|c|゜|g if $bbs eq 'vip';
				$newnum =~ s|d|‾|g if $bbs eq 'vip';
				$newnum =~ s|e|＿|g if $bbs eq 'vip';
				$newnum =~ s|f|⊃|g if $bbs eq 'vip';
				$newnum =~ s|⊂二二二|⊂二二二（　＾ω＾）二⊃ブーン| if $bbs eq 'vip';
				$newnum =~ s|0|安|g if $abegacha;
				$newnum =~ s|1|倍|g if $abegacha;
				$newnum =~ s|2|晋|g if $abegacha;
				$newnum =~ s|3|三|g if $abegacha;
				$newnum =~ s|4|紫|g if $abegacha;
				$newnum =~ s|5|雲|g if $abegacha;
				$newnum =~ s|6|院|g if $abegacha;
				$newnum =~ s|7|政|g if $abegacha;
				$newnum =~ s|8|誉|g if $abegacha;
				$newnum =~ s|9|清|g if $abegacha;
				$newnum =~ s|a|浄|g if $abegacha;
				$newnum =~ s|b|寿|g if $abegacha;
				$newnum =~ s|c|大|g if $abegacha;
				$newnum =~ s|d|居|g if $abegacha;
				$newnum =~ s|e|士|g if $abegacha;
				$newnum =~ s|f|殿|g if $abegacha;
				$newnum =~ s|紫雲院殿|紫雲院殿政誉清浄晋寿大居士| if $abegacha;
				$lvnum = $ninlv < 3 ? "L${ninlv}-" : '';
				$newnum = "($newnum)" if $bbs eq 'vip' && !$islucky && $lvnum;
				$name =~ s|\([^(]+\)<b>$|(${lvnum}${newnum})<b>|;
			} else {
				my $isAuth = $auth ? ' 認' : '';
				$name =~ s|(\([^(]+\)<b>)$|(${lvnum}${ninnum}${isAuth})<b></b> $1|;
			}
		}

		# 低レベル表示
		if ( $bbs_slip !~ /^v{5,6}$/ && $thslip !~ /^v{5,6}$/ && $ninlv < 5 && ( !$noid || ($noid && !$newmode) ) ) {
			my $bbs_noname = $bbsSet->Get('BBS_NONAME_NAME');
			my $th_noname = $Threads->GetAttr($threadid, 'noname');
			my $noname = $th_noname ? $th_noname : $bbs_noname;
			$name = $noname if !$name;
			$name .= " </b>(L${ninlv})</b>";
		}

		# 名前欄書き換え
		$name =~ s/\x94\x45\x96\x40\x92\x9f|\x83\x60\x83\x85(?:\x81\x5b|\x88\xea)\x83\x8a\x83\x62\x83\x76/\x88\xc0\x94\x7b\x90\x57\x8e\x4f/g;
		$name =~ s/【|】//g;
		$name =~ s|!ninja|</b>【忍法帖Lv.$ninlv】<b>|g;
		$name =~ s|!tt|</b>【$tt】<b>|g;
		if ($Form->Contain('FROM','!exp') || $Form->Contain('FROM','!total')) {
			my $nokoriSec = $time - time();
			$nokoriSec = 0 if $nokoriSec < 0;
			my $nokoriMin = int($nokoriSec / 60);
			my $lvupmsg = $auth || $ninlv < 4 ?  "あと約${nokoriMin}分でLvUP" : '認証切れなのでLvUP不可';
			$name =~ s/!(?:total|exp)/<\/b>【経験値:${exp}\/${lvUpCnt}(LvUP必要値) ${lvupmsg}】<b>/;
		}
		$name =~ s|!ninid|</b>【忍法帖ID:${ninnum}】<b>|g;
		$name =~ s|!nusi|</b>【主ID:${benum}】<b>|g;
		$name =~ s|!(?:gold\|tulip\|unchi\|poop)|</b>【${goldName}:${gold}g】<b>|g;
		if ($name =~ /!ctcnt/) {
			my $ctCnt = $session->param('ct') || 0;
			my $chidCnt = $session->param('chid') || 0;
			my $nashiCnt = $session->param('nashi') || 0;
			$name =~ s|!ctcnt|</b>【今日のスレ立てカウント:${ctCnt} (独:${chidCnt}/梨:${nashiCnt})】<b>|;
		}
		if ($name =~ /!npcnt/ && $bbs =~ /^(?:live(?:galileo|tulip)|exp1)$/) {
			my $np1 = $session->param('np1') || 0;
			my $np2 = $session->param('np2') || 0;
			my $npHour = $session->param('npH') || 0;
			$name =~ s|!npcnt|</b>【NOPOOL数 通常:${np1}/主:${np2}/一日:${npHour}】<b>|;
		}
		if ($name =~ /!bad/) {
			my $isbad = $session->param('badip');
			$isbad = 'NO' if !defined $isbad;
			$name =~ s|!bad|</b>【bad:${isbad}】<b>|;
		}
		if ($name =~ /!absnz/ && ($bbs eq 'unsaku') ) {
			my $ban = $session->param('ban');
			my $absnz = $session->param('absnz');
			my $lvdn = $session->param('lvdn');
			$ban = 'NO' if !defined $ban;
			$absnz = 'NO' if !defined $absnz;
			$lvdn = 'NO' if !defined $lvdn;
			$name =~ s|!absnz|</b>【ban:${ban} absnz:${absnz} lvdn:${lvdn}】<b>|;
		}
		$Form->Set('FROM', $name);

		# 通報
		if ( $bbs eq 'unsaku' && $Threads->GetAttr($threadid, 'report') ) {
			my $rprtCnt = $session->param('rprt') || 0;
			$rprtCnt++;
			$limCnt = 2 + int($ninlv / 20);
			PrintBBSError_Ninja($Sys, 10056, $koyuu) if $rprtCnt > $limCnt;
			$session->param('rprt', $rprtCnt);
			if ($msg =~ /livegalileo/) {
				$gold -= 50;
				PrintBBSError_Ninja($Sys, 10041, $koyuu) if $gold < 1;
			}
		}

		# 特殊スレのスレタイ変更
		if ($msg =~ /!chtt(?!(?:\s|　)*<br>)(.+)/ && $Sys->Equal('MODE', 2) && $ninlv >= 2 && ($threadid eq '1670697629' || $threadid eq '1666969581')) {
			# 新しいスレタイ
			my $newtt = $1;
			$newtt =~ s/<(br|hr)>.*//g;
			$newtt =~ s/&#0*10(?![0-9])|&#x0*[aA](?![0-9a-fA-F])//g;
			$newtt =~ s/^(?:\s|　)+//;
			$newtt = 'SNS・動画ソース雑談 ─ ' . $newtt if $threadid eq '1670697629';
			$newtt = 'タイムマシン速報 ─ ' . $newtt if $threadid eq '1666969581';
			my $sjbCnt = $bbsSet->Get('BBS_SUBJECT_COUNT', '0');
			$newtt = substr($newtt, 0, $sjbCnt) if length($newtt) > $sbjCnt;
			# 板のsubject.txt
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>).+(?=\s\(\d+\))|$newtt|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $datPath = "$bbspath/dat/$threadid.dat";
			# 日時
			my @week = qw/日 月 火 水 木 金 土/;
			my $time = sprintf("%04d/%02d/%02d(${week[$wday]}) %02d:%02d:%02d", $year + 1900, $mon +1, $mday, $hour, $min, $sec);
			# datを書き換え
			my $datData = '';
			if (open(my $fh, '<', $datPath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s|(<>)(?!.*<>).+|$1$newtt|;
				$datData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $datPath)) {
				print $fh $datData;
				close($fh);
			}
		}

	}

	# セッションに各種情報を保存
	$exp++;
	$session->param('ninpocho', $ninlv);
	$session->param('count', $exp);
	$session->param('time', $time);
	$gold = int($gold * 100) / 100;
	$session->param('gold', $gold);

	#スレタイ付加情報
	if ($Sys->Equal('MODE', 1)) {
		if ($capID) {
				$capName = $Sec->Get($capID, 'NAME', 1, '');
				$tt .= " [$capName★]";
		} else {
			my $kote = $bbs =~ /^(?:news1|kuso|abeshinzo)$/ ? '安倍晋三' : '警告ユーザ';
			my $extra = $bbslim ? $kote  : '';
			if (!$extra) {
				$ttmark = $session->param('ttmark') || 0;
				$extra = $ttmark . '&#x1f441;' if $ttmark ne 0;
			}
			if ($bbs eq 'news1') {
				my $belv = $ninlv < 10 ? "L${ninlv}-" : '';
				$tt .= " [${belv}${benum}${extra}★]";
			} else {
				my $ttlv = $ninlv < 5 ? " L${ninlv}" : '';
				my $ttid = '';
				if (!$chid && !$noid) {
					$ttid = substr($id, 3);
					my $ttid_end = '0';
					$ttid_end = $1 if $name =~ /<\/b>\s\((.)\)<b>/;
					$ttid .= $ttid_end
				}
				my $ttinfo = $ttid . $ttlv . $extra;
				$tt .= " [$ttinfo★]" if $ttinfo && $bbs eq 'livegalileo';
			}
		}
		$tt =~ s/(?:(\s)?\[(?:梨|独|実|下|認|乱|尾|NP)(\s)?\])+//g;
		$tt =~ s/&#0*10(?![0-9])|&#x0*[aA](?![0-9a-fA-F])//g;
		$Form->Set('subject', $tt);
	}

}

#------------------------------------------------------------------------------------------------------------
#	主機能(レス前処理)
#------------------------------------------------------------------------------------------------------------
sub Nusi16
{
	my ($this, $Sys, $Form, $Threads, $threadid, $session, $bbsSet, $ismobile) = @_;

	# キャップID
	my $capID = $Sys->Get('CAPID', '');

	# SID
	my $sid = $session ? $session->param('_SESSION_ID') || 0 : 0;

	# 主権限判定
	my $ownerSID = $Threads->GetAttr($threadid, 'sid') || 0;
	my $isSub = 0;
	if ($session && $Threads->GetAttr($threadid, 'enablesub') && !$capID) {
		$isSub = $Threads->GetAttr($threadid, "sub-$sid") || 0;
		$Threads->SetAttr($threadid, 'issub', $isSub);
		$Threads->SaveAttr($Sys);
	}
	my $isowner = $Sys->Equal('MODE', 1) || $sid eq $ownerSID || $isSub || $capID ? 1 : 0;

	# 主を設定
	$this->SetConf('isowner', $isowner);

	# フォームを取得
	my $name = $Form->Get('FROM');
	my $msg = $Form->Get('MESSAGE');
	my $mail = $Form->Get('mail');
	my $bbs = $Sys->Get('BBS');

	# スレタイ取得
	my $tt = $Form->Get('subject');
	$tt = $Threads->Get('SUBJECT', $threadid) if $tt eq '';

	# 日時を取得
	$ENV{'TZ'} = "JST-9";
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);

	# 主権限持ち処理
	if ($isowner && $name !~ /!nocmd/) {

		# SID情報ディレクトリ
		my $idDir = $Sys->Get('BBSPATH') . "/${bbs}/id/";
		my $ninDir = '.'. $Sys->Get('INFO') . '/.nin/';

		# スレ主指定
		if ($msg =~ /!nusi:([0-9a-f]{6}|ID:(?!(?:\?){3}-\d).{8}|ID:(?:\?){3}-\d+)/ && !$isSub) {
			my $id = $1;
			# sid取得
			my$targetSID = GetSID($id, $idDir, $ninDir);
			if ($targetSID) {
				# 属性情報を読み込む
				$Threads->LoadAttr($Sys);
				# 追加処理
				$Threads->SetAttr($threadid, 'sid', $targetSID);
				# 副主から削除
				if ($Threads->GetAttr($threadid, "sub-$targetSID")) {
					$Threads->SetAttr($threadid, "sub-$targetSID", 0);
					my $enable_sub = $Threads->GetAttr($threadid, 'enablesub') || 0;
					$enable_sub--;
					$Threads->SetAttr($threadid, 'enablesub', $enable_sub);
				}
				# スレの属性を設定し保存
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★${id}に主権限を移譲</font>";
				$Form->Set('MESSAGE', $msg);
			}
		}

		# 副主追加コマンド
		if ($msg =~ /!sub:((?:[0-9a-f]{6}|ID:.{8})(?:,(?:[0-9a-f]{6}|ID:.{8}))*)/ && !$isSub) {
			# 追加処理
			my $enable_sub = $Threads->GetAttr($threadid, 'enablesub') || 0;
			my @ids = split /,/, $1;
			for my $id (@ids) {
				# sid取得
				my $targetSID = GetSID($id, $idDir, $ninDir);
				if ($targetSID ne $ownerSID && !$Threads->GetAttr($threadid, "sub-$targetSID")) {
					$enable_sub++;
					$Threads->SetAttr($threadid, "sub-$targetSID", 1);
					# レスに設定メッセージを追加
					$msg .= "<hr><font color='red'>★${id}を副主に追加</font>";
					$Form->Set('MESSAGE', $msg);
				}
			}
			# スレの属性を設定し保存
			if ($enable_sub) {
				$Threads->SetAttr($threadid, 'enablesub', $enable_sub);
				$Threads->SaveAttr($Sys);
			}
		}

		# 副主削除コマンド
		if ($msg =~ /!delsub:((?:[0-9a-f]{6}|ID:.{8})(?:,(?:[0-9a-f]{6}|ID:.{8}))*)/ && !$isSub) {
			# 忍法帖ID
			my $ids = $1;
			# 削除処理
			my @ids = split /,/, $ids;
			my $infoDir = $Sys->Get('INFO');
			my $ninDir = ".$infoDir/.nin/";
			mkdir $ninDir if ! -d $ninDir;
			my $delcnt = 0;
			for my $id (@ids) {
				my $targetSID = GetSID($id, $idDir, $ninDir);
				if ($Threads->GetAttr($threadid, "sub-$targetSID")) {
					$Threads->SetAttr($threadid, "sub-$targetSID", 0);
					my $enable_sub = $Threads->GetAttr($threadid, 'enablesub') || 0;
					$enable_sub--;
					$Threads->SetAttr($threadid, 'enablesub', $enable_sub);
					$msg .= "<hr><font color='red'>★${id}を副主から削除</font>";
					$Form->Set('MESSAGE', $msg);
					$delcnt++;
				}
			}
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys) if $delcnt;
		}

		# exp1r
		if ($msg =~ /!exp1r/ && $Sys->Equal('BBS', 'exp1') && !$isSub && $session) {
			my $gold = $session->param('gold') || 1;
			my $cost = 10;
			$gold -= $cost;
			PrintBBSError_Ninja($Sys, 10030, $koyuu, $cost) if $gold < 1 && !$capID;
			$session->param('gold', $gold);
		}

		# 保護コマンド
		if ($msg =~ /!hogo/ && $session && $bbs eq 'news1') {
			PrintBBSError_Ninja($Sys, 10039, $koyuu) if $session->param('ninpocho') < 5 || $session->param('news1');
			my $gold = $session->param('gold') || 1;
			my $long_noname = length($Threads->GetAttr($threadid, 'name')) > 50 ? 1 : 0;
			if ( !$Threads->GetAttr($threadid, 'hogo') && $Sys->Equal('MODE', 2) && !$long_noname ) {
				# 制限
				my $hogoCnt = $session->param('hogo') || 0;
				$hogoCnt++;
				PrintBBSError_Ninja($Sys, 10021, $koyuu) if $hogoCnt > 3 && !$capID;
				my $cost = 10 * ($hogoCnt * $hogoCnt) * ($hogoCnt ** $hogoCnt);
				$gold -= $cost;
				PrintBBSError_Ninja($Sys, 10030, $koyuu, $cost) if $gold < 1 && !$capID;
				$session->param('gold', $gold);
				$session->param('hogo', $hogoCnt);
				# スレに保護属性を設定
				$Threads->SetAttr($threadid, 'hogo', 1);
				$Threads->SaveAttr($Sys);
				# 保護処理
				my $queue	= $Sys->Get('BBSPATH') . "/news1/info/pool-queue.txt";
				my $content = '';
				if (open(my $fh, "<", $queue)) {
					$content = do { local $/; <$fh> };
					$content =~ s|${threadid}\n||;
					close($fh);
				}
				if (open(my $fh, '>', $queue)) {
					print $fh $content;
					close($fh);
				}
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★HOGOを有効化（HOGOする必要性が無いスレは無効にします。スレが落ちても復帰要望は受け付けないので、必要なら立て直してください。)</font>";
				$Form->Set('MESSAGE', $msg);
			} elsif ($Sys->Equal('MODE', 1)) {
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>【HOGO失敗】スレ立て時の入力ではHOGOは有効になりません。</font>";
				$Form->Set('MESSAGE', $msg);
			} elsif ($long_noname) {
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>【HOGO失敗】774が長すぎます。</font>";
				$Form->Set('MESSAGE', $msg);
			}
		}

		# noabe
		if ($msg =~ /!(?:noabe|yamagami|nopena)/ && !$Threads->GetAttr($threadid, 'noabe')) {
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'noabe', 1);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレを強制コテ禁止モードに設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# noimg
		if ($msg =~ /!noimg/ && !$Threads->GetAttr($threadid, 'noimg')) {
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'noimg', 1);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレを画像禁止モードに設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# ln
		if ($msg =~ /!ln[:=]?([1-9]\d{0,2})/) {
				my $ln = $1;
				$ln = 100 if $ln > 100;
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'ln', $ln);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレの行数上限を${ln}に設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# len
		if ($msg =~ /!len[:=]?([1-9]\d{0,3})/) {
				my $len = $1;
				$len = 8192 if $len > 8192;
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'len', $len);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレの書き込みバイト数上限を${len}に設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# linelen
		if ($msg =~ /!linelen[:=]?([1-9]\d{0,3})/) {
				my $len = $1;
				$len = 8192 if $len > 8192;
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'llen', $len);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレの行ごとのバイト数上限を${len}に設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# nosansho
		if ($msg =~ /!nosansho/ && !$Threads->GetAttr($threadid, 'nosansho')) {
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'nosansho', 1);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★スレを数値文字参照禁止モードに設定</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# 774変更
		if ($msg =~ /!774[:=]?(.{0,1000})/) {
			$noname = $1;
			$noname =~ s/<br>.*//g;
			$noname =~ s/<hr>.*//g;
			$noname =~ s/★|&#(0*9733|x0*2605);/☆/ig;
			my $gobi = $Threads->GetAttr($threadid, 'gobi') || '';
			$gobi =~ s/(\.|\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
			$gobi =~ s/:[eh]$//;
			$noname =~ s/${gobi}$//g;
			# my $nameCnt = $bbsSet->Get('BBS_NAME_COUNT', '0');
			# $noname = substr($noname, 0, $nameCnt) if length($noname) > $nameCnt;
			# スレの774を設定
			$Threads->SetAttr($threadid, 'noname', $noname);
			# 属性情報を保存
			$Threads->SaveAttr($Sys);
		}

		# gobi
		if ($msg =~ /!gobi[:=]?([^:]{0,1000}(?::[eh])?)/) {
			$gobi = $1;
			$gobi =~ s/<br>.*//g;
			$gobi =~ s/<hr>.*//g;
			my $gobi_prev = $Threads->GetAttr($threadid, 'gobi') || '';
			$gobi_prev =~ s/(\.|\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
			$gobi_prev =~ s/:[eh]$//;
			$gobi =~ s/${gobi_prev}$//g;
			$gobi =~ s/!(?:pay|send|throw|nopool)/安倍晋三/g;
			# スレの774を設定
			$Threads->SetAttr($threadid, 'gobi', $gobi);
			# 属性情報を保存
			$Threads->SaveAttr($Sys);
		}

		# nopoopコマンド
		if ($msg =~ /!nopoop/ && !$Threads->GetAttr($threadid, 'nopoop')) {
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'nopoop', 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★投便禁止に設定</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# unlocksendコマンド
		if ($msg =~ /!unlock(pay|send|throw)/ && !$Threads->GetAttr($threadid, 'unlocksend') && !$Threads->GetAttr($threadid, 'unlockthrow') && $session) {
			my $ninlv = $session->param('ninpocho') || 0;
			my $gold = $session->param('gold') || 1;
			my $cmd = $1;
			my $unchi = $cmd eq 'throw' ? 1 : 0;
			my $attrName = $unchi ? 'unlockthrow' : 'unlocksend';
			my $char = $unchi ? '&#x1f4a9;' : '&#x1f337;';
			my $cost = 100;
			$gold -= $cost;
			PrintBBSError_Ninja($Sys, 10030, $koyuu, $cost) if $gold < 1 && !$capID;
			$session->param('gold', $gold);
			# スレ属性を設定
			$Threads->SetAttr($threadid, $attrName, 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレの投げ${char}制限を解除</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# hidenusi
		if ($msg =~ /!hidenusi/ && !$Threads->GetAttr($threadid, 'hidenusi')) {
				# スレの属性を設定し保存
				$Threads->SetAttr($threadid, 'hidenusi', 1);
				$Threads->SaveAttr($Sys);
				# レスに設定メッセージを追加
				$msg .= "<hr><font color='red'>★HIDENUSIモード</font>";
				$Form->Set('MESSAGE', $msg);
		}

		# ngkコマンド
		if ($msg =~ /!ngk/ && !$Threads->GetAttr($threadid, 'ngk')) {
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'ngk', 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			#強制名無し
			$Form->Set('FROM', '') if !$capID;
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレをNGKモードに設定</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# ngmコマンド
		if ($msg =~ /!ngm/ && !$Threads->GetAttr($threadid, 'ngm')) {
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'ngm', 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			$Form->Set('mail', '') if !$capID;
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレをNGMモードに設定</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# NOIDモードコマンド
		if ( ($msg =~ /!noid/ && !$Threads->GetAttr($threadid, 'noid') && $session) || ($bbs eq 'noid' && $Sys->Equal('MODE', 1) ) ) {
			if (!$capID && $bbs ne 'noid') {
				# limit
				PrintBBSError_Ninja($Sys, 10039, $koyuu) if ( $session->param('ninpocho') < 5 || $session->param($bbs) );
				# nashiCnt
				if ($bbs ne 'exp1') {
					my $nashiCnt = $session->param('nashi') || 0;
					my $gold = $session->param('gold') || 0;
					$nashiCnt++;
					my $bbs_slip = $bbsSet->Get('BBS_SLIP') || '';
					my $thslip = $Threads->GetAttr($threadid, 'slip') || '';
					my $cost = 10 * ($nashiCnt ** $nashiCnt);
					$gold -= $cost;
					PrintBBSError_Ninja($Sys, 10041, $koyuu) if $gold < 1;
					$session->param('nashi', $nashiCnt);
					$session->param('gold', $gold);
				}
			}
			# IDを非表示
			my $sid = $session->param('_SESSION_ID') || 0;
			my $time_id = int( ( rand( hex(substr($sid, 0, 12)) / (10 ** 8) ) + $yday + $threadid + time() ) / 2);
			$time_id = substr($time_id, 4, -1);
			$Form->Set('idpart', "ID:???-${time_id}");
			# 属性を設定し保存
			if ($bbs ne 'noid') {
				$Threads->SetAttr($threadid, 'noid', 1);
				$Threads->SaveAttr($Sys);
			}

		# idchange
		} elsif ($msg =~ /!(?:chid|idchange)/ && !$Threads->GetAttr($threadid, 'chid') && !$Threads->GetAttr($threadid, 'noid') && $bbs ne 'noid' && $session) {
			my $ninlv = $session->param('ninpocho') || 0;
			PrintBBSError_Ninja($Sys, 10039, $koyuu) if $ninlv < 5 || $session->param($bbs);
			#midt
			if ($bbs ne 'exp1' && !$capID) {
				my $chidCnt = $session->param('chid') || 0;
				my $gold = $session->param('gold') || 0;
				$chidCnt++;
				my $freeCnt = $ninlv < 20 ? 1 : 3;
				if ($chidCnt > $freeCnt) {
					my $cost = 5 * $chidCnt ** $chidCnt;
					$cost /= 5 if $bbs eq 'livetulip';
					$gold -= $cost;
					PrintBBSError_Ninja($Sys, 10041, $koyuu) if $gold < 1;
				}
				$session->param('chid', $chidCnt);
				$session->param('gold', $gold);
			}
			# 属性を設定し保存
			$Threads->SetAttr($threadid, 'chid', 1);
			$Threads->SaveAttr($Sys);
		}

		# chkey
		if ($msg =~ /!chkey[:=]?(.*)/ && !$Threads->GetAttr($threadid, 'chkey')) {
			my $chkey = $1;
			$chkey =~ s/<br>.*//g;
			$chkey =~ s/<hr>.*//g;
			# スレ属性をchidに	
			$Threads->SetAttr($threadid, 'chkey', $chkey);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
		}

		# weeks
		if ($msg =~ /!weeks[:=]?((?:.{1,50}\/){6}.{1,50})/) {
			$weeks = $1;
			$weeks =~ s/<br>.*//g;
			$weeks =~ s/<hr>.*//g;
			# スレのweeksを設定
			$Threads->SetAttr($threadid, 'weeks', $weeks);
			# 属性情報を保存
			$Threads->SaveAttr($Sys);
		}

		# mirrorコマンド
		if ($msg =~ /!mirror/ && $bbs eq 'liveuranus' && !$Threads->GetAttr($threadid, 'mirror')) {
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'mirror', 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレをMIRRORモードに設定</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# nomirrorコマンド
		if ($msg =~ /!nomirror/ && $bbs eq 'liveuranus' && !$Threads->GetAttr($threadid, 'nomirror')) {
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'nomirror', 1);
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレをMIRROR禁止に設定</font>";
			$Form->Set('MESSAGE', $msg);
		}

		# 解除コマンド
		if ($msg =~ /!kaijo:(.+)/) {
			my $kaijo_cmd = $1;
			my $kaijo_msg = '';

			#noimg
			if ($kaijo_cmd =~ /^noimg/ && $Threads->GetAttr($threadid, 'noimg')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'noimg', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★画像禁止モードを解除</font>";
			}

			#ln
			if ($kaijo_cmd =~ /^ln/ && $Threads->GetAttr($threadid, 'ln')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'ln', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★スレの行数上限設定を解除</font>";
			}

			#len
			if ($kaijo_cmd =~ /^len/ && $Threads->GetAttr($threadid, 'len')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'len', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★スレの書き込みバイト数上限設定を解除</font>";
			}

			#linelen
			if ($kaijo_cmd =~ /^linelen/ && $Threads->GetAttr($threadid, 'llen')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'llen', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★スレの行ごとのバイト数上限設定を解除</font>";
			}

			#nosansho
			if ($kaijo_cmd =~ /^nosansho/ && $Threads->GetAttr($threadid, 'nosansho')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'nosansho', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★数値文字参照禁止モードを解除</font>";
			}

			#mirror
			if ($kaijo_cmd =~ /^mirror/ && $Threads->GetAttr($threadid, 'mirror')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'mirror', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★MIRRORモードを解除</font>";
			}

			#nomirror
			if ($kaijo_cmd =~ /^nomirror/ && $Threads->GetAttr($threadid, 'nomirror')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'nomirror', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★MIRROR禁止を解除</font>";
			}

			#nopoop 
			if ($kaijo_cmd =~ /^nopoop/ && $Threads->GetAttr($threadid, 'nopoop')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'nopoop', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★投便禁止を解除</font>";
			}

			#nopool 
			if ($kaijo_cmd =~ /^nopool/ && $Threads->GetAttr($threadid, 'nusinp')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'nusinp', 0);
				$Threads->SetAttr($threadid, 'nopool', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★不落を解除</font>";
				# タグ削除
				my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.*?)(?:\s)?\[NP\](?:\s)?|$1|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
			}

			# new
			if ($kaijo_cmd =~ /^new/ && $Threads->GetAttr($threadid, 'new')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'new', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★新規用モードを解除</font>";
			}

			# nonew
			if ($kaijo_cmd =~ /^nonew/ && $Threads->GetAttr($threadid, 'nonew')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'nonew', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★NONEWモードを解除</font>";
			}

			# noabe
			if ($kaijo_cmd =~ /^(?:noabe|yamagami|nopena)/ && $Threads->GetAttr($threadid, 'noabe')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'noabe', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★強制コテ禁止モードを解除</font>";
			}

			# hidenusi
			if ($kaijo_cmd =~ /^hidenusi/ && $Threads->GetAttr($threadid, 'hidenusi')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'hidenusi', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★HIDENUSIモードを解除</font>";
			}

			# ngk
			if ($kaijo_cmd =~ /^ngk/ && $Threads->GetAttr($threadid, 'ngk')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'ngk', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★NGKモードを解除</font>";
			}

			# ngm
			if ($kaijo_cmd =~ /^ngm/ && $Threads->GetAttr($threadid, 'ngm')) {
				# 属性解除
				$Threads->SetAttr($threadid, 'ngm', 0);
				# 設定メッセージ
				$kaijo_msg =  "<hr><font color='red'>★NGMモードを解除</font>";
			}

			# レスに設定メッセージを追加
			if ($kaijo_msg) {
				$msg .= $kaijo_msg;
				$Form->Set('MESSAGE', $msg);
			}

			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
		}

		# tagコマンド
		if ($msg =~ /!tag:([a-zA-Z0-9,]+)/) {
			my $tag = $1;
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★スレタイに${tag}タグを追加</font>";
			$Form->Set('MESSAGE', $msg);
			# スレタイにタグを追加
			$Threads->SetAttr($threadid, 'tag', $tag);
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				if (!$tag) {
					$content =~ s|(?<=${threadid}\.dat<>)\[t:[a-zA-Z0-9]+\]\s(.+)(?=\s\[.+★\]\s\(\d+\))|$1|;
				} else {
					$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=\s\[.+★\]\s\(\d+\))|[t:${tag}] $1|;
				}
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SaveAttr($Sys);
			#sage
			$Sys->Set('updown', '-100');
		}

	}

	# スレ主以外でも処理
	if ($Sys->Equal('MODE', 2)) {

		# スレッドに書き込めるLvを判定
		if (!$isowner) {
			my $ninlv = $session->param('ninpocho') || 0;
			$tlv = $Threads->GetAttr($threadid, 'tlv') || 0;
			$tlv = $1 if !$tlv && $tt =~ /\s\[TLV([1-9]\d*)\]/;
			PrintBBSError_Ninja($Sys, 10004, $koyuu, $tlv) if $tlv && $ninlv < $tlv;
			if ($ismobile) {
				$tlv_m = $Threads->GetAttr($threadid, 'tlvm') || 0;
				$tlv_m = $1 if !$tlv_m && $tt =~ /\s\[TLVm([1-9]\d*)\]/;
				PrintBBSError_Ninja($Sys, 10049, $koyuu, $tlv_m) if $tlv_m && $ninlv < $tlv_m;
			}
		}

		# 高速書き込みモード
		my $livemode = $Threads->GetAttr($threadid, 'live') || 0;
		if ($livemode) {
			$Sys->Set('FASTMODE', 1);
		}

		#noimg
		PrintBBSError_Ninja($Sys, 10050, $koyuu) if !$isowner && $Threads->GetAttr($threadid, 'noimg') && $msg =~ /(?:!rmj|&#8238;|(?:n|&#(?:0*(?:110|78)|x0*[46]e);)(?:i|&#(?:0*105|x0*69);)(?:c|&#(?:0*99|x0*63);)(?:o|&#(?:0*111|x0*6f);)(?:(?:v|&#(?:0*118|x0*76);)(?:i|&#(?:0*105|x0*69);)(?:d|&#(?:0*100|x0*64);)(?:e|&#(?:0*101|x0*65);)(?:o|&#(?:0*111|x0*6f);))?(?:\.|&#(0*46|x0*2e))|(?:y|&#(?:0*121|x0*79);)(?:o|&#(?:0*111|x0*6f);)(?:u|&#(?:0*117|x0*75);)(?:t|&#(?:0*116|x0*74);)(?:u|&#(?:0*117|x0*75);)(?:(?:b|&#(?:0*98|x0*62);)(?:e|&#(?:0*101|x0*65);))?(?:\.|&#(0*46|x0*2e))|(?:t|&#(?:0*116|x0*74);)(?:w|&#(?:0*119|x0*77);)(?:i|&#(?:0*105|x0*69);)(?:m|&#(?:0*109|x0*6d);)(?:g|&#(?:0*103|x0*67);)(?:\.|&#(0*46|x0*2e);)|(?:i|&#(?:0*105|x0*69);)(?:m|&#(?:0*109|x0*6d);)(?:g|&#(?:0*103|x0*67);)(?:u|&#(?:0*117|x0*75);)(?:r|&#(?:0*114|x0*72);)(?:\.|&#(0*46|x0*2e);)|(?:\.|&#(?:0*46|x0*2e);)(?:(?:j|&#(?:0*(?:106|74)|x0*[46]a);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:e|&#(?:0*(?:101|69)|x0*[46]5);)?(?:g|&#(?:0*(?:103|71)|x0*[46]7);)|(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:n|&#(?:0*(?:110|78)|x0*[46]e);)(?:g|&#(?:0*(?:103|71)|x0*[46]7);)|(?:g|&#(?:0*(?:103|71)|x0*[46]7);)(?:i|&#(?:0*(?:105|73)|x0*[46]9);)(?:f|&#(?:0*(?:102|70)|x0*[46]6);)|(?:w|&#(?:0*(?:119|87)|x0*[57]7);)(?:e|&#(?:0*(?:101|69)|x0*[46]5);)(?:b|&#(?:0*(?:98|66)|x0*[46]2);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)|(?:m|&#(?:0*109|x0*6d);)(?:p|&#(?:0*(?:112|80)|x0*[57]0);)(?:4|&#(?:0*52|x0*34);)))/i;

		# 行数・バイト数制限
		my $lnlim = $Threads->GetAttr($threadid, 'ln') || 0;
		my $lenlim = $Threads->GetAttr($threadid, 'len') || 0;
		my $line_lenlim = $Threads->GetAttr($threadid, 'llen') || 0;
		if ( !$isowner && ($lnlim || $lenlim) ) {
			PrintBBSError_Ninja($Sys, 10054, $koyuu, $lenlim) if $msg =~ /!rmj/;
			$msg =~ s/&#0*10;|&#x0*[aA];//g;
			$Form->Set('MESSAGE', $msg);
			require './module/data_utils.pl';
			$conv = DATA_UTILS;
			my ($ln, $cl) = $conv->GetTextInfo(\$msg);
			PrintBBSError_Ninja($Sys, 10053, $koyuu, $lnlim) if $lnlim && $ln > $lnlim;
			PrintBBSError_Ninja($Sys, 10054, $koyuu, $lenlim) if $lenlim && length($msg) > $lenlim;
			PrintBBSError_Ninja($Sys, 10054, $koyuu, $line_lenlim) if $line_lenlim && $cl > $line_lenlim;
		}

		# nosansho
		PrintBBSError_Ninja($Sys, 10047, $koyuu) if $Threads->GetAttr($threadid, 'nosansho') && $msg =~ /&#|!rmj/ && !$capID;

		# noid
		my $noid = $Threads->GetAttr($threadid, 'noid');
		$noid = 1 if $bbs eq 'noid';
		if ($noid) {
			my $sid = $session ? $session->param('_SESSION_ID') || 0 : 0;
			my $time_id = int( ( rand( hex(substr($sid, 0, 12)) / (10 ** 8) ) + $yday + $threadid + time() ) / 2);
			$time_id = substr($time_id, 4, -1);
			$Form->Set('idpart', "ID:???-${time_id}") if !$capID;
		}

		# ngk
		my $ngk = $Threads->GetAttr($threadid, 'ngk') || 0;
		if ($ngk && !$capID) {
			$name = $name !~ /!nocmd/ ? '' : '!nocmd';
			$Form->Set('FROM', $name);
		}

		# ngm
		my $ngm = $Threads->GetAttr($threadid, 'ngm') || 0;
		if ($ngm && !$capID) {
			$Form->Set('mail', '');
		}

		# 774処理
		my $thNoName = $Threads->GetAttr($threadid, 'noname') || '';
		if ($thNoName) {
			$name = $thNoName if !$name;
			$Form->Set('FROM', $name);
		}

		# gobi
		my $gobi = $Threads->GetAttr($threadid, 'gobi') || '';
		if ($gobi && $name !~ /!nocmd/) {
			my $mode = $gobi =~ /:e$/ ? 1 : 0;
			$mode = 2 if $gobi =~ /:h$/;
			$gobi =~ s/:[eh]$//;
			if ($mode == 2) {
				$msg = $gobi . $msg;
			} else {
			$msg .= $gobi;
			$msg =~ s/(?<!<br>)<br>/${gobi}<br>/g if !$mode;
			$gobi =~ s/(\.|\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
			$msg =~ s/((?:&gt;){2}[1-9]\d{0,5}|https?:\/\/[a-zA-Z0-9\.\?\/_-]+)$gobi/$1/g;
			}
			$Form->Set('MESSAGE', $msg);
		}

		# noriben
		my $noriben = $Threads->GetAttr($threadid, 'noriben') || 0;
		$noriben = 1 if $tt =~ /\s\[海苔\]/;
		if ($noriben && !$capID && !$isowner) {
			$msg =~ s/(?:(?:安|&#(?:0*23433|x0*5b89);).*(?:\x94\x7b|部|&#(?:0*(?:20493|37096)|x0*(?:500d|90e8));).*)?(?:晋|普|&#(?:0*(?:26187|26222)|x0*(?:664b|666e));).*(?:三|3|&#(?:0*(?:19977|51)|x0*(?:4e09|33));)/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:晋|普|&#(?:0*(?:26187|26222)|x0*(?:664b|666e));).*さん.*どうして/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/ア.*ベ.*シ.*ン.*ゾ(?:.*ウ)?|あ.*べ.*し.*ん.*ぞ(?:.*う)?|シ.*ン.*ゾ.*ア.*ベ|ア.*ベ.*シ.*ン.*ゾ(?:.*ウ)?|シ.*ン.*ゾ.*ア.*ベ|a.?b.?e.?s.?(?:h.?)?i.?n.?z.?o.?u?/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/紫.*雲.*院.*殿.*政.*(?:誉|譽).*清.*浄.*晋.*寿.*大.*居.*(?:士|土)/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:晋|普|&#(?:0*(?:26187|26222)|x0*(?:664b|666e));).*さん.*どうして/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/ま.*(?:あ|ぁ).*い.*い.*ん.*そ.*う.*(*:い|ゆ).*う.*の|マ.*(?:ア|ァ).*イ.*イ.*ン.*ソ.*ウ.*(*:イ|ユ).*ウ.*ノ/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:意味の(?:な|無)い|(?:バカ|馬鹿)みたいな).{0,32}(?:いつも)?/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:下|くだ)らない.*終.*また/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:早|はや)く.*しろよ/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/こんな.*ける(?:訳|わけ)には.*ない/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/非常に(?:し|ひ)つこい/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/いわばまさに/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/だから.*てるじゃないか/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/そんなに興奮しないでください/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/これはちょっと.*くらい.*分かることだと思いますよ/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/これは.*随分.*辛口だ/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/みっともない.*はっきり.*て/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/理由を.*えるのではなく/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/いい.*ですから.*前に進めてください/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/\x83\x60\x83\x87\x81\x5b\x83\x5b\x83\x6f/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/(?:晋|&#(?:0*26187|x0*664b);)/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/&#8238;[^<]*/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$msg =~ s/!(?:rmj|randmoji)[^<]*/【&#9608;&#9608;&#9608;&#9608;】/gi;
			$Form->Set('MESSAGE', $msg);
		}

		#capsage
		my $capsage = $Threads->GetAttr($threadid, 'capsage') || 0;
		if ($capsage && $bbs !~ /^live/) {
			$Sys->Set('updown', 'bottom');
		}

	}

	# mirror
	if ( $bbs eq 'liveuranus' && ($Threads->GetAttr($threadid, 'mirror') || $name =~ /!mirror/) && $session && !$Threads->GetAttr($threadid, 'nomirror') && !$Threads->GetAttr($threadid, 'noid') && $msg !~ /&gt;&gt;/ ) {
		my $ninlv = $session->param('ninpocho') || 0;
		my $mirror_log_dir = $Sys->Get('BBSPATH') . "/$bbs/info/mirrorlog/";
		mkdir $mirror_log_dir if ! -d $mirror_log_dir;
		my $mirror_log = "${mirror_log_dir}${threadid}";
		if ($ninlv > 4 && ! -f $mirror_log) {
			my $mirror_txt = $Sys->Get('BBSPATH') . "/$bbs/info/mirror.txt";
			my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
			$resNum++;
			if (open(my $fh, ">", $mirror_txt)) {
				print $fh "$tt\n$tt\nhttps://sannan.nl/test/read.cgi/liveuranus/$threadid/$resNum\n\n$msg";
				close($fh);
			}
			require './module/file_utils.pl';
			FILE_UTILS::Copy($mirror_txt, $mirror_log);
		}
	}

	# nopool
	if ( $msg =~ /!nopool/ && $session && !$Threads->GetAttr($threadid, 'nopool') && $bbs =~ /^live(?:galileo|tulip)$/ && ((!$Threads->GetAttr($threadid, 'nusinp') && $isowner && $name !~ /!nocmd/) || ($Threads->GetAttr($threadid, 'nusinp') && !$isowner)) && $session ) {
		my $gold = $session->param('gold') || 1;
		my $bbsnopoolCnt_log = $Sys->Get('BBSPATH') . "/$bbs/info/nopoolcnt.log";
		my $bbsnopoolCnt = 0;
		if (open(my $fh, "<", $bbsnopoolCnt_log)) {
			$bbsnopoolCnt = <$fh>;
			close($fh);
		}
		PrintBBSError_Ninja($Sys, 10039, $koyuu) if $session->param('ninpocho') < 10 || $session->param($bbs);
		my $limCnt = 11;
		if ($bbsnopoolCnt < $limCnt) {
			# 制限
			my $npCnt = $session->param('np1') || 0;
			$npCnt++ if !$isowner;
			my $npCnt2 = $session->param('np2') || 0;
			$npCnt2++ if $isowner;
			PrintBBSError_Ninja($Sys, 10021, $koyuu) if ($npCnt + $npCnt2) > 10 && !$capID;
			my $npHour = $session->param('npH') || 0;
			$npHour++;
			my $CostCnt = $isowner ? $npCnt2 : $npCnt;
			my $cost = 50 * 2 ** ($CostCnt - 1);
			$cost /= 2; # 09/03
			$cost /= 2 if $bbs eq 'livetulip';
			if ($npHour < 2 || $isowner) {
				$cost = 500 if $cost > 500;
			} else {
				PrintBBSError_Ninja($Sys, 10057, $koyuu, $cost) if $msg !~ /!nopool:f/;
				$cost *= ($npHour ** 3);
			}
			if ($isowner) {
				$Threads->SetAttr($threadid, 'npcost', $cost);
				$cost *= 4;
			}
			$gold -= $cost;
			PrintBBSError_Ninja($Sys, 10030, $koyuu, $cost) if $gold < 1 && !$capID;
			$session->param('gold', $gold);
			$session->param('np1', $npCnt);
			$session->param('np2', $npCnt2);
			$session->param('npH', $npHour);
			my $nplv = $Threads->GetAttr($threadid, 'nplv') || 0;
			$nplv++;
			my $sucsessCnt = 5;
			my $nokori = $sucsessCnt - $nplv;
			my $nplmsg = $nplv < $sucsessCnt ? "まで残り${nokori}回（期間中に落ちても復帰要望は受け付けないので、必要なら立て直してください。糞スレには使わないでください。）" : '成功！';
			# レスに設定メッセージを追加
			$msg .= "<hr><font color='red'>★NOPOOL発動${nplmsg} コスト：${cost}g</font>";
			$Form->Set('MESSAGE', $msg);
			# nopool設定
			$Threads->SetAttr($threadid, 'nusinp', 1) if $isowner;
			$Threads->SetAttr($threadid, 'nplv', $nplv);
			if ($nplv >= $sucsessCnt) {
				$Threads->SetAttr($threadid, 'nopool', 1);
				my $thread_npcnt = $Threads->GetAttr($threadid, 'npcnt') || 0;
				$thread_npcnt++;
				$Threads->SetAttr($threadid, 'npcnt', $thread_npcnt);
				# スレ数カウントアップ
				if (open(my $fh, ">", $bbsnopoolCnt_log)) {
					$bbsnopoolCnt++;
					print $fh $bbsnopoolCnt;
					close($fh);
				}
				# スレタイにタグ
				my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[NP\]|$1|;
					my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
					$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [NP]|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
				# デポジット返還
				my $infoDir = $Sys->Get('INFO');
				my $ninDir = ".$infoDir/.nin/";
				my $ownerSID = $Threads->GetAttr($threadid, 'sid') || 0;
				my $nusi_cost = $Threads->GetAttr($threadid, 'npcost') || 0;
				if ($ownerSID && $nusi_cost) {
					my $ownerSS = CGI::Session->new('driver:file;serializer:default', $ownerSID, { Directory => $ninDir }) || 0;
					my $ownerSS_gold = $ownerSS->param('gold') || 1;
					$ownerSS_gold += $nusi_cost * 2;
					$ownerSS->param('gold', $ownerSS_gold);
				}
			}
			$Threads->SaveAttr($Sys);
		} else {
			$msg .= "<hr><font color='red'>板のnopoolスレ数の上限に達したため発動できません。</font>";
			$Form->Set('MESSAGE', $msg);
		}
	}

}

#------------------------------------------------------------------------------------------------------------
#	主機能(レス後処理)
#------------------------------------------------------------------------------------------------------------
sub Nusi32
{
	my ($this, $Sys, $Form, $Threads, $threadid) = @_;

	# スレッド情報を変更したかどうか
	my $modified = 0;
	
	# キャップID
	my $capID = $Sys->Get('CAPID', '');

	# スレ主かどうか
	my $isowner = $this->GetConf('isowner');
	
	# 副主かどうか
	my $isSub = $Threads->GetAttr($threadid, "issub") || 0;

	# フォーム情報
	my $name = $Form->Get('FROM');
	my $msg = $Form->Get('MESSAGE');
	my $mail = $Form->Get('mail');
	my $bbs = $Sys->Get('BBS');

	# スレタイ取得
	my $tt = $Threads->Get('SUBJECT', $threadid);

	# absnz
	if ($Sys->Equal('MODE', 1) && $msg =~ /!\ssage\s!\skisei/) {
		require './module/setting.pl';
		my $bbsSet = ISILDUR->new;
		$bbsSet->Load($Sys);
		my $maxmenu = $bbsSet->Get('BBS_MAX_MENU_THREAD');
		my $updown = '-' . $maxmenu;
		my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
		$Threads->OnDemand($Sys, $threadid, $resNum, $updown);
	}

	# スレ主以外でも処理
	if ($Sys->Equal('MODE', 2) && $name !~ /!nocmd/) {
		# notop
		my $notop = $Threads->GetAttr($threadid, 'notop') && $mail !~ /sage/;
		if ($notop) {
			require './module/setting.pl';
			my $bbsSet = ISILDUR->new;
			$bbsSet->Load($Sys);
			my $maxmenu = $bbsSet->Get('BBS_MAX_MENU_THREAD');
			my $updown = '-' . $maxmenu;
			my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
			$Threads->OnDemand($Sys, $threadid, $resNum, $updown);
		}
	}

	# スレ主・副主キャップならコマンド処理
	if ($isowner && $name !~ /!nocmd/) {

		# 日時を取得
		$ENV{'TZ'} = "JST-9";
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);

		# スレ主のみ処理
		if (!$isSub && !$capID) {

			# Dat落ち
			if ($msg =~ /!pool/ && $this->GetConf('enable_pool')) {
				#$Threads->Save($Sys);
				my $Pools = FRODO->new;
				$Pools->Load($Sys);
				$Pools->Add($threadid, $Threads->Get('SUBJECT', $threadid), $Threads->Get('RES', $threadid));
				$Pools->Save($Sys);
				$Threads->Delete($threadid);
				$modified = 1;
				require './module/file_utils.pl';
				my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
				FILE_UTILS::Copy("$path/dat/$threadid.dat", "$path/pool/$threadid.cgi");
				unlink "$path/dat/$threadid.dat";

			# スレスト
			} elsif ($msg =~ /!stop/ && $this->GetConf('enable_stop')) {
				# スレスト処理
				my $datPath = $Sys->Get('DATPATH');
				my $Thread = ARAGORN->new();
				$Thread->Load($Sys, $datPath, 0);
				$Thread->Stop($Sys);
				my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
				$Threads->OnDemand($Sys, $threadid, $resNum, 'bottom');
				$Thread->Save($Sys);
				$Thread->Close();
				# タグ付け
				my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
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
			
			# kuso
			} elsif ($msg =~ /!kuso/ && $Sys->Equal('BBS', 'news1')) {
				my $Pools = FRODO->new;
				$Pools->Load($Sys);
				$Pools->Add($threadid, $Threads->Get('SUBJECT', $threadid), $Threads->Get('RES', $threadid));
				$Pools->Save($Sys);
				$Threads->Delete($threadid);
				$modified = 1;
				require './module/gondor.pl';
				my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
				require './module/file_utils.pl';
				my $bbsPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
				FILE_UTILS::Copy("$bbsPath/dat/$threadid.dat", "$bbsPath/pool/$threadid.cgi");
				my $kusoPath = $Sys->Get('BBSPATH') . "/kuso";
				my $kusoDat = "$kusoPath/dat/$threadid.dat";
				FILE_UTILS::Copy("$bbsPath/dat/$threadid.dat", $kusoDat);
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

			# exp1r
			} elsif ($msg =~ /!exp1r/ && $Sys->Equal('BBS', 'exp1')) {
				my $Pools = FRODO->new;
				$Pools->Load($Sys);
				$Pools->Add($threadid, $Threads->Get('SUBJECT', $threadid), $Threads->Get('RES', $threadid));
				$Pools->Save($Sys);
				$Threads->Delete($threadid);
				$modified = 1;
				require './module/gondor.pl';
				my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
				require './module/file_utils.pl';
				my $bbsPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
				FILE_UTILS::Copy("$bbsPath/dat/$threadid.dat", "$bbsPath/pool/$threadid.cgi");
				my $dstPath = $Sys->Get('BBSPATH') . "/exp1r";
				my $dstDat = "$dstPath/dat/$threadid.dat";
				FILE_UTILS::Copy("$bbsPath/dat/$threadid.dat", $dstDat);
				unlink "$bbsPath/dat/$threadid.dat";
				my $sbjtxt = "$dstPath/subject.txt";
				my $content;
				if (open(my $fh, '<', $sbjtxt)) {
					$content = do { local $/; <$fh> };
					close $fh;
				}
				if (open(my $fh, '>', $sbjtxt)) {
					print $fh "${threadid}.dat<>${tt} (${resNum})\n${content}";
					close $fh;
				}
			}

		}

		# SLIPコマンド
		if ($msg =~ /!slip[:=](v{3,6}|verbose)/) {
			my $slip = $1;
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージを1に表示
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				if ($content =~ /<hr><font color='red'>※SLIP/) {
					$content =~ s|(<hr><font color='red'>※SLIP=)[a-z]+|$1${slip}|;
				} else {
					$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※SLIP=${slip}</font>$1|;
				}
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'slip', $slip);
			$Threads->SaveAttr($Sys);
		} elsif ($msg =~ /!jien/) {
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージを1に表示
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				if ($content =~ /<hr><font color='red'>※SLIP/) {
					$content =~ s|(<hr><font color='red'>※SLIP=)[a-z]+|$1vvv|;
				} else {
					$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※SLIP=vvv</font>$1|;
				}
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# スレ属性を設定
			$Threads->SetAttr($threadid, 'slip', 'vvv');
			$Threads->SaveAttr($Sys);
		} elsif ($msg =~ /!kaijo:(?:slip|jien)/) {
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージを1に表示
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s/<hr><font color='red'>※SLIP=[a-z]+<\/font>//;
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# 属性を設定し保存
			$Threads->SetAttr($threadid, 'slip', '');
			$Threads->SaveAttr($Sys);
		}

		# noid
		if ( $msg =~ /!noid/ ) {
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[梨\]|$1|;
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[元梨\]|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [梨]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:noid/ && $Threads->GetAttr($threadid, 'noid')) {
			# 属性を設定し保存
			$Threads->SetAttr($threadid, 'noid', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[梨\]|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [元梨]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# idchange
		if ( $msg =~ /!(?:chid|idchange)/ && !$Threads->GetAttr($threadid, 'noid') ) {
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[独\]|$1|;
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[元独\]|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [独]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:(?:chid|idchange)/) {
			# 属性を設定し保存
			$Threads->SetAttr($threadid, 'chid', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[独\]|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [元独]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# auth
		if ($msg =~ /!auth/ && !$Threads->GetAttr($threadid, 'auth')) {
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'auth', 1);
			$Threads->SaveAttr($Sys);
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [認]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:auth/ && $Threads->GetAttr($threadid, 'auth')) {
			# 属性を設定し保存
			$Threads->SetAttr($threadid, 'auth', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[認\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# sage
		if ( $msg =~ /!sage/ && ( !$Threads->GetAttr($threadid, 'sagemode') || ($capID && !$Threads->GetAttr($threadid, 'capsage')) ) ) {
			# スレ順を下げる
			my $updown = 'bottom';
			require './module/setting.pl';
			my $bbsSet = ISILDUR->new;
			$bbsSet->Load($Sys);
			my $maxmenu = $bbsSet->Get('BBS_MAX_MENU_THREAD');
			$updown = '-' . $maxmenu if !$capID || $bbs =~ /^live/;
			my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
			$Threads->OnDemand($Sys, $threadid, $resNum, $updown);
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'sagemode', 1);
			$Threads->SetAttr($threadid, 'notop', 0);
			$Threads->SaveAttr($Sys);
			# スレタイにタグ
			if (!$capID) {
				my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[下\]\s|$1|;
					my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
					$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [下]|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
			}
		} elsif ( $msg =~ /!kaijo:sage/ && ($Threads->GetAttr($threadid, 'sagemode') || ($Threads->GetAttr($threadid, 'capsage') && $capID) ) ) {
			my $iscapsage = $Threads->GetAttr($threadid, 'capsage');
			# 属性解除
			$Threads->SetAttr($threadid, 'sagemode', 0);
			$Threads->SetAttr($threadid, 'capsage', 0) if $capID && $iscapsage;
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[下\]|$1|;
				$content =~ s|(?<=${threadid}\.dat<>)\[↓\]\s|$1| if $capID && $iscapsage;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# notop
		if ( $msg =~ /!notop/ && !$Threads->GetAttr($threadid, 'notop') ) {
			# スレ順を下げる
			require './module/setting.pl';
			my $bbsSet = ISILDUR->new;
			$bbsSet->Load($Sys);
			my $maxmenu = $bbsSet->Get('BBS_MAX_MENU_THREAD');
			my $updown = '-' . $maxmenu;
			my $resNum = ARAGORN::GetNumFromFile($Sys->Get('DATPATH'));
			$Threads->OnDemand($Sys, $threadid, $resNum, 'top');
			$Threads->OnDemand($Sys, $threadid, $resNum, $updown);
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'notop', 1);
			$Threads->SetAttr($threadid, 'sagemode', 0);
			$Threads->SaveAttr($Sys);
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[下\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [下]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ( $msg =~ /!kaijo:notop/ && $Threads->GetAttr($threadid, 'notop') ) {
			# 属性解除
			$Threads->SetAttr($threadid, 'notop', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[下\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# LIVEモードコマンド
		if ($msg =~ /!live/ && !$Threads->GetAttr($threadid, 'live')) {
			# 高速書き込みモードを有効化
			$Sys->Set('FASTMODE', 1);
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'live', 1);
			$Threads->SaveAttr($Sys);
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[実\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [実]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:live/) {
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'live', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[実\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# newモードコマンド
		if ($msg =~ /!new/ && !$Threads->GetAttr($threadid, 'new') && $bbs ne 'livetulip') {
			# 高速書き込みモードを有効化
			$Sys->Set('FASTMODE', 1);
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'new', 1);
			$Threads->SaveAttr($Sys);
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[新\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [新]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:new/) {
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'new', 0);
			$Threads->SaveAttr($Sys);
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[新\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# 解除コマンド
		if ($msg =~ /!kaijo:add(-all)?/ && $Sys->Equal('MODE', 2)) {
			# オプション
			my $opt_all = $1 ? 'all' : 0;
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて追記
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				if ($opt_all) {
					$content =~ s/<hr><font[^<]+>[^<]+追記[^<]+<\/font>\s(?:<br>\s[^<]+)+//g;
				} else {
					$content =~ s/<hr><font[^<]+>[^<]+追記[^<]+<\/font>\s(?:<br>\s[^<]+)+(?!.*追記)//;
				}
				$data = $content;
				close($fh);
			}
			if ($data && open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
		}

		# 追記コマンド
		if ($msg =~ /!add(.*)/ && $Sys->Equal('MODE', 2)) {
			# 追記文
			my $addtxt = $1;
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# 日時
			my @week = qw/日 月 火 水 木 金 土/;
			my $time = sprintf("%04d/%02d/%02d(${week[$wday]}) %02d:%02d:%02d", $year + 1900, $mon +1, $mday, $hour, $min, $sec);
			# datを書き換えて追記
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※追記 $time</font> <br> $addtxt$1|;
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
		}

		# スレタイ修正
		if ($msg =~ /!chtt(?!(?:\s|　)*<br>)(.+)/ && $Sys->Equal('MODE', 2)) {
			# 新しいスレタイ
			my $newtt = $1;
			PrintBBSError_Ninja($Sys, 10055, $koyuu) if $newtt =~ /^(?:\s|　)*$/;
			$newtt =~ s/<(br|hr)>.*//g;
			$newtt =~ s/&#0*10(?![0-9])|&#x0*[aA](?![0-9a-fA-F])//g;
			$newtt =~ s/^(?:\s|　)+//;
			my $bbsSet = ISILDUR->new;
			$bbsSet->Load($Sys);
			my $sjbCnt = $bbsSet->Get('BBS_SUBJECT_COUNT', '0');
			$newtt = substr($newtt, 0, $sjbCnt) if length($newtt) > $sbjCnt;
			my $id = $Form->Get('idpart');
			$newtt .= ' [変]' if $id !~ /BOT/ && $bbs =~ /^(?:news1|live(?:galileo|tulip))$/;
			my $bbs = $Form->Get('bbs');
			$newtt = '[↓] ' . $newtt if $Threads->GetAttr($threadid, 'capsage');
			$newtt .= ' [梨]' if $Threads->GetAttr($threadid, 'noid');
			$newtt .= ' [独]' if $Threads->GetAttr($threadid, 'chid');
			$newtt .= ' [実]' if $Threads->GetAttr($threadid, 'live');
			$newtt .= ' [新]' if $Threads->GetAttr($threadid, 'new');
			$newtt .= ' [下]' if $Threads->GetAttr($threadid, 'sagemode');
			$newtt .= ' [認]' if $Threads->GetAttr($threadid, 'auth');
			$newtt .= ' [乱]' if $Threads->GetAttr($threadid, 'noname') =~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/ || $Threads->GetAttr($threadid, 'gobi') =~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/;
			$newtt .= ' [尾]' if $Threads->GetAttr($threadid, 'gobi');
			my $tlv = $Threads->GetAttr($threadid, 'tlv') || 0;
			$newtt .= " [TLV$tlv]" if $tlv;
			my $tlv_m = $Threads->GetAttr($threadid, 'tlvm') || 0;
			$newtt .= " [TLV$tlv_m]" if $tlv_m;
			$newtt .= ' [&#x1f337;]' if $Threads->GetAttr($threadid, 'unlocksend') || $Threads->GetAttr($threadid, 'unlockthrow');
			$newtt .= ' [NP]' if $Threads->GetAttr($threadid, 'nopool');
			my $tag = $Threads->GetAttr($threadid, 'tag');
			$newtt = $tag . $newtt if $tag;
			# 板のsubject.txt
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			my $ttNinID = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				if ($content =~ /(?<=${threadid}\.dat<>).+(?=\s\[.+★\]\s\(\d+\))/ && $id !~ /BOT/) {
					$ttNinID = $1 if $content =~ /(?<=${threadid}\.dat<>).+(\s\[.+★\])(?=\s\(\d+\))/;
					$content =~ s|(?<=${threadid}\.dat<>).+(?=\s\[.+★\]\s\(\d+\))|$newtt|;
				} else {
					$content =~ s|(?<=${threadid}\.dat<>).+(?=\s\(\d+\))|$newtt|;
				}
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $datPath = "$bbspath/dat/$threadid.dat";
			# 日時
			my @week = qw/日 月 火 水 木 金 土/;
			my $time = sprintf("%04d/%02d/%02d(${week[$wday]}) %02d:%02d:%02d", $year + 1900, $mon +1, $mday, $hour, $min, $sec);
			# datを書き換え
			my $datData = '';
			if (open(my $fh, '<', $datPath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s|(<>)(?!.*<>).+|$1$newtt$ttNinID|;
				$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※スレタイ変更 $time</font> <br> 変更前： $tt$1| if $id !~ /BOT/;
				$datData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $datPath)) {
				print $fh $datData;
				close($fh);
			}
			#速報くん
			if ($id =~ /BOT/ && $msg =~ /<br>.*!chtt/) {
				$msg =~ s/<br>!chtt.*//;
				$Form->Set('MESSAGE', $msg)
			}
			$Threads->SaveAttr($Sys);
		}

		# 774変更
		if ($msg =~ /!774[:=]?(.{0,1000})/) {
			my $noname = $1;
			$noname =~ s/<br>.*//g;
			$noname =~ s/<hr>.*//g;
			my $gobi = $Threads->GetAttr($threadid, 'gobi') || '';
			$gobi =~ s/(?:\.|\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
			$noname =~ s/${gobi}$//g;
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージを1に表示
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				if ($content =~ /<hr><font color='red'>※デフォ774→ .+?<\/font>/) {
					$content =~ s|<hr><font color='red'>※デフォ774→ .+?<\/font>|<hr><font color='red'>※デフォ774→ ${noname}</font>|;
				} else {
					$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※デフォ774→ $noname</font>$1|;
				}
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# スレタイにタグ
			if ($Threads->GetAttr($threadid, 'noname') =~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/) {
				my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[乱\]\s|$1|;
					my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
					$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [乱]|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
			}
		} elsif ($msg =~ /!kaijo:774/ && $Threads->GetAttr($threadid, 'noname')) {
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージ消去
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s|<hr><font color='red'>※デフォ774→ .+?<\/font>||;
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# タグ解除
			if ($Threads->GetAttr($threadid, 'noname') =~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/) {
				my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
				my $subjectsData = '';
				if (open(my $fh, "<", $subjects)) {
					my $content = do { local $/; <$fh> };
					$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[乱\]\s|$1|;
					$subjectsData = $content;
					close($fh);
				}
				if (open(my $fh, '>', $subjects)) {
					print $fh $subjectsData;
					close($fh);
				}
			}
			# 属性情報を設定
			$Threads->SetAttr($threadid, 'noname', 0);
			$Threads->SaveAttr($Sys);
		}

		# gobi
		if ($msg =~ /!gobi[:=]?([^:]{0,1000})/) {
			my $gobi = $1;
			$gobi =~ s/<br>.*//g;
			$gobi =~ s/<hr>.*//g;
			my $gobi_prev = $Threads->GetAttr($threadid, 'gobi') || '';
			$gobi_prev =~ s/(?:\.|\?|\*|\+|\(|\)|\[|\]|\^|\$)/\\$1/g;
			$gobi =~ s/${gobi_prev}$//g;
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージを1に表示
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				if ($content =~ /<hr><font color='red'>※GOBI→ .+?<\/font>/) {
					$content =~ s|<hr><font color='red'>※GOBI→ .+?<\/font>|<hr><font color='red'>※GOBI→ ${gobi}</font>|;
				} else {
					$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※GOBI→ $gobi</font>$1|;
				}
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $isrnd = $Threads->GetAttr($threadid, 'gobi') =~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/ ? 1 : 0;
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[尾\]\s|$1|;
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[乱\]\s|$1| if $isrnd;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [尾]|;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [乱]| if $isrnd;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		} elsif ($msg =~ /!kaijo:gobi/ && $Threads->GetAttr($threadid, 'gobi')) {
			# スレのdatのパス
			my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
			my $fpath = "$bbspath/dat/$threadid.dat";
			# datを書き換えて設定メッセージ消去
			my $data = '';
			if (open(my $fh, '<', $fpath)) {
				# flock($fh, 2);
				my $content = do { local $/; <$fh> };
				$content =~ s|<hr><font color='red'>※GOBI→ .+?<\/font>||;
				$data = $content;
				close($fh);
			}
			if (open(my $fh, '>', $fpath)) {
				# flock($fh, 2);
				print $fh $data;
				close($fh);
			}
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[尾\]\s|$1|;
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[乱\]\s|$1| if $Threads->GetAttr($threadid, 'noname') !~ /!(?:randmoji|rmj|animal|emoji|janken|omikuji|\d+D\d+)/;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# 属性解除
			$Threads->SetAttr($threadid, 'gobi', 0);
			$Threads->SaveAttr($Sys);
		}

		# 最大レス数
		if ($msg =~ /!max[:=]?(\d+)/) {
			# 最大レス数
			my $maxres = $1;
			# 処理
			if ($maxres !~ /^0/ && $maxres > 0) {
				# スレのdatのパス
				my $bbspath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
				my $fpath = "$bbspath/dat/$threadid.dat";
				# 最大レス数を適正化
				$maxres = 100000 if $maxres > 100000;
				my $resNum = ARAGORN::GetNumFromFile($fpath);
				if ($maxres < $resNum + 1) {
					$maxres = $resNum + 1
				}
				# 最大レス数を設定
				$Threads->SetAttr($threadid, 'maxres', $maxres);
				# 属性情報を保存
				$Threads->SaveAttr($Sys);
				# datを書き換えて設定メッセージを1に表示
				my $data = '';
				if (open(my $fh, '<', $fpath)) {
					# flock($fh, 2);
					my $content = do { local $/; <$fh> };
					if ($content =~ /<hr><font color='red'>※最大レス数→ \d+?<\/font>/) {
						$content =~ s|<hr><font color='red'>※最大レス数→ \d+?</font>|<hr><font color='red'>※最大レス数→ ${maxres}</font>|;
					} else {
						$content =~ s|(<>)(?=.+)(?!.*<>)|<hr><font color='red'>※最大レス数→ $maxres</font>$1|;
					}
					$data = $content;
					close($fh);
				}
				if (open(my $fh, '>', $fpath)) {
					# flock($fh, 2);
					print $fh $data;
					close($fh);
				}
			}
		}

		# tlvコマンド
		$msg =~ s/!バルサン/!tlv3/;
		if ($msg =~ /!tlv[:=]?(?!.*!tlv[1-9])([1-9]\d{0,2})/) {
			# スレに書き込める忍法帖Lv
			my $tlv = $1;
			$tlv = 100 if $tlv > 100 && !$capID;
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects) && $tlv) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[TLV[1-9]\d*\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [TLV${tlv}]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects) && $tlv) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'tlv', $tlv);
			$Threads->SaveAttr($Sys);
		} elsif ($msg =~/!kaijo:(?:tlv(?!-m)|バルサン)/) {
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[TLV\d+\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'tlv', 0);
			$Threads->SaveAttr($Sys);
		}

		# tlvコマンド
		if ($msg =~ /!tlv-m[:=]?(?!.*!tlv[1-9])([1-9]\d{0,2})/) {
			# スレに書き込める忍法帖Lv
			my $tlv = $1;
			$tlv = 100 if $tlv > 100 && !$capID;
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects) && $tlv) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[TLVm[1-9]\d*\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [TLVm${tlv}]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects) && $tlv) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'tlvm', $tlv);
			$Threads->SaveAttr($Sys);
		} elsif ($msg =~/!kaijo:tlv-m/) {
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[TLVm\d+\]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'tlvm', 0);
			$Threads->SaveAttr($Sys);
		}

		# noriben
		if ($msg =~ /!noriben/) {
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[海苔]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [海苔]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'noriben', 1);
			$Threads->SaveAttr($Sys);
		} elsif ($msg =~/!kaijo:noriben/) {
			# タグ解除
			my $subjects	= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/subject.txt';
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\s\[海苔]|$1|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
			# スレの属性を設定し保存
			$Threads->SetAttr($threadid, 'noriben', 0);
			$Threads->SaveAttr($Sys);
		}

		if ($msg =~/!unlock(?:send|pay|throw)/) {
			# スレタイにタグ
			my $subjects	= $Sys->Get('BBSPATH') . "/${bbs}/subject.txt";
			my $subjectsData = '';
			if (open(my $fh, "<", $subjects)) {
				my $content = do { local $/; <$fh> };
				$content =~ s|(?<=${threadid}\.dat<>)(.*?)\[&#x1f337;\]\s|$1|;
				my $kisha = '\\s\\[.+★\\]' if $content =~ /${threadid}\.dat<>.+\s\[.+★\]/;
				$content =~ s|(?<=${threadid}\.dat<>)(.+)(?=${kisha}\s\([1-9]\d*\))|$1 [&#x1f337;]|;
				$subjectsData = $content;
				close($fh);
			}
			if (open(my $fh, '>', $subjects)) {
				print $fh $subjectsData;
				close($fh);
			}
		}

		# スレッド情報を再保存
		if ($modified) {
			$Threads->Save($Sys);
		} else {
			$Threads->Close();
		}

	}

}

#------------------------------------------------------------------------------------------------------------
#	リモホ取得
#	-------------------------------------------------------------------------------------
sub Resolver {
  my $ip = shift;
  my $res = Net::DNS::Resolver->new;
  my $ans = $res->query($ip, 'PTR', 'IN');
  if ( ! $ans  ) {
    return $ip;
  }
  my $ret = $ip;
  for my $rr ( $ans->answer ) {
    if ( $rr->type eq 'PTR' ) {
      $ret = $rr->ptrdname;
      last;
    }
  }
  return $ret;
}

#------------------------------------------------------------------------------------------------------------
#	なんちゃってbbs.cgiエラーページ表示
#------------------------------------------------------------------------------------------------------------
sub PrintBBSError
{
	my ($Sys, $err) = @_;
	
	require './module/orald.pl';
	
	my $CGI = $Sys->Get('MainCGI');
	my $Page = $CGI->{'PAGE'};
	
	my $Error = ORALD->new;
	$Error->Load($Sys);
	$Error->Print($CGI, $Page, $err, $Sys->Get('AGENT'));
	
	$Page->Flush('', 0, 0);
	
	exit($err);
}

#------------------------------------------------------------------------------------------------------------
#	bbs.cgiエラーページ表示（忍法帖専用）
#------------------------------------------------------------------------------------------------------------
sub PrintBBSError_Ninja
{
	my ($Sys, $err, $koyuu, $lim1, $lim2) = @_;
	
	my $CGI = $Sys->Get('MainCGI');
	my $Page = $CGI->{'PAGE'};
	my $version = $Sys->Get('VERSION');
	
	# エラーログを保存
	require './module/peregrin.pl';
	my $Log = PEREGRIN->new;
	$Log->Load($Sys, 'ERR', '');
	$Log->Set('', $err, $version, $koyuu, $Sys->Get('AGENT'));
	$Log->Save($Sys);

	if ($err == 10001) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>スレ立ては、忍法帖Lv${lim1}以上でできます。認証板で認証すれば立てられるようになるかもしれません。<br>認証板はこちら↓</font><br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a></font><hr>");
	}

	if ($err == 10002) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このパスワードは使えません。漏れてるか、弱すぎます。推測されにくいパスワードにしてください。</font><hr>");
	}

	if ($err == 10003) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>この板では、あなたはスレ立て制限中です。ルール守ってください。（期間：残り${lim1}日）</font><hr>");
	}

	if ($err == 10004) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレは、忍法帖Lv${lim1}未満の人は書き込めないように設定されています。認証板で認証すれば立てられるようになるかもしれません。<br>認証板はこちら↓</font><br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a></font><hr>");
	}

	if ($err == 10005) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在のLvでは、文字数・改行数が制限されています。（時間が経てばこのエラーは表示されなくなります。）</font><hr>");
	}

	if ($err == 10006) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>パスワードはメール欄に入れてください。</font><hr>");
	}

	if ($err == 10007) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>書き込み制限中です。身に覚えのない場合はエラー報告板で報告お願いします。（無料VPNを利用して書き込んだことがある場合は受け付けません。）<br>エラー報告板はこちら↓</font><a href='https://vanilla.sannan.nl/error/' target='_blank'>https://vanilla.sannan.nl/error/</a><hr>");
	}

	if ($err == 10009) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>この板では、あなたはレス制限中です。ルール守ってください。（期間：残り${lim1}日）</font><hr>");
	}

	if ($err == 10010) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>新規の方の書き込みが集中しているため、このスレではLv${lim1}以下の方の投稿を制限中です。(認証板で認証すれば書き込めるかも）暫くしてからまた試してください。<br>認証板はこちら↓</font><br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a><hr>");
	}

	if ($err == 10011) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>24時間BANです。</font><hr>");
	}

	if ($err == 10012) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>Lv${lim1}以下はスレ立て制限中。暫くしてからまた試してください。</font><hr>");
	}

	if ($err == 10013) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在のLvでは、スレ立ては${lim1}分に1スレまで</font><hr>");
	}

	if ($err == 10014) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在の忍法帖Lvでの投稿数制限に達しました。暫く待ってください。（残り：${lim1}秒 Liveモードスレなら今でも書けます。）</font><hr>");
	}

	if ($err == 10015) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>荒らし対策のため、このスレはLv${lim1}以下の方の投稿を制限中です。${lim2}分くらい経ってからまた試してください。</font><hr>");
	}

	if ($err == 10016) {
		my $authID = md5_hex($koyuu);
		my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
		$Cookie->Set('authid', $authID);
		my $Set = $CGI->{'SET'};
		$Cookie->Out($Page, $Set->Get('BBS_COOKIEPATH'), 60 * 24 * 30);
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		my $ua = "$ENV{'HTTP_USER_AGENT'}";
		if ($ua =~ /^Mozilla\/\d\.\d\s\(Windows\sNT\s\d{2}\.\d;\sTrident\/\d\.\d;\srv:\d{2}.\d\)\slike\sGecko|monazilla|siki/i) {
		$Page->Print("<body><font color=red>書き込むには、画像認証をお願いします。（専ブラの仕様では押しても開けないので、ブラウザにコピペして開いてください。）</font><br><a href='https://sannan.nl/auth.php?authid=$authID' target='_blank'>https://sannan.nl/auth.php?authid=$authID</a><hr>");
		} else {
		$Page->Print("<body><font color=red>↓のURLから画像認証をお願いします。</font><br><a href='https://sannan.nl/auth.php?authid=$authID' target='_blank'>https://sannan.nl/auth.php?authid=$authID</a><hr>");
		}
	}

	if ($err == 10017) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>Lv${lim1}以下の人は、連続で立てられる回数が制限されています。他の人がスレ立てするのを待ってください。</font><hr>");
	}

	if ($err == 10018) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>エラーコード:10018 あなたが人間ならこれは誤判定です、すみません。誤判定の場合は、エラー報告板で報告お願いします。</font><hr>");
	}

	if ($err == 10019) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>規制対象のIPから投稿しようとしたため制限中です。（新規の人がVPNなどを使った場合のエラーです。）認証板で忍法帖レベルを${lim1}まで上げれば書き込めるようになります。</font><br>認証板はこちら↓<br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a><hr>");
	}

	if ($err == 10020) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>パスワードを「：」で囲ってください。</font><hr>");
	}

	if ($err == 10021) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>使用回数上限に達したため、このコマンドは来月まで制限中。</font><hr>");
	}

	if ($err == 10022) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>新規登録者が集中しているため暫くお待ちください。認証板で認証すれば書き込める可能性があります。<br>認証板はこちら↓<br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a></font><hr>");
	}

	if ($err == 10023) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>対応していないレスです。</font><hr>");
	}

	if ($err == 10024) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>Lv${lim1}以上でないと、削除コマンドは使用できません。削除依頼してください。</font><hr>");
	}

	if ($err == 10025) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>1日に削除できるレス数は${lim1}レスまでです。削除依頼してください。</font><hr>");
	}

	if ($err == 10026) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>強制コテ処分期間中はこのスレに書き込めません。</font><hr>");
	}

	if ($err == 10027) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在のレベルでは、リンクは投稿できません。（レベルが上がると、このエラーは出なくなります。）</font><hr>");
	}

	if ($err == 10028) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>マルチポストですか？投稿文を変えてください。（レベルが上がると、このエラーは出なくなります。）</font><hr>");
	}

	if ($err == 10030) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このコマンドを使用するには、チューリップが${lim1}g必要です。(チューリップは、認証やレベルアップで増やせます。</font><hr>");
	}

	if ($err == 10031) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在のレベルでは、画像は投稿できません。（レベルが上がると、このエラーは出なくなります。）</font><hr>");
	}

	if ($err == 10032) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>現在のレベルでは、数値文字参照や絵文字の数は制限されています。（レベルが上がると、このエラーは出なくなります。）</font><hr>");
	}

	if ($err == 10033) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>ninは廃止されました。save/loadを使用してください。</font><hr>");
	}

	if ($err == 10034) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>パスワードが違います。変更する場合はsaveで新しいパスワードを入力してください。</font><hr>");
	}

	if ($err == 10035) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>save/loadは名前欄入力に変更になりました。コマンド名の前に「#!」、後に「:」を付けてください。</font><hr>");
	}

	if ($err == 10036) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>パスワードに使えない文字が入っています。</font><hr>");
	}

	if ($err == 10037) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレでは使えません。</font><hr>");
	}

	if ($err == 10038) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>lvdnが増加しました。ルールを守りましょう。理由は運営削除板でご確認ください。※このエラーは増加後に一度だけ出ます。</font><hr>");
	}

	if ($err == 10039) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>忍法帖レベルが足りないため、このコマンドの使用は制限されています。</font><hr>");
	}

	if ($err == 10040) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>既にスレを沢山立てたため、チューリップが必要です。認証などでチューリップを稼ぐか、次の日の朝まで待ってください。</font><hr>");
	}

	if ($err == 10041) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>チューリップ不足です。</font><hr>");
	}

	if ($err == 10042) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>この板では日本語禁止です。</font><hr>");
	}

	if ($err == 10043) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>新規の方は認証板でレベルアップお願いします。</font><br>認証板はこちら↓<br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a><hr>");
	}

	if ($err == 10044) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>暫くしてから再度ロードを試してください。</font><hr>");
	}

	if ($err == 10045) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このIPでは書き込めません。</font><hr>");
	}

	if ($err == 10046) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレは、Lv${lim1}以上でないと書き込めません。</font><hr>");
	}

	if ($err == 10047) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレは、数値文字参照禁止です。（絵文字は使えません。）</font><hr>");
	}

	if ($err == 10048) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>新規の方は専ブラを使うか、別の回線・端末(スマホ)から忍法帖レベル上げをしてください。</font><hr>");
	}

	if ($err == 10049) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレは、スマホ回線では忍法帖Lv${lim1}以上でないと書き込めないように設定されています。認証板で認証すれば立てられるようになるかもしれません。<br>認証板はこちら↓</font><br><a href='https://sannan.nl/auth/' target='_blank'>https://sannan.nl/auth/</a></font><hr>");
	}

	if ($err == 10050) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレは、画像・動画リンクが禁止に設定されています。</font><hr>");
	}

	if ($err == 10051) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>忍法帖Lv${lim1}未満は、!rmjコマンドの使用は制限されています。</font><hr>");
	}

	if ($err == 10052) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>忍法帖Lv${lim1}未満は、RLOの使用は制限されています。</font><hr>");
	}

	if ($err == 10053) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレの最大書き込み行数は${lim1}に設定されています。</font><hr>");
	}

	if ($err == 10054) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>このスレの最大書き込みバイト数は${lim1}に設定されています。</font><hr>");
	}

	if ($err == 10055) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>無効なchttコマンドです。</font><hr>");
	}

	if ($err == 10056) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>あなたの忍法帖レベルでの1日の通報数上限に達しました。</font><hr>");
	}

	if ($err == 10057) {
		$Page->Print("Content-type: text/html\n\n");
		$Page->Print("<html><head><title>");
		$Page->Print("ERROR!</title></head><meta charset=\"Shift_JIS\"><!--nobanner-->\n");
		$Page->Print("<body><font color=red>一日に複数回Nopoolコマンドを使用する場合は、!nopool:fと打ってください。</font><hr>");
	}

	$Page->Flush('', 0, 0);
	
	exit($err);
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
