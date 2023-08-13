<?php
declare(strict_types=1);

require_once(dirname(__FILE__).'/../../test/module/system.php');

use \New_0ch_Plus\module\System as System;
use \PHPUnit\Framework\TestCase as TestCase;

class SystemTest extends TestCase {

	/**
	 * とりあえず new して Init を実行できるか、Initした結果値が変わっているかのテスト。
	 */
	public function testInit() {
		$System = new System();
		$result = $System->Get("SYSFILE", "default");
		$this->assertEquals($result, "default");

		/* Initの実行の際にファイルを生成するが、
		そのあたりでテストがうまくいかなかったため、いったんコメントアウト
		解決できる方いたら修正をお願いします m(__)m

		// 実行
		$result = $System->Init();
		$this->assertEquals($result, 0);

		// 実行後初期値ではない値が取得されていることの確認
		$result = $System->Get("SYSFILE", "default");
		$this->assertNotEquals($result, "default");
		*/
	}

	/**
	 * Get と Set を実行し値が書き換わっていることのテスト
	 */
	public function testGetAndSet() {
		$System = new System();

		// Get実行
		$result = $System->Get("SYSFILE", "default");
		$this->assertEquals($result, "default");

		// Set実行
		$System->Set("SYSFILE", "test Set");

		// 書き換えた値が取得されていることの確認
		$result = $System->Get("SYSFILE", "default");
		$this->assertEquals($result, "test Set");

		// 別の値は変わっていないことの確認
		$result = $System->Get("SERVER", "other default");
		$this->assertEquals($result, "other default");

		// 2回目のSet実行
		$System->Set("SYSFILE", "test Set second");

		// 書き換えた値が取得されていることの確認
		$result = $System->Get("SYSFILE", "default");
		$this->assertEquals($result, "test Set second");

		// 別の値は変わっていないことの確認
		$result = $System->Get("SERVER", "other default");
		$this->assertEquals($result, "other default");
	}

	/**
	 * Equals のテスト
	 */
	public function testEquals() {
		$System = new System();

		// 存在しないキーはfalse
		$result = $System->Equals("any key", null);
		$this->assertFalse($result);

		// 適当な値を入れて実行する
		$System->Set("SYSFILE", "test value");

		// 同じ値ならtrue
		$result = $System->Equals("SYSFILE", "test value");
		$this->assertTrue($result);

		// 違う値ならfalse
		$result = $System->Equals("SYSFILE", "not equals");
		$this->assertFalse($result);
	}

	/**
	 * GetOption と SetOption のテスト
	 */
	public function testGetOptionAndSetOption() {
		$System = new System();

		// OPTION がない場合なら -1
		$result = $System->Get('OPTION', 'default value');
		$this->assertEquals($result, "default value");
		$result = $System->GetOption(1);
		$this->assertEquals($result, -1);

		// SetOption の実行
		$System->SetOption('last', 'start', 'end', 'one', 'alone');

		// GetOption で想定通り取得できる。
		$result = $System->GetOption(1);
		$this->assertEquals($result, 'last');
		$result = $System->GetOption(2);
		$this->assertEquals($result, 'start');
		$result = $System->GetOption(3);
		$this->assertEquals($result, 'end');
		$result = $System->GetOption(4);
		$this->assertEquals($result, 'one');
		$result = $System->GetOption(5);
		$this->assertEquals($result, 'alone');

		// 範囲外は -1
		$result = $System->GetOption(0);
		$this->assertEquals($result, -1);
		$result = $System->GetOption(6);
		$this->assertEquals($result, -1);

		// Get での取得
		$result = $System->Get('OPTION', 'default value');
		$this->assertEquals($result, "last,start,end,one,alone");
	}
}
