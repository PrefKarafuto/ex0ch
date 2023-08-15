<?php
declare(strict_types=1);

namespace New_0ch_Plus\module;

/**
 * システムデータ管理モジュール
 */
class System {

	private $Sys;
	private $Key;
	private $ScriptFileName;
	private $ScriptName;
	private $HttpHost;

	/**
	 * コンストラクタ
	 */
	public function __construct() {
		// 初期化
		$this->Sys = [];
		$this->Key = [];
		// スーパーグローバル変数はコードの処理上で直接使わずプロパティとして持っておく
		$this->ScriptFileName = $_SERVER['SCRIPT_FILENAME'];
		$this->ScriptName = $_SERVER['SCRIPT_NAME'];
		$this->HttpHost = array_key_exists('HTTP_HOST', $_SERVER)? $_SERVER['HTTP_HOST']: 'localhost';
	}

	/**
	 * 初期化
	 * 
	 * @return int 正常終了したら0を返す
	 */
	public function Init():int {

		// システム設定を読み込む
		return $this->Load();
	}

	/**
	 * システム設定読み込み
	 * 
	 * @return int 正常終了したら0を返す
	 */
	private function Load():int {
		// システム情報の初期化
		$pSys = [];
		$this->Sys = &$pSys;
		$this->Key = [];
		System::InitSystemValue($pSys, $this->Key, $this->ScriptFileName);
		$sysFile = $pSys['SYSFILE'];

		// 設定ファイルから読み込む
		if (file_exists($sysFile) && $fh = fopen($sysFile, 'r')) {
			flock($fh, LOCK_EX);
			$lines = [];
			while (($line = fgets($fh)) !== false) {
				$lines[] = rtrim($line, "\r\n");
			}
			fclose($fh);

			foreach ($lines as $line) {
				if (preg_match('/^(.+?)<>(.*)$/', $line, $matches)) {
					$key = $matches[1];
					$value = $matches[2];
					$pSys[$key] = $value;
				}
			}
		}
		// 時間制限のチェック
		$dlist = getdate();
		if (($dlist['hours'] >= $pSys['LINKST'] || $dlist['hours'] < $pSys['LINKED']) &&
			($pSys['URLLINK'] === 'FALSE')) {
			$pSys['LIMTIME'] = 1;
		} else {
			$pSys['LIMTIME'] = 0;
		}
		// バージョンが異なっていたら設定ファイルを保存
		if ($pSys['CONFVER'] !== $pSys['VERSION']) {
			$this->Save();
		}

		return 0;
	}

	/**
	 * システム設定書き込み
	 */
	public function Save() {
		$this->NormalizeConf($this->ScriptName, $this->HttpHost);

		$path = $this->Sys['SYSFILE'];

		$mode = 'w';
		if (file_exists($path)) {
			$mode = 'r+';
			chmod($path, (int)$this->Get('PM-ADM'));
		}
		if ($fh = fopen($path, $mode)) {
			flock($fh, LOCK_EX);
			fseek($fh, 0);
			foreach ($this->Key as $key) {
				$val = $this->Sys[$key];
				fwrite($fh, $key . '<>' . $val . "\n");
			}
			ftruncate($fh, ftell($fh));
			fclose($fh);
		} else {
			trigger_error("can't save config: $path", E_USER_WARNING);
		}
		chmod($path, (int)$this->Get('PM-ADM'));
	}

	/**
	 * システム設定値取得
	 *
	 * @param mixed $key 取得キー
	 * @param mixed $default デフォルト
	 * @return mixed 設定値
	 */
	public function Get($key, $default = null) {
		return array_key_exists($key, $this->Sys)? $this->Sys[$key]: $default;
	}

	/**
	 * システム設定値設定
	 * 
	 * @param mixed $key 設定キー
	 * @param mixed $val 設定値
	 */
	public function Set($key, $data) {
		$this->Sys[$key] = $data;
	}

	/**
	 * システム設定値比較
	 * 
	 * @param mixed $key 設定キー
	 * @param mixed $data 設定値
	 * @return bool 同値なら真を返す
	 */
	public function Equals($key, $data) {
		if (!array_key_exists($key, $this->Sys)) {
			return false;
		}
		return $this->Sys[$key] == $data;
	}

	/**
	 * オプション値取得 - GetOption
	 * 
	 * @param mixed $flag 取得フラグ
	 * @return mixed 成功：オプション値 失敗：-1
	 */
	public function GetOption($flag) {
		if (!array_key_exists('OPTION', $this->Sys)) {
			return -1;
		}
		$elem = explode(',', $this->Sys['OPTION']);
		return array_key_exists(($flag - 1), $elem)? $elem[$flag - 1]: -1;
	}

	/**
	 * オプション値設定 -SetOption
	 * 
	 * @param mixed $last ラストフラグ
	 * @param mixed $start 開始行
	 * @param mixed $end 終了行
	 * @param mixed $one >>1表示フラグ
	 * @param mixed $alone 単独表示フラグ
	 */
	public function SetOption($last, $start, $end, $one, $alone) {
		$this->Sys['OPTION'] = $last . ',' . $start . ',' . $end . ',' . $one . ',' . $alone;
	}

