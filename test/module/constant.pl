#============================================================================================================
#
#	定数モジュール(ZP)
#
#	by ぜろちゃんねるプラス
#	http://zerochplus.sourceforge.jp/
#
#============================================================================================================
package	ZP;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
#use warnings;
#use bigint;

# CLIENT
#  M: Mobile Browser, F: Full Browser
our $C_PC				= 0x00000001;
our $C_P2				= 0x00000002;
our $C_DOCOMO_M			= 0x00000004;
our $C_DOCOMO_F			= 0x00000008;
our $C_DOCOMO			= $C_DOCOMO_M | $C_DOCOMO_F;
our $C_AU_M				= 0x00000010;
our $C_AU_F				= 0x00000020;
our $C_AU				= $C_AU_M | $C_AU_F;
our $C_SOFTBANK_M		= 0x00000040;
our $C_SOFTBANK_F		= 0x00000080;
our $C_SOFTBANK			= $C_SOFTBANK_M | $C_SOFTBANK_F;
our $C_WILLCOM_M		= 0x00000100;
our $C_WILLCOM_F		= 0x00000200;
our $C_WILLCOM			= $C_WILLCOM_M | $C_WILLCOM_F;
our $C_EMOBILE_M		= 0x00000400;
our $C_EMOBILE_F		= 0x00000800;
our $C_EMOBILE			= $C_EMOBILE_M | $C_EMOBILE_F;
our $C_IBIS				= 0x00001000;
our $C_JIG				= 0x00002000;
our $C_OPERAMINI		= 0x00004000;
our $C_IPHONE_F			= 0x00008000;
our $C_IPHONEWIFI		= 0x00010000;
our $C_IPHONE			= $C_IPHONE_F | $C_IPHONEWIFI;
our $C_FBSERVICE		= $C_IBIS | $C_JIG | $C_OPERAMINI;
our $C_MOBILEBROWSER	= $C_DOCOMO_M | $C_AU_M | $C_SOFTBANK_M | $C_WILLCOM_M | $C_EMOBILE_M;
our $C_FULLBROWSER		= $C_DOCOMO_F | $C_AU_F | $C_SOFTBANK_F | $C_WILLCOM_F | $C_EMOBILE_F | $C_FBSERVICE;
our $C_MOBILE			= $C_MOBILEBROWSER | $C_FULLBROWSER;
our $C_MOBILE_IDGET		= $C_DOCOMO_M | $C_AU_M | $C_SOFTBANK_M | $C_EMOBILE_M | $C_P2;


# ERRORNUM
our $E_SUCCESS				= 0; # must FALSE
#  入力内容に関するエラー
our $E_FORM_LONGSUBJECT		= 100;
our $E_FORM_LONGNAME		= 101;
our $E_FORM_LONGMAIL		= 102;
our $E_FORM_LONGTEXT		= 103;
our $E_FORM_LONGLINE		= 104;
our $E_FORM_MANYLINE		= 105;
our $E_FORM_MANYANCHOR		= 106;
our $E_FORM_NOSUBJECT		= 150;
our $E_FORM_NOTEXT			= 151;
our $E_FORM_NONAME			= 152;
our $E_FORM_NOCAPTCHA		= 153;
#  制限に関するエラー
our $E_LIMIT_STOPPEDTHREAD	= 200;
our $E_LIMIT_OVERMAXRES		= 201;
our $E_LIMIT_MOVEDTHREAD	= 202;
our $E_LIMIT_READONLY		= 203;
our $E_LIMIT_MOBILETHREAD	= 204;
our $E_LIMIT_FORBIDDENCGI	= 205;
our $E_LIMIT_OVERDATSIZE	= 206;
our $E_LIMIT_THREADCAPONLY	= 504;
#  規制に関するエラー
our $E_REG_MANYTHREAD		= 500;
our $E_REG_NOBREAKPOST		= 501;
our $E_REG_DOUBLEPOST		= 502;
our $E_REG_NOTIMEPOST		= 503;
our $E_REG_SAMBA_CAUTION	= 505; # continuously
our $E_REG_SAMBA_WARNING	= 506; # 505+1
our $E_REG_SAMBA_LISTED		= 507; # 505+2
our $E_REG_SAMBA_STILL		= 508; # 505+3
our $E_REG_SAMBA_2CH1		= 593; # 2ch errnum
our $E_REG_SAMBA_2CH2		= 599; # 2ch errnum
our $E_REG_SAMBA_2CH3		= 594; # 2ch errnum
our $E_REG_NGWORD			= 600;
our $E_REG_NGUSER			= 601;
our $E_REG_NOTJPHOST		= 207;
our $E_REG_DNSBL			= 997;
#  BEに関するエラー
our $E_BE_GETFAILED			= 890;
our $E_BE_CONNECTFAILED		= 891;
our $E_BE_LOGINFAILED		= 892;
our $E_BE_MUSTLOGIN			= 893;
our $E_BE_MUSTLOGIN2		= 894;
#  リクエストエラー
our $E_THREAD_INVALIDKEY	= 900;
our $E_THREAD_WRONGLENGTH	= 901;
our $E_THREAD_NOTEXIST		= 902;
our $E_POST_NOPRODUCT		= 950;
our $E_POST_INVALIDREFERER	= 998;
our $E_POST_INVALIDFORM		= 999;
our $E_POST_NOTEXISTBBS		= $E_POST_INVALIDFORM;
our $E_POST_NOTEXISTDAT		= $E_POST_INVALIDFORM;
#  read.cgi用エラー
our $E_READ_R_INVALIDBBS	= 1001; # 2ch errnum
our $E_READ_R_INVALIDKEY	= 1002; # 2ch errnum
our $E_READ_FAILEDLOADDAT	= 1003; # 2ch errnum
our $E_READ_FAILEDLOADSET	= 1004; # 2ch errnum
our $E_READ_INVALIDBBS		= 2011; # 2ch errnum
our $E_READ_INVALIDKEY		= 3001; # 2ch errnum
#  システム・その他のエラー
our $E_SYSTEM_ERROR			= 990;
#  ページ表示用番号
our $E_PAGE_FINDTHREAD		= $E_READ_FAILEDLOADDAT;
our $E_PAGE_THREAD			= 9000;
our $E_PAGE_COOKIE			= 9001;
our $E_PAGE_WRITE			= 9002;
our $E_PAGE_THREADMOBILE	= 9003;


