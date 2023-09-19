#============================================================================================================
#
#	拡張機能 - ワッチョイもどき
#	0ch_bbsslip.pl
#
#============================================================================================================
package ZPL_bbsslip;

use Socket;
use Digest::MD5 qw(md5_hex);
#use Net::Whois::Raw;
use Geo::IP;
use utf8;

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
	return 'ワッチョイもどき';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return 'ワッチョイもどきを名前欄に付けます。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ(スレ立て:1, レス:2, read:4, index:8, 書き込み前処理:16)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return (1 | 2);
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

	#板設定の読み込み
	require './module/setting.pl';
	my $bbssetting = SETTING->new;
	$bbssetting->Load($Sys);

	#板のBBS_SLIP設定を確認
	my $bbsslip = $bbssetting->Get('BBS_SLIP');

	#IP・リモホ・UAを取得
	my $ip_addr = ($ENV{'HTTP_CF_CONNECTING_IP'}) ? $ENV{'HTTP_CF_CONNECTING_IP'} : $ENV{'REMOTE_ADDR'};
	my $remoho  = gethostbyaddr(inet_aton($ip_addr), AF_INET);
	my $ua = "$ENV{'HTTP_USER_AGENT'}";

	#BBS_SLIP機能呼び出し
	if ($bbsslip =~ /^v{3,6}$/){
		#名前欄にワッチョイもどきを追加
		my $from = $Form->Get('FROM');
		if ($from eq '') {
			$from = $bbssetting->Get('BBS_NONAME_NAME');
		}
		my $res = BBS_SLIP($ip_addr, $remoho, $ua, $bbsslip);
		$from = "${from} </b>(${res})<b> </b>";
		$Form->Set('FROM',$from);
	}

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	BBS_SLIP機能
#	-------------------------------------------------------------------------------------
#	@param	$ip_addr IPアドレス
#	@param	$remoho リモートホスト
#	@param	$ua ユーザーエージェント
#	@return	結果文字列
#
#------------------------------------------------------------------------------------------------------------
sub BBS_SLIP
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


	# Geo::IPがインストールされているかチェック
	my $geo_ip_installed = eval {
	    require Geo::IP;
	    1;  # 成功
	};

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
#	Module END
#============================================================================================================
1;
