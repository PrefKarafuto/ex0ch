<?php
declare(strict_types=1);

namespace New_0ch_Plus\module;

/**
 * システムデータ管理モジュール
 */
class Setting {

	private ?System $Sys;
	private $Setting;

	/**
	 * コンストラクタ
	 */
	public function __construct() {
		// 初期化
		$this->Sys = null;
		$this->Setting = [];
	}

	/**
	 * 掲示板のSETTING.TXTのパスを取得する。
	 */
	private function getSettingPath(System $Sys):string {
		return $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/SETTING.TXT';
	}

	/**
	 * 掲示板設定読み込み
	 * 
	 * @param System $Sys SYSTEM
	 * @return int エラー番号
	 */
	public function Load(System $Sys):int {
		$this->Sys = $Sys;
		$set = [];
		$this->Setting = &$set;
		Setting::InitSettingData($set);

		$path = $this->getSettingPath($Sys);

		if (file_exists($path) && $fh = fopen($path, 'r')) {
			flock($fh, LOCK_EX);
			$lines = [];
			while (($line = fgets($fh)) !== false) {
				$lines[] = preg_replace("/[\r\n]+\z/", '', $line);
			}
			fclose($fh);
			$lines = mb_convert_encoding($lines, "UTF-8", "CP932");

			foreach ($lines as $line) {
				if (preg_match('/^(.+?)=(.*)$/', $line, $matches)) {
					$key = $matches[1];
					$value = $matches[2];
					$set[$key] = $value;
				}
			}
			return 1;
		}
		return 0;
	}

	/**
	 * 掲示板設定書き込み
	 * 
	 * @param System $Sys SYSTEM
	 */
	public function Save(System $Sys) {
		$path = $this->getSettingPath($Sys);

		// ２ちゃんねるのSETTING.TXT順序
		$ch2setting = [
			"BBS_TITLE",			"BBS_TITLE_PICTURE",	"BBS_TITLE_COLOR",		"BBS_TITLE_LINK",
			"BBS_BG_COLOR",			"BBS_BG_PICTURE",		"BBS_NONAME_NAME",		"BBS_MAKETHREAD_COLOR",
			"BBS_MENU_COLOR",		"BBS_THREAD_COLOR",		"BBS_TEXT_COLOR",		"BBS_NAME_COLOR",
			"BBS_LINK_COLOR",		"BBS_ALINK_COLOR",		"BBS_VLINK_COLOR",		"BBS_THREAD_NUMBER",
			"BBS_CONTENTS_NUMBER",	"BBS_LINE_NUMBER",		"BBS_MAX_MENU_THREAD",	"BBS_SUBJECT_COLOR",
			"BBS_PASSWORD_CHECK",	"BBS_UNICODE",			"BBS_DELETE_NAME",		"BBS_NAMECOOKIE_CHECK",
			"BBS_MAILCOOKIE_CHECK",	"BBS_SUBJECT_COUNT",	"BBS_NAME_COUNT",		"BBS_MAIL_COUNT",
			"BBS_MESSAGE_COUNT",	"BBS_NEWSUBJECT",		"BBS_THREAD_TATESUGI",	"BBS_AD2",
			"SUBBBS_CGI_ON",		"NANASHI_CHECK",		"timecount",			"timeclose",
			"BBS_PROXY_CHECK",		"BBS_OVERSEA_THREAD",	"BBS_OVERSEA_PROXY",	"BBS_RAWIP_CHECK",
			"BBS_SLIP",				"BBS_DISP_IP",			"BBS_FORCE_ID",			"BBS_BE_ID",
			"BBS_BE_TYPE2",			"BBS_NO_ID",			"BBS_JP_CHECK",			"BBS_VIP931",
			"BBS_4WORLD",			"BBS_YMD_WEEKS",		"BBS_NINJA",
		];

		$orz = $this->Setting;

		$mode = 'w';
		if (file_exists($path)) {
			$mode = 'r+';
			chmod($path, (int)$Sys->Get('PM-TXT'));
		}
		if ($fh = fopen($path, $mode)) {
			flock($fh, LOCK_EX);
			fseek($fh, 0);

			// 順番に出力
			foreach ($ch2setting as $key) {
				$val = $this->Get($key, '');
				$conv_key = mb_convert_encoding($key, "CP932", "UTF-8");
				$conv_val = mb_convert_encoding($val, "CP932", "UTF-8");
				fwrite($fh, $conv_key . '=' . $conv_val . "\n");
				unset($orz[$key]);
			}
			foreach ($orz as $key) {
				$val = $this->Get($key, '');
				$conv_key = mb_convert_encoding($key, "CP932", "UTF-8");
				$conv_val = mb_convert_encoding($val, "CP932", "UTF-8");
				fwrite($fh, $conv_key . '=' . $conv_val . "\n");
			}
			ftruncate($fh, ftell($fh));
			fclose($fh);
		} else {
			trigger_error("can't save setting: $path", E_USER_WARNING);
		}
		chmod($path, (int)$Sys->Get('PM-TXT'));
	}

