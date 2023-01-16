#!/usr/bin/perl
#============================================================================================================
#
#	携帯用ページ表示専用CGI
#	p.cgi
#	---------------------------------------------
#	2004.09.15 システム改変に伴う新規作成
#
#============================================================================================================

use strict;
#use warnings;
##use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
no warnings 'once';

BEGIN { use lib './perllib'; }

# CGIの実行結果を終了コードとする
exit(PCGI());

#------------------------------------------------------------------------------------------------------------
#
#	p.cgiメイン
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PCGI
{
	my ($Sys, $Threads, $Set, $Page, $Form, $Conv);
	my (%pPath, @tList);
	my ($base, $max, $err);
	
	require './module/thread.pl';
	require './module/setting.pl';
	require './module/data_utils.pl';
	require './module/system.pl';
	require './module/form.pl';
	require './module/buffer_output.pl';
	
	$Threads	= new THREAD;
	$Conv		= new DATA_UTILS;
	$Set		= new SETTING;
	$Sys		= new SYSTEM;
	$Form		= FORM->new(0);
	$Page		= new BUFFER_OUTPUT;
	
	$max = 0;
	$err = 1;
	
	# urlからパスを解析
	GetPathData(\%pPath);
	
	# モジュールの初期化
	$Form->DecodeForm(1);
	$Sys->Init();
	$Sys->Set('BBS', $pPath{'bbs'});
	$err = $Set->Load($Sys);
	
	if ($err == 1) {
		$Threads->Load($Sys);
		
		# スレッドリストの作成
		if ($Form->Equal('method', '')) {
			# 検索無し
			$max = CreateThreadList($Threads, $Set, \@tList, \%pPath, '');
		}
		else {
			# 検索あり
			$max = CreateThreadList($Threads, $Set, \@tList, \%pPath, $Form->Get('word', ''));
		}
	}
	
	# ページの出力
	PrintHead($Page, $Sys, $Set, $pPath{'st'}, $max);
	PrintThreadList($Page, $Sys, $Conv, \@tList) if ($err == 1);
	PrintFoot($Page, $Sys, $Set, $pPath{'st'}, $max);
	
	# 画面へ出力
	$Page->Flush(0, 0, '');
}

