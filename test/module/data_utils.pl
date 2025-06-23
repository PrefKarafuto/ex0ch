#============================================================================================================
#
#	汎用データ変換・取得モジュール
#
#============================================================================================================
package	DATA_UTILS;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use Encode;
use Socket qw(inet_pton AF_INET6 AF_INET);
use HTML::Entities;
use JSON;
use Storable;
use File::Spec;
use LWP::UserAgent;
no warnings qw(once);

#------------------------------------------------------------------------------------------------------------
#
#	モジュールコンストラクタ - new
#	-------------------------------------------
#	引　数：なし
#	戻り値：モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my $obj = {};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	URL引数取得 - GetArgument
#	-------------------------------------------
#	引　数：$pENV : %ENVのリファレンス
#	戻り値：引数配列
#
#------------------------------------------------------------------------------------------------------------
sub GetArgument
{
	my $this = shift;
	my ($pENV) = @_;
	
	my @retArg = ();
	
	# PATH_INFOあり
	if (defined $pENV->{'PATH_INFO'} && $pENV->{'PATH_INFO'} ne '') {
		my @Awork = split(/\//, $pENV->{'PATH_INFO'}, -1);
		@retArg = (@Awork[1, 2], ConvertOption($Awork[3]));
	}
	# QUERY_STRING
	else {
		my @Awork = split(/[&;]/, $pENV->{'QUERY_STRING'}, -1);
		@retArg = (undef, undef, 0, 1, 1000, 1, 0);
		foreach (@Awork) {
			my ($var, $val) = split(/=/, $_, 2);
			$retArg[0] = $val if ($var eq 'bbs');	# BBS
			$retArg[1] = $val if ($var eq 'key');	# スレッドキー
			$retArg[3] = $val if ($var eq 'st');	# 開始レス番
			$retArg[4] = $val if ($var eq 'to');	# 終了レス番
			# 1非表示
			if ($var eq 'nofirst' && $val eq 'true') {
				$retArg[5] = 1;
			}
			# 最新n件表示
			if ($var eq 'last' && $val != -1) {
				$retArg[2] = 1;
				$retArg[3] = $val;
				$retArg[4] = $val;
			}
		}
		# 単独表示フラグ
		if ($retArg[3] == $retArg[4] && $retArg[2] != 1) {
			$retArg[6] = 1;
		}
	}
	
	return @retArg;
}

#------------------------------------------------------------------------------------------------------------
#
#	表示レス数正規化 - RegularDispNum
#	-------------------------------------------
#	引　数：$Sys   : SYSTEM
#			$Dat   : DATオブジェクト
#			$last  : lastフラグ
#			$start : 開始行
#			$end   : 終了行
#	戻り値：(開始行、終了行)
#
#------------------------------------------------------------------------------------------------------------
sub RegularDispNum
{
	my $this = shift;
	my ($Sys, $Dat, $last, $start, $end) = @_;
	
	# 大きさ判定 swap
	if ($start > $end && $end != -1) {
		($start, $end) = ($end, $start);
	}
	
	my $resmax = $Dat->Size();
	my ($st, $ed);
	
	# 最新n件表示
	if ($last == 1) {
		$st = $resmax - $start + 1;
		$st = 1 if ($st < 1);
		$ed = $resmax;
	}
	# 指定表示
	elsif ($start || $end) {
		if ($end == -1) {
			$st = $start < 1 ? 1 : $start;
			$ed = $resmax;
		}
		else {
			$st = $start < 1 ? 1 : $start;
			$ed = $end < $resmax ? $end : $resmax;
		}
	}
	# 全件表示
	else {
		$st = 1;
		$ed = $resmax;
	}
	
	# 時間による制限有り
	if ($Sys->Get('LIMTIME')) {
		# 表示レス数が100超えた
		if ($ed - $st >= 100) {
			$ed = $st + 100 - 1;
		}
	}
	return ($st, $ed);
}

#------------------------------------------------------------------------------------------------------------
#
#	URL変換 - ConvertURL
#	--------------------------------------------
#	引　数：$Sys : SYSTEMモジュール
#			$Set : SETTING
#			$mode : エージェント
#			$text : 変換テキスト(リファレンス)
#	戻り値：変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertURL
{
	my $this = shift;
	my ($Sys, $Set, $mode, $text) = @_;
	
	# 時間による制限有り
	return $text if ($Sys->Get('LIMTIME'));
	
	my $server = $Sys->Get('SERVER');
	my $cushion = $Set->Get('BBS_REFERER_CUSHION');
	my $reg1 = q{(?<!a href=")(?<!src=")(https?|ftp)://(([-\w.!~*'();/?:\@=_+\$,%#]|&(?![lg]t;))+)};	# URL検索１
	my $reg2 = q{<(https?|ftp)::(([-\w.!~*'();/?:\@=_+\$,%#]|&(?![lg]t;))+)>};	# URL検索２
	
	# 携帯から
	if ($mode eq 'O') {
		$$text =~ s/$reg1/<$1::$2>/g;
		while ($$text =~ /$reg2/) {
			my $work = (split(/\//, $2))[0];
			$work =~ s/(www\.|\.com|\.net|\.jp|\.co|\.ne)//g;
			$$text =~ s|$reg2|<a href="$1://$2">$work</a>|;
		}
		$$text =~ s/ <br> /<br>/g;
		$$text =~ s/\s*<br>/<br>/g;
		$$text =~ s/(?:<br>){2}/<br>/g;
		$$text =~ s/(?:<br>){3,}/<br><br>/g;
	}
	# PCから
	else {
		# クッションあり
		if ($cushion) {
			$server =~ /$reg1/;
			$server = $2;
			$$text =~ s/$reg1/<$1::$2>/g;
			while ($$text =~ /$reg2/) {
				# 自鯖リンク -> クッションなし
				if ($2 =~ m{^\Q$server\E(?:/|$)}) {
					$$text =~ s|$reg2|<a href="$1://$2" target="_blank">$1://$2</a>|;
				}
				# 自鯖以外
				else {
					if($1 eq 'http') {
						$$text =~ s|$reg2|<a href="$1://$cushion$2" target="_blank">$1://$2</a>|;
					}
					elsif ($cushion =~ m{^(?:jump\.x0\.to|nun\.nu)/$}) {
						$$text =~ s|$reg2|<a href="http://$cushion$1://$2" target="_blank">$1://$2</a>|;
					}
					else {
						$$text =~ s|$reg2|<a href="$1://$2" target="_blank">$1://$2</a>|;
					}
				}
			}
		}
		# クッション無し
		else {
			$$text =~ s|$reg1|<a href="$1://$2" target="_blank">$1://$2</a>|g;
		}
	}
	return $text;
}
=pod
sub ConvertVideo
{
	my $this = shift;
	my ($text) = @_;
	my $reg = q{(?<!src=")(?<!a href=")(https?:\/\/.*?\.mp4)};
	$$text =~ s||<video src="$1" width=100 height=100 controls preload="metadata">|g;
	
	return $text;
}
=cut
#Tweet埋め込み
sub ConvertTweet
{
	my $this = shift;
	my ($text) = @_ ;
	
	my $reg = '<a.*?>(https?://(twitter|x)(\.com/[A-Za-z0-9_]+/status/([0-9]+)/?))';	 # TwitterURL検索
	
	$$text =~ s|$reg|<a href="$1">$1</a><br><blockquote class="twitter-tweet" data-width="300"><a href="https://twitter$3">Tweet読み込み中...</a></blockquote>|g;

	return $text;
	
}
#つべニコ動埋め込み
sub ConvertMovie
{
	my $this = shift;
	my ($text) = @_ ;

	# Youtube URL patterns
	my $youtube_pattern1 = qr{(https?://youtu\.be/([a-zA-Z0-9_-]+))};
	my $youtube_pattern2 = qr{(https?://(www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]+))};

	# NicoNico URL patterns
	my $nico_pattern1 = qr{(https?://nico\.ms/sm([0-9]+))};
	my $nico_pattern2 = qr{(https?://(www\.)?nicovideo\.jp/watch/sm([0-9]+))};

	my $reg1 = '<div class="video"><div class="video_iframe"><iframe width="560" height="315" src=';
	my $reg2 = 'frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div></div>';

	$$text =~ s|$youtube_pattern1|$reg1"https://www.youtube.com/embed/$2"$reg2|g;
	$$text =~ s|$youtube_pattern2|$reg1"https://www.youtube.com/embed/$3"$reg2|g;
	$$text =~ s|$nico_pattern1|$reg1"https://embed.nicovideo.jp/watch/sm$3"$reg2|g;
	$$text =~ s|$nico_pattern2|$reg1"https://embed.nicovideo.jp/watch/sm$3"$reg2|g;

	return $text;
}

#------------------------------------------------------------------------------------------------------------
#
#	引用変換 - ConvertQuotation
#	--------------------------------------------
#	引　数：$Sys : SYSTEMオブジェクト
#			$text : 変換テキスト
#			$mode : エージェント
#	戻り値：変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertQuotation
{
	my $this = shift;
	my ($Sys, $text, $mode) = @_;
	
	# 時間による制限有り
	return $text if ($Sys->Get('LIMTIME'));
	
	my $pathCGI = $Sys->Get('SERVER') . $Sys->Get('CGIPATH');
	
	if ($Sys->Get('PATHKIND')) {
		# URLベースを生成
		my $buf = '<a class=reply_link href="';
		$buf .= $pathCGI .  '/read.cgi';
		$buf .= '?bbs=' . $Sys->Get('BBS') . '&key=' . $Sys->Get('KEY');
		$buf .= '&nofirst=true';
		
		$$text =~ s{&gt;&gt;([1-9][0-9]*)-([1-9][0-9]*)}
					{$buf&st=$1&to=$2" target="_blank">>>$1-$2</a>}g;
		$$text =~ s{&gt;&gt;([1-9][0-9]*)-(?!0)}
					{$buf&st=$1&to=-1" target="_blank">>>$1-</a>}g;
		$$text =~ s{&gt;&gt;-([1-9][0-9]*)}
					{$buf&st=1&to=$1" target="_blank">>>$1-</a>}g;
		$$text =~ s{&gt;&gt;([1-9][0-9]*)}
					{$buf&st=$1&to=$1" target="_blank">>>$1</a>}g;
	}
	else{
		# URLベースを生成
		my $buf = "<a class=reply_link href=\"";
		$buf .= $pathCGI . '/read.cgi/';
		$buf .= $Sys->Get('BBS') . '/' . $Sys->Get('KEY');
		
		$$text =~ s{&gt;&gt;([1-9][0-9]*)-([1-9][0-9]*)}
					{$buf/$1-$2n" target="_blank">>>$1-$2</a>}g;
		$$text =~ s{&gt;&gt;([1-9][0-9]*)-(?!0)}
					{$buf/$1-" target="_blank">>>$1-</a>}g;
		$$text =~ s{&gt;&gt;-([1-9][0-9]*)}
					{$buf/-$1" target="_blank">>>-$1</a>}g;
		$$text =~ s{&gt;&gt;([1-9][0-9]*)}
					{$buf/$1" target="_blank">>>$1</a>}g;
	}
	$$text	=~ s{>>(?=[1-9])}{&gt;&gt;}g;
	
	return $text;
}

#------------------------------------------------------------------------------------------------------------
#
#	特殊引用変換 - ConvertSpecialQuotation
#	--------------------------------------------
#	引　数：$Sys	SYSTEM
#           $text : 変換テキスト
#	戻り値：変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertSpecialQuotation
{
	my $this = shift;
	my	($Sys, $text) = @_;
	
	$$text = '<br>' . $$text . '<br>';
	
	# ＞引用変換
	while($$text =~ /<br> ＞(.*?)<br>/){
		$$text =~ s/<br> ＞(.*?)<br>/<br><font color=gray>＞$1<\/font><br>/;
	}
	# ＃引用変換
	while($$text =~ /<br> ＃(.*?)<br>/){
		$$text =~ s/<br> ＃(.*?)<br>/<br><font color=green>＃$1<\/font><br>/;
	}
	# #引用変換
	while($$text =~ /<br> #(.*?)<br>/){
		$$text =~ s/<br> #(.*?)<br>/<br><font color=green>#$1<\/font><br>/;
	}
	
	# 最初につけた<br>を取り外す
	$$text = substr($$text,4,length($$text) - 8);
	
	return $text;
}

#------------------------------------------------------------------------------------------------------------
#
#	スレタイ変換 - ConvertThreadTitle
#	--------------------------------------------
#	引　数：$Sys : SYSTEMモジュール
#			$text : 変換テキスト(リファレンス)
#	戻り値：変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertThreadTitle
{
	my $this = shift;
	my ($Sys, $text) =@_;
	my $cache = {};
	my @bbsname;
	# サーバー名を取得 「http://example.jp」
	my $server = $Sys->Get('SERVER');
	# CGIのパス部分を取得 「/test」
	my $cgipath = $Sys->Get('CGIPATH');
	my $oldbbs = $Sys->Get('BBS');
	require './module/bbs_info.pl';
	my $info = BBS_INFO->new;
	$info->Load($Sys);
	
	$$text =~ s{(?<=\>)\Q$server$cgipath\E/read\.cgi/([0-9a-zA-Z_\-]+)/([0-9]+)/?([0-9\-]+)?/?}{
		my $title = (($oldbbs eq $1)?'':($1.'/')).GetThreadTitle($Sys, $cache, $1, $2).($3?" >>$3":'');
		(defined $title ? $title : $&)
	}ge;
	
	return $text;
	
}
sub GetThreadTitle
{
	my ($Sys, $cache, $bbs, $thread) = @_;
	
	my $Threads = $cache->{$bbs};
	
	if (!defined $cache->{$bbs}) {
		my $oldbbs = $Sys->Get('BBS');
		$Sys->Set('BBS', $bbs);
		
		require './module/thread.pl';
		$Threads = THREAD->new;
		$Threads->Load($Sys);
		$Threads->Close();
		$cache->{$bbs} = $Threads;
		
		$Sys->Set('BBS', $oldbbs);
	}
	
	my $title = $Threads->Get('SUBJECT', $thread);
	
	return $title;
}

#------------------------------------------------------------------------------------------------------------
#
#	汎用画像タグ変換
#	-------------------------------------------------------------------------------------
#	引数    	$Sys	SYSTEM
#			$limit	リンク時間制限
#			$text	対象文字列
#	戻り値	変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertImageTag
{
	my $this = shift;
	my ($Sys,$limit,$text) = @_;

	my $type = $Sys->Get('IMGTAG');

	my $reg_img = qq{(jpe?g|gif|bmp|a?png|tiff?|xcf|webp)};
	my $reg1 = qq{(?<!src="?)https?://.*?\.$reg_img};
	my $reg2 = qq{<a.*?>(.*?\.$reg_img)};
	my $reg3 = qq{(?<!src="?)https?://(i\.imgur\.com/[a-zA-Z0-9]{7}|pbs\.twimg\.com/media/[a-zA-Z0-9]{15})\.$reg_img};
	my $reg4 = qq{<a.*?>(https?://(i\.imgur\.com/[a-zA-Z0-9]{7}|pbs\.twimg\.com/media/[a-zA-Z0-9]{15})\.$reg_img)};
	
	if($limit||($Sys->Get('URLLINK') eq 'FALSE')){
		$reg1 = $reg3 if $type;
		$$text =~ s|$reg1|<a href=\"$1\">$1</a><br><img class=\"post_image\" src=\"$1\" style=\"max-width:250px;max-height:250px;\">|g;
	}
	else{
		$reg2 = $reg4 if $type;
		$$text =~ s|$reg2|<a href=\"$1\">$1</a><br><img class=\"post_image\" src=\"$1\" style=\"max-width:250px;max-height:250px;\">|g;
	}
	return $text;
}
#------------------------------------------------------------------------------------------------------------
#
#	テキスト削除 - DeleteText
#	--------------------------------------------
#	引　数：$text : 対象テキスト(リファレンス)
#			$len  : 最大文字数
#	戻り値：成形後テキスト
#
#------------------------------------------------------------------------------------------------------------
sub DeleteText
{
	my $this = shift;
	my ($text, $len) = @_;
	
	my @lines = split(/ ?<br> ?/, $$text, -1);
	my $ret = '';
	my $tlen = 0;
	
	foreach (@lines) {
		$tlen += length $_;
		last if ($tlen > $len);
		$ret .= "$_<br>";
		$tlen += 4;
	}
	
	return substr($ret, 0, -4);
}

#------------------------------------------------------------------------------------------------------------
#
#	改行数取得 - GetTextLine
#	--------------------------------------------
#	引　数：$text : 対象テキスト(リファレンス)
#	戻り値：改行数
#
#------------------------------------------------------------------------------------------------------------
sub GetTextLine
{
	my $this = shift;
	my ($text) = @_;
	
	$_ = $$text;
	my $l = s/(\r\n|[\r\n])/a/g || s/(<br>)/a/gi;
	
	return ($l + 1);
}

#------------------------------------------------------------------------------------------------------------
#
#	行列情報取得 - GetTextInfo
#	------------------------------------------------
#	引　数：$text : 調査テキスト(リファレンス)
#	戻り値：($tline,$tcolumn) : テキストの行数と
#			テキストの最大桁数
#	備　考：テキストの行区切りは<br>になっていること
#
#------------------------------------------------------------------------------------------------------------
sub GetTextInfo
{
	my $this = shift;
	my ($text) = @_;
	
	my @lines = split(/ ?<br> ?/, $$text, -1);
	
	my $mx = 0;
	foreach (@lines) {
		if ($mx < length($_)) {
			$mx = length($_);
		}
	}
	
	return (scalar(@lines), $mx);
}

#------------------------------------------------------------------------------------------------------------
#
#	エージェントモード取得 - GetAgentMode
#	--------------------------------------------
#	引　数：$UA   : ユーザーエージェント
#	戻り値：エージェントモード
#
#------------------------------------------------------------------------------------------------------------
sub GetAgentMode
{
	my $this = shift;
	my ($client) = @_;
	
	my $agent = '0';
	
	if ($client & $ZP::C_MOBILEBROWSER) {
		$agent = 'O';
	}
	elsif ($client & $ZP::C_FULLBROWSER) {
		$agent = 'Q';
	}
	elsif ($client & $ZP::C_P2) {
		$agent = 'P';
	}
	elsif ($client & $ZP::C_IPHONE_F) {
		$agent = 'i';
	}
	elsif ($client & $ZP::C_IPHONEWIFI) {
		$agent = 'I';
	}
	else {
		$agent = '0';
	}
	
	return $agent;
}

#------------------------------------------------------------------------------------------------------------
#
#	クライアント(機種)取得 - GetClient
#	--------------------------------------------
#	引　数：なし
#	戻り値：クライアント(機種)
#
#------------------------------------------------------------------------------------------------------------
sub GetClient
{
	my $this = shift;
	
	my $ua = $ENV{'HTTP_USER_AGENT'} || '';
	my $host = $ENV{'REMOTE_HOST'};
	my $addr = $ENV{'REMOTE_ADDR'};
	my $client = 0;
	
	require './module/cidr_list.pl';
	
	my $cidr = $ZP_CIDR::cidr;
	
	if (CIDRHIT($cidr->{'docomo'}, $addr)) {
		$client = $ZP::C_DOCOMO_M;
	}
	elsif (CIDRHIT($cidr->{'docomo_pc'}, $addr)) {
		$client = $ZP::C_DOCOMO_F;
	}
	elsif (CIDRHIT($cidr->{'vodafone'}, $addr)) {
		$client = $ZP::C_SOFTBANK_M;
	}
	elsif (CIDRHIT($cidr->{'vodafone_pc'}, $addr)) {
		$client = $ZP::C_SOFTBANK_F;
	}
	elsif (CIDRHIT($cidr->{'ezweb'}, $addr)) {
		$client = $ZP::C_AU_M;
	}
	elsif (CIDRHIT($cidr->{'ezweb_pc'}, $addr)) {
		$client = $ZP::C_AU_F;
	}
	elsif (CIDRHIT($cidr->{'emobile'}, $addr)) {
		if ($ua =~ m|^emobile/1\.0\.0|) {
			$client = $ZP::C_EMOBILE_M;
		}
		else {
			$client = $ZP::C_EMOBILE_F;
		}
	}
	elsif (CIDRHIT($cidr->{'willcom'}, $addr)) {
		if ($ua =~ m|^Mozilla/3\.0|) {
			$client = $ZP::C_WILLCOM_M;
		}
		elsif ($ua =~ m|^Mozilla/4\.0| && $ua =~ m/IEMobile|PPC/) {
			$client = $ZP::C_WILLCOM_M;
		}
		else {
			$client = $ZP::C_WILLCOM_F;
		}
	}
	elsif (CIDRHIT($cidr->{'ibis'}, $addr)) {
		$client = $ZP::C_IBIS;
	}
	elsif (CIDRHIT($cidr->{'jig'}, $addr)) {
		$client = $ZP::C_JIG;
	}
	elsif (CIDRHIT($cidr->{'iphone'}, $addr)) {
		$client = $ZP::C_IPHONE_F;
	}
	elsif (CIDRHIT($cidr->{'p2'}, $addr)) {
		$client = $ZP::C_P2;
	}
	elsif ($host =~ m|\.opera-mini\.net$|) {
		$client = $ZP::C_OPERAMINI;
	}
	elsif ($ua =~ / iPhone| iPad/) {
		$client = $ZP::C_IPHONEWIFI;
	}
	else {
		$client = $ZP::C_PC;
	}
	
	return $client;
}

#------------------------------------------------------------------------------------------------------------
#
#	IPチェック(CIDR対応) by (-Ac)
#	-------------------------------------------------------------------------------------
#	@param	$orz	CIDRリスト(配列)
#	@param	$ho		チェック文字
#	@return	ヒットした場合1 それ以外は0
#
#------------------------------------------------------------------------------------------------------------
sub CIDRHIT {
    my ($orz, $ho) = @_;

    foreach (@$orz) {
        $_ .= '/32' if ($_ !~ m|/|);

        my ($target, $length) = split('/', $_);

        my ($ipaddr_bin, $target_bin);

        if (index($ho, ':') != -1) { # IPv6アドレスの場合
            $ipaddr_bin = inet_pton(AF_INET6, $ho);
            $target_bin = inet_pton(AF_INET6, $target);
        } else { # IPv4アドレスの場合
            $ipaddr_bin = inet_pton(AF_INET, $ho);
            $target_bin = inet_pton(AF_INET, $target);
        }

        # inet_pton の結果をチェック
        unless (defined $ipaddr_bin && defined $target_bin) {
            next; # 無効なエントリはスキップ
        }

        # バイナリデータをビット列に変換
        my $ipaddr_bits = unpack("B*", $ipaddr_bin);
        my $target_bits = unpack("B*", $target_bin);

        # 指定された長さでビット列を比較
        if (substr($ipaddr_bits, 0, $length) eq substr($target_bits, 0, $length)) {
            return 1;
        }
    }

    return 0;
}


#------------------------------------------------------------------------------------------------------------
#
#	携帯機種情報取得
#	-------------------------------------------------------------------------------------
#	@param	$client	
#	@return	個体識別番号
#
#------------------------------------------------------------------------------------------------------------
sub GetProductInfo
{
	my $this = shift;
	my ($client) = @_;
	
	my $product;
	
	# docomo
	if ( $client & $ZP::C_DOCOMO ) {
		# $ENV{'HTTP_X_DCMGUID'} - 端末製造番号, 個体識別情報, ユーザID, iモードID
		$product = $ENV{'HTTP_X_DCMGUID'};
		$product =~ s/^X-DCMGUID: ([a-zA-Z0-9]+)$/$1/i;
	}
	# SoftBank
	elsif ( $client & $ZP::C_SOFTBANK ) {
		# USERAGENTに含まれる15桁の数字 - 端末シリアル番号
		$product = $ENV{'HTTP_USER_AGENT'};
		$product =~ s/.+\/SN([A-Za-z0-9]+)\ .+/$1/;
	}
	# au
	elsif ( $client & $ZP::C_AU ) {
		# $ENV{'HTTP_X_UP_SUBNO'} - サブスクライバID, EZ番号
		$product = $ENV{'HTTP_X_UP_SUBNO'};
		$product =~ s/([A-Za-z0-9_]+).ezweb.ne.jp/$1/i;
	}
	# e-mobile(音声端末)
	elsif ( $client & $ZP::C_EMOBILE ) {
		# $ENV{'X-EM-UID'} - 
		$product = $ENV{'X-EM-UID'};
		$product =~ s/x-em-uid: (.+)/$1/i;
	}
	# 公式p2
	elsif ( $client & $ZP::C_P2 ) {
		# $ENV{'HTTP_X_P2_CLIENT_IP'} - (発言者のIP)
		# $ENV{'HTTP_X_P2_MOBILE_SERIAL_BBM'} - (発言者の固体識別番号)
		$ENV{'REMOTE_P2'} = $ENV{'REMOTE_ADDR'};
		($ENV{'REMOTE_ADDR'}) = $ENV{'HTTP_X_P2_CLIENT_IP'};
		$ENV{'REMOTE_HOST'} = $this->reverse_lookup($ENV{'REMOTE_ADDR'});
		if( $ENV{'HTTP_X_P2_MOBILE_SERIAL_BBM'} ne "" ) {
			$product = $ENV{'HTTP_X_P2_MOBILE_SERIAL_BBM'};
		}
		else {
			$product = $ENV{'HTTP_USER_AGENT'};
			$product =~ s/.+p2-user-hash: (.+)\)/$1/i;
		}
	}
	else {
		$product = $ENV{'REMOTE_HOST'};
	}
	
	return $product;
}

#------------------------------------------------------------------------------------------------------------
#
#	ID作成関数 - MakeIDnew
#	--------------------------------------
#	戻り値：ID
#
#------------------------------------------------------------------------------------------------------------
sub MakeIDnew {
	my $this = shift;
	my ($Sys, $column,$sid,$chid) = @_;

	my $addr = $ENV{'REMOTE_ADDR'};
	my @ip = ($addr =~ /:/) ? split(/:/,$addr) : split(/\./,$addr);
	my $ua = $ENV{'HTTP_SEC_CH_UA'} // $ENV{'HTTP_USER_AGENT'};

	my $provider;
	my $HOST = $ENV{'REMOTE_HOST'};

	# プロバイダのドメインを取得
	if ($HOST) {
		$HOST =~ s/ne\.jp/nejp/g;
		$HOST =~ s/ad\.jp/adjp/g;
		$HOST =~ s/or\.jp/orjp/g;

		my @d = split(/\./, $HOST);  # リモートホストからドメイン部分を取り出す
		if (@d) {
			my $c = scalar @d;
			$provider = $d[$c - 2] . $d[$c - 1];
		}
	}

	require Digest::MD5;
	my $ctx = Digest::MD5->new;
	$ctx->add('ex0ch ID Generation');
	$ctx->add(':', $Sys->Get('SERVER'));
	$ctx->add(':', $Sys->Get('BBS'));
	# セッションIDが存在する場合はセッションIDを、存在しない場合はIP+UAを使ってIDを生成
	if ($sid) {
		$ctx->add(':', $sid);
	} else {
		$ctx->add(':', $ip[0].$ip[1].($#ip > 3 ? $ip[2].$ip[3]:'').$provider);
		$ctx->add(':', $ua);
	}
	$ctx->add(':', join('-', (localtime)[3,4,5]));
	$ctx->add(':', $chid);
	
	my $id = $ctx->b64digest;
	$id = substr($id, 0, $column);

	return $id;
}
#------------------------------------------------------------------------------------------------------------
#
#	トリップ作成関数 - ConvertTrip
#	--------------------------------------
#	引　数：$key     : トリップキー(リファレンス)
#			$column  : 桁数
#			$shatrip : 12桁トリップON/OFF
#	戻り値：変換後文字列
#
#------------------------------------------------------------------------------------------------------------
sub ConvertTrip
{
	my $this = shift;
	my ($key, $column, $shatrip) = @_;
	
	# cryptのときの桁取得
	$column *= -1;
	
	my $trip = '';
	$$key = '' if (!defined $$key);
	$$key = Encode::encode("cp932",$$key);
	if (length($$key) >= 12) {
		# 先頭1文字の取得
		my $mark = substr($$key, 0, 1);
		
		if ($mark eq '#' || $mark eq '$') {
			# 生キー
			if ($$key =~ m|^#([0-9a-zA-Z]{16})([./0-9A-Za-z]{0,2})$|) {
				my $key2 = pack('H*', $1);
				my $salt = substr($2 . '..', 0, 2);
				
				# 0x80問題再現
				$key2 =~ s/\x80[\x00-\xff]*$//;
				
				$trip = substr(crypt($key2, $salt), $column);
			}
			# 将来の拡張用
			else {
				$trip = '???';
			}
		}
		# SHA1(新仕様)トリップ
		elsif ($shatrip) {
			require Digest::SHA::PurePerl;
			Digest::SHA::PurePerl->import( qw(sha1_base64) );
			$trip = substr(sha1_base64($$key), 0, 12);
			$trip =~ tr/+/./;
		}
	}
	
	# 従来のトリップ生成方式
	if ($trip eq '') {
		my $salt = substr($$key, 1, 2);
		$salt = '' if (!defined $salt);
		$salt .= 'H.';
		$salt =~ s/[^\.-z]/\./go;
		$salt =~ tr/:;<=>?@[\\]^_`/ABCDEFGabcdef/;
		
		# 0x80問題再現
		$$key =~ s/\x80[\x00-\xff]*$//;
		
		$trip = substr(crypt($$key, $salt), $column);
	}
	
	return $trip;
}

#------------------------------------------------------------------------------------------------------------
#
#	オプション変換 - ConvertOption
#	--------------------------------------
#	引　数：$opt : オプション
#	戻り値：結果配列
#
#------------------------------------------------------------------------------------------------------------
sub ConvertOption
{
	my ($opt) = @_;
	
	$opt = '' if (!defined $opt);
	
	# 初期値
	my @ret = (
		-1,	# ラストフラグ
		-1,	# 開始行
		-1,	# 終了行
		-1,	# >>1非表示フラグ
		-1	# 単独表示フラグ
	);
	
	# 最新n件(1無し)
	if ($opt =~ /l(\d+)n/) {
		$ret[0] = 1;
		$ret[1] = $1 + 1;
		$ret[2] = $1 + 1;
		$ret[3] = 1;
	}
	# 最新n件(1あり)
	elsif ($opt =~ /l(\d+)/) {
		$ret[0] = 1;
		$ret[1] = $1;
		$ret[2] = $1;
		$ret[3] = 0;
	}
	# n-m(1無し)
	elsif ($opt =~ /(\d+)-(\d+)n/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = $2;
		$ret[3] = 1;
	}
	# n-m(1あり)
	elsif ($opt =~ /(\d+)-(\d+)/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = $2;
		$ret[3] = 0;
	}
	# n以降(1無し)
	elsif ($opt =~ /(\d+)-n/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = -1;
		$ret[3] = 1;
	}
	# n以降(1あり)
	elsif ($opt =~ /(\d+)-/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = -1;
		$ret[3] = 0;
	}
	# nまで(1あり)
	elsif ($opt =~ /-(\d+)/) {
		$ret[0] = 0;
		$ret[1] = 1;
		$ret[2] = $1;
		$ret[3] = 0;
	}
	# n表示(1無し)
	elsif ($opt =~ /(\d+)n/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = $1;
		$ret[3] = 1;
		$ret[4] = 1;
	}
	# n表示(1あり)
	elsif ($opt =~ /(\d+)/) {
		$ret[0] = 0;
		$ret[1] = $1;
		$ret[2] = $1;
		$ret[3] = 1;
		$ret[4] = 1;
	}
	
	return @ret;
}

#------------------------------------------------------------------------------------------------------------
#
#	パス生成 - CreatePath
#	-------------------------------------------
#	引　数：$Sys  : SYSTEM
#			$mode : 0:read 1:r
#			$bbs  : BBSキー
#			$key  : スレッドキー
#			$opt  : オプション
#	戻り値：生成されたパス
#
#------------------------------------------------------------------------------------------------------------
sub CreatePath
{
	my $this = shift;
	my ($Sys, $mode, $bbs, $key, $opt) = @_;
	
	my $path = $Sys->Get('SERVER') . $Sys->Get('CGIPATH') . '/read.cgi';
	
	# QUERY_STRINGパス生成
	if ($Sys->Get('PATHKIND')) {
		my @opts = ConvertOption($opt);
		
		# ベース作成
		$path .= "?bbs=$bbs&key=$key";
		
		# 最新n件表示
		if ($opts[0]) {
			$path .= "&last=$opts[1]";
		}
		# 指定表示
		else {
			$path .= "&st=$opts[1]";
			$path .= "&to=$opts[2]";
		}
		
		# >>1表示の付加
		$path .= '&nofirst=' . ($opts[3] == 1 ? 'true' : 'false');
	}
	# PATH_INFOパス生成
	else {
		$path .= "/$bbs/$key/$opt";
	}
	
	return $path;
}

#------------------------------------------------------------------------------------------------------------
#
#	日付取得 - GetDate
#	--------------------------------------
#	引　数：$Set  : SETTING.TXT
#			$msect : msec on/off
#	戻り値：日付文字列
#
#------------------------------------------------------------------------------------------------------------
sub GetDate
{
	my $this = shift;
	my ($Set, $msect, $time) = @_;
	
	$ENV{'TZ'} = 'JST-9';
	$time = $time ? $time : time;
	my @info = localtime $time;
	$info[5] += 1900;
	$info[4] += 1;
	
	# 曜日の取得
	my $week = ('日', '月', '火', '水', '木', '金', '土')[$info[6]];
	if (defined $Set && ! $Set->Equal('BBS_YMD_WEEKS', '')) {
		$week = (split(/\//, $Set->Get('BBS_YMD_WEEKS')))[$info[6]];
	}
	
	my $str = '';
	$str .= sprintf('%04d/%02d/%02d', $info[5], $info[4], $info[3]);
	$str .= "($week)" if ($week ne '');
	$str .= sprintf(' %02d:%02d:%02d', $info[2], $info[1], $info[0]);
	
	# msecの取得
	if ($msect) {
		eval {
			require Time::HiRes;
			my $times = Time::HiRes::time();
			$str .= sprintf(".%02d", ($times * 100) % 100);
		};
	}
	
	return $str;
	
}

#------------------------------------------------------------------------------------------------------------
#
#	シリアル値から日付文字列を取得する
#	-------------------------------------------------------------------------------------
#	@param	$serial	シリアル値
#	@param	$mode	0:時間表示有り 1:日付のみ
#	@return	日付文字列
#
#------------------------------------------------------------------------------------------------------------
sub GetDateFromSerial
{
	my $this = shift;
	my ($serial, $mode) = @_;
	
	$ENV{'TZ'} = 'JST-9';
	my @info = localtime $serial;
	$info[5] += 1900;
	$info[4] += 1;
	
	my $str = sprintf('%04d/%02d/%02d', $info[5], $info[4], $info[3]);
	$str .= sprintf(' %02d:%02d', $info[2], $info[1]) if (!$mode);
	
	return $str;
}

#------------------------------------------------------------------------------------------------------------
#
#	ID部分文字列生成
#	-------------------------------------------------------------------------------------
#	@param	$Set	SETTING
#	@param	$Form	FORM
#	@param	$Sec	
#	@param	$id		ID
#	@param	$koyuu	端末固有番号
#	@param	$type	端末識別子
#	@return	ID部分文字列
#
#------------------------------------------------------------------------------------------------------------
sub GetIDPart
{
	my $this = shift;
	my ($Set, $Form, $Sec, $id, $capID, $koyuu, $type) = @_;
	
	my $noid = $Sec->IsAuthority($capID, $ZP::CAP_DISP_NOID, $Form->Get('bbs'));
	my $noslip = $Sec->IsAuthority($capID, $ZP::CAP_DISP_NOSLIP, $Form->Get('bbs'));
	my $customid = $Sec->IsAuthority($capID, $ZP::CAP_DISP_CUSTOMID, $Form->Get('bbs'));
	
	# ID表示無し
	if ($Set->Equal('BBS_NO_ID', 'checked')) {
		return '';
	}
	
	# ホスト表示
	elsif ($Set->Equal('BBS_DISP_IP', 'checked')) {
		my $str = '???';
		if ($noid) {
			$str = '???';
		} elsif ($type eq 'O') {
			$str = "$koyuu $ENV{'REMOTE_HOST'}";
		} elsif ($type eq 'P') {
			$str = "$koyuu $ENV{'REMOTE_HOST'} ($ENV{'REMOTE_ADDR'};)";
		} else {
			$str = "$koyuu";
		}
		if (!$noslip && $Set->Get('BBS_SLIP')) {
			$str .= " $type";
		}
		return "HOST:$str";
	}
	
	# IP表示 Ver.Siberia
	elsif ($Set->Equal('BBS_DISP_IP', 'siberia')){
		my $str = '???';
		if ($noid) {
			$str = '???';
		} elsif ($type eq 'P') {
			$str = "$ENV{'REMOTE_P2'}";
		} else {
			$str = "$ENV{'REMOTE_ADDR'}";
		}
		if (!$noslip && $Set->Get('BBS_SLIP')) {
			$str .= " $type";
		}
		return "発信元:$str";
	}
	
	# IP表示 Ver.Karafuto
	elsif ($Set->Equal('BBS_DISP_IP', 'karafuto')) {
		my $str = '???';
		if ($noid) {
			$str = '???';
		} elsif ($type eq 'P') {
			$str = "$ENV{'HTTP_X_P2_CLIENT_IP'} ($koyuu)";
		} elsif ($type eq 'O') {
			$str = "$ENV{'REMOTE_ADDR'} ($koyuu)";
		} else {
			$str = "$ENV{'REMOTE_ADDR'};";
		}
		if (!$noslip && $Set->Get('BBS_SLIP')) {
			$str .= " $type";
		}
		return "発信元:$str";
	}
	
	# 各キャップ専用ID
	elsif ($customid && $Sec->Get($capID, 'CUSTOMID', 1) ne '') {
		my $str = $Sec->Get($capID, 'CUSTOMID', 1);
		if (!$noslip && $Set->Get('BBS_SLIP')) {
			$str .= " $type";
		}
		return "ID:$str";
	}
	
	# ID表示
	else {
		my $str = '???';
		if ($noid) {
			$str = '???';
		} elsif ($Set->Equal('BBS_FORCE_ID', 'checked')) {
			$str = $id;
		} elsif ($Form->IsInput(['mail'])) {
			$str = '???';
		} else {
			$str = $id;
		}
		if (!$noslip && $Set->Get('BBS_SLIP')) {
			$str .= "$type";
		}
		return "ID:$str";
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	特殊文字変換 - ConvertCharacter0
#	--------------------------------------
#	引　数：$data : 変換元データ(参照)
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub ConvertCharacter0
{
	my $this = shift;
	my ($data) = @_;
	
	$$data = '' if (!defined $$data);
	
	$$data =~ s/^($ZP::RE_SJIS*?)＃/$1#/g;
}

#------------------------------------------------------------------------------------------------------------
#
#	特殊文字変換 - ConvertCharacter1
#	--------------------------------------
#	引　数：$data : 変換元データ(参照)
#			$mode : 
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub ConvertCharacter1
{
	my $this = shift;
	my ($data, $mode) = @_;
	
	$$data = '' if (!defined $$data);
	
	# all
	$$data =~ s/</&lt;/g;
	$$data =~ s/>/&gt;/g;
	$$data =~ s/&#0*1[03];//gi;
	$$data =~ s/&#[xX]0*[aAdD];//gi; 
	$$data =~ s/&#0{0,}xd;?//gi;
	$$data =~ s/&#0{0,}xa;?//gi;
	
	# mail
	if ($mode == 1) {
		$$data =~ s/"/&quot;/g;#"
	}
	
	# text
	if ($mode == 2) {
		$$data =~ s/\n/<br>/g;
	}
	# not text
	else {
		$$data =~ s/\n//g;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	禁則文字変換 - ConvertCharacter2
#	--------------------------------------
#	引　数：$data : 変換元データ(参照)
#			$mode : 
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub ConvertCharacter2
{
	my $this = shift;
	my ($data_ref, $mode) = @_;
	
	# 未定義なら空文字列に
	$$data_ref = '' if (!defined $$data_ref);

	# name mail
	if ($mode == 0 || $mode == 1) {
		$$data_ref =~ s/★/☆/g;
		$$data_ref =~ s/◆/◇/g;
		$$data_ref =~ s/&#0{0,}9733;/☆/g;
		$$data_ref =~ s/&#0{0,}9670;/◇/g;
		$$data_ref =~ s/&#x0{0,}2605;/☆/gi;
		$$data_ref =~ s/&#x0{0,}25c6;/◇/gi;
		$$data_ref =~ s/(削|&#0{0,}(21066|x524a);)(除|&#0{0,}(38500|x6994);)/”削除”/gi;
	}
	
	# name
	if ($mode == 0) {
		$$data_ref =~ s/(管|&#0{0,}(31649|x7ba1);)(理|&#0{0,}(29702|x7406);)/”管理”/gi;
		$$data_ref =~ s/(管|&#0{0,}(31649|x7ba1);)(直|&#0{0,}(30452|x76f4);)/”管直”/gi;
		$$data_ref =~ s/(復|&#0{0,}(24489|x5fa9);)(帰|&#0{0,}(24112|x5e30);)/”復帰”/gi;
	}

}

#------------------------------------------------------------------------------------------------------------
#
#	特殊文字変換 - ConvertFusianasan
#	--------------------------------------
#	引　数：$data : 変換元データ(参照)
#			$host : 
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub ConvertFusianasan
{
	my $this = shift;
	my ($data, $host) = @_;
	
	$$data = '' if (!defined $$data);
	
	$$data =~ s/山崎渉/fusianasan/g;
	$$data =~ s|^($ZP::RE_SJIS*?)fusianasan|$1</b>$host<b>|g;
	$$data =~ s|^($ZP::RE_SJIS*?)fusianasan|$1 </b>$host<b>|g;
}

#------------------------------------------------------------------------------------------------------------
#
#	連続アンカー検出 - IsAnker
#	--------------------------------------
#	引　数：$text : 検査対象テキスト
#			$num  : 最大アンカー数
#	戻り値：0:許容内 1:だめぽ
#
#------------------------------------------------------------------------------------------------------------
sub IsAnker
{
	my $this = shift;
	my ($text, $num) = @_;
	
	$_ = $$text;
	my $cnt = s/&gt;&gt;([1-9])//g;
	
	return ($cnt > $num ? 1 : 0);
}

#------------------------------------------------------------------------------------------------------------
#
#	リファラ判断 - IsReferer
#	--------------------------------------
#	引　数：$Sys : SYSTEM
#	戻り値：許可なら0,NGなら1
#
#------------------------------------------------------------------------------------------------------------
sub IsReferer
{
	my $this = shift;
	my ($Sys, $pENV) = @_;
	
	my $svr = $Sys->Get('SERVER');
	if ($pENV->{'HTTP_REFERER'} =~ /\Q$svr\E/) {		# 自鯖からならOK
		return 0;
	}
	if ($pENV->{'HTTP_USER_AGENT'} =~ /Monazilla/) {	# ２ちゃんツールもOK
		return 0;
	}
	return 1;
}

#------------------------------------------------------------------------------------------------------------
#
#	日本IPチェック - IsJPIP
#	--------------------------------------
#	引　数：$Sys   : SYSTEM
#			$mode	: VPNフラグの設定
#	戻り値：プロクシなら対象ポート番号
#
#------------------------------------------------------------------------------------------------------------
sub IsJPIP {
    my ($self, $Sys) = @_;
    my $ipAddr     = $ENV{'REMOTE_ADDR'}  // '';
    my $remoteHost = $ENV{'REMOTE_HOST'}  // '';

    # ホスト名が .jp なら即 true
    return 1 if $remoteHost =~ /\.jp$/i;

    # IP をバイナリ化
    my $ip_bin = ip_to_bin($ipAddr) or return 0;

    my $infoDir    = '.'.$Sys->Get('INFO');
    my $cache_file = $infoDir. '/IP_List/jpn_ip_cache.cgi';

    # キャッシュが無い or 30日以上古いときは更新
    if (!-e $cache_file or (-M $cache_file) > 30) {
        update_ip_cache($cache_file, $infoDir);
    }

    # キャッシュ読み込み
    my $cache = retrieve($cache_file);
    my $list = length($ip_bin)==4 ? $cache->{v4} : $cache->{v6};

    return ip_in_list_binary($ip_bin, $list);
}
sub ip_to_bin {
    my ($ip) = @_;
    return inet_pton(AF_INET,  $ip) if inet_pton(AF_INET,  $ip);
    return inet_pton(AF_INET6, $ip) if inet_pton(AF_INET6, $ip);
    return;  # 無効な IP
}
sub make_mask {
    my ($prefix, $alen) = @_;
    my $full = int($prefix/8);
    my $rem  = $prefix % 8;
    return ("\xFF" x $full)
         . ($rem ? chr((0xFF << (8-$rem)) & 0xFF) : '')
         . ("\x00" x ($alen - $full - ($rem?1:0)));
}
sub update_ip_cache {
    my ($cache_file, $infoDir) = @_;

    # キャッシュディレクトリを作成（存在しなければ）
    use File::Basename qw(dirname);
    use File::Path     qw(mkpath);
    my $cache_dir = dirname($cache_file);
    unless (-d $cache_dir) {
        mkpath($cache_dir,0,0700)
            or die "ディレクトリ $cache_dir の作成に失敗: $!";
    }

    # — LWP::UserAgent を使って APNIC データ取得 —
    my $url = 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest';
    my $ua  = LWP::UserAgent->new(
        agent   => 'MyApp/1.0',
        timeout => 10,
    );
    my $res = $ua->get($url);
    die "APNIC 取得失敗: " . $res->status_line . "\n"
        unless $res->is_success;

    my $content = $res->decoded_content(charset => 'none');

    # — 取得データをパースしてバイナリリスト作成 —
    my (@v4, @v6);
    for my $line (split /\n/, $content) {
        next if $line =~ /^#/;
        if ($line =~ /^apnic\|JP\|ipv4\|(\d+\.\d+\.\d+\.\d+)\|(\d+)\|/) {
            my ($addr, $count) = ($1, $2);
            my $prefix = 32 - int(log($count)/log(2));
            if (my $bin = inet_pton(AF_INET, $addr)) {
                push @v4, { net_bin => $bin, mask => make_mask($prefix, length $bin) };
            }
        }
        elsif ($line =~ /^apnic\|JP\|ipv6\|([0-9a-f:]+)\|(\d+)\|/i) {
            my ($addr, $prefix) = ($1, $2);
            if (my $bin = inet_pton(AF_INET6, $addr)) {
                push @v6, { net_bin => $bin, mask => make_mask($prefix, length $bin) };
            }
        }
    }

    # — Storable でキャッシュ書き出し —
    store { v4 => \@v4, v6 => \@v6 }, $cache_file;
}
sub ip_in_list_binary {
    my ($ip_bin, $list) = @_;
    my ($lo, $hi, $idx) = (0, $#$list, -1);
    while ($lo <= $hi) {
        my $mid = int(($lo + $hi) / 2);
        if ($ip_bin lt $list->[$mid]{net_bin}) {
            $hi = $mid - 1;
        } else {
            $idx = $mid;
            $lo  = $mid + 1;
        }
    }
    return 0 if $idx < 0;
    my $e = $list->[$idx];
    return (($ip_bin & $e->{mask}) eq $e->{net_bin}) ? 1 : 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	プロクシチェック - IsProxyAPI
#	--------------------------------------
#	引　数：$Sys   : SYSTEM
#			$mode	: VPNフラグの設定
#	戻り値：プロクシなら対象ポート番号
#
#------------------------------------------------------------------------------------------------------------
sub IsProxyAPI {
    my $this = shift;
    my ($Sys, $mode) = @_;

    my $infoDir = $Sys->Get('INFO');
    my $ipAddr = $ENV{'REMOTE_ADDR'};
    my $api_key = $Sys->Get('PROXYCHECK_APIKEY');
	my $api_name = $Sys->Get('PROXYCHECK_API');
	my $cache_day = 7;		# キャッシュの有効期間

    $mode //= 1;  # デフォルト値を設定

    my $cacheFile = "$infoDir/IP_List/proxy_check.cgi"; # 結果のキャッシュファイル
    my $proxy_list = -e $cacheFile ? retrieve($cacheFile) : {};

    if (defined $proxy_list->{$ipAddr} && $proxy_list->{$ipAddr}->{"time"} + 60*60*24*$cache_day > time) {
        return $proxy_list->{$ipAddr}->{"flag"};
    }
	
	# APIリクエスト
	# 'サービス名'	=> {url => "エンドポイントURL", json_key => 'API返答に含まれるプロキシ判定のキー', json_value => 'プロキシ判定が真であることを意味する値'},
	my $api_req = {
		'proxycheck.io'	=> {url => "https://proxycheck.io/v2/${ipAddr}?key=${$api_key}&vpn=${mode}", json_key => 'proxy', json_value => 'yes'},
		'ipqualityscore'=> {url => "https://ipqualityscore.com/api/json/ip/${$api_key}/${ipAddr}", json_key => 'proxy', json_value => 'true'},
		'ip2location'	=> {url => "https://api.ip2location.io/?key=${$api_key}&ip=${ipAddr}&format=json", json_key => 'is_proxy', json_value => 'true'},
		'abstract'		=> {url => "https://ipgeolocation.abstractapi.com/v1/?api_key=${$api_key}&ip_address=${ipAddr}", json_key => 'is_vpn', json_value => 'true'},
		'ipdata'		=> {url => "https://api.ipdata.co/${ipAddr}/threat?api-key=${$api_key}", json_key => 'is_anonymous', json_value => 'true'},
	};

    if ($api_key && $api_name) {
        my $ua = LWP::UserAgent->new();
        my $response = $ua->get($api_req->{$api_name}{url});

        if ($response->is_success) {
            my $json = $response->decoded_content();
            my $out = decode_json($json);
            my $isProxy = $out->{$ipAddr}->{$api_req->{$api_name}{json_key}};

            $proxy_list->{$ipAddr}->{"flag"} = $isProxy eq $api_req->{$api_name}{json_value} ? 1 : 0;
            $proxy_list->{$ipAddr}->{"time"} = time;
            store $proxy_list, $cacheFile;
            chmod 0600, $cacheFile;

            return $proxy_list->{$ipAddr}->{"flag"};
        }
    }
    return 0;
}
#------------------------------------------------------------------------------------------------------------
#
#	プロクシチェック - IsListedDNSBL
#	--------------------------------------
#	引　数：$Sys   : SYSTEM
#			$Form  : 
#			$from  : 名前欄
#			$mode  : エージェント
#	戻り値：プロクシなら対象ポート番号
#
#------------------------------------------------------------------------------------------------------------
sub IsListedDNSBL
{
	my $this = shift;
	my ($Sys, $Form, $from, $mode) = @_;
	
	my @dnsbls = ();
	
	push(@dnsbls, 'torexit.dan.me.uk') if($Sys->Get('DNSBL_TOREXIT'));# Tor検出用
	push(@dnsbls, 'zen.spamhaus.org') if($Sys->Get('DNSBL_SPAMHAUS'));
	push(@dnsbls, 'all.s5h.net') if($Sys->Get('DNSBL_S5H'));
	push(@dnsbls, 'dnsbl.dronebl.org') if($Sys->Get('DNSBL_DRONEBL'));
	
	# DNSBL問い合わせ
	foreach my $dnsbl (@dnsbls) {
		if (CheckDNSBL($ENV{'REMOTE_ADDR'},$dnsbl)) {
			$Form->Set('FROM', "</b> [—\{}\@{}\@{}-] <b>$from");
			$Sys->Set('ISPROXY','dnsbl');
			return ($mode eq 'P' ? 0 : 1);
		}
	}
	
	return 0;
}

sub IsProxyDNSBL
{
	my $this = shift;
	my ($Sys, $Form, $from, $mode) = @_;
	return IsListedDNSBL($Sys, $Form, $from, $mode);
}

#------------------------------------------------------------------------------------------------------------
#
#	DNSBL正引き(timeout付き) - CheckDNSBL
#	--------------------------------------
#
#------------------------------------------------------------------------------------------------------------
sub CheckDNSBL {
	my $this = shift;
	my ($ip, $DNSBL_host) = @_;
	my $reversed_ip = '';
	require Net::DNS;

	if ($ip =~ /:/) {  # IPv6アドレスの場合
		$ip =~ s/://g;
		$reversed_ip = join('.', reverse(split('', $ip)));
	} else {  # IPv4アドレスの場合
		$reversed_ip = join('.', reverse(split(/\./, $ip)));
	}

	my $query_host = "$reversed_ip.$DNSBL_host";

	my $res = Net::DNS::Resolver->new(
		tcp_timeout => 1,  # TCPタイムアウトを1秒に設定
		udp_timeout => 1,  # UDPタイムアウトを1秒に設定
		retry       => 1,  # 再試行回数を1回に設定
	);

	my $query = $res->query($query_host, "A");

	if ($query) {
		foreach my $rr ($query->answer) {
			return 1 if $rr->type eq "A";  # Aレコードが見つかったら1を返して終了
		}
	}
	return 0;  # マッチしない場合は0を返す
}

#------------------------------------------------------------------------------------------------------------
#
#	パス合成・正規化 - MakePath * not mkdir/mkpath
#	--------------------------------------
#	引　数：$path1 : パス1
#			$path2 : パス2
#	戻り値：正規化パス
#
#------------------------------------------------------------------------------------------------------------
sub MakePath
{
	my $this = (ref($_[0]) eq 'DATA_UTILS' ? shift : undef);
	my ($path1, $path2) = @_;
	
	$path1 = '.' if (! defined $path1 || $path1 eq '');
	$path2 = '.' if (! defined $path2 || $path2 eq '');
	
	my @dir1 = ($path1 =~ m[^/|[^/]+]g);
	my @dir2 = ($path2 =~ m[^/|[^/]+]g);
	
	my $absflg = 0;
	if ($dir2[0] eq '/') {
		$absflg = 1;
		@dir1 = @dir2;
	}
	else {
		push @dir1, @dir2;
	}
	
	my @dir3 = ();
	
	my $depth = 0;
	for my $i (0 .. $#dir1) {
		if ($i == 0 && $dir1[$i] eq '/') {
			$absflg = 1;
		}
		elsif ($dir1[$i] eq '.' || $dir1[$i] eq '') {
		}
		elsif ($dir1[$i] eq '..') {
			if ($depth >= 1) {
				pop @dir3;
			}
			else {
				if ($absflg) {
					last;
				}
				if ($#dir3 == -1 || $dir3[$#dir3] eq '..') {
					push @dir3, '..';
				}
				else {
					pop @dir3;
				}
			}
			$depth--;
		}
		else {
			push @dir3, $dir1[$i];
			$depth++;
		}
	}
	
	my $path3;
	if ($#dir3 == -1) {
		$path3 = ($absflg ? '/' : '.');
	}
	else {
		$path3 = ($absflg ? '/' : '') . join('/', @dir3);
	}
	
	return $path3;
}

# 逆引き関数
sub reverse_lookup {
	my $this = shift;
	my ($ip) = @_;

	# IPv4とIPv6のアドレスを判断し、適切なSocket定数を使用
	my $inet = $ip =~ /:/ ? AF_INET6 : AF_INET;
	my $addr = inet_pton($inet, $ip);

	# 逆引き実施
	my $host = gethostbyaddr($addr, $inet);

	# 逆引きが成功した場合はホスト名を、失敗した場合はIPアドレスを返す
	return $host ? $host : $ip;
}

# IPv6展開
sub expand_ipv6 {
	my $this = shift;
	my ($ip) = @_;
	# いきなり128 bitのバイナリにする
	my $packed_addr = inet_pton(AF_INET6, $ip);
	# inet_pton は失敗しないはずだが
	# nginx + Listen Unix domain socket の場合は REMOTE_ADDR = "unix:" and REMOTE_ADDR =~ /:/ になるので
	# localhost(::1) として返す（扱う）
	if (!defined $packed_addr) {
		return "0000:0000:0000:0000:0000:0000:0000:0001";
	}
	# 16ビットずつ文字列に戻しつつ8個の配列にする
	my @blocks = unpack '(H4)8', $packed_addr;
	return join(':', @blocks);
}

# CDNのIPを判定
sub is_cdn_ip {
    my ($class, $ip) = @_;
    require './module/cidr_list.pl';
	my $cidr = $ZP_CIDR::cidr;
	
	if($ip =~ /:/){
		return $ENV{'HTTP_CF_CONNECTING_IP'} if CIDRHIT($cidr->{cf_v6}, $ip);
		return $ENV{'HTTP_FASTLY_CLIENT_IP'} if CIDRHIT($cidr->{fs_v6}, $ip);
		return $ENV{'HTTP_TRUE_CLIENT_IP'} if CIDRHIT($cidr->{ak_v6}, $ip);
	}else{
		return $ENV{'HTTP_CF_CONNECTING_IP'} if CIDRHIT($cidr->{cf_v4}, $ip);
		return $ENV{'HTTP_FASTLY_CLIENT_IP'} if CIDRHIT($cidr->{fs_v4}, $ip);
		return $ENV{'HTTP_TRUE_CLIENT_IP'} if CIDRHIT($cidr->{ak_v4}, $ip);
	}

    return;
}
#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