	/**
	 * 掲示板設定読み込み(指定ファイル)
	 * 
	 * @param mixed $path 指定ファイルのパス
	 * @return int エラー番号
	 */
	public function LoadFrom($path):int {
		$set = [];
		$this->Setting = &$set;

		if (file_exists($path) && $fh = fopen($path, 'r')) {
			flock($fh, LOCK_EX);
			$lines = [];
			while (($line = fgets($fh)) !== false) {
				$lines[] = preg_replace("/[\r\n]+\z/", '', $line);
			}
			fclose($fh);
			$lines = mb_convert_encoding($lines, "UTF-8", "CP932");

			foreach ($lines as $line) {
				if (preg_match('/^(.+?)=(.*)$/', $line, $matches)) {
					$key = $matches[1];
					$value = $matches[2];
					$set[$key] = $value;
				}
			}
			return 1;
		} else {
			trigger_error("can't load setting: $path", E_USER_WARNING);
		}
		return 0;
	}

	/**
	 * 掲示板設定書き込み(指定ファイル)
	 * 
	 * @param mixed $path 指定ファイルのパス
	 */
	public function SaveAs($path) {

		$mode = 'w';
		if (file_exists($path)) {
			$mode = 'r+';
			chmod($path, (int)$this->Sys->Get('PM-TXT'));
		}
		if ($fh = fopen($path, $mode)) {
			flock($fh, LOCK_EX);
			fseek($fh, 0);

			foreach ($this->Setting as $key) {
				$val = $this->Get($key, '');
				$conv_key = mb_convert_encoding($key, "CP932", "UTF-8");
				$conv_val = mb_convert_encoding($val, "CP932", "UTF-8");
				fwrite($fh, $conv_key . '=' . $conv_val . "\n");
			}
			ftruncate($fh, ftell($fh));
			fclose($fh);
		} else {
			trigger_error("can't save setting: $path", E_USER_WARNING);
		}
		chmod($path, (int)$this->Sys->Get('PM-TXT'));
	}

	/**
	 * 掲示板設定キー取得
	 * 
	 * @param ?array $keySet キーセット格納バッファ
	 * @return array 変更したキーセット格納バッファ
	 */
	public function GetKeySet(?array &$keySet) {
		foreach ($this->Setting as $key => $val) {
			$keySet[] = $key;
		}
		return $keySet;
	}

	/**
	 * 掲示板設定値比較
	 * 
	 * @param mixed $key 設定キー
	 * @param mixed $val 設定値
	 * @return bool 同値なら真を返す
	 */
	public function Equals($key, $val) {
		if (!array_key_exists($key, $this->Setting)) {
			return false;
		}
		return $this->Setting[$key] == $val;
	}

	/**
	 * 掲示板設定値取得
	 *
	 * @param mixed $key 取得キー
	 * @param mixed $default デフォルト
	 * @return mixed 設定値
	 */
	public function Get($key, $default = null) {
		return array_key_exists($key, $this->Setting)? $this->Setting[$key]: $default;
	}

	/**
	 * 掲示板設定値設定
	 * 
	 * @param mixed $key 設定キー
	 * @param mixed $val 設定値
	 */
	public function Set($key, $val) {
		$this->Setting[$key] = $val;
	}

