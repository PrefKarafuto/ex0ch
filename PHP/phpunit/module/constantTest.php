<?php
declare(strict_types=1);

require_once(dirname(__FILE__).'/../../test/module/constant.php');

use \New_0ch_Plus\module\ZP as ZP;
use \PHPUnit\Framework\TestCase as TestCase;

class ConstantTest extends TestCase {

	/**
	 * Client定数値を呼び出せるかテスト。
	 */
	public function testClientConst() {
		# CLIENT
		#  M: Mobile Browser, F: Full Browser
		$C_PC				= 0x00000001;
		$C_P2				= 0x00000002;
		$C_DOCOMO_M			= 0x00000004;
		$C_DOCOMO_F			= 0x00000008;
		$C_DOCOMO			= $C_DOCOMO_M | $C_DOCOMO_F;
		$C_AU_M				= 0x00000010;
		$C_AU_F				= 0x00000020;
		$C_AU				= $C_AU_M | $C_AU_F;
		$C_SOFTBANK_M		= 0x00000040;
		$C_SOFTBANK_F		= 0x00000080;
		$C_SOFTBANK			= $C_SOFTBANK_M | $C_SOFTBANK_F;
		$C_WILLCOM_M		= 0x00000100;
		$C_WILLCOM_F		= 0x00000200;
		$C_WILLCOM			= $C_WILLCOM_M | $C_WILLCOM_F;
		$C_EMOBILE_M		= 0x00000400;
		$C_EMOBILE_F		= 0x00000800;
		$C_EMOBILE			= $C_EMOBILE_M | $C_EMOBILE_F;
		$C_IBIS				= 0x00001000;
		$C_JIG				= 0x00002000;
		$C_OPERAMINI		= 0x00004000;
		$C_IPHONE_F			= 0x00008000;
		$C_IPHONEWIFI		= 0x00010000;
		$C_IPHONE			= $C_IPHONE_F | $C_IPHONEWIFI;
		$C_FBSERVICE		= $C_IBIS | $C_JIG | $C_OPERAMINI;
		$C_MOBILEBROWSER	= $C_DOCOMO_M | $C_AU_M | $C_SOFTBANK_M | $C_WILLCOM_M | $C_EMOBILE_M;
		$C_FULLBROWSER		= $C_DOCOMO_F | $C_AU_F | $C_SOFTBANK_F | $C_WILLCOM_F | $C_EMOBILE_F | $C_FBSERVICE;
		$C_MOBILE			= $C_MOBILEBROWSER |$C_FULLBROWSER;
		$C_MOBILE_IDGET		= $C_DOCOMO_M | $C_AU_M | $C_SOFTBANK_M | $C_EMOBILE_M | $C_P2;

		# CLIENT
		#  M: Mobile Browser, F: Full Browser
		$this->assertEquals(ZP::C_PC, $C_PC);
		$this->assertEquals(ZP::C_P2, $C_P2);
		$this->assertEquals(ZP::C_DOCOMO_M, $C_DOCOMO_M);
		$this->assertEquals(ZP::C_DOCOMO_F, $C_DOCOMO_F);
		$this->assertEquals(ZP::C_DOCOMO, $C_DOCOMO);
		$this->assertEquals(ZP::C_AU_M, $C_AU_M);
		$this->assertEquals(ZP::C_AU_F, $C_AU_F);
		$this->assertEquals(ZP::C_AU, $C_AU);
		$this->assertEquals(ZP::C_SOFTBANK_M, $C_SOFTBANK_M);
		$this->assertEquals(ZP::C_SOFTBANK_F, $C_SOFTBANK_F);
		$this->assertEquals(ZP::C_SOFTBANK, $C_SOFTBANK);
		$this->assertEquals(ZP::C_WILLCOM_M, $C_WILLCOM_M);
		$this->assertEquals(ZP::C_WILLCOM_F, $C_WILLCOM_F);
		$this->assertEquals(ZP::C_WILLCOM, $C_WILLCOM);
		$this->assertEquals(ZP::C_EMOBILE_M, $C_EMOBILE_M);
		$this->assertEquals(ZP::C_EMOBILE_F, $C_EMOBILE_F);
		$this->assertEquals(ZP::C_EMOBILE, $C_EMOBILE);
		$this->assertEquals(ZP::C_IBIS, $C_IBIS);
		$this->assertEquals(ZP::C_JIG, $C_JIG);
		$this->assertEquals(ZP::C_OPERAMINI, $C_OPERAMINI);
		$this->assertEquals(ZP::C_IPHONE_F, $C_IPHONE_F);
		$this->assertEquals(ZP::C_IPHONEWIFI, $C_IPHONEWIFI);
		$this->assertEquals(ZP::C_IPHONE, $C_IPHONE);
		$this->assertEquals(ZP::C_FBSERVICE, $C_FBSERVICE);
		$this->assertEquals(ZP::C_MOBILEBROWSER, $C_MOBILEBROWSER);
		$this->assertEquals(ZP::C_FULLBROWSER, $C_FULLBROWSER);
		$this->assertEquals(ZP::C_MOBILE, $C_MOBILE);
		$this->assertEquals(ZP::C_MOBILE_IDGET, $C_MOBILE_IDGET);
	}

