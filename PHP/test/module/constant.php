<?php
declare(strict_types=1);

namespace New_0ch_Plus\module;

/**
 * 定数モジュール(ZP)
 * 
 * by ぜろちゃんねるプラス
 * http://zerochplus.sourceforge.jp/
 * https://github.com/PrefKarafuto/New_0ch_Plus/
 */
class ZP {

	# CLIENT
	#  M: Mobile Browser, F: Full Browser
	public const C_PC				= 0x00000001;
	public const C_P2				= 0x00000002;
	public const C_DOCOMO_M			= 0x00000004;
	public const C_DOCOMO_F			= 0x00000008;
	public const C_DOCOMO			= self::C_DOCOMO_M | self::C_DOCOMO_F;
	public const C_AU_M				= 0x00000010;
	public const C_AU_F				= 0x00000020;
	public const C_AU				= self::C_AU_M | self::C_AU_F;
	public const C_SOFTBANK_M		= 0x00000040;
	public const C_SOFTBANK_F		= 0x00000080;
	public const C_SOFTBANK			= self::C_SOFTBANK_M | self::C_SOFTBANK_F;
	public const C_WILLCOM_M		= 0x00000100;
	public const C_WILLCOM_F		= 0x00000200;
	public const C_WILLCOM			= self::C_WILLCOM_M | self::C_WILLCOM_F;
	public const C_EMOBILE_M		= 0x00000400;
	public const C_EMOBILE_F		= 0x00000800;
	public const C_EMOBILE			= self::C_EMOBILE_M | self::C_EMOBILE_F;
	public const C_IBIS				= 0x00001000;
	public const C_JIG				= 0x00002000;
	public const C_OPERAMINI		= 0x00004000;
	public const C_IPHONE_F			= 0x00008000;
	public const C_IPHONEWIFI		= 0x00010000;
	public const C_IPHONE			= self::C_IPHONE_F | self::C_IPHONEWIFI;
	public const C_FBSERVICE		= self::C_IBIS | self::C_JIG | self::C_OPERAMINI;
	public const C_MOBILEBROWSER	= self::C_DOCOMO_M | self::C_AU_M | self::C_SOFTBANK_M | self::C_WILLCOM_M | self::C_EMOBILE_M;
	public const C_FULLBROWSER		= self::C_DOCOMO_F | self::C_AU_F | self::C_SOFTBANK_F | self::C_WILLCOM_F | self::C_EMOBILE_F | self::C_FBSERVICE;
	public const C_MOBILE			= self::C_MOBILEBROWSER | self::C_FULLBROWSER;
	public const C_MOBILE_IDGET		= self::C_DOCOMO_M | self::C_AU_M | self::C_SOFTBANK_M | self::C_EMOBILE_M | self::C_P2;


	# ERRORNUM
	public const E_SUCCESS				= 0; # must FALSE
	#  入力内容に関するエラー
	public const E_FORM_LONGSUBJECT		= 100;
	public const E_FORM_LONGNAME		= 101;
	public const E_FORM_LONGMAIL		= 102;
	public const E_FORM_LONGTEXT		= 103;
	public const E_FORM_LONGLINE		= 104;
	public const E_FORM_MANYLINE		= 105;
	public const E_FORM_MANYANCHOR		= 106;
	public const E_FORM_NOSUBJECT		= 150;
	public const E_FORM_NOTEXT			= 151;
	public const E_FORM_NONAME			= 152;
	public const E_FORM_NOCAPTCHA		= 153;
	#  制限に関するエラー
	public const E_LIMIT_STOPPEDTHREAD	= 200;
	public const E_LIMIT_OVERMAXRES		= 201;
	public const E_LIMIT_MOVEDTHREAD	= 202;
	public const E_LIMIT_READONLY		= 203;
	public const E_LIMIT_MOBILETHREAD	= 204;
	public const E_LIMIT_FORBIDDENCGI	= 205;
	public const E_LIMIT_OVERDATSIZE	= 206;
	public const E_LIMIT_THREADCAPONLY	= 504;
	#  規制に関するエラー
	public const E_REG_MANYTHREAD		= 500;
	public const E_REG_NOBREAKPOST		= 501;
	public const E_REG_DOUBLEPOST		= 502;
	public const E_REG_NOTIMEPOST		= 503;
	public const E_REG_SAMBA_CAUTION	= 505; # continuously
	public const E_REG_SAMBA_WARNING	= 506; # 505+1
	public const E_REG_SAMBA_LISTED		= 507; # 505+2
	public const E_REG_SAMBA_STILL		= 508; # 505+3
	public const E_REG_SAMBA_2CH1		= 593; # 2ch errnum
	public const E_REG_SAMBA_2CH2		= 599; # 2ch errnum
	public const E_REG_SAMBA_2CH3		= 594; # 2ch errnum
	public const E_REG_NGWORD			= 600;
	public const E_REG_NGUSER			= 601;
	public const E_REG_SPAMKILL			= 602;
	public const E_REG_SAMETITLE		= 603;
	public const E_REG_NOTJPHOST		= 207;
	public const E_REG_DNSBL			= 997;
	#  BEに関するエラー
	public const E_BE_GETFAILED			= 890;
	public const E_BE_CONNECTFAILED		= 891;
	public const E_BE_LOGINFAILED		= 892;
	public const E_BE_MUSTLOGIN			= 893;
	public const E_BE_MUSTLOGIN2		= 894;
	#  リクエストエラー
	public const E_THREAD_INVALIDKEY	= 900;
	public const E_THREAD_WRONGLENGTH	= 901;
	public const E_THREAD_NOTEXIST		= 902;
	public const E_POST_NOPRODUCT		= 950;
	public const E_POST_INVALIDREFERER	= 998;
	public const E_POST_INVALIDFORM		= 999;
	public const E_POST_NOTEXISTBBS		= self::E_POST_INVALIDFORM;
	public const E_POST_NOTEXISTDAT		= self::E_POST_INVALIDFORM;
	#  read.cgi用エラー
	public const E_READ_R_INVALIDBBS	= 1001; # 2ch errnum
	public const E_READ_R_INVALIDKEY	= 1002; # 2ch errnum
	public const E_READ_FAILEDLOADDAT	= 1003; # 2ch errnum
	public const E_READ_FAILEDLOADSET	= 1004; # 2ch errnum
	public const E_READ_INVALIDBBS		= 2011; # 2ch errnum
	public const E_READ_INVALIDKEY		= 3001; # 2ch errnum
	#  システム・その他のエラー
	public const E_SYSTEM_ERROR			= 990;
	#  ページ表示用番号
	public const E_PAGE_FINDTHREAD		= self::E_READ_FAILEDLOADDAT;
	public const E_PAGE_THREAD			= 9000;
	public const E_PAGE_COOKIE			= 9001;
	public const E_PAGE_WRITE			= 9002;
	public const E_PAGE_THREADMOBILE	= 9003;


