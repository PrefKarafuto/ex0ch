<?php
declare(strict_types=1);

namespace New_0ch_Plus\module;

/**
 * 出力管理モジュール
 */
class BufferOutput {

	private $Buff;

	/**
	 * コンストラクタ
	 */
	public function __construct() {
		// 初期化
		$this->Buff = [];
	}

	/**
	 * Buffer配列の取得
	 */
	public function getBuffer():array {
		return $this->Buff;
	}

	/**
	 * バッファ出力 - Print
	 * 
	 * @param mixed $line 出力テキスト
	 */
	public function Print($line) {
		$this->Buff[] = $line;
	}

	/**
	 * INPUTタグ出力 - HTMLInput
	 * 
	 * @param mixed $kind タイプ
	 * @param mixed $name 名前
	 * @param mixed $value 値
	 */
	public function HTMLInput($kind, $name, $value) {
		$line = "<input type=\"" . $kind . "\" name=\"" . $name . "\" value=\"" . $value . "\">\n";

		$this->Buff[] = $line;
	}

	/**
	 * バッファフラッシュ - Flush
	 * 
	 * @param mixed $flag 出力フラグ
	 * @param mixed $perm パーミッション
	 * @param mixed $szFilePath 出力パス
	 */
	public function Flush($flag, $perm, $path) {

		// ファイルへ出力
		if ($flag) {
			chmod($path, $perm);
			$mode = file_exists($path)? 'r+': 'w';
			if (file_exists($path) && $fh = fopen($path, $mode)) {
				flock($fh, LOCK_EX);
				fseek($fh, 0);
				fwrite($fh, implode($this->Buff));
				ftruncate($fh, ftell($fh));
				fclose($fh);
			}
		} else {
			// 標準出力に出力
			echo implode($this->Buff);
		}
	}

	/**
	 * バッファクリア - Clear
	 */
	public function Clear() {
		$this->Buff = [];
	}

	/**
	 * マージ - Merge
	 * 
	 * @param BufferOutput $buffer BUFFER_OUTPUTモジュール
	 */
	public function Merge(BufferOutput $buffer) {
		foreach ($buffer->getBuffer() as $val) {
			$this->Buff[] = $val;
		}
	}
}
