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
	my $reg1 = q{(?<!a href=")(?<!src=")(https?|ftp)://(([-\w.!~*'();/?:\@=+\$,%#]|&(?![lg]t;))+)};	# URL検索１
	my $reg2 = q{<(?<!a href=")(?<!src=")(https?|ftp)::(([-\w.!~*'();/?:\@=+\$,%#]|&(?![lg]t;))+)>};	# URL検索２
	
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
#Imgur埋め込み
sub ConvertImgur
{
	my $this = shift;
	my ($text) = @_ ;
	
	my $reg = '(?<!src=")(https://i\.imgur\.com/[A-Za-z0-9_]+\.(bmp|png|jpe?g))';	 # ImgurURL検索
	
	$$text =~ s|$reg|<blockquote class="imgur-embed-pub" lang="ja" data-id="a/$2"><a href="$1"></a></blockquote>|g;
	
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
	
	my $reg = '(?<!src=")(?<!a href=")(https://twitter\.com/[A-Za-z0-9_]+/status/([^\p{Hiragana}\p{Katakana}\p{Han}\s]+)/?)';	 # TwitterURL検索
	
	$$text =~ s|$reg|<a href="$1">$1</a><br><blockquote  class="twitter-tweet" data-width="300"><a href="$1">Tweet読み込み中...</a></blockquote>|g;
	
	return $text;
	
}
#つべニコ動埋め込み
sub ConvertMovie
{
	my $this = shift;
	my ($text) = @_ ;
	
	my $reg1 = '(https://youtu\.be/([^\p{Hiragana}\p{Katakana}\p{Han}\s]+)/?)';             # YoutubeURL検索
	my $reg2 = '(https://nico\.ms/([a-z]+)([0-9])+)';	                                    # ニコ動URL検索
	my $reg3 = '(https://(www\.)?youtube\.com/([^\p{Hiragana}\p{Katakana}\p{Han}\s]+)/?)';  # YoutubeURL検索
	my $reg4 = '(https://(www\.)?nicovideo\.jp/([a-z]+)/([a-z]+)([0-9])+/?)';	            # ニコ動URL検索
	
	$$text =~ s|$reg1|<div class="responsive"><iframe width="560" height="315" src="$1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div>|g;
	$$text =~ s|$reg2|<div class="responsive"><iframe width="560" height="315" src="$1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div>|g;
	$$text =~ s|$reg3|<div class="responsive"><iframe width="560" height="315" src="$1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div>|g;
	$$text =~ s|$reg4|<div class="responsive"><iframe width="560" height="315" src="$1" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div>|g;
	
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
		my $buf = '<a class=reply_link rel="noopener noreferrer" href="';
		$buf .= $pathCGI . '/read.cgi';
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
		my $buf = '<a class=reply_link rel="noopener noreferrer" href="';
		$buf .= $pathCGI .  '/read.cgi/';
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
#	    	$limit	リンク時間制限
#	    	$text	対象文字列
#	戻り値	変換後のメッセージ
#
#------------------------------------------------------------------------------------------------------------
sub ConvertImageTag
{
	my $this = shift;
	my ($Sys,$limit, $text,$index) = @_;

	my $reg1 = q{(?<!src="?)https?://.*?\.(jpe?g|gif|bmp|png)};
	my $reg2 = q{<a.*?>(.*?\.(jpe?g|gif|bmp|png))};
	
	if($limit||($Sys->Get('URLLINK') eq 'FALSE')){
		if ($index){
			$$text =~ s|$reg1|<a href=\"$1\">$1</a><br><img src=\"$1\" width=\"65\" height=\"65\">|g;
		}
		else{
			$$text =~ s|$reg1|<a href=\"$1\">$1</a><br><img src=\"$1\" style=\"max-width:100%;height:auto;\">|g;
		}
	}
	else{
		if ($index){
			$$text =~ s|$reg2|<a href=\"$1\">$1</a><br><img src=\"$1\" width=\"65\" height=\"65\">|g;
		}
		else{
			$$text =~ s|$reg2|<a href=\"$1\">$1</a><br><img src=\"$1\" style=\"max-width:100%;height:auto;\">|g;
		}
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
	my $addr = ($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
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

sub CIDRHIT
{
	
	my ($orz, $ho) = @_;
	
	foreach (@$orz) {
		# 完全一致 = /32 ってことで^^;
		$_ .= '/32' if ($_ !~ m|/|);
		
		# 以下CIDR形式
		my ($target, $length) = split('/', $_);
		
		my $ipaddr = unpack("B$length", pack('C*', split(/\./, $ho)));
		$target = unpack("B$length", pack('C*', split(/\./, $target)));
		
		if ($target eq $ipaddr) {
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
		$ENV{'REMOTE_P2'} = ($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
		(($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}) = $ENV{'HTTP_X_P2_CLIENT_IP'};
		$ENV{'REMOTE_HOST'} = $this->GetRemoteHost(($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR});
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
#	リモートホスト(IP)取得関数 - GetRemoteHost
#	---------------------------------------------
#	引　数：なし
#	戻り値：IP、リモホス
#
#------------------------------------------------------------------------------------------------------------
sub GetRemoteHost
{
	my $this = shift;
	
	my $host = ($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};
	$host = gethostbyaddr(pack('C4', split(/\./, $host)), 2) || $host;
	
	return $host;
}

#------------------------------------------------------------------------------------------------------------
#
#	ID作成関数 - MakeID
#	--------------------------------------
#	引　数：$server : サーバー名
#			$client : 端末
#			$koyuu  : 端末固有識別子
#			$bbs    : 板名
#			$column : ID桁数
#	戻り値：ID
#
#------------------------------------------------------------------------------------------------------------
sub MakeID
{
	my $this = shift;
	my ($server, $client, $koyuu, $bbs, $column) = @_;
	
	# 種の生成
	my $uid;
	if ($client & ($ZP::C_P2 | $ZP::C_MOBILE)) {
		# 端末番号 もしくは p2-user-hash の上位3文字を取得
		#$uid = main::GetProductInfo($this, $ENV{'HTTP_USER_AGENT'}, $ENV{'REMOTE_HOST'});
		if (length($koyuu) > 8) {
			$uid = substr($koyuu, 0, 2) . substr($koyuu, -6, 3);
		}
		else {
			$uid = substr($koyuu, 0, 5);
		}
	}
	else {
		# IPを分解
		my @nums = split(/\./, (($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}));
		# 上位3つの1桁目取得
		$uid = substr($nums[3], -2) . substr($nums[2], -2) . substr($nums[1], -1);
	}
	
	my @times = localtime time;
	
	# サーバー名・板名を結合する
	$uid .= substr(crypt($server, $times[4]), 2, 1) . substr(crypt($bbs, $times[4]), 2, 2);
	
	# 桁を設定
	$column *= -1;
	
	# IDの生成
	my $ret = substr(crypt(crypt($uid, $times[5]), $times[3] + 31), $column);
	$ret =~ s/\./+/g;
	
	return $ret;
}
sub MakeIDnew
{
	my $this = shift;
	my ($Sys, $column) = @_;
	
	require Digest::SHA::PurePerl;
	my $ctx = Digest::SHA::PurePerl->new;
	$ctx->add('0ch+ ID Generation');
	$ctx->add(':', $Sys->Get('SERVER'));
	$ctx->add(':', $Sys->Get('BBS'));
	$ctx->add(':', $Sys->Get('KOYUU'));
	$ctx->add(':', join('-', (localtime)[3,4,5]));
	#$ctx->add(':', $Sys->Get('KEY'));
	
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
	my ($Set, $msect) = @_;
	
	$ENV{'TZ'} = 'JST-9';
	my @info = localtime time;
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
			$str = "$koyuu $ENV{'REMOTE_HOST'} (($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};)";
		} else {
			$str = "$koyuu";
		}
		if (!$noslip && $Set->Equal('BBS_SLIP', 'checked')) {
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
			$str = "($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}";
		}
		if (!$noslip && $Set->Equal('BBS_SLIP', 'checked')) {
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
			$str = "($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR} ($koyuu)";
		} else {
			$str = "($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR};";
		}
		if (!$noslip && $Set->Equal('BBS_SLIP', 'checked')) {
			$str .= " $type";
		}
		return "発信元:$str";
	}
	
	# 各キャップ専用ID
	elsif ($customid && $Sec->Get($capID, 'CUSTOMID', 1) ne '') {
		my $str = $Sec->Get($capID, 'CUSTOMID', 1);
		if (!$noslip && $Set->Equal('BBS_SLIP', 'checked')) {
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
		if (!$noslip && $Set->Equal('BBS_SLIP', 'checked')) {
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
	my ($data, $mode) = @_;
	
	$$data = '' if (!defined $$data);
	
	# name mail
	if ($mode == 0 || $mode == 1) {
		$$data =~ s/★/☆/g;
		$$data =~ s/◆/◇/g;
		$$data =~ s/削除/”削除”/g;
	}
	
	# name
	if ($mode == 0) {
		$$data =~ s/管理/”管理”/g;
		$$data =~ s/管直/”管直”/g;
		$$data =~ s/復帰/”復帰”/g;
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
#	プロクシチェック - IsProxy
#	--------------------------------------
#	引　数：$Sys   : SYSTEM
#			$Form  : 
#			$from  : 名前欄
#			$mode  : エージェント
#	戻り値：プロクシなら対象ポート番号
#
#------------------------------------------------------------------------------------------------------------
sub IsProxy
{
	my $this = shift;
	my ($Sys, $Form, $from, $mode) = @_;
	
	# 携帯, iPhone(3G回線) はプロキシ規制を回避する
	return 0 if ($mode eq 'O' || $mode eq 'i');
	
	my @dnsbls = ();
	push(@dnsbls, 'zen.spamhaus.org') if($Sys->Get('SPAMHAUS'));
	push(@dnsbls, 'bl.spamcop.net') if($Sys->Get('SPAMCOP'));
    push(@dnsbls, 'b.barracudacentral.org') if($Sys->Get('BARRACUDA'));
	
	# DNSBL問い合わせ
	my $addr = join('.', reverse( split(/\./, (($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}))));
	foreach my $dnsbl (@dnsbls) {
		if (CheckDNSBL("$addr.$dnsbl") eq '127.0.0.2') {
			$Form->Set('FROM', "</b> [—\{}\@{}\@{}-] <b>$from");
			return ($mode eq 'P' ? 0 : 1);
		}
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	DNSBL正引き(timeout付き) - CheckDNSBL
#	--------------------------------------
#	引　数：$host : 正引きするHOST
#	戻り値：プロキシであれば127.0.0.2
#
#------------------------------------------------------------------------------------------------------------
sub CheckDNSBL
{
	my ($host) = @_;
	
	my $ret = eval {
		require Net::DNS;
		my $res = Net::DNS::Resolver->new;
		$res->tcp_timeout(1);
		$res->udp_timeout(1);
		$res->retry(1);
		
		if ((my $query = $res->query($host))) {
			my @ans = $query->answer;
			
			foreach (@ans) {
				return $_->address;
			}
		}
		if ($res->errorstring eq 'query timed out') {
			return '127.0.0.0';
		}
	};
	
	return $ret if (defined $ret);
	
	if ($@) {
		require Net::DNS::Lite;
		my $res = Net::DNS::Lite->new(
			server => [ qw(8.8.4.4 8.8.8.8) ], # google public dns
			timeout => [2, 3],
		);
		
		my @ans = $res->resolve($host, 'a');
		return $_->[4] foreach (@ans);
	}
	
	return '127.0.0.1';
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

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