	# CAP PERMISSION
	public const CAP_FORM_LONGSUBJECT		=  1; # タイトル文字数 制限解除
	public const CAP_FORM_LONGNAME			=  2; # 名前文字数 制限解除
	public const CAP_FORM_LONGMAIL			=  3; # メール文字数 制限解除
	public const CAP_FORM_LONGTEXT			=  4; # 本文文字数 制限解除
	public const CAP_FORM_MANYLINE			=  5; # 本文行数 制限解除
	public const CAP_FORM_LONGLINE			=  6; # 本文1行文字数 制限解除
	public const CAP_FORM_NONAME			=  7; # 名無し 制限解除
	public const CAP_REG_MANYTHREAD			=  8; # スレッド作成 規制解除
	public const CAP_LIMIT_THREADCAPONLY	=  9; # スレッド作成可能
	public const CAP_REG_NOBREAKPOST		= 10; # 連続投稿 規制解除
	public const CAP_REG_DOUBLEPOST			= 11; # 二重書き込み 規制解除
	public const CAP_REG_NOTIMEPOST			= 12; # 短時間投稿 規制解除
	public const CAP_LIMIT_READONLY			= 13; # 読取専用 制限解除
	public const CAP_DISP_NOID				= 14; # ID非表示
	public const CAP_DISP_NOHOST			= 15; # 本文ホスト非表示
	public const CAP_LIMIT_MOBILETHREAD		= 16; # 携帯からのスレッド作成 制限解除
	public const CAP_DISP_HANLDLE			= 17; # コテハン★表示
	public const CAP_REG_SAMBA				= 18; # Samba 規制解除
	public const CAP_REG_DNSBL				= 19; # プロキシ 規制解除
	public const CAP_REG_NOTJPHOST			= 20; # 海外ホスト 規制解除
	public const CAP_REG_NGUSER				= 21; # ユーザー 規制解除
	public const CAP_REG_NGWORD				= 22; # NGワード 規制解除
	public const CAP_DISP_NOSLIP			= 23; # 端末識別子非表示
	public const CAP_DISP_CUSTOMID			= 24; # 専用ID許可
	public const CAP_MAXNUM					= 24;
	# USER AUTHORITY
	public const AUTH_SYSADMIN		=  0; # システム管理権限(形式的に)
	public const AUTH_USERGROUP		=  1; # 管理グループ設定
	public const AUTH_CAPGROUP		=  2; # キャップグループ設定
	public const AUTH_THREADSTOP	=  3; # スレッド停止・再開
	public const AUTH_THREADPOOL	=  4; # スレッドdat落ち・復活
	public const AUTH_TREADDELETE	=  5; # スレッド削除
	public const AUTH_THREADINFO	=  6; # スレッド情報更新
	public const AUTH_KAKOCREATE	=  7; # 過去ログ生成
	public const AUTH_KAKODELETE	=  8; # 過去ログ削除
	public const AUTH_BBSSETTING	=  9; # 掲示板設定
	public const AUTH_NGWORDS		= 10; # NGワード編集
	public const AUTH_ACCESUSER		= 11; # アクセス制限編集
	public const AUTH_RESDELETE		= 12; # レスあぼーん
	public const AUTH_RESEDIT		= 13; # レス編集
	public const AUTH_BBSEDIT		= 14; # 各種編集
	public const AUTH_LOGVIEW		= 15; # ログの閲覧・削除
	public const AUTH_MAXNUM		= 15;


	# REGEXP
	public const RE_SJIS	= '(?:[\x00-\x7f\xa1-\xdf]|[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])';


}
