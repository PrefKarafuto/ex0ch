#============================================================================================================
#
#	忍法帖情報管理パッケージ
#
#============================================================================================================
package	NINPOCHO;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
use CGI::Session;
use CGI::Cookie;
use Digest::MD5;
use Storable qw(lock_store lock_retrieve);
use MIME::Base64 ();
use POSIX qw(strftime);
no warnings 'once';

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
		'SESSION'		=> undef,   # セッションオブジェクト
		'SID'			=> undef,   # セッションID
		'ANON_FLAG'     => undef,   # 匿名化状態か
		'CREATE_FLAG'   => undef,   # 新規作成か
		'LOAD_FLAG'     => undef,   # passからロードか
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖ロード
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$password	あればパスワードで忍法帖をロード。無ければ通常ロード
#	@return	パスワードがあり、かつセッションIDが見つからない場合0
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	my ($Sys,$password) = @_;
	my ($sid,$sid_saved,$sid_before);

	my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
	my $Form = $Sys->Get('MainCGI')->{'FORM'};
	my $Set = $Sys->Get('MainCGI')->{'SET'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
	$sid = $Sys->Get('SID');
	
	#パスワードがあった場合
	if($password){
		my $ctx2 = Digest::MD5->new;
		my $exp = $Sys->Get('PASS_EXPITY') || 1;
		my $long_expiry = 60*60*24*$exp;
		
		$ctx2->add($Sys->Get('SECURITY_KEY'));
		$ctx2->add(':', $password);
		my $ctx2_hexdigest = $ctx2->hexdigest();
		my $filename = $ninDir.'hash/pw-' . $ctx2_hexdigest . '.cgi';
		my $hash_table = {};

		if (-e $filename) {
			$hash_table = lock_retrieve($filename);
		}
		
		# キーに対応する値が存在するかチェック
		if (exists $hash_table->{'sid'}) {
			# 有効期限をチェック
			if (($hash_table->{'sid'}{'time'} + $long_expiry) < time) {
				# 有効期限切れの場合は削除してundefを返す
				delete $hash_table->{'sid'};
				lock_store $hash_table, $filename;
			} else {
				# 有効期限内の場合は値を返す
				$hash_table->{'sid'}{'time'} = time;
				lock_store $hash_table, $filename;
				$sid_saved = $hash_table->{'sid'}{'value'};
			}
		}

		if($sid_saved && $sid_saved ne $sid){
			$sid_before = $sid;
			$sid = $sid_saved;
		}else{
			# 無かったらロードしない
			return undef;
		}
	}

	# セッションデータのロードもしくは新規作成
	my $session = CGI::Session->new("driver:file;serializer:storable", $sid, {Directory => $ninDir});
	if($session ->is_new()){
		$sid = $session->id();
		$this->{'CREATE_FLAG'} = 1;

		#新規作成時に追加
		my $mes = $Form->Get('MESSAGE');
		$mes =~ s/<(b|h)r>//g;
		$session->param('new_message',substr($mes, 0, 30));
		$session->param('c_bbsdir',$Sys->Get('BBS'));
		$session->param('c_threadkey',$Sys->Get('KEY'));
		$session->param('c_addr',$ENV{'REMOTE_ADDR'});
		$session->param('c_host',$ENV{'REMOTE_HOST'});
		$session->param('c_ua',$ENV{'HTTP_USER_AGENT'});
	}else{
		if ($sid && $sid_before){
			#忍法帖ロード時に追加
			my $load_count = $session->param('load_count') || 0;
			$this->{'LOAD_FLAG'} = 1;
			$load_count++;
			my $mes = $Form->Get('MESSAGE');
			$mes =~ s/<(b|h)r>//g;
			$session->param('load_count',$load_count);
			$session->param('load_message',substr($mes, 0, 30));
			$session->param('load_from',$sid_before);
			$session->param('load_time',time);
			$session->param('load_bbsdir',$Sys->Get('BBS'));
			$session->param('load_threadkey',$Sys->Get('KEY'));
			$session->param('load_addr',$ENV{'REMOTE_ADDR'});
			$session->param('load_host',$ENV{'REMOTE_HOST'});
			$session->param('load_ua',$ENV{'HTTP_USER_AGENT'});
		}else{
			# 通常時処理
			# ninpocho.plでは行わない
		}
	}
	$this->{'SESSION'} = $session;

	$this->{'SID'} = $sid;
	$Sys->Set('SID',$sid);

	return $sid;
}
# セッションIDから忍法帖を読み込む(admin.cgi用)
sub LoadOnly {
	my $this = shift;
	my ($Sys,$sid) = @_;
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
	my $session = CGI::Session->load("driver:file;serializer:storable", $sid, {Directory => $ninDir});

	# セッションの読み込みが失敗した場合、0を返す
	return 0 unless $session;

	$this->{'SESSION'} = $session;
	$this->{'SID'} = $sid;
	return 1; # 正常に読み込みが完了した場合、1を返す
}
# セッションに忍法帖保存(admin.cgi用)
sub SaveOnly
{
	my $this = shift;
	return 0 unless $this->{'SESSION'};
	# セッションを閉じる
	$this->{'SESSION'}->flush();
	return 1;
}
#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報取得
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @return 忍法帖の要素の情報
#
#------------------------------------------------------------------------------------------------------------
sub Get {
	my $this = shift;
	my ($name) = @_;

	# セッションが存在しない場合は空文字列を返す
	return '' unless $this->{'SESSION'};

	# パラメータの値を取得し、未初期化の場合は空文字列を返す
	my $val = $this->{'SESSION'}->param($name) // '';
	
	return $val;
}
sub isNew
{
	my $this = shift;
	return $this->{'CREATE_FLAG'};
}
sub isLoad
{
	my $this = shift;
	return $this->{'LOAD_FLAG'};
}
#------------------------------------------------------------------------------------------------------------
#
#   忍法帖情報設定
#   -------------------------------------------------------------------------------------
#   @param  可変長の情報種別パス
#   @param  $val        設定値
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($name, $val) = @_;
	
	return unless $this->{'SESSION'};
	$this->{'SESSION'}->param($name,$val);

	return $this->{'SESSION'}->param($name);
}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖削除（admin.cgiでの使用を想定）
#   -------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#   @param  $sid_array_ref    セッションIDの配列リファレンス
#   @return 削除に成功したら1　$sidで指定されたセッションがなければ0
#
#------------------------------------------------------------------------------------------------------------
sub Delete {
	my $this=shift;
	my ($Sys, $sid_array_ref) = @_;
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
	my @file_list = (
		'hash/user_info.cgi',
		'hash/password.cgi',
		'hash/ip_addr.cgi'
	);
	my $count = 0;

	foreach my $sid (@$sid_array_ref) {
		my $session = CGI::Session->load("driver:file;serializer:storable", $sid, {Directory => $ninDir});
		if ($session->is_empty) {
			next; # このセッションIDは無効なので次へ
		} else {
			if ( ($session->ctime) <= time() ) {
				$session->delete();
				$session->flush();
				$count++;
			}
			foreach my $filename (@file_list) {
				my $hash_table = {};
				if (-e $filename) {
					$hash_table = lock_retrieve($filename);
					# ハッシュテーブルの各キーと値を繰り返し確認
					foreach my $key (keys %$hash_table) {
						# 値が目的の値と一致した場合、その要素を削除
						if ($hash_table->{$key}->{value} eq $sid) {
							delete $hash_table->{$key};
						}
					}
					# 変更をファイルに保存
					lock_store $hash_table, $filename;
					chmod 0600,$filename;
				}
			}
		}
	}
	return $count;
}
sub DeleteOnly
{
	my $this=shift;
	$this->{'SESSION'}->delete();
	$this->{'SESSION'}->flush();
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖情報保存
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$com	真ならパスワードで忍法帖をセーブ。偽なら通常セーブ
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	my ($Sys,$com) = @_;
	my $password;
	my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
	my $sid = $this->{'SID'};
	my $session = $this->{'SESSION'};

	# 忍法帖を使わない場合
	return 0 unless $session;

	if ($com) {
		my $seed = undef;
		if ($session->param('password_is_randomized')) {
			# 「ランダム生成」したパスワードを取り出す。
			$password = $session->param('password_is_randomized');
		} else {
			if (open my $fh, '<', '/dev/urandom') {
				# Unix系
				binmode $fh;
				read $fh, $seed, 8;
				close $fh;
				$password = MIME::Base64::encode_base64url($seed);
			} else {
				# Windows系
				$seed = Digest::MD5->new->add($^O, rand(2**32), $^V, $$)->digest;
			}
			$password = substr MIME::Base64::encode_base64url($seed), 0, 11;
		}
		my $ctx3 = Digest::MD5->new;
		$ctx3->add($Sys->Get('SECURITY_KEY'));
		$ctx3->add(':', $password);
		my $ctx3_hexdigest = $ctx3->hexdigest();
		my $pass_file = $ninDir . 'hash/pw-' . $ctx3_hexdigest . '.cgi';
		# 既にpasswordが設定されていた場合、既存のパスワードを削除
		# ランダム生成の場合は「削除しない」
		if($session->param('password_file_hash') && !$session->param('password_is_randomized')) {
			my $old_pass_file = $ninDir . 'hash/pw-' . $session->param('password_file_hash') . '.cgi';
			if (-e $old_pass_file) {
				unlink $old_pass_file;
			}
		}
		if (defined $seed && !$session->param('password_is_randomized')) {
			# パスワードをランダム生成した場合「のみ」平文で保管する。
			# 既に保管してあった場合はそのまま表示する
			$session->param('password_is_randomized', $password);
		}
		my $hash_table = {};

		if (-e $pass_file) {
			$hash_table = lock_retrieve($pass_file);
		}
		$hash_table->{'sid'} = {
			value => $sid,
			time => time,
		};
		lock_store $hash_table, $pass_file;
		chmod 0600,$pass_file,
		$session->param('password_file_hash', $ctx3_hexdigest);
	}

	# セッション有効期限を設定
	if($session->param('password_is_randomized')){
		$session->expire($Sys->Get('PASS_EXPIRY').'d');
	}else{
		$session->expire($Sys->Get('NIN_EXPIRY').'d');
	}
	# セッションを閉じる
	$session->flush();
	if ($password) {
		my $nowtime = strftime "%Y-%m-%d %H:%M:%S", localtime time;
		$Sys->Set('NIN_PASS',$password);
		$Sys->Set('TIME',$nowtime);

		return $ZP::E_FORM_SAVECOMMAND;
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