#------------------------------------------------------------------------------------------------------------
#
#	ヘッダ部分出力
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@param	$Sys	SYSTEM
#	@param	$num	表示数
#	@param	$last	最終数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintHead
{
	my ($Page, $Sys, $Set, $start, $last) = @_;
	my ($path, $st, $bbs, $code);
	
	$path	= $Sys->Get('SERVER') . $Sys->Get('CGIPATH') . '/p.cgi';
	$bbs	= $Sys->Get('BBS');
	$start	= $start - $Set->Get('BBS_MAX_MENU_THREAD');
	$st		= $start < 1 ? 1 : $start;
	$code	= 'Shift_JIS';
	
	# HTMLヘッダの出力
	$Page->Print("Content-type: text/html\n\n");
	$Page->Print('<html><!--nobanner--><head><title>i-mode 0ch</title>');
	$Page->Print("<meta http-equiv=Content-Type content=\"text/html;charset=$code\">");
	$Page->Print('</head>');
	$Page->Print("<body><form action=\"$path/$bbs\" method=\"POST\">");
	
	if ($Sys->Get('PATHKIND')) {
		$Page->Print("<a href=\"$path?bbs=$bbs&st=$st\">前</a> ");
		$Page->Print("<a href=\"$path?bbs=$bbs&st=$last\">次</a><br>\n");
	}
	else {
		$Page->Print("<a href=\"$path/$bbs/$st\">前</a> ");
		$Page->Print("<a href=\"$path/$bbs/$last\">次</a><br>\n");
	}
	$Page->Print("<input type=hidden name=method value=search>");
	$Page->Print("<input type=text name=word><input type=submit value=\"検索\"><hr>");
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドリストの表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@param	$Sys	SYSTEM
#	@param	$Conv	DATA_UTILS
#	@param	$pList	リスト格納バッファ
#	@param	$base	ベースパス
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadList
{
	my ($Page, $Sys, $Conv, $pList) = @_;
	my (@elem, $path);
	
	foreach (@{$pList}) {
		@elem = split(/<>/, $_);
		$path = $Conv->CreatePath($Sys, 1, $Sys->Get('BBS'), $elem[1], 'l10');
		$Page->Print("$elem[0]: <a href=\"$path\">$elem[2]($elem[3])</a><br>\n");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	フッタ部分出力 - PrintHead
#	-------------------------------------------------------------------------------------
#	@param	$Page	BUFFER_OUTPUT
#	@param	$Sys	SYSTEM
#	@param	$num	表示数
#	@param	$last	最終数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintFoot
{
	my ($Page, $Sys, $Set, $start, $last) = @_;
	my ($ver, $path, $st, $bbs);
	
	$path	= $Sys->Get('SERVER') . $Sys->Get('CGIPATH') . '/p.cgi';
	$bbs	= $Sys->Get('BBS');
	$ver	= $Sys->Get('VERSION');
	$start	= $start - $Set->Get('BBS_MAX_MENU_THREAD');
	$st		= $start < 1 ? 1 : $start;
	
	if ($Sys->Get('PATHKIND')) {
		$Page->Print("<hr><a href=\"$path?bbs=$bbs&st=$st\">前</a> ");
		$Page->Print("<a href=\"$path?bbs=$bbs&st=$last\">次</a><br>\n");
	}
	else {
		$Page->Print("<hr><a href=\"$path/$bbs/$st\">前</a> ");
		$Page->Print("<a href=\"$path/$bbs/$last\">次</a><br>\n");
	}
	$Page->Print("<hr>$ver</form></body></html>\n");
}

#------------------------------------------------------------------------------------------------------------
#
#	パスデータ解析
#	-------------------------------------------------------------------------------------
#	@param	$pHash	ハッシュの参照
#	@return	なし
#
#	2010.08.12 windyakin ★
#	 -> http://0ch.mine.nu/test/read.cgi/jikken/1273239400/5 対応
#
#------------------------------------------------------------------------------------------------------------
sub GetPathData
{
	my ($pHash) = @_;
	my (@plist, $var, $val);
	
	$pHash->{'bbs'} = '';
	$pHash->{'st'} = 0;
	
	if ($ENV{'PATH_INFO'}) {
		use CGI;
		@plist = split(/\//, CGI::escapeHTML($ENV{'PATH_INFO'}));
		$pHash->{'bbs'} = $plist[1] if (defined $plist[1]);
		$pHash->{'st'} = int($plist[2] || 0);
	}
	else {
		@plist = split(/&/, $ENV{'QUERY_STRING'});
		foreach (@plist) {
			($var, $val) = split(/=/, $_);
			$pHash->{$var} = $val;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	スレッドリストの生成
#	-------------------------------------------------------------------------------------
#	@param	$Threads	THREAD
#	@param	$Set		SETTING
#	@param	$pList		結果格納用配列
#	@param	$pHash		情報ハッシュ
#	@param	$keyWord	検索ワード
#	@return	リスト最後のインデクス
#
#------------------------------------------------------------------------------------------------------------
sub CreateThreadList
{
	my ($Threads, $Set, $pList, $pHash, $keyWord) = @_;
	my (@threadSet, $threadNum, $max, $start);
	my ($key, $subject, $res, $i, $data);
	
	# スレッド一覧の取得
	$Threads->GetKeySet('ALL', '', \@threadSet);
	$threadNum = @threadSet;
	
	# 検索ワード無しの場合は開始からスレッド表示最大数までのリストを作成
	if ($keyWord eq '') {
		$start	= $pHash->{'st'} > $threadNum ? $threadNum : $pHash->{'st'};
		$start	= $start < 1 ? 1 : $start;
		$max	= $start + $Set->Get('BBS_MAX_MENU_THREAD');
		$max	= $max < $threadNum ? $max : $threadNum + 1;
		$max	= $max == $start ? $max + 1 : $max;
		for ($i = $start ; $i < $max ; $i++) {
			$key		= $threadSet[$i - 1];
			$subject	= $Threads->Get('SUBJECT', $key);
			$res		= $Threads->Get('RES', $key);
			$data		= "$i<>$key<>$subject<>$res";
			push @{$pList}, $data;
		}
	}
	# 検索ワードがある場合は検索ワードを含む全てのスレッドのリストを作成
	else {
		my $nextNum = 1;
		$max	= $threadNum;
		$start	= 1;
		for ($i = $start;$i < $max + 1;$i++) {
			$key		= $threadSet[$i - 1];
			$subject	= $Threads->Get('SUBJECT', $key);
			if ($subject =~ /\Q$keyWord\E/) {
				$res	= $Threads->Get('RES', $key);
				$data	= "$i<>$key<>$subject<>$res";
				push @{$pList}, $data;
				$nextNum = $i;
			}
		}
		$max = $nextNum + 1;
	}
	return $max;
}

