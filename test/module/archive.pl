#============================================================================================================
#
#	過去ログ管理モジュール
#
#============================================================================================================
package	ARCHIVE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
#use warnings;

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
		'KEY'		=> undef,
		'SUBJECT'	=> undef,
		'DATE'		=> undef,
		'PATH'		=> undef
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログ情報ファイル読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	エラー番号
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'KEY'} = {};
	$this->{'SUBJECT'} = {};
	$this->{'DATE'} = {};
	$this->{'PATH'} = {};
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/kako/kako.idx';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '');
			
			my @elem = split(/<>/, $_);
			if (scalar(@elem) < 5) {
				warn "invalid line in $path";
				next;
			}
			
			my $id = $elem[0];
			$this->{'KEY'}->{$id} = $elem[1];
			$this->{'SUBJECT'}->{$id} = $elem[2];
			$this->{'DATE'}->{$id} = $elem[3];
			$this->{'PATH'}->{$id} = $elem[4];
		}
		return 0;
	}
	return -1;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログ情報ファイル書き込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/kako/kako.idx';
	
	chmod($Sys->Get('PM-DAT'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		foreach (keys %{$this->{'KEY'}}) {
			my $data = join('<>',
				$_,
				$this->{'KEY'}->{$_},
				$this->{'SUBJECT'}->{$_},
				$this->{'DATE'}->{$_},
				$this->{'PATH'}->{$_}
			);
			
			print $fh "$data\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	else {
		warn "can't save subject: $path";
	}
	chmod($Sys->Get('PM-DAT'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	IDセット取得
#	-------------------------------------------------------------------------------------
#	@param	$kind	検索種別
#	@param	$name	検索ワード
#	@param	$pBuf	IDセット格納バッファ
#	@return	キーセット数
#
#------------------------------------------------------------------------------------------------------------
sub GetKeySet
{
	my $this = shift;
	my ($kind, $name, $pBuf) = @_;
	
	my $n = 0;
	
	if ($kind eq 'ALL') {
		foreach my $key (keys %{$this->{'KEY'}}) {
			if ($this->{'KEY'}->{$key} ne '0') {
				$n += push @$pBuf, $key;
			}
		}
	}
	else {
		foreach my $key (keys %{$this->{$kind}}) {
			if ($this->{$kind}->{$key} eq $name || $kind eq 'ALL') {
				$n += push @$pBuf, $key;
			}
		}
	}
	
	return $n;
}

#------------------------------------------------------------------------------------------------------------
#
#	情報取得
#	-------------------------------------------------------------------------------------
#	@param	$kind		情報種別
#	@param	$key		ユーザID
#	@param	$default	デフォルト
#	@return	ユーザ情報
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($kind, $key, $default) = @_;
	
	my $val = $this->{$kind}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	追加
#	-------------------------------------------------------------------------------------
#	@param	$key		スレッドキー
#	@param	$subject	スレッドタイトル
#	@param	$date		更新日時
#	@param	$path		パス
#	@return	ID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($key, $subject, $date, $path) = @_;
	
	my $id = time;
	$id++ while (exists $this->{'KEY'}->{$id});
	
	$this->{'KEY'}->{$id} = $key;
	$this->{'SUBJECT'}->{$id} = $subject;
	$this->{'DATE'}->{$id} = $date;
	$this->{'PATH'}->{$id} = $path;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		ID
#	@param	$kind	情報種別
#	@param	$val	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($id, $kind, $val) = @_;
	
	if (exists $this->{$kind}->{$id}) {
		$this->{$kind}->{$id} = $val;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除ID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'KEY'}->{$id};
	delete $this->{'SUBJECT'}->{$id};
	delete $this->{'DATE'}->{$id};
	delete $this->{'PATH'}->{$id};
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログ情報の更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub UpdateInfo
{
	my $this = shift;
	my ($Sys) = @_;
	
	require './module/file_utils.pl';
	
	$this->{'KEY'} = {};
	$this->{'SUBJECT'} = {};
	$this->{'DATE'} = {};
	$this->{'PATH'} = {};
	
	my $path = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/kako';
	
	# ディレクトリ情報を取得
	my $hierarchy = {};
	my @dirList = ();
	FILE_UTILS::GetFolderHierarchy($path, $hierarchy);
	FILE_UTILS::GetFolderList($hierarchy, \@dirList, '');
	
	foreach my $dir (@dirList) {
		my @fileList = ();
		FILE_UTILS::GetFileList("$path/$dir", \@fileList, '([0-9]+)\.html');
		$this->Add(0, 0, 0, $dir);
		foreach my $file (sort @fileList) {
			my @elem = split(/\./, $file);
			my $subj = GetThreadSubject("$path/$dir/$file");
			if (defined $subj) {
				$this->Add($elem[0], $subj, time, $dir);
			}
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログindexの更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Page	
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub UpdateIndex
{
	my $this = shift;
	my ($Sys, $Page) = @_;
	
	# 告知情報読み込み
	require './module/banner.pl';
	my $Banner = BANNER->new;
	$Banner->Load($Sys);
	
	my $basePath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS');
	
	# パスをキーにしてハッシュを作成
	my %PATHES = ();
	foreach my $id (keys %{$this->{'KEY'}}) {
		my $path = $this->{'PATH'}->{$id};
		$PATHES{$path} = $id;
	}
	my @dirs = keys %PATHES;
	unshift @dirs, '';
	
	# パスごとにindexを生成する
	foreach my $path (@dirs) {
		my @info = ();
		
		# 1階層下のサブフォルダを取得する
		my @folderList = ();
		GetSubFolders($path, \@dirs, \@folderList);
		foreach my $dir (sort @folderList) {
			push @info, "0<>0<>0<>$dir";
		}
		
		# ログデータがあれば情報配列に追加する
		foreach my $id (keys %{$this->{'KEY'}}) {
			if ($path eq $this->{'PATH'}->{$id} && $this->{'KEY'}->{$id} ne '0') {
				my $data = join('<>',
					$this->{'KEY'}->{$id},
					$this->{'SUBJECT'}->{$id},
					$this->{'DATE'}->{$id},
					$path
				);
				push @info, "$data";
			}
		}
		
		# indexファイルを出力する
		$Page->Clear();
		OutputIndex($Sys, $Page, $Banner, \@info, $basePath, $path);
		chmod($Sys->Get('PM-KDIR'), "$basePath/kako$path");
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	サブフォルダを取得する
#	-------------------------------------------------------------------------------------
#	@param	$base	親フォルダパス
#	@param	$pDirs	ディレクトリ名の配列
#	@param	$pList	サブフォルダ格納配列
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub GetSubFolders
{
	
	my ($base, $pDirs, $pList) = @_;
	
	# foreach my $dir とすると$pDirが破壊される
	foreach (@$pDirs) {
		my $dir = $_;
		if ($dir =~ s|^\Q$base/\E|| && $dir !~ m|/|) {
			push @$pList, $dir;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログタイトルの取得
#	-------------------------------------------------------------------------------------
#	@param	$path	取得するファイルのパス
#	@return	タイトル
#
#------------------------------------------------------------------------------------------------------------
sub GetThreadSubject
{
	
	my ($path) = @_;
	my $title = undef;
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		
		foreach (@lines) {
			if ($_ =~ m|<title>(.*)</title>|) {
				$title = $1;
				last;
			}
		}
	}
	else {
		warn "can't open: $path";
	}
	return $title;
}

#------------------------------------------------------------------------------------------------------------
#
#	過去ログindexを出力する
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Page	BUFFER_OUTPUT
#	@param	$Banner	BANNER
#	@param	$pInfo	出力情報配列
#	@param	$base	掲示板トップパス
#	@param	$path	index出力パス
#	@param	$Set	SETTING
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub OutputIndex
{
	
	my ($Sys, $Page, $Banner, $pInfo, $base, $path, $Set) = @_;
	
	my $cgipath	= $Sys->Get('CGIPATH');
	
	require './module/header_footer_meta.pl';
	my $Caption = HEADER_FOOTER_META->new;
	$Caption->Load($Sys, 'META');
	
	my $version = $Sys->Get('VERSION');
	my $bbsRoot = $Sys->Get('CGIPATH') . '/' . $Sys->Get('BBSPATH') . '/'. $Sys->Get('BBS');
	my $board = $Sys->Get('BBS');
	
	$Page->Print(<<HTML);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>

 <meta http-equiv="Content-Type" content="text/html;charset=Shift_JIS">

HTML
	
	$Caption->Print($Page, undef);
	
	$Page->Print(<<HTML);
 <title>過去ログ倉庫 - $board$path</title>

</head>
<!--nobanner-->
<body>
HTML
	
	# 告知欄出力
	$Banner->Print($Page, 100, 2, 0) if ($Sys->Get('BANNER') & 5);
	
	$Page->Print(<<HTML);

<h1 align="center" style="margin-bottom:0.2em;">過去ログ倉庫</h1>
<h2 align="center" style="margin-top:0.2em;">$board</h2>

<table border="1">
 <tr>
  <th>KEY</th>
  <th>subject</th>
  <th>date</th>
 </tr>
HTML
	
	foreach (@$pInfo) {
		my @elem = split(/<>/, $_, -1);
		
		# サブフォルダ情報
		if ($elem[0] eq '0') {
			$Page->Print(" <tr>\n  <td>Directory</td>\n  <td><a href=\"$elem[3]/\">");
			$Page->Print("$elem[3]</a></td>\n  <td>-</td>\n </tr>\n");
		}
		# 過去ログ情報
		else {
			$Page->Print(" <tr>\n  <td>$elem[0]</td>\n  <td><a href=\"$elem[0].html\">");
			$Page->Print("$elem[1]</a></td>\n  <td>$elem[2]</td>\n </tr>\n");
		}
	}
	$Page->Print("</table>\n\n<hr>\n");
	$Page->Print(<<HTML);

<a href="$bbsRoot/">■掲示板に戻る■</a> | <a href="$bbsRoot/kako/">■過去ログトップに戻る■</a> | <a href="../">■1つ上に戻る■</a>

<hr>

<div align="right">
$version
</div>
</body>
</html>
HTML
	
	# index.htmlを出力する
	$Page->Flush(1, 0666, "$base/kako$path/index.html");
}

#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
