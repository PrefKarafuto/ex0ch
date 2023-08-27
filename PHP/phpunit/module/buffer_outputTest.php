<?php
declare(strict_types=1);

require_once(dirname(__FILE__).'/../../test/module/buffer_output.php');

use \New_0ch_Plus\module\BufferOutput as BufferOutput;
use \PHPUnit\Framework\TestCase as TestCase;

class Buffer_outputTest extends TestCase {

	/**
	 * バッファ出力テスト。
	 */
	public function testPrint() {
		
		$buffer = new BufferOutput();
		$this->assertEquals($buffer->getBuffer(), []);

		$buffer->Print("1");
		$buffer->Print("2");
		$buffer->Print("3");
		$buffer->Print("4");
		$buffer->Print("ab");
		$buffer->Print("cd");
		$buffer->Print("ef");
		$buffer->Print("gh");

		$this->assertEquals($buffer->getBuffer(), ["1", "2", "3", "4",
			"ab", "cd", "ef", "gh"]);
	}

	/**
	 * INPUTタグ出力テスト。
	 */
	public function testHTMLInput() {
		
		$buffer = new BufferOutput();
		$this->assertEquals($buffer->getBuffer(), []);

		$buffer->HTMLInput("text", "name1", "value1");
		$buffer->HTMLInput("check", "name2", "value2");
		$buffer->HTMLInput("hidden", "name3", "value3");

		$this->assertEquals($buffer->getBuffer(), [
			"<input type=\"text\" name=\"name1\" value=\"value1\">\n",
			"<input type=\"check\" name=\"name2\" value=\"value2\">\n",
			"<input type=\"hidden\" name=\"name3\" value=\"value3\">\n"
		]);
	}

	/**
	 * バッファフラッシュテスト。
	 */
	public function testFlush() {
		
		$buffer = new BufferOutput();
		$this->assertEquals($buffer->getBuffer(), []);

		$buffer->Print("1");
		$buffer->HTMLInput("hidden", "test1", "test1");
		$buffer->Print("abcd");

		// 標準出力の監視
		ob_start();
		$buffer->Flush(false, "", "");
		$outputs = ob_get_clean();

		$this->assertEquals($outputs,
			"1<input type=\"hidden\" name=\"test1\" value=\"test1\">\nabcd");

		/*
		ファイルの出力テストはうまく行うアイデアがないため、
		いったんコメントアウトしてテストを行わないでいます。
		うまく行えるアイデアがある方に対応いただけたらと思います。

		// ファイルに出力
		$filepath = "file path";
		$buffer->Flush(true, 666, $filepath);
		// ファイルを取得
		$lines = [];
		if (file_exists($filepath) && $fh = fopen($filepath, 'r')) {
			flock($fh, LOCK_EX);
			while (($line = fgets($fh)) !== false) {
				$lines[] = $line;
			}
			fclose($fh);
		}
		$this->assertEquals($buffer->getBuffer(), $lines);
		 */
	}

	/**
	 * バッファクリアテスト。
	 */
	public function testClear() {
		
		$buffer = new BufferOutput();
		$this->assertEquals($buffer->getBuffer(), []);

		$buffer->Print("print1");
		$this->assertEquals($buffer->getBuffer(), ["print1"]);

		$buffer->Clear();
		$this->assertEquals($buffer->getBuffer(), []);
	}

	
	/**
	 * マージテスト。
	 */
	public function testMerge() {
		
		$buffer1 = new BufferOutput();
		$this->assertEquals($buffer1->getBuffer(), []);
		$buffer2 = new BufferOutput();
		$this->assertEquals($buffer2->getBuffer(), []);

		$buffer1->Print("buf");
		$buffer1->Print("fer");
		$buffer1->Print("1");
		$this->assertEquals($buffer1->getBuffer(), ["buf", "fer", "1"]);
		$buffer2->Print("pri");
		$buffer2->Print("nt");
		$buffer2->Print("2");
		$this->assertEquals($buffer2->getBuffer(), ["pri", "nt", "2"]);

		$buffer1->Merge($buffer2);
		$this->assertEquals($buffer1->getBuffer(), ["buf", "fer", "1", "pri", "nt", "2"]);
	}
}