	/**
	 * システム変数初期化 - InitSystemValue
	 * 
	 * @param array &$pSys ハッシュの参照
	 * @param array &$pKey 配列の参照
	 * @param mixed $fileName スクリプトのファイル名
	 */
	private static function InitSystemValue(array &$pSys, array &$pKey, $fileName) {
		$sys = [
			'SYSFILE'	=> './info/system.cgi',								# システム設定ファイル
			'SERVER'	=> '',										# 設置サーバパス
			'CGIPATH'	=> '/test',									# CGI設置パス
			'INFO'		=> '/info',									# 管理データ設置パス
			'DATA'		=> '/datas',									# 初期データ設置パス
			'BBSPATH'	=> '..',									# 掲示板設置パス
			'DEBUG'		=> 0,										# デバグモード
			'VERSION'	=> '0ch+ BBS dev-r104 20230806',						# CGIバージョン
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
			'HEADTEXT'	=> '<small>■<b>レス検索</b>■</small>',					# ヘッダ下部の表示文字列
			'HEADURL'	=> '../test/search.cgi',							# ヘッダ下部のURL
			'FASTMODE'	=> 0,										# 高速モード
			
			# ここからぜろプラオリジナル
			'SAMBATM'	=> 0,										# 短時間投稿規制秒数
			'DEFSAMBA'	=> 10,										# Samba待機秒数デフォルト値
			'DEFHOUSHI'	=> 60,										# Samba奉仕時間(分)デフォルト値
			'BANNER'	=> 1,										# read.cgi他の告知欄の表示
			'KAKIKO'	=> 1,										# 2重かきこですか？？
			'COUNTER'	=> '',										# 機能削除済につき未使用
			'PRTEXT'	=> 'ぜろちゃんねるプラス再開発プロジェクト',					# PR欄の表示文字列
			'PRLINK'	=> 'https://github.com/PrefKarafuto/New_0ch_Plus',				# PR欄のリンクURL
			'TRIP12'	=> 1,										# 12桁トリップを変換するかどうか
			'MSEC'		=> 0,										# msecまで表示するか
			'BBSGET'	=> 0,										# bbs.cgiでGETメソッドを使用するかどうか
			'CONFVER'	=> '',										# システム設定ファイルのバージョン
			'UPCHECK'	=> 0,										# 更新チェック間隔(日)
			
			# DNSBL設定
			'SPAMHAUS'		=> 0,									# zen.spamhaus.org
			'SPAMCOP'		=> 0,									# bl.spamcop.net
			'BARRACUDA'	    	=> 0,									# b.barracudacentral.org
			
			'HCAPTCHA_SITEKEY'	=>'',									#hCaptchaサイトキー
			'HCAPTCHA_SECRETKEY'	=>'',									#hCaptchaシークレットキー
			'IMGTAG'		=> 0,									#画像リンクをIMGタグに変換
			
			'PERM_EXEC'		=> 0700,
			'PERM_DATA'		=> 0600,
			'PERM_CONTENT'		=> 0644,
			'PERM_SYSDIR'		=> 0700,
			'PERM_DIR'		=> 0711,
		];
		// Permission
		// windows ではない
		// 現プロセスがこのファイルの所持者じゃない場合追加のパーミッション設定を行う
		$uid = (stat($fileName))[4];
		if ($uid == 0){
		} elseif ($uid == getmyuid()) {
		} else {
			$sys['PM-DAT'] = 0666;
			$sys['PM-STOP'] = 0444;
			$sys['PM-TXT'] = 0666;
			$sys['PM-LOG'] = 0666;
			$sys['PM-ADM'] = 0666;
			$sys['PM-ADIR'] = 0777;
			$sys['PM-BDIR'] = 0777;
			$sys['PM-LDIR'] = 0777;
			$sys['PM-KDIR'] = 0777;
		}

		foreach($sys as $key => $val) {
			$pSys[$key] = $val;
		}

		// 情報保持キー
		$key = array_keys($sys);
		$del_key = array_search('VERSION', $key);
		if (!is_bool($key)) {
			unset($key[$del_key]);
		}

		array_push($pKey, ...$key);
	}

	/**
	 * システム変数正規化 - NormalizeConf
	 * 
	 * @param mixed $ScriptName スクリプト名
	 * @param mixed $HttpHost ホスト名
	 */
	private function NormalizeConf($ScriptName, $HttpHost) {

		if ($this->Get('SERVER', '') == '') {
			$path = $ScriptName;
			$pattern1 = "|/[^/]+\.cgi([\/\?].*)?$|";
			$pattern2 = "|/[^/]+\.php([\/\?].*)?$|";
			$path = preg_replace($pattern1, '', $path);
			$path = preg_replace($pattern2, '', $path);
			$this->Set('SERVER', 'http://' . $HttpHost);
			$this->Set('CGIPATH', $path);
		}
		// set CGI Path
		$server = $this->Get('SERVER', '');
		$cgipath = $this->Get('CGIPATH', '');
		$pattern = "|^(http://[^/]+)(/.+)$|";
		if (preg_match($pattern, $server, $matches)) {
			$server = $matches[1];
			$cgipath = $matches[2] . $cgipath;
		}
		$this->Set('SERVER', $server);
		$this->Set('CGIPATH', $cgipath);
		
		$this->Set('CONFVER', $this->Get('VERSION'));
	}
}
