#============================================================================================================
#
#	忍法帖情報管理パッケージ
#
#============================================================================================================
package	SLIP;

use strict;
use utf8;
use warnings;
use CGI::Session;
use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use Net::Whois::Raw;
use Geo::IP;
use Storable qw(store retrieve);
#------------------------------------------------------------------------------------------------------------
#	SLIP生成
#------------------------------------------------------------------------------------------------------------
sub generate_name_field {
    my ($res, $bbs_slip, $thslip, $name, $bbsflag, $bbs_noname) = @_;
    my $zero = 1;
    if ($bbs_slip !~ /^v{3,6}/ && $thslip !~ /^v{3,6}/ && $name !~ /!slip:v{3,6}/ && !$bbsflag) {
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
    $res =~ s/\s.{4}-.{4}// if $bbs_slip !~ /^v{4,6}/ && $thslip !~ /^v{4,6}/ && $name !~ /!slip:v{4,6}/ && !$bbsflag && $zero;
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
			'^.*\\.(vpn|tor|proxy|private)$',
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
	my $tor_ip_txt = "$infoDir/tor-ip.txt";
    $isAnon += ListCheck($ipAddr,$vpngate_ip_txt) ;
	$isAnon += ListCheck($ipAddr,$tor_ip_txt);

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

    my $res = whois($ipAddr);
    for my $line (split /\n/, $res) {
        if ($line =~ /country:\s*([A-Z]{2})/i) {
            $country = $1;
            last;
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
		my $isSlipName5ch = 1;
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

sub GetTorExitNodeList
{
	my ($fileName) = @_;
	# 新しいUserAgentオブジェクトを作成
	my $ua = LWP::UserAgent->new;

	# HTTPリクエストを送信し、レスポンスを受け取る
	my $response = $ua->get('https://check.torproject.org/exit-addresses');

	if ($response->is_success) {
		# レスポンスのコンテンツを取得
		my $content = $response->decoded_content;

		# IPアドレスを格納するためのハッシュ
		my %ips;

		# 正規表現を使用してExitAddressを検索し、IPアドレスをハッシュに保存（重複排除）
		while ($content =~ /ExitAddress (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/g) {
			$ips{$1} = 1;
		}

		# ファイルにIPアドレスを保存
		open(my $fh, '>', $fileName);
		foreach my $ip (keys %ips) {
			print $fh "$ip\n";
		}
		close $fh;
		return 1;
	}
	return 0;
}
sub GetVPNGateList
{
	my ($fileName) = @_;
	# 新しいUserAgentオブジェクトを作成
	my $ua = LWP::UserAgent->new;

	# HTTPリクエストを送信し、レスポンスを受け取る
	my $response = $ua->get('http://www.vpngate.net/api/iphone/');

	if ($response->is_success) {
		# レスポンスのコンテンツを取得
		my $content = $response->decoded_content;

		# IPアドレスを格納するためのハッシュ
		my %ips;

		# IPアドレスをハッシュに保存（重複排除）
		while ($content =~ /,(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}),/g) {
			$ips{$1} = 1;
		}

		# ファイルにIPアドレスを保存
		open(my $fh, '>', $fileName);
		foreach my $ip (keys %ips) {
			print $fh "$ip\n";
		}
		close $fh;
		return 1;
	}
	return 0;
}
sub ListCheck {
    my ($ipAddr, $fileName) = @_;

    # ファイルハンドルの宣言
    my $fh;

    # ファイルを開けるかチェック
    unless (open($fh, '<', $fileName)) {
        return undef;
    }

    # 保存されたIPアドレスを読み込む
    my %saved_ips = map { chomp; $_ => 1 } <$fh>;
    close $fh;

    # ユーザーのIPアドレスがリストにあるかどうかをチェック
    return 1 if (exists $saved_ips{$ipAddr});
    return 0;
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
    my $yday2 = '';
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
			$slip_nickname = 'anon';	
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
	my $noid = $Threads->GetAttr($threadid, 'noid') || 0;
	$noid = 1 if $bbs eq 'noid';
	#idを設定
	$id = $Form->Set('idpart', $id) if !$noid;

	# bbs_slipを生成
	my $kaisen = $idEnd ne '0' && !$noid ? " </b> ($idEnd)<b>" : '';
	my $slip_result = "$kaisen </b>(${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc})<b>";

	return $slip_result;
}
sub BBS_SLIP_OLD
{
	my ($ip_addr, $remoho, $ua, $bbsslip) = @_;
	my ($slip_ip, $slip_remoho, $slip_ua);

	$Net::Whois::Raw::OMIT_MSG = 1;

	#bbs_slipに使用する文字
	my @slip_char = (0..9, "a".."z", "A".."Z", ".", "/");
	#slip_ip生成
	$ip_addr =~ /^(\d{1,4})\.(\d{1,4})/;
	my $ip_char1 = $slip_char[$1 % 64];
	my $ip_char2 = $slip_char[$2 % 64];
	$slip_ip = $ip_char1 . $ip_char2;

	#slip_remoho生成
	if ($remoho eq "") {
		$slip_remoho = "none";
	}else {
		$remoho =~ /^([a-zA-Z]+)[\d\-\.]*([a-zA-Z][a-zA-Z\d\.\-]+)$/;
		my $remoho_name = "$1 $2";
		my $remoho_dig = md5_hex($remoho_name);
		$remoho_dig =~ /^(.{2})(.{2})/;
		my $remoho_char1 = $slip_char[hex($1) % 64];
		my $remoho_char2 = $slip_char[hex($2) % 64];
		$slip_remoho = $remoho_char1 . $remoho_char2;
	}

	#slip_ua生成
	my $ua_dig = md5_hex($ua);
	$ua_dig =~ /^(.{2})(.{2})(.{2})(.{2})/;
	my $ua_char1 = $slip_char[hex($1) % 64];
	my $ua_char2 = $slip_char[hex($2) % 64];
	my $ua_char3 = $slip_char[hex($3) % 64];
	my $ua_char4 = $slip_char[hex($4) % 64];
	$slip_ua = $ua_char1 . $ua_char2 . $ua_char3 . $ua_char4;


	#スマホ・タブレット判定
	my $fixed_nickname_end = "";
	my $mobile_nickname_end = "";
	if ($ua =~ /.*(iphone|ipad|android|mobile).*/i) {
		$fixed_nickname_end = "W";
		$mobile_nickname_end = "M";
	}else {
		$mobile_nickname_end = "T";
	}


	#bbs_slipの初期設定
	my $slip_id = "";
	my $slip_nickname = "ﾜｯﾁｮｲ${fixed_nickname_end}";
	my $slip_aa = $slip_ip;
	my $slip_bb = $slip_remoho;
	my $slip_cccc = $slip_ua;


	#モバイル回線判定用のリモホ・事業者名・IP
	my @mobile_remoho = (
		".*\\.openmobile\\.ne\\.jp",
		".*\\.panda-world\\.ne\\.jp",
		"KD027.*\\.au-net\\.ne\\.jp",
		"KD036.*\\.au-net\\.ne\\.jp",
		"KD106.*\\.au-net\\.ne\\.jp",
		"KD111.*\\.au-net\\.ne\\.jp",
		"KD119.*\\.au-net\\.ne\\.jp",
		"KD182.*\\.au-net\\.ne\\.jp",
		".*\\.msa\\.spmode\\.ne\\.jp",
		".*\\.msb\\.spmode\\.ne\\.jp",
		".*\\.msc\\.spmode\\.ne\\.jp",
		".*\\.msd\\.spmode\\.ne\\.jp",
		".*\\.mse\\.spmode\\.ne\\.jp",
		".*\\.msf\\.spmode\\.ne\\.jp",
		".*\\.fix\\.mopera\\.net",
		".*\\.air\\.mopera\\.net",
		".*\\.vmobile\\.jp",
		".*\\.bmobile\\.ne\\.jp",
		".*\\.mineo\\.jp",
		".*omed01\\.tokyo\\.ocn\\.ne\\.jp",
		".*omed01\\.osaka\\.ocn\\.ne\\.jp",
		".*mobac01\\.tokyo\\.ocn\\.ne\\.jp",
		".*mobac01\\.osaka\\.ocn\\.ne\\.jp",
		".*\\.mvno\\.rakuten\\.jp",
		".*\\.nttpc\\.ne\\.jp",
		"UQ.*au-net\\.ne\\.jp",
		"dcm\\d(?:-\\d+){4}\\.tky\\.mesh\\.ad\\.jp",
		"neoau\\d(?:-\\d+){4}\\.tky\\.mesh\\.ad\\.jp",
		".*\\.ap\\.dream\\.jp",
		".*\\.ap\\.mvno\\.net",
		"fenics\\d+\\.wlan\\.ppp\\.infoweb\\.ne\\.jp"
	);
	my @mobile_whois = (
		"Plus One marketing",
		"LogicLinks",
		"SORASIM"
	);
	my @rakuten_mno_ip = (
		"101\\.102\\.(?:\\d|[1-5]\\d|6[0-3])\\.\\d{1,3}",
		"103\\.124\\.[0-3]\\.\\d{1,3}",
		"110\\.165\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}",
		"119\\.30\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}",
		"119\\.31\\.1(?:2[89]|[3-5]\\d)\\.\\d{1,3}",
		"133\\.106\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}",
		"133\\.106\\.(?:1[6-9]|2\\d|3[01])\\.\\d{1,3}",
		"133\\.106\\.(?:3[2-9]|[45]\\d|6[0-3])\\.\\d{1,3}",
		"133\\.106\\.(?:6[4-9]|[7-9]\\d|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}",
		"133\\.106\\.(?:[89]|1[0-5])\\.\\d{1,3}",
		"157\\.192(?:\\.\\d{1,3}){2}",
		"193\\.114\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}",
		"193\\.114\\.(?:3[2-9]|[45]\\d|6[0-3])\\.\\d{1,3}",
		"193\\.114\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}",
		"193\\.115\\.(?:\\d|[12]\\d|3[01])\\.\\d{1,3}",
		"193\\.117\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}",
		"193\\.118\\.(?:\\d|[12]\\d|3[01])\\.\\d{1,3}",
		"193\\.118\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}",
		"193\\.119\\.(?:1(?:2[89]|[3-9]\\d)|2\\d{2})\\.\\d{1,3}",
		"193\\.82\\.1(?:[6-8]\\d|9[01])\\.\\d{1,3}",
		"194\\.193\\.2(?:2[4-9]|[34]\\d|5[0-5])\\.\\d{1,3}",
		"194\\.193\\.(?:6[4-9]|[78]\\d|9[0-5])\\.\\d{1,3}",
		"194\\.223\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}",
		"202\\.176\\.(?:1[6-9]|2\\d|3[01])\\.\\d{1,3}",
		"202\\.216\\.(?:\\d|1[0-5])\\.\\d{1,3}",
		"210\\.157\\.(?:19[2-9]|2(?:[01]\\d|2[0-3]))\\.\\d{1,3}",
		"211\\.133\\.(?:[6-8]\\d|9[01])\\.\\d{1,3}",
		"211\\.7\\.(?:[9][6-9]|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}",
		"219\\.105\\.1(?:4[4-9]|5\\d)\\.\\d{1,3}",
		"219\\.105\\.(?:19[2-9]|2\\d{2})\\.\\d{1,3}",
		"219\\.106\\.(?:\\d{1,2}|1(?:[01]\\d|2[0-7]))\\.\\d{1,3}"
	);

	#モバイル回線のslip_id
	my @mobile_ids = (
		"Sr",
		"Sp",
		"Sa",
		"Sd",
		"SD",
		"MM"
	);

	#モバイル回線のニックネーム
	my @mobile_nicknames = (
		"ｵｯﾍﾟｹ${mobile_nickname_end}",
		"ｻｻｸｯﾃﾛ${mobile_nickname_end}",
		"ｱｳｱｳｱｰ${mobile_nickname_end}",
		"ｱｳｱｳｲｰ${mobile_nickname_end}",
		"ｱｳｱｳｳｰ${mobile_nickname_end}",
		"ｱｳｱｳｴｰ${mobile_nickname_end}",
		"ｱｳｱｳｵｰ${mobile_nickname_end}",
		"ｱｳｱｳｶｰ${mobile_nickname_end}",
		"ｽﾌﾟｰ${mobile_nickname_end}",
		"ｽﾌﾟｯｯ${mobile_nickname_end}",
		"ｽｯﾌﾟ${mobile_nickname_end}",
		"ｽｯｯﾌﾟ${mobile_nickname_end}",
		"ｽﾌﾟﾌﾟ${mobile_nickname_end}",
		"ｽﾌｯ${mobile_nickname_end}",
		"ﾍﾟﾗﾍﾟﾗ${mobile_nickname_end}",
		"ｴｱﾍﾟﾗ${mobile_nickname_end}",
		"ﾌﾞｰｲﾓ${mobile_nickname_end}",
		"ﾍﾞｰｲﾓ${mobile_nickname_end}",
		"ｵｲｺﾗﾐﾈｵ${mobile_nickname_end}",
		"ﾜﾝﾄﾝｷﾝ${mobile_nickname_end}",
		"ﾜﾝﾐﾝｸﾞｸ${mobile_nickname_end}",
		"ﾊﾞｯﾄﾝｷﾝ${mobile_nickname_end}",
		"ﾊﾞｯﾐﾝｸﾞｸ${mobile_nickname_end}",
		"ﾗｸｯﾍﾟﾍﾟ${mobile_nickname_end}",
		"ﾗｸﾗｯﾍﾟ${mobile_nickname_end}",
		"ｱｳｱｳｸｰ${mobile_nickname_end}",
		"ﾄﾞｺｸﾞﾛ${mobile_nickname_end}",
		"ﾄﾞﾅﾄﾞﾅｰ${mobile_nickname_end}",
		"ﾄﾝﾓｰ${mobile_nickname_end}",
		"ｱﾒ${mobile_nickname_end}",
		"ﾆｬﾌﾆｬ${mobile_nickname_end}",
		"ｲﾙｸﾝ${mobile_nickname_end}",
		"ｹﾞﾏｰ${mobile_nickname_end}",
		"ﾌﾘｯﾃﾙ${mobile_nickname_end}"
	);

	#公衆Wi-Fiのリモホ・ネットワーク名・IP
	my @fwifi_remoho = (
		".*\\.m-zone\\.jp",
		"\\d+\\.wi-fi\\.kddi\\.com",
		".*\\.wi-fi\\.wi2\\.ne\\.jp",
		".*\\.family-wifi\\.jp"
	);
	my @fwifi_whois = (
		"INPLUS-FWIFI",
		"FON"
	);
	my $lawson_ip = "210\\.227\\.19\\.[67]\\d\$";
	#公衆Wi-FiのID
	my $fwifi_id = "FF";
	#公衆Wi-Fiのニックネーム
	my @fwifi_nicknames = (
		"ｴﾑｿﾞﾈ${fixed_nickname_end}[公衆]",
		"ｱｳｳｨﾌ${fixed_nickname_end}[公衆]",
		"ﾜｲｰﾜ2${fixed_nickname_end}[公衆]",
		"ﾌｧﾐﾏ${fixed_nickname_end}[公衆]",
		"ﾌｫﾝﾌｫﾝ${fixed_nickname_end}[公衆]",
		"ﾏｸﾄﾞ${fixed_nickname_end}[公衆]"
	);

	#逆引き判定
	if ($slip_remoho eq "none") { #逆引きできない場合
		my $isunknown = "yes";
		my $res = whois($ip_addr);

		#モバイル回線判定
		my $mobile_nickname_idx = -1;
		for my $name (@mobile_whois) {
			if ($res =~ /.*${name}.*/) {
				$slip_id = "MM";
				$slip_nickname = $mobile_nicknames[$mobile_nickname_idx];
				$slip_aa = $slip_id;
				$slip_bb = $slip_ip;
				$isunknown = "no";
				last;
			}
			$mobile_nickname_idx--;
		}
		#楽天モバイル(MNO)判定
		if ($isunknown eq "yes") {
			for my $name (@rakuten_mno_ip) {
				if ($ip_addr =~ /${name}/) {
					$slip_id = "MM";
					$slip_nickname = "ﾃﾃﾝﾃﾝﾃﾝM";
					$slip_aa = $slip_id;
					$slip_bb = $slip_ip;
					$isunknown = "no";
					last;
				}
			}
		}

		#公衆判定
		if ($isunknown eq "yes") {
			my $fwifi_nickname_idx = -1;
			for my $name (@fwifi_whois) {
				if ($res =~ /.*${name}.*/) {
					$slip_id = $fwifi_id;
					$slip_nickname = $fwifi_nicknames[$fwifi_nickname_idx];
					$slip_aa = $slip_id;
					$slip_bb = $slip_ip;
					$isunknown = "no";
					last;
				}
				$fwifi_nickname_idx--;
			}
		}
		#ローソン判定
		if ($isunknown eq "yes") {
			if ($ip_addr =~ /${lawson_ip}/) {
				$slip_id = "FF";
				$slip_nickname = "ﾛｰｿﾝ${fixed_nickname_end}[公衆]";
				$slip_aa = $slip_id;
				$slip_bb = $slip_ip;
				$isunknown = "no";
			}
		}

		#逆引き不可能 ｱﾝﾀﾀﾞﾚ
		if ($isunknown eq "yes") {
			$slip_id = "Un";
			$slip_nickname = "ｱﾝﾀﾀﾞﾚ${fixed_nickname_end}";
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
		}
	}else{ #逆引きできる場合
		my $ismobile = 0;
		#モバイル回線判定
		my $mobile_id_idx = 0;
		my $mobile_nickname_idx = 0;
		for my $name (@mobile_remoho) {
			if ($remoho =~ /^${name}$/) {
				$slip_id = $mobile_ids[$mobile_id_idx];
				$slip_nickname = $mobile_nicknames[$mobile_nickname_idx];
				$slip_aa = $slip_id;
				$slip_bb = $slip_ip;
				$ismobile = 1;
				last;
			}
			if ($mobile_id_idx < 2 || $mobile_nickname_idx =~ /^(7|9|15)$/) {
				$mobile_id_idx++;
			}
			$mobile_nickname_idx++;
		}

		#公衆判定
		if ($ismobile == 0) {
			my $fwifi_nickname_idx = 0;
			for my $name (@fwifi_remoho) {
				if ($remoho =~ /^${name}$/) {
					$slip_id = $fwifi_id;
					$slip_nickname = $fwifi_nicknames[$fwifi_nickname_idx];
					$slip_aa = $slip_id;
					$slip_bb = $slip_ip;
					last;
				}
				$fwifi_nickname_idx++;
			}
		}

  #社畜判定
  if ($ismobile == 0) {
    if ($remoho =~ /^.+\.co\.jp$/) {
      $slip_nickname = "ｼｬﾁｰｸ${fixed_nickname_end}";
    }
  }
}

	# Geo::IPがインストールされているかチェック
	my $geo_ip_installed = 0;#軽量化

	# 国を判定
	my $gi_dat = "./datas/GeoIPCity.dat";
	if ($geo_ip_installed && -f $gi_dat) {
	    my $gi = Geo::IP->open($gi_dat, GEOIP_STANDARD);
	    my $record = $gi->record_by_addr($ip_addr);
	    my $ip_country =  $record->country_code;
	    if ($ip_country =~ /^(?!.*JP).*$/) {
	        $slip_nickname = "ｶﾞｲｺｰｸ${fixed_nickname_end}[${ip_country}]";
	        $slip_aa = $ip_country;
	        $slip_bb = $slip_ip;
	    }
	}

	#bbs_slipを生成
	my $slip_result = 'undef';
	if($bbsslip eq 'vvv'){
		$slip_result = ${slip_nickname};
	}
	elsif($bbsslip eq 'vvvv'){
		$slip_result = "${slip_nickname} [${ip_addr}]";
	}
	elsif($bbsslip eq 'vvvvv'){
		$slip_result = "${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc}";
	}
	elsif($bbsslip eq 'vvvvvv'){
		$slip_result = "${slip_nickname} ${slip_aa}${slip_bb}-${slip_cccc} [${ip_addr}]";
	}

	return $slip_result;
}
#============================================================================================================
#	モジュール終端
#============================================================================================================
1;