#============================================================================================================
#
#	管理セキュリティ管理モジュール
#	-------------------------------------------------------------------------------------
#	このモジュールは管理CGIのセキュリティ情報を管理します。
#	以下の3つのパッケージによって構成されます
#
#	USER_INFO	: ユーザ情報管理
#	GROUP_INFO		: グループ情報管理
#	SECURITY		: セキュリティインタフェイス
#
#============================================================================================================

#============================================================================================================
#
#	ユーザ管理パッケージ
#
#============================================================================================================
package	USER_INFO;

use strict;
use utf8;
binmode(STDOUT,":utf8");
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
		'NAME'	=> undef,
		'PASS'	=> undef,
		'FULL'	=> undef,
		'EXPL'	=> undef,
		'SYSAD'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	# ハッシュ初期化
	$this->{'NAME'} = {};
	$this->{'PASS'} = {};
	$this->{'FULL'} = {};
	$this->{'EXPL'} = {};
	$this->{'SYSAD'} = {};
	
	my $path = '.' . $Sys->Get('INFO') . '/users.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '');
			
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 6) {
				warn "invalid line in $path";
				next;
			}
			
			my $id = $elem[0];
			$this->{'NAME'}->{$id} = $elem[1];
			$this->{'PASS'}->{$id} = $elem[2];
			$this->{'FULL'}->{$id} = $elem[3];
			$this->{'EXPL'}->{$id} = $elem[4];
			$this->{'SYSAD'}->{$id} = $elem[5];
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = '.' . $Sys->Get('INFO') . '/users.cgi';
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		binmode($fh);
		seek($fh, 0, 0);
		
		foreach (keys %{$this->{'NAME'}}) {
			my $data = join('<>',
				$_,
				$this->{'NAME'}->{$_},
				$this->{'PASS'}->{$_},
				$this->{'FULL'}->{$_},
				$this->{'EXPL'}->{$_},
				$this->{'SYSAD'}->{$_}
			);
			
			print $fh "$data\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザIDセット取得
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
		$n += push @$pBuf, keys %{$this->{'NAME'}};
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
#	ユーザ情報取得
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
#	ユーザ追加
#	-------------------------------------------------------------------------------------
#	@param	$name	情報種別
#	@param	$pass	ユーザID
#	@param	$full	
#	@param	$explan	説明
#	@param	$sysad	管理者フラグ
#	@return	ユーザID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($name, $pass, $full, $explan, $sysad) = @_;
	
	my $id = time;
	$this->{'NAME'}->{$id} = $name;
	$this->{'PASS'}->{$id} = $this->GetStrictPass($pass, $id);
	$this->{'EXPL'}->{$id} = $explan;
	$this->{'FULL'}->{$id} = $full;
	$this->{'SYSAD'}->{$id} = $sysad;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		ユーザID
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
		if ($kind eq 'PASS') {
			$val = $this->GetStrictPass($val, $id);
		}
		$this->{$kind}->{$id} = $val;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ユーザ情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除ユーザID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'NAME'}->{$id};
	delete $this->{'PASS'}->{$id};
	delete $this->{'FULL'}->{$id};
	delete $this->{'EXPL'}->{$id};
	delete $this->{'SYSAD'}->{$id};
}

#------------------------------------------------------------------------------------------------------------
#
#	暗号化パス取得
#	-------------------------------------------------------------------------------------
#	@param	$pass	パスワード
#	@param	$key	パスワード変換キー
#	@return	暗号化されたパスコード
#
#------------------------------------------------------------------------------------------------------------
sub GetStrictPass
{
	my $this = shift;
	my ($pass, $key) = @_;
	
	my $hash;
	
	if (length($pass) >= 9) {
		require Digest::SHA::PurePerl;
		Digest::SHA::PurePerl->import( qw(sha1_base64) );
		$hash = substr(crypt($key, 'ZC'), -2);
		$hash = substr(sha1_base64("ZeroChPlus_${hash}_$pass"), 0, 10);
	}
	else {
		$hash = substr(crypt($pass, substr(crypt($key, 'ZC'), -2)), -10);
	}
	
	return $hash;
}


