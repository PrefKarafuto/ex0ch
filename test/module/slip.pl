#============================================================================================================
#
#	BBS_SLIP生成パッケージ
#
#============================================================================================================
package	SLIP;

use strict;
use utf8;
use warnings;
use CGI::Session;
use CGI::Cookie;
use Digest::MD5 qw(md5_hex);
use JSON;
use LWP::UserAgent;
use Storable qw(store retrieve);
# コンストラクタ
sub new
{
	my $class = shift;
	
	my $obj = {};
	bless $obj, $class;
	
	return $obj;
}
#------------------------------------------------------------------------------------------------------------
#	各種判定
#------------------------------------------------------------------------------------------------------------
# 拒否IP
sub is_denied_ip {
    my ($ipAddr, $infoDir) = @_;

    my $denyIP_file = ".$infoDir/IP_List/deny.cgi";

    # ファイルが存在しない場合はすぐに0を返す
    return 0 unless -e $denyIP_file;

    # ファイルからハッシュテーブルを読み込む
    my $denied_ips = retrieve($denyIP_file);

    # IPアドレスがハッシュテーブルに存在するかチェック
    return exists $denied_ips->{$ipAddr} ? 1 : 0;
}


# 匿名化判定
sub is_anonymous {
    my ($isFwifi, $country, $remoho, $ipAddr, $infoDir) = @_;
    my $isAnon = 0;

    if (!$isFwifi && $country eq 'JP' && $remoho ne $ipAddr) {
        my @anon_remoho = (
            '^.*\\.(vpngate\\.v4\\.open\\.ad\\.jp|opengw\\.net)$',
			'(vpn|tor|proxy|onion)',
            '^.*\\.(?:ablenetvps\\.ne\\.jp|amazonaws\\.com|arena\\.ne\\.jp|akamaitechnologies\\.com|cdn77\\.com|cnode\\.io|datapacket\\.com|digita-vm\\.com|googleusercontent\\.com|hmk-temp\\.com||kagoya\\.net|linodeusercontent\\.com|sakura\\.ne\\.jp|vultrusercontent\\.com|xtom\\.com)$',
            '^.*\\.(?:tsc-soft\\.com|53ja\\.net)$'
        );

        for my $name (@anon_remoho) {
            if ($remoho =~ /(?:${name})/i) {
                $isAnon = 1;
                last;
            }
        }
    }

    return $isAnon;
}

# 公衆Wifi判定
sub is_public_wifi {
    my ($country, $ipAddr, $remoho) = @_;
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


# モバイル判定
sub is_mobile {
    my ($country, $ipAddr, $remoho) = @_;

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
			"lib"
			);
		@mobile_nicknames = (
			"ｵｯﾍﾟｹｰ",
			"ｵｯｯﾍﾟｹ",
			"ｵｯﾍﾟｹｴ",
			"ｵｯﾍﾟｹｹ",
			"ｻｻｸｯﾃﾛﾗ",
			"ｻｻｸｯﾃﾛﾘ",
			"ｻｻｸｯﾃﾛﾙ",
			"ｻｻｸｯﾃﾛﾚ",
			"ﾊｹﾞ",
			"ｱｳｱｳｱｰ",
			"ｱｳｱｳｲｰ",
			"ｱｳｱｳｳｰ",
			"ｱｳｱｳｴｰ",
			"ｱｳｱｳｵｰ",
			"ｱｳｱｳｶｰ",
			"ｱｳｱｳｹｰ",
			"ｽﾌﾟｰ",
			"ｽﾌﾟｯｯ",
			"ｽｯﾌﾟ",
			"ｽｯｯﾌﾟ",
			"ｽﾌﾟﾌﾟ",
			"ｽﾌｯ",
			"ｽｯﾌﾟｰ",
			"ｽﾌﾟﾌﾟｰ",
			"ﾍﾞﾗﾍﾟﾗ",
			"ｴｱﾍﾟﾗ",
			"ﾌﾞｰｲﾓ",
			"ﾍﾞｰｲﾓ",
			"ｵｲｺﾗﾐﾈｵ",
			"ﾜﾝﾄﾝｷﾝ",
			"ﾜﾝﾐﾝｸﾞｸ",
			"ﾊﾞｯﾄﾝｷﾝ",
			"ﾊﾞｯﾐﾝｸﾞｸ",
			"ﾗｸｯﾍﾟﾍﾟ",
			"ﾗｸﾗｯﾍﾟ",
			"ｱｳｱｳｸｰ",
			"ﾄﾞｺｸﾞﾛ",
			"ﾄﾞﾅﾄﾞﾅ",
			"ﾄﾝﾓｰ",
			"ｱﾒ",
			"ﾆﾌﾓ",
			"ﾘﾌﾞﾓ"
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
						$ismobile = $isSlipName5ch ? 'ﾃﾃﾝﾃﾝﾃﾝ' : 'ten';
						last;
					}
				}
			}
			my @sorasim_ip = (
				'103\\.41\\.25[2-5]\\.\\d{1,3}',
				'153\\.124\\.(16[8-9]|17[0-5])\\.\\d{1,3}'
			);
			if (!$ismobile) {
				for my $name (@sorasim_ip) {
					if ($ipAddr =~ /.*${name}.*/) {
						$ismobile = $isSlipName5ch ? 'ｲﾙｸﾝ' : 'mkun';
						last;
					}
				}
			}
			my @logiclinks_ip = (
				'103\\.90\\.1[6-9]\\.\\d{1,3}',
				'219\\.100\\.18[0-3]\\.\\d{1,3}'
			);
			if (!$ismobile) {
				for my $name (@logiclinks_ip) {
					if ($ipAddr =~ /.*${name}.*/) {
						$ismobile = $isSlipName5ch ? 'ｹﾞﾏｰ' : 'lmate';
						last;
					}
				}
			}
		}
	}

    return $ismobile;
}

