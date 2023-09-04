#!/usr/bin/perl
use strict;
use utf8;
use warnings;
binmode(STDOUT,":encoding(cp932)");
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);

my $system_dir = './test';
chdir $system_dir;

exit(main());

sub main
{
	print "Content-Type: text/html; charset=Shift_JIS\n\n";
	print "<title>BBSMENU</title>";
	require "./module/system.pl";
	my $SYS = new SYSTEM;
	return undef if ($SYS->Init() ne 0);
	
	my @time=localtime;
	$time[5] += 1900;
	$time[4] ++;
	
	my $bbsmenu = getbbsmenu();
	my $url = $SYS->Get('SERVER');
	my $lastmodified = (stat './bbsmenu.cgi')[9];
	
	if (! defined $bbsmenu) {
		print "BBSMENUがありません<br>\n";
		return 0;
	}
	print "<body style=\"border:0px solid #333; position:fixed; left:0em; top:0em; bottom:auto; width:12em; height:100%; z-index:1; margin:0; padding:0; color:#F33; background: #FFF; overflow-y: scroll;font-size:0.81em;\"><font size=\"2\">";
	print "<a href=\"$url\" target=\"_top\">TOP</a><br>";
	print "<a href=\"./search.cgi\" target=\"_top\">レス検索</a><br><br>";
	foreach my $category (@$bbsmenu) {
		print "<b>$category->{name}</b><br>\n";
		
		foreach my $bbs (@{$category->{list}}) {
			print "<a href=\"$bbs->{url}\" target=\"_main\">$bbs->{name}</a><br>\n";
		}
		
		print "<br>\n";
	}
	print "<b>他のサイト</b><br>";
	print "<a href=\"https://github.com/PrefKarafuto/New_0ch_Plus\" target=\"_top\">ぜろちゃんねるプラス</a><br><br>";
	print "<br>更新日<br>$time[5]/$time[4]/$time[3]";
	print "</font></body>";
	return 0;
}

sub getbbsmenu
{
	require "./module/system.pl";
	require "./module/bbs_info.pl";
	require "./module/data_utils.pl";
	
	my $SYS = new SYSTEM;
	return undef if ($SYS->Init() ne 0);
	
	my $basedir = $SYS->Get('SERVER', '').$SYS->Get('CGIPATH', '');
	$basedir =~ s/\/test$//;
	
	my $BBS = BBS_INFO->new;
	$BBS->Load($SYS);
	
	my $Category = CATEGORY_INFO->new;
	$Category->Load($SYS);
	
	my @catSet = ();
	$Category->GetKeySet(\@catSet);
	
	my $bbsmenu = [];
	
	foreach my $catid (sort @catSet) {
		my $catData = {};
		
		$catData->{name} = $Category->Get('NAME', $catid);
		
		my $bbslist = [];
		$catData->{list} = $bbslist;
		
		my @bbsSet = ();
		$BBS->GetKeySet('CATEGORY', $catid, \@bbsSet);
		
		foreach my $bbsid (sort @bbsSet) {
			my $bbsData = {};
			
			$bbsData->{name} = $BBS->Get('NAME', $bbsid);
			
			my $bbsDir = $BBS->Get('DIR', $bbsid);
			$bbsData->{dir} = $bbsDir;
			$bbsData->{url} = "$basedir/$bbsDir";
			
			push @$bbslist, $bbsData;
		}
		
		push @$bbsmenu, $catData;
	}
	
	return $bbsmenu;
}