# CAP PERMISSION
our $CAP_FORM_LONGSUBJECT		=  1; # タイトル文字数 制限解除
our $CAP_FORM_LONGNAME			=  2; # 名前文字数 制限解除
our $CAP_FORM_LONGMAIL			=  3; # メール文字数 制限解除
our $CAP_FORM_LONGTEXT			=  4; # 本文文字数 制限解除
our $CAP_FORM_MANYLINE			=  5; # 本文行数 制限解除
our $CAP_FORM_LONGLINE			=  6; # 本文1行文字数 制限解除
our $CAP_FORM_NONAME			=  7; # 名無し 制限解除
our $CAP_REG_MANYTHREAD			=  8; # スレッド作成 規制解除
our $CAP_LIMIT_THREADCAPONLY	=  9; # スレッド作成可能
our $CAP_REG_NOBREAKPOST		= 10; # 連続投稿 規制解除
our $CAP_REG_DOUBLEPOST			= 11; # 二重書き込み 規制解除
our $CAP_REG_NOTIMEPOST			= 12; # 短時間投稿 規制解除
our $CAP_LIMIT_READONLY			= 13; # 読取専用 制限解除
our $CAP_DISP_NOID				= 14; # ID非表示
our $CAP_DISP_NOHOST			= 15; # 本文ホスト非表示
our $CAP_LIMIT_MOBILETHREAD		= 16; # 携帯からのスレッド作成 制限解除
our $CAP_DISP_HANLDLE			= 17; # コテハン★表示
our $CAP_REG_SAMBA				= 18; # Samba 規制解除
our $CAP_REG_DNSBL				= 19; # プロキシ 規制解除
our $CAP_REG_NOTJPHOST			= 20; # 海外ホスト 規制解除
our $CAP_REG_NGUSER				= 21; # ユーザー 規制解除
our $CAP_REG_NGWORD				= 22; # NGワード 規制解除
our $CAP_DISP_NOSLIP			= 23; # 端末識別子非表示
our $CAP_DISP_CUSTOMID			= 24; # 専用ID許可
our $CAP_MAXNUM					= 24;
# USER AUTHORITY
our $AUTH_SYSADMIN		=  0; # システム管理権限(形式的に)
our $AUTH_USERGROUP		=  1; # 管理グループ設定
our $AUTH_CAPGROUP		=  2; # キャップグループ設定
our $AUTH_THREADSTOP	=  3; # スレッド停止・再開
our $AUTH_THREADPOOL	=  4; # スレッドdat落ち・復活
our $AUTH_TREADDELETE	=  5; # スレッド削除
our $AUTH_THREADINFO	=  6; # スレッド情報更新
our $AUTH_KAKOCREATE	=  7; # 過去ログ生成
our $AUTH_KAKODELETE	=  8; # 過去ログ削除
our $AUTH_BBSSETTING	=  9; # 掲示板設定
our $AUTH_NGWORDS		= 10; # NGワード編集
our $AUTH_ACCESUSER		= 11; # アクセス制限編集
our $AUTH_RESDELETE		= 12; # レスあぼーん
our $AUTH_RESEDIT		= 13; # レス編集
our $AUTH_BBSEDIT		= 14; # 各種編集
our $AUTH_LOGVIEW		= 15; # ログの閲覧・削除
our $AUTH_MAXNUM		= 15;


# REGEXP
our $RE_SJIS	= '(?:[\x00-\x7f\xa1-\xdf]|[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])';


#============================================================================================================
#	モジュール終端
#============================================================================================================
1;
