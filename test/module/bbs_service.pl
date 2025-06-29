#============================================================================================================
#
#	bbs.cgi支援モジュール
#
#============================================================================================================
package	BBS_SERVICE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use LWP::UserAgent;
use warnings;

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
		'THREADS'	=> undef,
		'CONV'		=> undef,
		'BANNER'	=> undef,
		'CODE'		=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化
#	-------------------------------------------------------------------------------------
#	@param	$Sys		SYSTEM
#	@param	$Setting	SETTING
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	my ($Sys, $Setting) = @_;
	
	require './module/thread.pl';
	require './module/data_utils.pl';
	require './module/banner.pl';
	
	# 使用モジュールを設定
	$this->{'SYS'} = $Sys;
	$this->{'THREADS'} = THREAD->new;
	$this->{'CONV'} = DATA_UTILS->new;
	$this->{'BANNER'} = BANNER->new;
	$this->{'CODE'} = 'sjis';
	
	if (!defined $Setting) {
		require './module/setting.pl';
		$this->{'SET'} = SETTING->new;
		$this->{'SET'}->Load($Sys);
	}
	else {
		$this->{'SET'} = $Setting;
	}
	
	# 情報の読み込み
	$this->{'THREADS'}->Load($Sys);
	$this->{'BANNER'}->Load($Sys);
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	生成されたら1を返す
#
#------------------------------------------------------------------------------------------------------------
sub CreateIndex
{
	my $this = shift;
	
	my $Sys = $this->{'SYS'};
	my $Threads = $this->{'THREADS'};
	my $bbsSetting = $this->{'SET'};
	
	# CREATEモード、またはスレッドがindex表示範囲内の場合のみindexを更新する
	if ($Sys->Equal('MODE', 'CREATE')
		|| ($Threads->GetPosition($Sys->Get('KEY')) < $bbsSetting->Get('BBS_MAX_MENU_THREAD'))) {
		
		require './module/buffer_output.pl';
		require './module/header_footer_meta.pl';
		my $Index = BUFFER_OUTPUT->new;
		my $Caption = HEADER_FOOTER_META->new;
		
		PrintIndexHead($this, $Index, $Caption);
		PrintIndexMenu($this, $Index);
		PrintTimeLine($this,$Index);
		PrintIndexPreview($this, $Index);
		PrintIndexFoot($this, $Index, $Caption);
		
		my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/index.html';
		$Index->Flush(1, $Sys->Get('PM-TXT'), $path);
		
		return 1;
	}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	subback.html生成
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub CreateSubback
{
	my $this = shift;
	
	require './module/buffer_output.pl';
	my $Page = BUFFER_OUTPUT->new;
	
	my $Sys = $this->{'SYS'};
	my $Threads = $this->{'THREADS'};
	my $Set = $this->{'SET'};
	my $Conv = $this->{'CONV'};
	
	require './module/header_footer_meta.pl';
	my $Caption = HEADER_FOOTER_META->new;
	$Caption->Load($Sys, 'META');
	
	# HTMLヘッダの出力
	my $title = $Set->Get('BBS_TITLE');
	my $code = $this->{'CODE'};
	my $data_url = $Sys->Get('SERVER').$Sys->Get('CGIPATH').$Sys->Get('DATA');
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv="Content-Type" content="text/html;charset=Shift_JIS">
 <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <link rel="stylesheet" type="text/css" href="$data_url/design.css">

HTML
	
	$Caption->Print($Page, undef);
	
	$Page->Print(" <title>$title - スレッド一覧</title>\n\n");
	$Page->Print("</head>\n<body>\n\n");

	$Page->Print("<nav class=\"sidebar\" id=\"pc-sidebar\"><ul>\n");
	$Page->Print("<li class=\"menu-title\">$title</li>\n");
	$Page->Print("<li><a href=\"./\">掲示板に戻る</a></li>\n");
	
	$Page->Print("</ul></nav>\n");

	# スマホ用メニューバー
	$Page->Print("<nav class=\"dropdown\" id=\"mobile-dropdown\">\n");
	$Page->Print("<button class=\"dropbtn\" onclick=\"toggleDropdown()\"><span class=\"sitename\">$title</span>\n");
	$Page->Print("<div class=\"hamburger-icon\"><span></span><span></span><span></span></div></button>");
	$Page->Print("<div class=\"dropdown-content\" id=\"dropdown-content\">\n");
	$Page->Print("<a href=\"./\">掲示板に戻る</a>\n");
	$Page->Print("</div></nav>\n");

	$Page->Print("<main class=\"content\">\n");
	
	# バナー表示
	if ($Sys->Get('BANNER') & 5) {
		$this->{'BANNER'}->Print($Page, 100, 2, 0);
	}
	
	$Page->Print("<div class=\"threads\">");
	$Page->Print("<small>\n");
	
	# 全スレッドを取得
	my @threadSet = ();
	$Threads->GetKeySet('ALL', '', \@threadSet);
	my $threadsNum = @threadSet;
	$Page->Print("<h><font size=3 color=red>スレッド一覧</font></h><br><p>全部で$threadsNum\のスレッドがあります</p><br>");
	
	# スレッド分だけループをまわす
	my $bbs = $Sys->Get('BBS');
	my $max = $Sys->Get('SUBMAX');
	my $i = 0;
	foreach my $key (@threadSet) {
		last if ((++$i > $max)&&$Set->Get('BBS_READONLY') ne 'on');
		
		my $name = $Threads->Get('SUBJECT', $key);
		my $res = $Threads->Get('RES', $key);
		my $path = $Conv->CreatePath($Sys, 0, $bbs, $key, 'l50');
		
		$Page->Print("&nbsp;&nbsp;$i: <a href=\"$path\">$name($res)</a><br>\n");
	}
	
	# フッタ部分の出力
	my $cgipath = $Sys->Get('CGIPATH');
	my $version = $Sys->Get('VERSION');
	$Page->Print(<<HTML);
</small>
</div>
<hr>
<div align="left" style="margin-top:1em;">
<small><a href="./"><b>掲示板に戻る</b></a>／<a href="./kako/" target="_blank"><b>過去ログ倉庫はこちら</b></a></small>
</div>

<hr>

<div align="right">
$version
</div>

</main>
<style>
/* スマホ用レイアウト */
img {
	max-width: 100%;
	height:auto;
}

textarea {
width:95%;
margin:0;
}
</style>


</body>
</html>
HTML
	
	# subback.htmlに書き込み
	my $paths = $Sys->Get('BBSPATH') . "/$bbs";
	$Page->Flush(1, $Sys->Get('PM-TXT'), "$paths/subback.html");
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(ヘッダ部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page		
#	@param	$Caption	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintIndexHead
{
	my $this = shift;
	my ($Page, $Caption) = @_;
	
	$Caption->Load($this->{'SYS'}, 'META');
	my $title = $this->{'SET'}->Get('BBS_TITLE');
	my $link = $this->{'SET'}->Get('BBS_TITLE_LINK');
	my $image = $this->{'SET'}->Get('BBS_TITLE_PICTURE');
	my $CSP = $this->{'SYS'}->Get('CSP');
#	my $code = $this->{'CODE'};

	my $url = $this->{'SYS'}->Get('SERVER').'/'.$this->{'SYS'}->Get('BBS').'/';
	my $data_url = $this->{'SYS'}->Get('SERVER').$this->{'SYS'}->Get('CGIPATH').$this->{'SYS'}->Get('DATA');
	my $favicon = $this->{'SET'}->Get('BBS_FAVICON');
	my $bbsinfo = $this->{'SET'}->Get('BBS_SUBTITLE');
	my $ogpimage = $image;
	if($image !~ /^https?:\/\//){
		$ogpimage = $this->{'SYS'}->Get('SERVER').$image;
	}

	# HTMLヘッダの出力
	$Page->Print(<<HEAD);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja" prefix="og: http://ogp.me/ns#">
<head>
 <meta http-equiv="Content-Type" content="text/html;charset=Shift_JIS">
 <meta http-equiv="Content-Script-Type" content="text/javascript">
 <meta name="viewport" content="width=device-width,initial-scale=1.0">
 <meta property="og:url" content="$url">
 <meta property="og:title" content="$title">
 <meta property="og:description" content="$bbsinfo">
 <meta property="og:type" content="website">
 <meta property="og:image" content="$ogpimage">
 <meta property="og:site_name" content="EXぜろちゃんねる">
 <meta name="twitter:card" content="summary_large_image">
 <link rel="stylesheet" type="text/css" href="$data_url/design.css">
 <link rel="icon" href="$favicon">
HEAD
	$Page->Print('<script src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>') if ($this->{'SET'}->Get('BBS_TWITTER'));
	$Page->Print('<meta http-equiv="Content-Security-Policy" content="frame-src \'self\' https://www.nicovideo.jp/ https://www.youtube.com/ https://imgur.com/  https://platform.twitter.com/;">') if ($CSP);
	
	$Caption->Print($Page, undef);
	
	$Page->Print(" <title>$title</title>\n\n");
	
	# cookie用scriptの出力
	if ($this->{'SET'}->Equal('SUBBBS_CGI_ON', 1)) {
		require './module/cookie.pl';
		COOKIE::Print(undef, $Page);
	}
	$Page->Print("</head>\n<!--nobanner-->\n");
	
	# <body>タグ出力
	{
		my @work = ();
		$work[0] = $this->{'SET'}->Get('BBS_BG_COLOR');
		$work[1] = $this->{'SET'}->Get('BBS_TEXT_COLOR');
		$work[2] = $this->{'SET'}->Get('BBS_LINK_COLOR');
		$work[3] = $this->{'SET'}->Get('BBS_ALINK_COLOR');
		$work[4] = $this->{'SET'}->Get('BBS_VLINK_COLOR');
		$work[5] = $this->{'SET'}->Get('BBS_BG_PICTURE');
		
		$Page->Print("<body bgcolor=\"$work[0]\" text=\"$work[1]\" link=\"$work[2]\" ");
		$Page->Print("alink=\"$work[3]\" vlink=\"$work[4]\" background=\"$work[5]\">\n");

	}

	# サイドメニュー
	require './module/bbs_info.pl';
	my $Category = CATEGORY_INFO->new;
	my $BBS = BBS_INFO ->new;
	$Category->Load($this->{'SYS'});
	$BBS->Load($this->{'SYS'});
	my @catSet;
	my @bbsSet;
	$Category->GetKeySet(\@catSet);
	$BBS->GetKeySet('ALL', '', \@bbsSet);

	my $sitename = $this->{'SYS'}->Get('SITENAME') || 'EXぜろちゃんねる';
	my $kako = $this->{'SET'}->Get('BBS_KAKO') ?  '../'.$this->{'SET'}->Get('BBS_KAKO') : './kako';

	# PC用メニューバー
	$Page->Print("<nav class=\"sidebar\" id=\"pc-sidebar\"><ul>\n");
	$Page->Print("<li class=\"menu-title\">$sitename</li>\n");
	$Page->Print("<li><a href=\"../test/search.cgi\">検索</a></li>\n");
	$Page->Print("<li><a href=\"../bbsmenu.html\">BBS MENU</a></li>\n") if -e '../bbsmenu.html';
	$Page->Print("<hr>");
	$Page->Print("<li class=\"category-title\">$title</li>\n");
	$Page->Print("<li><a href=\"./subback.html\">スレッド一覧</a></li>\n");
	$Page->Print("<li><a href=\"$kako\">過去ログ倉庫</a></li>\n");
	$Page->Print("<li><a href=\"./#top\">ページトップ</a></li>\n");
	$Page->Print("<li><a href=\"./#new_thread\">スレッド作成</a></li>\n") if $this->{'SET'}->Get('BBS_READONLY') ne 'on';
	$Page->Print("<hr>");
	$Page->Print("<li class=\"menu-title\">掲示板一覧</li>\n");
	foreach my $catid (sort @catSet) {
		my $catname = $Category->Get('NAME', $catid);
		$Page->Print("<li class=\"category-title\">$catname</li>\n");
		my $is_active = "";
		foreach my $id (sort @bbsSet) {
			my $name = $BBS->Get('NAME', $id);
			my $dir = $BBS->Get('DIR', $id);
			$is_active = 'class="active"' if $this->{'SYS'}->Get('BBS') eq $dir;
			$Page->Print("<li><a $is_active href=\"../$dir/\">$name</a></li>\n") if $catid eq $BBS->Get('CATEGORY', $id);
			$is_active = "";
		}
	}
	
	$Page->Print("</ul></nav>\n");

	# スマホ用メニューバー
	$Page->Print("<nav class=\"dropdown\" id=\"mobile-dropdown\">\n");
	$Page->Print("<button class=\"dropbtn\" onclick=\"toggleDropdown()\"><span class=\"sitename\">$sitename</span>\n");
	$Page->Print("<div class=\"hamburger-icon\"><span></span><span></span><span></span></div></button>");
	$Page->Print("<div class=\"dropdown-content\" id=\"dropdown-content\">\n");
	$Page->Print("<a href=\"../test/search.cgi\">検索</a>\n");
	$Page->Print("<a href=\"../bbsmenu.html\">BBS MENU</a>\n") if -e '../bbsmenu.html';
	$Page->Print("<hr>");
	$Page->Print("<span class=\"category-title\">$title</span>\n");
	$Page->Print("<a href=\"./subback.html\">スレッド一覧</a>\n");
	$Page->Print("<a href=\"$kako\">過去ログ倉庫</a>\n");
	$Page->Print("<a href=\"./#top\">ページトップ</a>\n");
	$Page->Print("<a href=\"./#new_thread\">スレッド作成</a>\n") if $this->{'SET'}->Get('BBS_READONLY') ne 'on';
	$Page->Print("<hr>");
	$Page->Print("<li class=\"menu-title\">掲示板一覧</li>\n");
	foreach my $catid (sort @catSet) {
		my $catname = $Category->Get('NAME', $catid);
		$Page->Print("<span class=\"category-title\">$catname</span>\n");
		my $is_active = '';
		foreach my $id (sort @bbsSet) {
			my $name = $BBS->Get('NAME', $id);
			my $dir = $BBS->Get('DIR', $id);
			$is_active = 'class="active"' if $this->{'SYS'}->Get('BBS') eq $dir;
			$Page->Print("<a $is_active href=\"../$dir/\">$name</a>\n") if $catid eq $BBS->Get('CATEGORY', $id);
			$is_active = "";
		}
	}
	$Page->Print("</div></nav>\n");


	$Page->Print("<main class=\"content\">\n");
	$Page->Print("<a name=\"top\"></a>\n");
	
	# 看板画像表示あり
	if ($image ne '') {
		$Page->Print("<div align=\"center\">");
		# 看板画像からのリンクあり
		if ($link ne '') {
			$Page->Print("<a href=\"$link\"><img src=\"$image\" border=\"0\" alt=\"$link\"></a>");
		}
		# 看板画像にリンクはなし
		else {
			$Page->Print("<img src=\"$image\" border=\"0\" alt=\"$link\">");
		}
		$Page->Print("</div>\n");
	}
	my $cgipath = $this->{'SYS'}->Get('CGIPATH');
	
	$Page->Print(<<HTML);
<table cellspacing="7" cellpadding="3" width="95%" style="margin:1.2em auto;" align="center">
<tbody><tr><td>
  <a href="../bbsmenu.html" style="color:inherit;text-decoration: none;">
   <div style="padding:0.25em 0.50em;border-radius:0.25em/0.25em;background:#39F;color:#FFF;font-size:1.25em;" align="center">$title</div>
  </a>
  </td></tr>
  </tbody>
 </table>
HTML
	# ヘッダテーブルの表示
	$Caption->Load($this->{'SYS'}, 'HEAD');
	$Caption->Print($Page, $this->{'SET'});
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(スレッドメニュー部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintIndexMenu
{
	my $this = shift;
	my ($Page) = @_;
	
	my $Conv = $this->{'CONV'};
	my $menuCol = $this->{'SET'}->Get('BBS_MENU_COLOR');
	
	# バナーの表示
	$this->{'BANNER'}->Print($Page, 95, 0, 0) if ($this->{'SYS'}->Get('BANNER') & 3);
	
	$Page->Print(<<MENU);

<a name="menu"></a>
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$menuCol" style="margin:1.2em auto;" align="center">
 <tr>
  <td>
  <small>
MENU
	
	my @threadSet = ();
	$this->{'THREADS'}->GetKeySet('ALL', '', \@threadSet);
	
	# スレッド分だけループをまわす
	my $prevNum = $this->{'SET'}->Get('BBS_THREAD_NUMBER');
	my $menuNum = $this->{'SET'}->Get('BBS_MAX_MENU_THREAD');
	my $max = $this->{'SYS'}->Get('SUBMAX');
	my $i = 0;
	foreach my $key (@threadSet) {
		last if ((++$i > $menuNum) || ($i > $max));
		
		my $name = $this->{'THREADS'}->Get('SUBJECT', $key);
		my $res = $this->{'THREADS'}->Get('RES', $key);
		my $path = $Conv->CreatePath($this->{'SYS'}, 0, $this->{'SYS'}->Get('BBS'), $key, 'l50');
		
		# プレビュースレッドの場合はプレビューへのリンクを貼る
		if ($i <= $prevNum) {
						$Page->Print("<font size=3>");
			$Page->Print("  <a href=\"$path\" target=\"body\">$i:</a> ");
			$Page->Print("<a href=\"#$i\">$name($res)</a>　</font>\n");
						$Page->Print("<hr>") if $i == $prevNum;
		}
		else {
			$Page->Print("  <a href=\"$path\" target=\"body\">$i: $name($res)</a>　\n");
		}
	}
		my $threadNum = @threadSet;
		$Page->Print("（全部で$threadNum\のスレッドがあります）");
	$Page->Print(<<MENU);
  </small>
  <br><br><div align="left"><font size=3><b><a href="./kako">過去ログ倉庫</a>／<a href="./subback.html">スレッド一覧</a>／<a href="./">リロード</a></b></font></div>
  </td>
 </tr>
</table>

MENU
	
	# サブバナーの表示(表示したら空行をひとつ挿入)
	if ($this->{'BANNER'}->PrintSub($Page)) {
		$Page->Print("\n");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(タイムライン部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintTimeLine
{
	my $this = shift;
	my ($Page) = @_;
	
	my $Conv = $this->{'CONV'};
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $menuCol = $this->{'SET'}->Get('BBS_MENU_COLOR');
	my $tl_max = $Set->Get('BBS_TL_MAX');

	return unless $tl_max;

	my $TLpath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/info/timeline';
    opendir(my $dir, $TLpath) or die "Cannot open directory: $!";
    my @files = sort { (stat("$TLpath/$b"))[9] <=> (stat("$TLpath/$a"))[9] } 
    grep { /\.cgi$/ && -f "$TLpath/$_" } readdir($dir);
    closedir($dir);
	
	$Page->Print(<<MENU);
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$menuCol" style="margin:1.2em auto;" align="center">
<tbody>
 <tr>
  <td>
  <small>
  <div style="height: 200px; overflow-y: scroll;" id="timeline" >
MENU
	if(@files){
		foreach my $file (@files) {
			my $filepath = "$TLpath/$file";
			open(my $fh, '<', $filepath) or die "Cannot open file: $!";
			my $line = <$fh>;
			close($fh);
			
			my $mtime = (stat($filepath))[9];

			my @lines = split(/<>/, $line);
			my $message = $lines[3];
			$message =~ s/<br>//g;
			$message = (split(/</,$message))[0];
			my $title  = $lines[4];
			my $url = $lines[5];

			my $str_max = 60;

			if (length($message) > $str_max) {
				$message = substr($message, 0, $str_max) . "...";
			}
			if (length($title) > $str_max) {
				$title = substr($title, 0, $str_max) . "...";
			}

			$Page->Print(<<MENU);
		<a href="$url" class="timeline-entry" data-mtime="$mtime">
			<div class="tl_title">
				<span class="tl_time"> - </span> $title
			</div>
			<div class="tl_message">$message</div>
		</a>
MENU
    	}
	}else{
		$Page->Print("投稿はありません");
	}

	$Page->Print(<<MENU);
	</div>
  </small>
  </td>
 </tr><tr><td>
<button type="button" onclick="window.location.href='./'; window.location.reload();">
    再読み込み
</button>
 </td></tr>
 </tbody>
</table>

MENU
}
#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(スレッドプレビュー部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page		
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintIndexPreview
{
	my $this = shift;
	my ($Page) = @_;
	
	# 拡張機能ロード
	require './module/plugin.pl';
	my $Plugin = PLUGIN->new;
	$Plugin->Load($this->{'SYS'});
	
	# 有効な拡張機能一覧を取得
	my @commands = ();
	my @pluginSet = ();
	$Plugin->GetKeySet('VALID', 1, \@pluginSet);
	my $count = 0;
	foreach my $id (@pluginSet) {
		# タイプがread.cgiの場合はロードして実行
		if ($Plugin->Get('TYPE', $id) & 8) {
			my $file = $Plugin->Get('FILE', $id);
			my $className = $Plugin->Get('CLASS', $id);
			if (-e "./plugin/$file") {
				require "./plugin/$file";
				my $Config = PLUGINCONF->new($Plugin, $id);
				$commands[$count++] = $className->new($Config);
			}
		}
	}
	
	require './module/dat.pl';
	my $Dat = DAT->new;
	
	my @threadSet = ();
	$this->{'THREADS'}->GetKeySet('ALL', '', \@threadSet);
	
	# 前準備
	my $prevNum = $this->{'SET'}->Get('BBS_THREAD_NUMBER');
	my $threadNum = (scalar(@threadSet) > $prevNum ? $prevNum : scalar(@threadSet));
	my $tblCol = $this->{'SET'}->Get('BBS_THREAD_COLOR');
	my $ttlCol = $this->{'SET'}->Get('BBS_SUBJECT_COLOR');
	my $prevT = $threadNum;
	my $nextT = ($threadNum > 1 ? 2 : 1);
	my $Conv = $this->{'CONV'};
	my $basePath = $this->{'SYS'}->Get('BBSPATH') . '/' . $this->{'SYS'}->Get('BBS');
	my $max = $this->{'SYS'}->Get('SUBMAX');
	
	my $cnt = 0;
	foreach my $key (@threadSet) {
		last if (++$cnt > $prevNum || $cnt > $max);
		
		my $subject = $this->{'THREADS'}->Get('SUBJECT', $key);
		my $res = $this->{'THREADS'}->Get('RES', $key);
		$nextT = 1 if ($cnt == $threadNum);
		
		# ヘッダ部分の表示
		$Page->Print(<<THREAD);
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$tblCol" style="margin-bottom:1.2em;" align="center">
 <tr>
  <td>
  <a name="$cnt"></a>
  <div align="right"><a href="#menu">■</a><a href="#$prevT">▲</a><a href="#$nextT">▼</a></div>
  <div style="margin-bottom:0.2em;"><b>【$cnt:$res】</b><font size="+2" color="$ttlCol"><b>$subject</b></font></div>
  <dl class="post" style="margin-top:0px; border-style:none none none none;">
THREAD
		
		# プレビューの表示
		my $datPath = "$basePath/dat/$key.dat";
		$Dat->Load($this->{'SYS'}, $datPath, 1);
		$this->{'SYS'}->Set('KEY', $key);
		PrintThreadPreviewOne($this, $Page, $Dat, \@commands);
		$Dat->Close();
		
		# フッタ部分の表示
		my $allPath = $Conv->CreatePath($this->{'SYS'}, 0, $this->{'SYS'}->Get('BBS'), $key, '');
		my $lastPath = $Conv->CreatePath($this->{'SYS'}, 0, $this->{'SYS'}->Get('BBS'), $key, 'l50');
		my $numPath = $Conv->CreatePath($this->{'SYS'}, 0, $this->{'SYS'}->Get('BBS'), $key, '1-100');
		$Page->Print(<<KAKIKO);
	<div style="font-weight:bold;">
	 <a href="$allPath">全部読む</a>
	 <a href="$lastPath">最新50</a>
	 <a href="$numPath">1-100</a><br class="smartphone">
	 <a href="#top">板のトップ</a>
	 <a href="./">リロード</a>
	</div>
	</span>
   </blockquote>
  </form>
  </td>
 </tr>
</table>

KAKIKO
		
		# カウンタの更新
		$nextT++;
		$prevT++;
		$prevT = 1 if ($cnt == 1);
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(フッタ部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page		
#	@param	$Caption	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintIndexFoot
{
	my $this = shift;
	my ($Page, $Caption) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	my $tblCol = $Set->Get('BBS_MAKETHREAD_COLOR');
	my $cgipath = $Sys->Get('CGIPATH');
	my $bbs = $Sys->Get('BBS');
	my $ver = $Sys->Get('VERSION');
	my $samba = int ($Set->Get('BBS_SAMBATIME', '') eq ''
					? $Sys->Get('DEFSAMBA') : $Set->Get('BBS_SAMBATIME'));
	my $tm = time;

	my $upform = ($Sys->Get('UPLOAD') && $Sys->Get('IMGUR_ID') && $Sys->Get('IMGUR_SECRET') && $Set->Get('BBS_UPLOAD')) ? 
	'<input type="file" id="fileInput" name="image_file" accept="image/jpeg,image/png,image/gif,image/apng,image/tiff,
    video/mp4,video/mpeg,video/avi,video/webm,video/quicktime,video/x-matroska,video/x-flv,video/x-msvideo,video/x-ms-wmv">
	<button type="button" id="clearBtn" style="display:none">選択解除</button>' : '';
	my $data_url = $Sys->Get('SERVER').$Sys->Get('CGIPATH').$Sys->Get('DATA');

	if ($Set->Get('BBS_READONLY') ne 'on'){
	# スレッド作成画面を別画面で表示
	if (0) {
		# 廃止
=pod
		$Page->Print(<<FORM);
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$tblCol" align="center">
 <tr>
  <td align="center">
  <form method="POST" action="$cgipath/bbs.cgi" style="margin:1.2em 0;">
  <input type="submit" value="新規スレッド作成画面へ" style="font-size: 1.4em;"><br>
  <input type="hidden" name="bbs" value="$bbs">
  <input type="hidden" name="time" value="$tm">
  </form>
  </td>
 </tr>
</table>
FORM
=cut
	}
	# スレッド作成フォームはindexと同じ画面に表示
	else {
		my $status = $Set->Equal('BBS_READONLY', 'caps') || $Set->Equal('BBS_THREADCAPONLY', 'checked') ? '必須' : '任意';
		$Page->Print(<<FORM);

<form method="POST" action="$cgipath/bbs.cgi" enctype="multipart/form-data">
<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="$tblCol" style="margin-bottom:1.2em;" align="center">
 <tr>
  <td>
  <input type="submit" value="　新規スレッド作成　">
  <hr><a id=\"new_thread\"></a>
  <div class ="reverse_order">
  <span class = "order2"><input type="text" name="subject" size="40" placeholder="スレッドタイトル（必須）"></span>
  </div>
  <br class="smartphone">
  <input type="text" name="FROM" size="19" placeholder="名前（任意）">
  <input type="text" name="mail" size="19" placeholder="コマンド・Cap（$status）"> $upform<br>
   <span style="margin-top:0px;">
   <div class="bbs_service_textarea"><textarea rows="5" cols="70" name="MESSAGE" placeholder="投稿したい内容を入力してください（必須）"></textarea></div>
   </span>
	<input type="hidden" name="bbs" value="$bbs">
  <input type="hidden" name="time" value="$tm">
  <input type="hidden" name="from_index" value="1">
</td>
 </tr>
</table>
</form>
FORM
	}
}
	else{
		$Page->Print('<table border="1" cellspacing="7" cellpadding="3" width="95%" bgcolor="#CCFFCC" style="margin-bottom:1.2em;" align="center">');
		$Page->Print("<tr><td>READ ONLY</td></tr></table>");
	}
	
	# footの表示
	$Caption->Load($Sys, 'FOOT');
	$Caption->Print($Page, $Set);
	$Page->Print("<div align=\"center\"><a href=\"./SETTING.TXT\">SETTING.TXT</a></div>");

	my ($sec,$min,$hour,$day,$mon,$year) = localtime($Sys->Get('LASTMOD'));
	$mon ++;
	$year += 1900;
	my $lastMod = sprintf("Last modified : %d/%02d/%02d %02d:%02d:%02d",$year,$mon,$day,$hour,$min,$sec);
	$Page->Print("<div align=\"center\" style=\"font-size: 0.8em; color: #933;\">$lastMod</div>");

	my $is_fcgi = $ENV{'FCGI_ROLE'} ? '/FastCGI' : '';
	
	$Page->Print(<<FOOT);
<div style="margin-top:1.2em;">
<a href="https://github.com/PrefKarafuto/ex0ch">EXぜろちゃんねる</a>
BBS.CGI - $ver (Perl$is_fcgi)
@{[ $Sys->Get('DNSBL_TOREXIT') ? '+dan.me.uk' : '' ]}
@{[ $Sys->Get('DNSBL_SPAMHAUS') ? '+S5H' : '' ]}
@{[ $Sys->Get('DNSBL_S5H') ? '+S5H' : '' ]}
@{[ $Sys->Get('DNSBL_DRONEBL') ? '+DeoneBL' : '' ]}
@{[ $Set->Get('BBS_NINJA') ? '+忍法帖' : '' ]}
@{[ $Set->Get('BBS_AUTH') ? '+ユーザー認証' : '' ]}
+Samba24=$samba<br>
</div>
</main>
<div id="overlay">
	<img id="overlay-image">
  </div>
<style>
/* スマホ用レイアウト */
img {
	max-width: 100%;
	height:auto;
}
</style>
 <script language="javascript" src="$data_url/script.js"></script>
FOOT
	
	$Page->Print("</body>\n</html>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(スレッドプレビュー部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page		
#	@param	$Dat		
#	@param	$commands	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadPreviewOne
{
	my $this = shift;
	my ($Page, $Dat, $commands) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Set = $this->{'SET'};
	
	# 前準備
	my $contNum = $this->{'SET'}->Get('BBS_CONTENTS_NUMBER');
	my $cgiPath = $Sys->Get('SERVER') . $Sys->Get('CGIPATH');
	my $bbs = $Sys->Get('BBS');
	my $key = $Sys->Get('KEY');
	my $tm = time;
 	my $bbsPath = $Sys->Get('BBSPATH');
	
	my $permt = DAT::GetPermission("$bbsPath/$bbs/dat/$key.dat");
	my $perms = $Sys->Get('PM-STOP');
	my $isstop = $permt == $perms;
 
	require "./module/thread.pl";
	my $Threads = THREAD->new;

	$Threads->LoadAttr($Sys);
	my $AttrMax = $Threads->GetAttr($key,'maxres');
	my $threadStop = $Threads->GetAttr($key,'stop');
	my $threadPool = $Threads->GetAttr($key,'pool');
	my $rmax = $AttrMax ? $AttrMax : $Sys->Get('RESMAX');
	# 表示数の正規化
	my ($start, $end) = $this->{'CONV'}->RegularDispNum($Sys, $Dat, 1, $contNum, $contNum);
	$start++ if ($start == 1);
	
	# 1の表示
	PrintResponse($this, $Page, $Dat, $commands, 1);
	# 残りの表示
	for (my $i = $start; $i <= $end; $i++) {
		PrintResponse($this, $Page, $Dat, $commands, $i);
	}
	if($rmax > $Dat->Size() && $this->{'SET'}->Get('BBS_READONLY') ne 'on' && !$isstop && !$threadStop && !$threadPool){
		# 書き込みフォームの表示
		my $status = $this->{'SET'}->Equal('BBS_READONLY', 'caps') ? '必須' : '任意';
		my $upform = ($Sys->Get('UPLOAD') && $Sys->Get('IMGUR_ID') && $Sys->Get('IMGUR_SECRET') && $Set->Get('BBS_UPLOAD')) ? 
	'<input type="file" id="fileInput" name="image_file" accept="image/jpeg,image/png,image/gif,image/apng,image/tiff,
    video/mp4,video/mpeg,video/avi,video/webm,video/quicktime,video/x-matroska,video/x-flv,video/x-msvideo,video/x-ms-wmv">
	<button type="button" id="clearBtn" style="display:none">選択解除</button>' : '';
		$Page->Print(<<KAKIKO);
  </dl>
  <hr>
  <form method="POST" action="$cgiPath/bbs.cgi" enctype="multipart/form-data">
   <blockquote>
   <input type="hidden" name="bbs" value="$bbs">
   <input type="hidden" name="key" value="$key">
   <input type="hidden" name="time" value="$tm">
   <input type="hidden" name="from_index" value="1">
   <input type="submit" value="　書き込む　" name="submit"><br class="smartphone">
   <input type="text" name="FROM" size="19" placeholder="名前（任意）">
   <input type="text" name="mail" size="19" placeholder="コマンド・Cap（$status）"> $upform<br>
	<div class ="bbs_service_textarea">
	<textarea rows="5" cols="64" name="MESSAGE" placeholder="投稿したい内容を入力してください（必須）"></textarea>
	</div>
KAKIKO
	}
	else{
		$Page->Print("<hr>");
		$Page->Print("<font size=4>READ ONLY</font><br><br>");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	index.html生成(レス表示部分)
#	-------------------------------------------------------------------------------------
#	@param	$Page		
#	@param	$Dat		
#	@param	$commands	
#	@param	$n			
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResponse
{
	my $this = shift;
	my ($Page, $Dat, $commands, $n) = @_;
	
	my $Sys = $this->{'SYS'};
	my $Conv = $this->{'CONV'};
	my $Set = $this->{'SET'};
	
	my $pdat = $Dat->Get($n - 1);
	return if (!defined $pdat);
	
	my @elem = split(/<>/, $$pdat, -1);
	my $contLen = length $elem[3];
	my $contLine = $Conv->GetTextLine(\$elem[3]);
	my $nameCol = $this->{'SET'}->Get('BBS_NAME_COLOR');
	my $dispLine = $this->{'SET'}->Get('BBS_INDEX_LINE_NUMBER');
	my $aa='';
 
	# URLと引用個所の適応
	$Conv->ConvertMovie(\$elem[3])if($Set->Get('BBS_MOVIE') eq 'checked');
	$Conv->ConvertURL($Sys, $Set, 0, \$elem[3])if($Sys->Get('URLLINK') eq 'TRUE');
	$Conv->ConvertTweet(\$elem[3])if($Set->Get('BBS_TWITTER') eq 'checked');
	$Conv->ConvertSpecialQuotation($Sys, \$elem[3])if($Set->Get('BBS_HIGHLIGHT') eq 'checked');
	$Conv->ConvertImageTag($Sys,$Sys->Get('LIMTIME'),\$elem[3])if($Set->Get('BBS_IMGTAG'));
	$Conv->ConvertQuotation($Sys, \$elem[3], 0);
 
	# 拡張機能を実行
	$Sys->Set('_DAT_', \@elem);
	$Sys->Set('_NUM_', $n);
	foreach my $command (@$commands) {
		$command->execute($this->{'SYS'}, undef, 8);
	}

	$Page->Print("   <dt>$n 名前：");
	
	# メール欄有り
	if ($elem[1] eq '') {
		$Page->Print("<font color=\"$nameCol\"><b>$elem[0]</b></font>");
	}
	# メール欄無し
	else {
		my $color = $Set->Get('BBS_LINK_COLOR');
		$Page->Print("<font color=\"$color\"><b>$elem[0]</b></font>");
	}
	if($elem[1] =~ /!aafont/){
		# レイアウトが崩れるのでCO
		#$aa = 'class="aaview"';
	}
	# 表示行数内ならすべて表示する
	if ($contLine <= $dispLine || $n == 1) {
		$Page->Print("：$elem[2]</dt>\n    <dd $aa>$elem[3]<br><br></dd>\n");
	}
	# 表示行数を超えたら省略表示を付加する
	else {
		my @dispBuff = split(/<br>/i, $elem[3]);
		my $path = $Conv->CreatePath($Sys, 0, $Sys->Get('BBS'), $Sys->Get('KEY'), "${n}n");
		
		$Page->Print("：$elem[2]</dt>\n    <div $aa><dd>");
		for (my $k = 0; $k < $dispLine; $k++) {
			$Page->Print("$dispBuff[$k]<br>");
		}
		$Page->Print("</div><font color=\"green\">（省略されました・・全てを読むには");
		$Page->Print("<a href=\"$path\" target=\"_blank\">ここ</a>");
		$Page->Print("を押してください）</font><br><br></dd>\n");
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