#============================================================================================================
#
#	グループ管理パッケージ
#
#============================================================================================================
package	GROUP_INFO;

use strict;
use utf8;
binmode(STDOUT,":utf8");
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
		'NAME'	=> undef,
		'EXPL'	=> undef,
		'AUTH'	=> undef,
		'USERS'	=> undef,
	};
	
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ情報読み込み
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys) = @_;
	
	# ハッシュ初期化
	$this->{'NAME'} = {};
	$this->{'EXPL'} = {};
	$this->{'AUTH'} = {};
	$this->{'USERS'} = {};
	
	my $path = $Sys->Get('BBSPATH') . '/' .  $Sys->Get('BBS') . '/info/groups.cgi';
	
	if (open(my $fh, '<', $path)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			next if ($_ eq '');
			
			my @elem = split(/<>/, $_, -1);
			if (scalar(@elem) < 5) {
				warn "invalid line in $path";
				next;
			}
			
			my $id = $elem[0];
			$elem[4] =~ s/ //g;
			$this->{'NAME'}->{$id} = $elem[1];
			$this->{'EXPL'}->{$id} = $elem[2];
			$this->{'AUTH'}->{$id} = $elem[3];
			$this->{'USERS'}->{$id} = $elem[4];
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys) = @_;
	
	my $path = $Sys->Get('BBSPATH') . '/' .  $Sys->Get('BBS') . '/info/groups.cgi';
	
	chmod($Sys->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		binmode($fh);
		
		foreach (keys %{$this->{'NAME'}}) {
			my $data = join('<>',
				$_,
				$this->{'NAME'}->{$_},
				$this->{'EXPL'}->{$_},
				$this->{'AUTH'}->{$_},
				$this->{'USERS'}->{$_}
			);
			
			print $fh "$data\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	chmod($Sys->Get('PM-ADM'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	グループIDセット取得
#	-------------------------------------------------------------------------------------
#	@param	$pBuf	IDセット格納バッファ
#	@return	グループID数
#
#------------------------------------------------------------------------------------------------------------
sub GetKeySet
{
	my $this = shift;
	my ($pBuf) = @_;
	
	my $n += push @$pBuf, keys %{$this->{'NAME'}};
	
	return $n;
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ情報取得
#	-------------------------------------------------------------------------------------
#	@param	$kind		種別
#	@param	$key		グループID
#	@param	$default	デフォルト
#	@return	グループ名
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
#	グループ追加
#	-------------------------------------------------------------------------------------
#	@param	$name		情報種別
#	@param	$explan		説明
#	@param	$authors	権限セット
#	@param	$users		ユーザセット
#	@return	グループID
#
#------------------------------------------------------------------------------------------------------------
sub Add
{
	my $this = shift;
	my ($name, $explan, $authors, $users) = @_;
	
	my $id = time;
	$this->{'NAME'}->{$id} = $name;
	$this->{'EXPL'}->{$id} = $explan;
	$this->{'AUTH'}->{$id} = $authors;
	$this->{'USERS'}->{$id} = $users;
	
	return $id;
}

#------------------------------------------------------------------------------------------------------------
#
#	グループユーザ追加
#	-------------------------------------------------------------------------------------
#	@param	$id		グループID
#	@param	$user	追加ユーザID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub AddUser
{
	my $this = shift;
	my ($id, $user) = @_;
	
	my @users = split(/\,/, $this->{'USERS'}->{$id});
	my @match = grep($user, @users);
	
	# 登録済みのユーザは重複登録しない
	if (scalar(@match)) {
		$this->{'USERS'}->{$id} .= ",$user";
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	グループ情報設定
#	-------------------------------------------------------------------------------------
#	@param	$id		グループID
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
#	グループ情報削除
#	-------------------------------------------------------------------------------------
#	@param	$id		削除グループID
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Delete
{
	my $this = shift;
	my ($id) = @_;
	
	delete $this->{'NAME'}->{$id};
	delete $this->{'EXPL'}->{$id};
	delete $this->{'AUTH'}->{$id};
	delete $this->{'USERS'}->{$id};
}

#------------------------------------------------------------------------------------------------------------
#
#	所属ユーザグループ取得
#	-------------------------------------------------------------------------------------
#	@param	$id		ユーザID
#	@return	ユーザが所属しているグループID
#
#------------------------------------------------------------------------------------------------------------
sub GetBelong
{
	my $this = shift;
	my ($id) = @_;
	
	my $Users = $this->{'USERS'};
	foreach my $group (keys %$Users) {
		my @users = split(/\,/, $Users->{$group});
		foreach my $user (@users) {
			if ($id eq $user) {
				return $group;
			}
		}
	}
	
	return '';
}


#============================================================================================================
#
#	セキュリティ管理パッケージ
#
#============================================================================================================
package SECURITY;

use strict;
use utf8;
binmode(STDOUT,":utf8");
#use warnings;

use CGI::Session;

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
		'SYS'	=> undef,
		'USER'	=> undef,
		'GROUP'	=> undef,
		'BBS'	=> undef,
		'SOPT'	=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	my ($Sys) = @_;
	
	$this->{'SYS'} = $Sys;
	
	# 2重ロード防止
	if (! defined $this->{'USER'}) {
		$this->{'USER'} = USER_INFO->new;
		$this->{'GROUP'} = GROUP_INFO->new;
		$this->{'USER'}->Load($Sys);
		
		my $infopath = $Sys->Get('INFO');
		$this->{'SOPT'} = {
			'min'		=> 30,
			'driver'	=> 'driver:file;serializer:default',
			'option'	=> { Directory => ".$infopath/.session/" },
		};
		
		$this->CleanSessions;
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	ログイン判定
#	-------------------------------------------------------------------------------------
#	@param	$name	ユーザ名
#	@param	$pass	パスワード
#	@param	$sid	セッションID
#	@return	正式なユーザなら1を返す
#
#------------------------------------------------------------------------------------------------------------

sub IsLogin
{
	my $this = shift;
	my ($name, $pass, $sid) = @_;
	
	my $User = $this->{'USER'};
	my @keySet = ();
	$User->GetKeySet('NAME', $name, \@keySet);
	
	return (0, '') if (!scalar(@keySet));
	
	my $opt = $this->{'SOPT'};
	
	if (defined $pass && $pass ne '') {
		my $userid = undef;
		foreach my $id (@keySet) {
			my $lPass = $User->Get('PASS', $id);
			my $hash = $User->GetStrictPass($pass, $id);
			if ($lPass eq $hash) {
				$userid = $id;
				last;
			}
		}
		
		return (0, '') if (!$userid);
		
		my $session = CGI::Session->new($opt->{'driver'}, undef, $opt->{'option'});
		$session->param('addr', (($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR}));
		$session->param('user', $name);
		$session->param('uid', $userid);
		$session->expire("+$opt->{'min'}m");
		
		return ($userid, $session->id());
	} elsif (defined $sid && $sid ne '') {
		my $session = CGI::Session->new($opt->{'driver'}, $sid, $opt->{'option'});
		
		$_ = $session->param('addr');
		if (!defined $_ || $_ ne (($ENV{HTTP_CF_CONNECTING_IP}) ? $ENV{HTTP_CF_CONNECTING_IP} : $ENV{REMOTE_ADDR})) {
			$session->delete();
			return (0, '');
		}
		
		$_ = $session->param('user');
		if (!defined $_ || $_ ne $name) {
			$session->delete();
			return (0, '');
		}
		
		my $userid = undef;
		$_ = $session->param('uid');
		foreach my $id (@keySet) {
			if ($_ eq $id) {
				$userid = $id;
				last;
			}
		}
		
		if (!$userid) {
			$session->delete();
			return (0, '');
		}
		
		$session->expire("+$opt->{'min'}m");
		
		return ($userid, $session->id());
	} else {
		return (0, '');
	}
}

sub Logout
{
	my $this = shift;
	my ($sid) = @_;
	
	my $opt = $this->{'SOPT'};
	my $session = CGI::Session->new($opt->{'driver'}, $sid, $opt->{'option'});
	$session->delete();
}

sub CleanSessions
{
	my $this = shift;
	
	my $opt = $this->{'SOPT'};
	CGI::Session->find($opt->{'driver'}, sub {
		my ($session) = @_;
		if ($session->is_empty || $session->atime + 60*$opt->{'min'} <= time) {
			$session->delete();
		}
	}, $opt->{'option'});
}

#------------------------------------------------------------------------------------------------------------
#
#	権限判定前グループ情報準備
#	-------------------------------------------------------------------------------------
#	@param	$bbs	適応個所
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetGroupInfo
{
	my $this = shift;
	my ($bbs) = @_;
	
	my $Sys = $this->{'SYS'};
	
	my $oldbbs = $Sys->Get('BBS');
	$Sys->Set('BBS', $bbs);
	$this->{'BBS'} = $bbs;
	
	$this->{'GROUP'}->Load($Sys);
	
	$Sys->Set('BBS', $oldbbs);
}

#------------------------------------------------------------------------------------------------------------
#
#	権限判定
#	-------------------------------------------------------------------------------------
#	@param	$id		ユーザID
#	@param	$author	権限
#	@param	$bbs	適応個所
#	@return	ユーザが権限を持っていたら1を返す
#
#------------------------------------------------------------------------------------------------------------
sub IsAuthority
{
	my $this = shift;
	my ($id, $author, $bbs) = @_;
	
	# システム管理権限グループなら無条件OK
	my $sysad = $this->{'USER'}->Get('SYSAD', $id);
	return 1 if ($sysad);
	return 0 if ($bbs eq '*');
	
	# 対象BBSに所属しているか確認
	my $group = $this->{'GROUP'}->GetBelong($id);
	return 0 if ($group eq '');
	
	# 権限を持っているか確認
	my $auth = $this->{'GROUP'}->Get('AUTH', $group);
	my @authors = split(/\,/, $auth);
	foreach my $auth (@authors) {
		if ($auth == $author) {
			return 1;
		}
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	所属掲示板リスト取得
#	-------------------------------------------------------------------------------------
#	@param	$id		ユーザID
#	@param	$BBS	BBS_INFOオブジェクト
#	@param	$pList	結果格納用配列の参照
#	@return	所属掲示板数
#
#------------------------------------------------------------------------------------------------------------
sub GetBelongBBSList
{
	my $this = shift;
	my ($id, $Bbs, $pList) = @_;
	
	my $n = 0;
	
	# システム管理ユーザは全てのBBSに所属とする
	if ($this->{'USER'}->Get('SYSAD', $id)) {
		$Bbs->GetKeySet('ALL', '', $pList);
		$n = scalar @$pList;
	}
	# 一般ユーザは所属グループから判断する
	else {
		my $origbbs = $this->{'BBS'};
		my @keySet = ();
		$Bbs->GetKeySet('ALL', '', \@keySet);
		
		foreach my $bbsID (@keySet) {
			my $bbsDir = $Bbs->Get('DIR', $bbsID);
			SetGroupInfo($this, $bbsDir);
			if ($this->{'GROUP'}->GetBelong($id) ne '') {
				$n += push @$pList, $bbsID;
			}
		}
		
		# 後処理
		if (defined $origbbs) {
			SetGroupInfo($this, $origbbs);
		}
	}
	return $n;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