#------------------------------------------------------------------------------------------------------------
#	BBS_SLIP生成
#	-------------------------------------------------------------------------------------
#	@param	$chid		SLIP_ID変更用
#	@return	$slip_result
#	@return	$idEnd		ID末尾
#------------------------------------------------------------------------------------------------------------
sub BBS_SLIP
{
	my $this = shift;
	my ($Sys, $chid) = @_;
	my ($slip_ip, $slip_remoho, $slip_ua);

	my $ipAddr = $ENV{'REMOTE_ADDR'};
	my $remoho = $ENV{'REMOTE_HOST'};
	my $ua = $ENV{'HTTP_USER_AGENT'};
	my $infoDir = $Sys->Get('INFO');

	# 各種判定
	my $country = $Sys->Get('IPCOUNTRY') ne 'abroad' ? 'JP': 'ｶﾞｲｺｰｸ';
	my $ismobile = is_mobile($country,$ipAddr,$remoho);
	my $isFwifi = is_public_wifi($country,$ipAddr,$remoho);
	my $isProxy = $Sys->Get('ISPROXY');
	my $isAnon = is_anonymous($isFwifi,$country,$ipAddr,$remoho,$infoDir);

	# bbs_slipに使用する文字
	my @slip_chars = (0..9, 'a'..'z', 'A'..'Z', '.', '/');

	# 一週間で文字列変更
	my $week_number = int((time + 172800) / (60 * 60 * 24 * 7));# 水曜9時に
	my ($chnum1,$chnum2,$chnum3,$chnum4);
	srand($week_number);
	$chnum1 = int(rand(1000000));
	srand($week_number*2);
	$chnum2 = int(rand(1000000));
	srand($week_number*3);
	$chnum3 = int(rand(1000000));
	srand($week_number*4);
	$chnum4 = int(rand(1000000));

	#idの末尾
	my $idEnd = '0';

	# slip_ip生成
	my $fo = '';
	my $so = '';
	if ($ipAddr =~ /^(\d{1,3})\.(\d{1,3})/) {
		$fo = $1 + $chnum1 + $chid;
		$so = $2 + $chnum2 + $chid;
	} elsif ($ipAddr =~ /^([\da-fA-F]{1,4}):([\da-fA-F]{1,4}):([\da-fA-F]{1,4}):([\da-fA-F]{1,4})/) {
		$fo = hex($1) + hex($2) + $chnum1 + $chid;
		$so = hex($3) + hex($4) + $chnum2 + $chid;
	}

	my $ip_char1 = $slip_chars[$fo % 64];
	my $ip_char2 = $slip_chars[$so % 64];
	$slip_ip = $remoho =~ /^KD.*au-net\.ne\.jp$/ ? $ip_char1 . $ip_char1 : $ip_char1 . $ip_char2;

	# slip_remoho生成
	my $year = (localtime(time))[5];
	my $mon = (localtime(time))[4];
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
	my $slip_nickname = "ﾜｯﾁｮｲ${fixed_nickname_end}";
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
		"ｶﾞｯｸｼ${fixed_nickname_end}",
		"ﾎﾞﾝﾎﾞﾝ${fixed_nickname_end}",
		"ｼｬﾁｰｸ${fixed_nickname_end}",
		"ｺﾑｲｰﾝ${fixed_nickname_end}"
		);
	my @special_idEnd = (
		'6',
		'7',
		'C',
		'G'
	);

	# 串判定
	if ($isProxy) {
		if($isProxy eq 'proxy'){
			$idEnd = '8';
			$slip_nickname = 'ｸｼｻﾞｼ';	
			$slip_nickname .= $fixed_nickname_end;
		}else{
			$idEnd = '8';
			$slip_nickname = 'ﾌﾞﾛｯｸ';	
			$slip_nickname .= $fixed_nickname_end;
		}
	}else{
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
			if ($unknown && $country ne 'JP' && $country) {
				$idEnd = 'H';
				$slip_nickname = "${country}${fixed_nickname_end}";
				$slip_aa = 'FC';
				$slip_bb = $slip_ip;
				$unknown = 0;
			}

			# 逆引き不可能
			if ($unknown) {
				$slip_id = 'hh';
				$idEnd = 'h';
				$slip_nickname = "ｱﾝﾀﾀﾞﾚ${fixed_nickname_end}";
				$slip_aa = $slip_id;
				$slip_bb = $slip_ip;
			}

		} else { # 逆引きできる場合
			my $remoho_checked = 0;

			# 国を判定
			if (!$remoho_checked && $country && $country ne 'JP') {
				$idEnd = 'H';
				$slip_nickname = "${country}${fixed_nickname_end}";
				$slip_aa = 'FC';
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

		# ローカル環境
		if ($ipAddr eq '127.0.0.1'){
			$slip_id = 'lc';
			$idEnd = 'l';
			$slip_nickname = "ﾛｰｶﾙ${fixed_nickname_end}";
			$slip_aa = $slip_id;
			$slip_bb = $slip_ip;
		}
	}

	# 匿名環境の場合は末尾が"8"になる
	return $slip_nickname,$slip_aa,$slip_bb,$slip_cccc,$idEnd;
}

# 旧式
sub BBS_SLIP_OLD
{
	my ($ip_addr, $remoho, $ua, $bbsslip) = @_;
	my ($slip_ip, $slip_remoho, $slip_ua);

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

	#bbs_slipを生成
	my $slip_result = '';
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