	/**
	 * ErrorNum定数値を呼び出せるかテスト。
	 */
	public function testErrorNumConst() {
		# ERRORNUM
		$E_SUCCESS				= 0; # must FALSE
		#  入力内容に関するエラー
		$E_FORM_LONGSUBJECT		= 100;
		$E_FORM_LONGNAME		= 101;
		$E_FORM_LONGMAIL		= 102;
		$E_FORM_LONGTEXT		= 103;
		$E_FORM_LONGLINE		= 104;
		$E_FORM_MANYLINE		= 105;
		$E_FORM_MANYANCHOR		= 106;
		$E_FORM_NOSUBJECT		= 150;
		$E_FORM_NOTEXT			= 151;
		$E_FORM_NONAME			= 152;
		$E_FORM_NOCAPTCHA		= 153;
		#  制限に関するエラー
		$E_LIMIT_STOPPEDTHREAD	= 200;
		$E_LIMIT_OVERMAXRES		= 201;
		$E_LIMIT_MOVEDTHREAD	= 202;
		$E_LIMIT_READONLY		= 203;
		$E_LIMIT_MOBILETHREAD	= 204;
		$E_LIMIT_FORBIDDENCGI	= 205;
		$E_LIMIT_OVERDATSIZE	= 206;
		$E_LIMIT_THREADCAPONLY	= 504;
		#  規制に関するエラー
		$E_REG_MANYTHREAD		= 500;
		$E_REG_NOBREAKPOST		= 501;
		$E_REG_DOUBLEPOST		= 502;
		$E_REG_NOTIMEPOST		= 503;
		$E_REG_SAMBA_CAUTION	= 505; # continuously
		$E_REG_SAMBA_WARNING	= 506; # 505+1
		$E_REG_SAMBA_LISTED		= 507; # 505+2
		$E_REG_SAMBA_STILL		= 508; # 505+3
		$E_REG_SAMBA_2CH1		= 593; # 2ch errnum
		$E_REG_SAMBA_2CH2		= 599; # 2ch errnum
		$E_REG_SAMBA_2CH3		= 594; # 2ch errnum
		$E_REG_NGWORD			= 600;
		$E_REG_NGUSER			= 601;
		$E_REG_SPAMKILL			= 602;
		$E_REG_SAMETITLE		= 603;
		$E_REG_NOTJPHOST		= 207;
		$E_REG_DNSBL			= 997;
		#  BEに関するエラー
		$E_BE_GETFAILED			= 890;
		$E_BE_CONNECTFAILED		= 891;
		$E_BE_LOGINFAILED		= 892;
		$E_BE_MUSTLOGIN			= 893;
		$E_BE_MUSTLOGIN2		= 894;
		#  リクエストエラー
		$E_THREAD_INVALIDKEY	= 900;
		$E_THREAD_WRONGLENGTH	= 901;
		$E_THREAD_NOTEXIST		= 902;
		$E_POST_NOPRODUCT		= 950;
		$E_POST_INVALIDREFERER	= 998;
		$E_POST_INVALIDFORM		= 999;
		$E_POST_NOTEXISTBBS		= $E_POST_INVALIDFORM;
		$E_POST_NOTEXISTDAT		= $E_POST_INVALIDFORM;
		#  read.cgi用エラー
		$E_READ_R_INVALIDBBS	= 1001; # 2ch errnum
		$E_READ_R_INVALIDKEY	= 1002; # 2ch errnum
		$E_READ_FAILEDLOADDAT	= 1003; # 2ch errnum
		$E_READ_FAILEDLOADSET	= 1004; # 2ch errnum
		$E_READ_INVALIDBBS		= 2011; # 2ch errnum
		$E_READ_INVALIDKEY		= 3001; # 2ch errnum
		#  システム・その他のエラー
		$E_SYSTEM_ERROR			= 990;
		#  ページ表示用番号
		$E_PAGE_FINDTHREAD		= $E_READ_FAILEDLOADDAT;
		$E_PAGE_THREAD			= 9000;
		$E_PAGE_COOKIE			= 9001;
		$E_PAGE_WRITE			= 9002;
		$E_PAGE_THREADMOBILE	= 9003;

		# ERRORNUM
		$this->assertEquals(ZP::E_SUCCESS, $E_SUCCESS);
		#  入力内容に関するエラー
		$this->assertEquals(ZP::E_FORM_LONGSUBJECT, $E_FORM_LONGSUBJECT);
		$this->assertEquals(ZP::E_FORM_LONGNAME, $E_FORM_LONGNAME);
		$this->assertEquals(ZP::E_FORM_LONGMAIL, $E_FORM_LONGMAIL);
		$this->assertEquals(ZP::E_FORM_LONGTEXT, $E_FORM_LONGTEXT);
		$this->assertEquals(ZP::E_FORM_LONGLINE, $E_FORM_LONGLINE);
		$this->assertEquals(ZP::E_FORM_MANYLINE, $E_FORM_MANYLINE);
		$this->assertEquals(ZP::E_FORM_MANYANCHOR, $E_FORM_MANYANCHOR);
		$this->assertEquals(ZP::E_FORM_NOSUBJECT, $E_FORM_NOSUBJECT);
		$this->assertEquals(ZP::E_FORM_NOTEXT, $E_FORM_NOTEXT);
		$this->assertEquals(ZP::E_FORM_NONAME, $E_FORM_NONAME);
		$this->assertEquals(ZP::E_FORM_NOCAPTCHA, $E_FORM_NOCAPTCHA);
		#  制限に関するエラー
		$this->assertEquals(ZP::E_LIMIT_STOPPEDTHREAD, $E_LIMIT_STOPPEDTHREAD);
		$this->assertEquals(ZP::E_LIMIT_OVERMAXRES, $E_LIMIT_OVERMAXRES);
		$this->assertEquals(ZP::E_LIMIT_MOVEDTHREAD, $E_LIMIT_MOVEDTHREAD);
		$this->assertEquals(ZP::E_LIMIT_READONLY, $E_LIMIT_READONLY);
		$this->assertEquals(ZP::E_LIMIT_MOBILETHREAD, $E_LIMIT_MOBILETHREAD);
		$this->assertEquals(ZP::E_LIMIT_FORBIDDENCGI, $E_LIMIT_FORBIDDENCGI);
		$this->assertEquals(ZP::E_LIMIT_OVERDATSIZE, $E_LIMIT_OVERDATSIZE);
		$this->assertEquals(ZP::E_LIMIT_THREADCAPONLY, $E_LIMIT_THREADCAPONLY);
		#  規制に関するエラー
		$this->assertEquals(ZP::E_REG_MANYTHREAD, $E_REG_MANYTHREAD);
		$this->assertEquals(ZP::E_REG_NOBREAKPOST, $E_REG_NOBREAKPOST);
		$this->assertEquals(ZP::E_REG_DOUBLEPOST, $E_REG_DOUBLEPOST);
		$this->assertEquals(ZP::E_REG_NOTIMEPOST, $E_REG_NOTIMEPOST);
		$this->assertEquals(ZP::E_REG_SAMBA_CAUTION, $E_REG_SAMBA_CAUTION); # continuously
		$this->assertEquals(ZP::E_REG_SAMBA_WARNING, $E_REG_SAMBA_WARNING); # 505+1
		$this->assertEquals(ZP::E_REG_SAMBA_LISTED, $E_REG_SAMBA_LISTED); # 505+2
		$this->assertEquals(ZP::E_REG_SAMBA_STILL, $E_REG_SAMBA_STILL); # 505+3
		$this->assertEquals(ZP::E_REG_SAMBA_2CH1, $E_REG_SAMBA_2CH1); # 2ch errnum
		$this->assertEquals(ZP::E_REG_SAMBA_2CH2, $E_REG_SAMBA_2CH2); # 2ch errnum
		$this->assertEquals(ZP::E_REG_SAMBA_2CH3, $E_REG_SAMBA_2CH3); # 2ch errnum
		$this->assertEquals(ZP::E_REG_NGWORD, $E_REG_NGWORD);
		$this->assertEquals(ZP::E_REG_NGUSER, $E_REG_NGUSER);
		$this->assertEquals(ZP::E_REG_SPAMKILL, $E_REG_SPAMKILL);
		$this->assertEquals(ZP::E_REG_SAMETITLE, $E_REG_SAMETITLE);
		$this->assertEquals(ZP::E_REG_NOTJPHOST, $E_REG_NOTJPHOST);
		$this->assertEquals(ZP::E_REG_DNSBL, $E_REG_DNSBL);
		#  BEに関するエラー
		$this->assertEquals(ZP::E_BE_GETFAILED, $E_BE_GETFAILED);
		$this->assertEquals(ZP::E_BE_CONNECTFAILED, $E_BE_CONNECTFAILED);
		$this->assertEquals(ZP::E_BE_LOGINFAILED, $E_BE_LOGINFAILED);
		$this->assertEquals(ZP::E_BE_MUSTLOGIN, $E_BE_MUSTLOGIN);
		$this->assertEquals(ZP::E_BE_MUSTLOGIN2, $E_BE_MUSTLOGIN2);
		#  リクエストエラー
		$this->assertEquals(ZP::E_THREAD_INVALIDKEY, $E_THREAD_INVALIDKEY);
		$this->assertEquals(ZP::E_THREAD_WRONGLENGTH, $E_THREAD_WRONGLENGTH);
		$this->assertEquals(ZP::E_THREAD_NOTEXIST, $E_THREAD_NOTEXIST);
		$this->assertEquals(ZP::E_POST_NOPRODUCT, $E_POST_NOPRODUCT);
		$this->assertEquals(ZP::E_POST_INVALIDREFERER, $E_POST_INVALIDREFERER);
		$this->assertEquals(ZP::E_POST_INVALIDFORM, $E_POST_INVALIDFORM);
		$this->assertEquals(ZP::E_POST_NOTEXISTBBS, $E_POST_NOTEXISTBBS);
		$this->assertEquals(ZP::E_POST_NOTEXISTDAT, $E_POST_NOTEXISTDAT);
		#  read.cgi用エラー
		$this->assertEquals(ZP::E_READ_R_INVALIDBBS, $E_READ_R_INVALIDBBS); # 2ch errnum
		$this->assertEquals(ZP::E_READ_R_INVALIDKEY, $E_READ_R_INVALIDKEY); # 2ch errnum
		$this->assertEquals(ZP::E_READ_FAILEDLOADDAT, $E_READ_FAILEDLOADDAT); # 2ch errnum
		$this->assertEquals(ZP::E_READ_FAILEDLOADSET, $E_READ_FAILEDLOADSET); # 2ch errnum
		$this->assertEquals(ZP::E_READ_INVALIDBBS, $E_READ_INVALIDBBS); # 2ch errnum
		$this->assertEquals(ZP::E_READ_INVALIDKEY, $E_READ_INVALIDKEY); # 2ch errnum
		#  システム・その他のエラー
		$this->assertEquals(ZP::E_SYSTEM_ERROR, $E_SYSTEM_ERROR);
		#  ページ表示用番号
		$this->assertEquals(ZP::E_PAGE_FINDTHREAD, $E_PAGE_FINDTHREAD);
		$this->assertEquals(ZP::E_PAGE_THREAD, $E_PAGE_THREAD);
		$this->assertEquals(ZP::E_PAGE_COOKIE, $E_PAGE_COOKIE);
		$this->assertEquals(ZP::E_PAGE_WRITE, $E_PAGE_WRITE);
		$this->assertEquals(ZP::E_PAGE_THREADMOBILE, $E_PAGE_THREADMOBILE);
	}

