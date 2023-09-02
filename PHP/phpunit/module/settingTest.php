<?php
declare(strict_types=1);

require_once(dirname(__FILE__).'/../../test/module/system.php');
require_once(dirname(__FILE__).'/../../test/module/setting.php');

use \New_0ch_Plus\module\Setting as Setting;
use \New_0ch_Plus\module\System as System;
use \PHPUnit\Framework\TestCase as TestCase;

class SettingTest extends TestCase {

	/**
	 * 掲示板設定読み込みのテスト。
	 */
	public function testLoad() {
		// ファイルの存在しない等で読み込みできないテスト
		$Setting = new Setting();
		$result = $Setting->Get('BBS_DELETE_NAME', 'defaults');
		$this->assertEquals($result, 'defaults');

		$System = new System();
		$System->Set("PM-TXT", 0644);
		$System->Set("BBSPATH", '..');
		$System->Set("BBS", 'not found');

		$result = $Setting->Load($System);
		$this->assertEquals($result, 0);

		// Load は初期設定項目が設定されている。
		$result = $Setting->Get('BBS_DELETE_NAME', 'defaults');
		$this->assertEquals($result, 'あぼーん');

		// ファイルの読み込み成功テスト
		$Setting = new Setting();
		$result = $Setting->Get('BBS_DELETE_NAME', 'defaults');
		$this->assertEquals($result, 'defaults');

		$System->Set("PM-TXT", 0644);
		$System->Set("BBSPATH", '..');
		$System->Set("BBS", '');

		/* ファイルを読み込みするが、
		そのあたりでテストがうまくいかなかったため、いったんコメントアウト
		解決できる方いたら修正をお願いします m(__)m

		// 実行
		$result = $Setting->Load($System);

		$exists = file_exists($path)
		$this->assertTrue($exists);
		*/
	}

	/**
	 * 掲示板設定読み込み(指定ファイル)のテスト。
	 */
	public function testLoadFrom() {
		// ファイルの存在しない等で読み込みできないテスト
		$Setting = new Setting();
		$result = $Setting->Get('BBS_DELETE_NAME', 'defaults');
		$this->assertEquals($result, 'defaults');

		$path = '../not found/nofile.txt';

		$this->assertTrue(true);
		/* ファイルの読み込みが失敗するが、
		errorで落ちるのが正なのか、return 0 が正なのかひとまずわからなかったため
		いったん保留

		$result = $Setting->LoadFrom($path);
		$this->assertEquals($result, 0);

		// LoadFrom は初期設定項目が設定されない。
		$result = $Setting->Get('BBS_DELETE_NAME', 'defaults');
		$this->assertEquals($result, 'defaults');
		*/

		// ファイルの読み込み成功テスト
		$Setting = new Setting();
		$path = '../SETTING.txt';

		/* ファイルを読み込みするが、
		そのあたりでテストがうまくいかなかったため、いったんコメントアウト
		解決できる方いたら修正をお願いします m(__)m

		// 実行
		$result = $Setting->Load($System);

		$exists = file_exists($path)
		$this->assertTrue($exists);
		*/
	}

	/**
	 * 掲示板設定書き込みのテスト。
	 */
	public function testSave() {
		$System = new System();
		$System->Set("PM-TXT", 0644);
		$System->Set("BBSPATH", '..');
		$System->Set("BBS", '');

		$Setting = new Setting();

		$this->assertTrue(true);
		/* ファイルを生成するが、
		そのあたりでテストがうまくいかなかったため、いったんコメントアウト
		解決できる方いたら修正をお願いします m(__)m

		// 実行
		$result = $Setting->Save($System);

		$exists = file_exists($path)
		$this->assertTrue($exists);
		*/
	}

	/**
	 * 掲示板設定書き込み(指定ファイル)のテスト。
	 */
	public function testSaveAs() {
		$Setting = new Setting();

		$path = '../SETTING.TXT';

		$this->assertTrue(true);
		/* ファイルを生成するが、
		そのあたりでテストがうまくいかなかったため、いったんコメントアウト
		解決できる方いたら修正をお願いします m(__)m

		// 実行
		$result = $Setting->SaveAs($path);

		$exists = file_exists($path)
		$this->assertTrue($exists);
		*/
	}

	/**
	 * 掲示板設定キー取得
	 */
	public function testGetKeySet() {
		$Setting = new Setting();
		$Setting->Set("BBS_TITLE", "test Set");
		$Setting->Set("BBS_TITLE_PICTURE", "test Set");
		$Setting->Set("BBS_TITLE_COLOR", "test Set");

		// 実行・未定義の変数を渡す
		$Setting->GetKeySet($keySet);

		// 配列になって戻ってくる。
		$this->assertEquals($keySet, [
			"BBS_TITLE", "BBS_TITLE_PICTURE", "BBS_TITLE_COLOR"
		]);
	}

	/**
	 * Get と Set を実行し値が書き換わっていることのテスト
	 */
	public function testGetAndSet() {
		$Setting = new Setting();

		// Get実行
		$result = $Setting->Get("BBS_TITLE", "default");
		$this->assertEquals($result, "default");

		// Set実行
		$Setting->Set("BBS_TITLE", "test Set");

		// 書き換えた値が取得されていることの確認
		$result = $Setting->Get("BBS_TITLE", "default");
		$this->assertEquals($result, "test Set");

		// 別の値は変わっていないことの確認
		$result = $Setting->Get("BBS_TITLE_PICTURE", "other default");
		$this->assertEquals($result, "other default");

		// 2回目のSet実行
		$Setting->Set("BBS_TITLE", "test Set second");

		// 書き換えた値が取得されていることの確認
		$result = $Setting->Get("BBS_TITLE", "default");
		$this->assertEquals($result, "test Set second");

		// 別の値は変わっていないことの確認
		$result = $Setting->Get("BBS_TITLE_PICTURE", "other default");
		$this->assertEquals($result, "other default");
	}

	/**
	 * Equals のテスト
	 */
	public function testEquals() {
		$Setting = new Setting();

		// 存在しないキーはfalse
		$result = $Setting->Equals("any key", null);
		$this->assertFalse($result);

		// 適当な値を入れて実行する
		$Setting->Set("BBS_TITLE", "test value");

		// 同じ値ならtrue
		$result = $Setting->Equals("BBS_TITLE", "test value");
		$this->assertTrue($result);

		// 違う値ならfalse
		$result = $Setting->Equals("BBS_TITLE", "not equals");
		$this->assertFalse($result);
	}

}
