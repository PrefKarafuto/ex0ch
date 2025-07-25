#============================================================================================================
#
#	システムデータ管理モジュール
#
#============================================================================================================
package	SYSTEM;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;
no warnings 'redefine';

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
		'KEY'	=> undef,
	};
	bless $obj, $class;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	初期化
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	正常終了したら0を返す
#
#------------------------------------------------------------------------------------------------------------
sub Init
{
	my $this = shift;
	
	# システム設定を読み込む
	return $this->Load;
}

#------------------------------------------------------------------------------------------------------------
#
#	システム設定読み込み
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	正常終了したら0を返す
#
#------------------------------------------------------------------------------------------------------------
sub Load
{
	my $this = shift;
	
	# システム情報ハッシュの初期化
	my $pSys = $this->{'SYS'} = {};
	$this->{'KEY'} = [];
	InitSystemValue($this->{'SYS'}, $this->{'KEY'});
	my $sysFile = $this->{'SYS'}->{'SYSFILE'};
	
	# 設定ファイルから読み込む
	if (open(my $fh, '<', $sysFile)) {
		flock($fh, 2);
		my @lines = <$fh>;
		close($fh);
		map { s/[\r\n]+\z// } @lines;
		
		foreach (@lines) {
			if ($_ =~ /^(.+?)<>(.*)$/) {
				$pSys->{$1} = $2;
			}
		}
	}
	
	# 時間制限のチェック
	my @dlist = localtime time;
	if (($dlist[2] >= $pSys->{'LINKST'} || $dlist[2] < $pSys->{'LINKED'}) &&
		($pSys->{'URLLINK'} eq 'FALSE')) {
		$pSys->{'LIMTIME'} = 1;
	}
	else {
		$pSys->{'LIMTIME'} = 0;
	}

	#セキュリティキーの設定
	if (!$pSys->{'SECURITY_KEY'}){
		use Digest::MD5;
		my $md5 = Digest::MD5->new();
		$md5->add($$,time(),rand(time));
		$pSys->{'SECURITY_KEY'} = $md5->hexdigest();
	}

	if ($this->Get('CONFVER', '') ne $pSys->{'VERSION'}) {
		$this->Save();
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	システム設定書き込み
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Save
{
	my $this = shift;
	
	$this->NormalizeConf();
	
	my $path = $this->{'SYS'}->{'SYSFILE'};
	
	chmod($this->Get('PM-ADM'), $path);
	if (open(my $fh, (-f $path ? '+<' : '>'), $path)) {
		flock($fh, 2);
		seek($fh, 0, 0);
		#binmode($fh);
		
		foreach my $key (@{$this->{'KEY'}}) {
			my $val = $this->{'SYS'}->{$key};
			print $fh "$key<>$val\n";
		}
		
		truncate($fh, tell($fh));
		close($fh);
	}
	else {
		warn "can't save config: $path";
	}
	chmod($this->Get('PM-ADM'), $path);
}

#------------------------------------------------------------------------------------------------------------
#
#	システム設定値取得
#	-------------------------------------------------------------------------------------
#	@param	$key	取得キー
#			$default : デフォルト
#	@return	設定値
#
#------------------------------------------------------------------------------------------------------------
sub Get
{
	my $this = shift;
	my ($key, $default) = @_;
	
	my $val = $this->{'SYS'}->{$key};
	
	return (defined $val ? $val : (defined $default ? $default : undef));
}

#------------------------------------------------------------------------------------------------------------
#
#	システム設定値設定
#	-------------------------------------------------------------------------------------
#	@param	$key	設定キー
#	@param	$data	設定値
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub Set
{
	my $this = shift;
	my ($key, $data) = @_;
	
	$this->{'SYS'}->{$key} = $data;
}

#------------------------------------------------------------------------------------------------------------
#
#	システム設定値比較
#	-------------------------------------------------------------------------------------
#	@param	$key	設定キー
#	@param	$val	設定値
#	@return	同等なら真を返す
#
#------------------------------------------------------------------------------------------------------------
sub Equal
{
	my $this = shift;
	my ($key, $data) = @_;
	
	return($this->{'SYS'}->{$key} eq $data);
}

#------------------------------------------------------------------------------------------------------------
#
#	オプション値取得- GetOption
#	-------------------------------------------
#	引　数：$flag : 取得フラグ
#	戻り値：成功:オプション値
#			失敗:-1
#
#------------------------------------------------------------------------------------------------------------
sub GetOption
{
	my $this = shift;
	my ($flag) = @_;
	
	my @elem = split(/\,/, $this->{'SYS'}->{'OPTION'});
	
	return $elem[$flag - 1];
}

#------------------------------------------------------------------------------------------------------------
#
#	オプション値設定 - SetOption
#	-------------------------------------------
#	引　数：$last  : ラストフラグ
#			$start : 開始行
#			$end   : 終了行
#			$one   : >>1表示フラグ
#			$alone : 単独表示フラグ
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub SetOption
{
	my $this = shift;
	my ($last, $start, $end, $one, $alone) = @_;
	
	$this->{'SYS'}->{'OPTION'} = "$last,$start,$end,$one,$alone";
}

#------------------------------------------------------------------------------------------------------------
#
#	システム変数初期化 - InitSystemValue
#	-------------------------------------------
#	引　数：$pSys : ハッシュの参照
#			$pKey : 配列の参照
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub InitSystemValue
{
	my ($pSys, $pKey) = @_;
	
	my %sys = (
		'SYSFILE'	=> './info/system.cgi',						# システム設定ファイル
		'SERVER'	=> '',										# 設置サーバパス
		'CGIPATH'	=> '/test',									# CGI設置パス
		'INFO'		=> '/info',									# 管理データ設置パス
		'DATA'		=> '/datas',								# 初期データ設置パス
		'BBSPATH'	=> '..',									# 掲示板設置パス
		'SITENAME'	=> '',										# サイトの名前
		'DEBUG'		=> 0,										# デバグモード(未使用)
		'VERSION'	=> 'ex0ch BBS dev-r195 20250702',			# CGIバージョン
		'PM-DAT'	=> 0644,									# datパーミション
		'PM-STOP'	=> 0444,									# スレストパーミション
		'PM-TXT'	=> 0644,									# TXTパーミション
		'PM-LOG'	=> 0600,									# LOGパーミション
		'PM-ADM'	=> 0600,									# 管理ファイル群
		'PM-ADIR'	=> 0700,									# 管理DIRパーミション
		'PM-BDIR'	=> 0711,									# 板DIRパーミション
		'PM-LDIR'	=> 0700,									# ログDIRパーミション
		'PM-KDIR'	=> 0755,									# 倉庫DIRパーミション
		'ERRMAX'	=> 500,										# エラーログ最大保持数
		'SUBMAX'	=> 500,										# subject最大保持数
		'RESMAX'	=> 1000,									# レス最大書き込み数
		'ADMMAX'	=> 500,										# 管理操作ログ最大保持数
		'HSTMAX'	=> 500,										# ホストログ最大保持数
		'FLRMAX'	=> 100,										# 書き込み失敗ログ最大保持数
		'ANKERS'	=> 10,										# 最大アンカー数
		'URLLINK'	=> 'TRUE',									# URLへの自動リンク
		'LINKST'	=> 23,										# リンク禁止開始時間
		'LINKED'	=> 2,										# リンク禁止終了時間
		'PATHKIND'	=> 0,										# 生成パスの種類
		'HEADTEXT'	=> '<small>■<b>トップ</b>■</small>',	  # ヘッダ下部の表示文字列
		'HEADURL'	=> '../',									# ヘッダ下部のURL
		'FASTMODE'	=> 0,										# 高速モード
		
		# ここからぜろプラオリジナル
		'SAMBATM'	=> 0,										# 短時間投稿規制秒数
		'DEFSAMBA'	=> 10,										# Samba待機秒数デフォルト値
		'DEFHOUSHI'	=> 60,										# Samba奉仕時間(分)デフォルト値
		'BANNER'	=> 1,										# read.cgi他の告知欄の表示
		'KAKIKO'	=> 1,										# 2重かきこですか？？
		'COUNTER'	=> '',										# 機能削除済につき未使用
		'PRTEXT'	=> 'EXぜろちゃんねる',						# PR欄の表示文字列
		'PRLINK'	=> 'https://prefkarafuto.github.io/',	# PR欄のリンクURL
		'TRIP12'	=> 1,										# 12桁トリップを変換するかどうか
		'MSEC'		=> 0,										# msecまで表示するか
		'CONFVER'	=> '',										# システム設定ファイルのバージョン
		'UPCHECK'	=> 7,										# 更新チェック間隔(日)
		'LASTCHECK'	=> 0,										# 前回チェック時刻
		
		# DNSBL設定
		'DNSBL_TOREXIT'	=> 0,									# torexit.dan.me.uk
		'DNSBL_SPAMHAUS'		=> 0,							# zen.spamhaus.org
		'DNSBL_S5H'		=> 0,									# all.s5h.net
		'DNSBL_DRONEBL'	=> 0,									# dnsbl.dronebl.org

		'SECURITY_KEY'	=> '',									# セキュリティキー（初回起動時に自動設定されます）
		'LAST_FLUSH'	=> '',									# 定期的に動かす必要がある機能用

		'CAPTCHA'			=> '',								# キャプチャの種類
		'CAPTCHA_LENIENCY'	=> '',								# IP検証強度（Turnstileのみ）
		'CAPTCHA_SITEKEY'	=> '',								# Captchaサイトキー
		'CAPTCHA_SECRETKEY'	=> '',								# Captchaシークレットキー

		'PROXYCHECK_API'	=> '',								# プロキシ判定API
		'PROXYCHECK_APIKEY'	=> '',								# APIキー

		'UPLOAD'		=> '',									# 画像アップロード
		'IMGUR_ID'		=> '',									# Imgur ID
		'IMGUR_SECRET'	=> '',									# Imgur シークレットID
		'IMGUR_AUTH'	=> '',									# Imgur API 認証状況

		'ADMINCAP'		=> '',									# admin.cgiにCaptchaを課すか
		'SEARCHCAP'		=> '',									# search.cgiにCaptchaを課すか

		'BGDSL'			=> '',									# 強力な複合規制機能を許可(実験的)

		'LASTMOD'		=> '',									# 最後にシステム管理者がログインした時刻
		'LOGOUT'		=> 30,									# 無操作状態で管理画面から自動ログアウトするまでの時間

		'IMGTAG'		=> 1,									# 画像リンクをIMGタグに変換 => Imgur以外の画像URLもIMGタグに変換
		'CSP'			=> 0,									# コンテンツセキュリティポリシーを記述
		'BANMAX'		=> 10,									# スレッドあたり最大BAN可能人数
		'NINLVMAX'		=> 40,									# 忍法帖Lv最大値
		'HIDE_HITS'		=> 1,									# 規制ユーザー非公開
		'CM_THEME'		=> 'abcdef',							# CodeMirror テーマ
		'REFRESH_MODE'	=> 'default',							# 書き込み後の遷移先

		'COOKIE_EXPIRY'	=> 30,									# Cookie期限
		'NIN_EXPIRY'	=> 30,									# 忍法帖データ保持期限
		'AUTH_EXPIRY'	=> 30,									# Captcha認証有効期限
		'PASS_EXPIRY'	=> 365,									# パスワードを設定した場合の忍法帖データ保持期限
		
		# 未使用
		'PERM_EXEC'		=> 0700,
		'PERM_DATA'		=> 0600,
		'PERM_CONTENT'	=> 0644,
		'PERM_SYSDIR'	=> 0700,
		'PERM_DIR'		=> 0711,
	);
	
	my $uid = (stat $ENV{'SCRIPT_FILENAME'})[4];
	if ($uid == 0) { # root / not linux
	} elsif ($uid == $<) { # suEXEC
	} else {
		$sys{'PM-DAT'} = 0666;
		$sys{'PM-STOP'} = 0444;
		$sys{'PM-TXT'} = 0666;
		$sys{'PM-LOG'} = 0666;
		$sys{'PM-ADM'} = 0666;
		$sys{'PM-ADIR'} = 0777;
		$sys{'PM-BDIR'} = 0777;
		$sys{'PM-LDIR'} = 0777;
		$sys{'PM-KDIR'} = 0777;
	}
	
	while (my ($key, $val) = each %sys) {
		$pSys->{$key} = $val;
	}
	
	# 情報保持キー
	my @key = grep { 'VERSION' !~ /\b$_\b/ } sort keys %sys;
	
	splice @$pKey, 0, scalar(@$pKey);
	push @$pKey, @key;
}

# 全設定ハッシュをそのまま返す
sub All {
    my $this = shift;
	my ($hash) = @_;
	if($hash){
		$this->{'SYS'} = $hash;
	}else{
		return $this->{'SYS'} ||= {};
	}
}

#------------------------------------------------------------------------------------------------------------
#
#	システム変数正規化 - NormalizeConf
#	-------------------------------------------
#	引　数：
#	戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub NormalizeConf
{
	my $this = shift;
	my ($path, $buf, $perm, $server, $cgipath);
	
	if ($this->Get('SERVER', '') eq '') {
		my $path = $ENV{'SCRIPT_NAME'};
		$path =~ s|/[^/]+\.cgi([\/\?].*)?$||;
		$this->Set('SERVER', 'http://' . $ENV{'HTTP_HOST'});
		$this->Set('CGIPATH', $path);
	}
	
	if ('set CGI Path') {
		my $server = $this->Get('SERVER', '');
		my $cgipath = $this->Get('CGIPATH', '');
		if ($server =~ m|^(http://[^/]+)(/.+)$|) {
			$server = $1;
			$cgipath = "$2$cgipath";
		}
		$this->Set('SERVER', $server);
		$this->Set('CGIPATH', $cgipath);
	}
	
	$this->Set('CONFVER', $this->Get('VERSION'));
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