	/**
	 * CAP PERMISSION定数値を呼び出せるかテスト。
	 */
	public function testCapPermissionConst() {
		# CAP PERMISSION
		$CAP_FORM_LONGSUBJECT		=  1; # タイトル文字数 制限解除
		$CAP_FORM_LONGNAME			=  2; # 名前文字数 制限解除
		$CAP_FORM_LONGMAIL			=  3; # メール文字数 制限解除
		$CAP_FORM_LONGTEXT			=  4; # 本文文字数 制限解除
		$CAP_FORM_MANYLINE			=  5; # 本文行数 制限解除
		$CAP_FORM_LONGLINE			=  6; # 本文1行文字数 制限解除
		$CAP_FORM_NONAME			=  7; # 名無し 制限解除
		$CAP_REG_MANYTHREAD			=  8; # スレッド作成 規制解除
		$CAP_LIMIT_THREADCAPONLY	=  9; # スレッド作成可能
		$CAP_REG_NOBREAKPOST		= 10; # 連続投稿 規制解除
		$CAP_REG_DOUBLEPOST			= 11; # 二重書き込み 規制解除
		$CAP_REG_NOTIMEPOST			= 12; # 短時間投稿 規制解除
		$CAP_LIMIT_READONLY			= 13; # 読取専用 制限解除
		$CAP_DISP_NOID				= 14; # ID非表示
		$CAP_DISP_NOHOST			= 15; # 本文ホスト非表示
		$CAP_LIMIT_MOBILETHREAD		= 16; # 携帯からのスレッド作成 制限解除
		$CAP_DISP_HANLDLE			= 17; # コテハン★表示
		$CAP_REG_SAMBA				= 18; # Samba 規制解除
		$CAP_REG_DNSBL				= 19; # プロキシ 規制解除
		$CAP_REG_NOTJPHOST			= 20; # 海外ホスト 規制解除
		$CAP_REG_NGUSER				= 21; # ユーザー 規制解除
		$CAP_REG_NGWORD				= 22; # NGワード 規制解除
		$CAP_DISP_NOSLIP			= 23; # 端末識別子非表示
		$CAP_DISP_CUSTOMID			= 24; # 専用ID許可
		$CAP_MAXNUM					= 24;

		$this->assertEquals(ZP::CAP_FORM_LONGSUBJECT, $CAP_FORM_LONGSUBJECT); # タイトル文字数 制限解除
		$this->assertEquals(ZP::CAP_FORM_LONGNAME, $CAP_FORM_LONGNAME); # 名前文字数 制限解除
		$this->assertEquals(ZP::CAP_FORM_LONGMAIL, $CAP_FORM_LONGMAIL); # メール文字数 制限解除
		$this->assertEquals(ZP::CAP_FORM_LONGTEXT, $CAP_FORM_LONGTEXT); # 本文文字数 制限解除
		$this->assertEquals(ZP::CAP_FORM_MANYLINE, $CAP_FORM_MANYLINE); # 本文行数 制限解除
		$this->assertEquals(ZP::CAP_FORM_LONGLINE, $CAP_FORM_LONGLINE); # 本文1行文字数 制限解除
		$this->assertEquals(ZP::CAP_FORM_NONAME, $CAP_FORM_NONAME); # 名無し 制限解除
		$this->assertEquals(ZP::CAP_REG_MANYTHREAD, $CAP_REG_MANYTHREAD); # スレッド作成 規制解除
		$this->assertEquals(ZP::CAP_LIMIT_THREADCAPONLY, $CAP_LIMIT_THREADCAPONLY); # スレッド作成可能
		$this->assertEquals(ZP::CAP_REG_NOBREAKPOST, $CAP_REG_NOBREAKPOST); # 連続投稿 規制解除
		$this->assertEquals(ZP::CAP_REG_DOUBLEPOST, $CAP_REG_DOUBLEPOST); # 二重書き込み 規制解除
		$this->assertEquals(ZP::CAP_REG_NOTIMEPOST, $CAP_REG_NOTIMEPOST); # 短時間投稿 規制解除
		$this->assertEquals(ZP::CAP_LIMIT_READONLY, $CAP_LIMIT_READONLY); # 読取専用 制限解除
		$this->assertEquals(ZP::CAP_DISP_NOID, $CAP_DISP_NOID); # ID非表示
		$this->assertEquals(ZP::CAP_DISP_NOHOST, $CAP_DISP_NOHOST); # 本文ホスト非表示
		$this->assertEquals(ZP::CAP_LIMIT_MOBILETHREAD, $CAP_LIMIT_MOBILETHREAD); # 携帯からのスレッド作成 制限解除
		$this->assertEquals(ZP::CAP_DISP_HANLDLE, $CAP_DISP_HANLDLE); # コテハン★表示
		$this->assertEquals(ZP::CAP_REG_SAMBA, $CAP_REG_SAMBA); # Samba 規制解除
		$this->assertEquals(ZP::CAP_REG_DNSBL, $CAP_REG_DNSBL); # プロキシ 規制解除
		$this->assertEquals(ZP::CAP_REG_NOTJPHOST, $CAP_REG_NOTJPHOST); # 海外ホスト 規制解除
		$this->assertEquals(ZP::CAP_REG_NGUSER, $CAP_REG_NGUSER); # ユーザー 規制解除
		$this->assertEquals(ZP::CAP_REG_NGWORD, $CAP_REG_NGWORD); # NGワード 規制解除
		$this->assertEquals(ZP::CAP_DISP_NOSLIP, $CAP_DISP_NOSLIP); # 端末識別子非表示
		$this->assertEquals(ZP::CAP_DISP_CUSTOMID, $CAP_DISP_CUSTOMID); # 専用ID許可
		$this->assertEquals(ZP::CAP_MAXNUM, $CAP_MAXNUM);
	}