	/**
	 * SETTING項目初期化 - InitSettingData
	 * 
	 * @param array &$pSET ハッシュの参照
	 */
	private static function InitSettingData(array &$pSET) {
		$set = [
			# ２ちゃんねる互換設定項目
			'BBS_TITLE'				=> '掲示板＠ぜろちゃんねるプラス',
			'BBS_TITLE_PICTURE'		=> 'kanban.gif',
			'BBS_TITLE_COLOR'		=> '#000000',
			'BBS_TITLE_LINK'		=> 'https://github.com/PrefKarafuto/New_0ch_Plus/',
			'BBS_BG_COLOR'			=> '#FFFFFF',
			'BBS_BG_PICTURE'		=> 'ba.gif',
			'BBS_NONAME_NAME'		=> '名無しさん＠ぜろちゃんねるプラス',
			'BBS_MAKETHREAD_COLOR'	=> '#CCFFCC',
			'BBS_MENU_COLOR'		=> '#CCFFCC',
			'BBS_THREAD_COLOR'		=> '#EFEFEF',
			'BBS_TEXT_COLOR'		=> '#000000',
			'BBS_NAME_COLOR'		=> 'green',
			'BBS_LINK_COLOR'		=> '#0000FF',
			'BBS_ALINK_COLOR'		=> '#FF0000',
			'BBS_VLINK_COLOR'		=> '#AA0088',
			'BBS_THREAD_NUMBER'		=> 10,
			'BBS_CONTENTS_NUMBER'	=> 10,
			'BBS_LINE_NUMBER'		=> 12,
			'BBS_MAX_MENU_THREAD'	=> 30,
			'BBS_SUBJECT_COLOR'		=> '#FF0000',
			'BBS_PASSWORD_CHECK'	=> 'checked',
			'BBS_UNICODE'			=> 'pass',
			'BBS_DELETE_NAME'		=> 'あぼーん',
			'BBS_NAMECOOKIE_CHECK'	=> 'checked',
			'BBS_MAILCOOKIE_CHECK'	=> 'checked',
			'BBS_SUBJECT_COUNT'		=> 48,
			'BBS_NAME_COUNT'		=> 128,
			'BBS_MAIL_COUNT'		=> 64,
			'BBS_MESSAGE_COUNT'		=> 2048,
			'BBS_NEWSUBJECT'		=> 1,
			'BBS_THREAD_TATESUGI'	=> 5,
			'BBS_AD2'				=> '',
			'SUBBBS_CGI_ON'			=> 1,
			'NANASHI_CHECK'			=> '',
			'timecount'				=> 7,
			'timeclose'				=> 5,
			'BBS_PROXY_CHECK'		=> '',
			'BBS_OVERSEA_THREAD'	=> '',
			'BBS_OVERSEA_PROXY'		=> '',
			'BBS_RAWIP_CHECK'		=> '',
			'BBS_SLIP'				=> '',
			'BBS_DISP_IP'			=> '',
			'BBS_FORCE_ID'			=> 'checked',
			'BBS_BE_ID'				=> '',
			'BBS_BE_TYPE2'			=> '',
			'BBS_NO_ID'				=> '',
			'BBS_JP_CHECK'			=> '',
			'BBS_YMD_WEEKS'			=> '日/月/火/水/木/金/土',
			'BBS_NINJA'				=> '',

			# 以下0chオリジナル設定項目
			'BBS_DATMAX'			=> 512,
			'BBS_SUBJECT_MAX'		=> '',
			'BBS_RES_MAX'			=> '',
			'BBS_COOKIEPATH'		=> '/',
			'BBS_READONLY'			=> 'caps',
			'BBS_REFERER_CUSHION'	=> 'jump.x0.to/',
			'BBS_THREADCAPONLY'		=> '',
			'BBS_THREADMOBILE'		=> '',
			'BBS_TRIPCOLUMN'		=> 10,
			'BBS_SUBTITLE'			=> 'またーり雑談',
			'BBS_COLUMN_NUMBER'		=> 256,
			'BBS_SAMBATIME'			=> '',
			'BBS_HOUSHITIME'		=> '',
			'BBS_CAP_COLOR'			=> '',
			'BBS_TATESUGI_HOUR'		=> '0',
			'BBS_TATESUGI_COUNT'	=> '5',
			'BBS_TATESUGI_COUNT2'	=> '1',
			'BBS_INDEX_LINE_NUMBER'	=> 12,

			# 改造版で追加部分
			'BBS_SPAMKILLI_ASCII'	=> 2,
			'BBS_SPAMKILLI_MAIL'	=> 5,
			'BBS_SPAMKILLI_HOST'	=> 7,
			'BBS_SPAMKILLI_URL'		=> 5,
			'BBS_SPAMKILLI_MESSAGE'	=> 95,
			'BBS_SPAMKILLI_LINK'	=> 3,
			'BBS_SPAMKILLI_MESPOINT'=> 2,
			'BBS_SPAMKILLI_DOMAIN'	=> 'jp,com,net,org=2;*=3',
			'BBS_SPAMKILLI_POINT'	=> 10,

			'BBS_IMGTAG'			=> '',
			'BBS_IMGUR'				=> '',
			'BBS_TWITTER'			=> '',
			'BBS_MOVIE'				=> '',
			'BBS_URL_TITLE'			=> '',
			'BBS_HIGHLIGHT'			=> 'checked',

			'BBS_TASUKERUYO'		=> '',
			'BBS_OMIKUJI'			=> '',
			'BBS_FAVICON'			=> 'icon.png',

			'BBS_HCAPTCHA'			=> '',
			'BBS_READTYPE'			=> '5ch',
			'BBS_POSTCOLOR'			=> '#FFFFFF',
			'BBS_MASCOT'			=> ''
		];

		foreach($set as $key => $val) {
			$pSET[$key] = $val;
		}
	}
}