	/**
	 * USER AUTHORITY定数値を呼び出せるかテスト。
	 */
	public function testUserAuthorityConst() {
		# USER AUTHORITY
		$AUTH_SYSADMIN		=  0; # システム管理権限(形式的に)
		$AUTH_USERGROUP		=  1; # 管理グループ設定
		$AUTH_CAPGROUP		=  2; # キャップグループ設定
		$AUTH_THREADSTOP	=  3; # スレッド停止・再開
		$AUTH_THREADPOOL	=  4; # スレッドdat落ち・復活
		$AUTH_TREADDELETE	=  5; # スレッド削除
		$AUTH_THREADINFO	=  6; # スレッド情報更新
		$AUTH_KAKOCREATE	=  7; # 過去ログ生成
		$AUTH_KAKODELETE	=  8; # 過去ログ削除
		$AUTH_BBSSETTING	=  9; # 掲示板設定
		$AUTH_NGWORDS		= 10; # NGワード編集
		$AUTH_ACCESUSER		= 11; # アクセス制限編集
		$AUTH_RESDELETE		= 12; # レスあぼーん
		$AUTH_RESEDIT		= 13; # レス編集
		$AUTH_BBSEDIT		= 14; # 各種編集
		$AUTH_LOGVIEW		= 15; # ログの閲覧・削除
		$AUTH_MAXNUM		= 15;

		$this->assertEquals(ZP::AUTH_SYSADMIN, $AUTH_SYSADMIN); # システム管理権限(形式的に)
		$this->assertEquals(ZP::AUTH_USERGROUP, $AUTH_USERGROUP); # 管理グループ設定
		$this->assertEquals(ZP::AUTH_CAPGROUP, $AUTH_CAPGROUP); # キャップグループ設定
		$this->assertEquals(ZP::AUTH_THREADSTOP, $AUTH_THREADSTOP); # スレッド停止・再開
		$this->assertEquals(ZP::AUTH_THREADPOOL, $AUTH_THREADPOOL); # スレッドdat落ち・復活
		$this->assertEquals(ZP::AUTH_TREADDELETE, $AUTH_TREADDELETE); # スレッド削除
		$this->assertEquals(ZP::AUTH_THREADINFO, $AUTH_THREADINFO); # スレッド情報更新
		$this->assertEquals(ZP::AUTH_KAKOCREATE, $AUTH_KAKOCREATE); # 過去ログ生成
		$this->assertEquals(ZP::AUTH_KAKODELETE, $AUTH_KAKODELETE); # 過去ログ削除
		$this->assertEquals(ZP::AUTH_BBSSETTING, $AUTH_BBSSETTING); # 掲示板設定
		$this->assertEquals(ZP::AUTH_NGWORDS, $AUTH_NGWORDS); # NGワード編集
		$this->assertEquals(ZP::AUTH_ACCESUSER, $AUTH_ACCESUSER); # アクセス制限編集
		$this->assertEquals(ZP::AUTH_RESDELETE, $AUTH_RESDELETE); # レスあぼーん
		$this->assertEquals(ZP::AUTH_RESEDIT, $AUTH_RESEDIT); # レス編集
		$this->assertEquals(ZP::AUTH_BBSEDIT, $AUTH_BBSEDIT); # 各種編集
		$this->assertEquals(ZP::AUTH_LOGVIEW, $AUTH_LOGVIEW); # ログの閲覧・削除
		$this->assertEquals(ZP::AUTH_MAXNUM, $AUTH_MAXNUM);
	}

	/**
	 * Regexp定数値を呼び出せるかテスト。
	 */
	public function testRegexpConst() {
		# REGEXP
		$RE_SJIS	= '(?:[\x00-\x7f\xa1-\xdf]|[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])';

		$this->assertEquals(ZP::RE_SJIS, $RE_SJIS);
	}

}
