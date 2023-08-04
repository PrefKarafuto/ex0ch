;##############################################################
;#      ニュース速報(VIP)＠2ch掲示板                          #
;# ■　VIP に伝説の機能をつけよう。。。 ＆                    #
;# ■新機能のまとめ  ＆                                       #
;# ■万博の実行委員会に電話してネトラジで放映■  発           #
;#                                                            #
;# perl Library N速VIP的新機能「VIP クオリティ」              #
;#    v1.1 EXPO2005 EDIT (05/04/05)【VIP クオリティ】         #
;# By ◆EXPwYoDqN2 (2ch-tgu-log@104.net)                      #
;# http://tgu-log.hp.infoseek.co.jp/vip_quality.html          #
;# http://vipper.nullpo.org                                   #
;#                                                            #
;# Special Thanks to ニュース速報(VIP)＠2ch掲示板             #
;# 「■　VIP に伝説の機能をつけよう。。。３１」>>777氏        #
;# (http://ex7.2ch.net/test/read.cgi/news4vip/1094732051/777) #
;# ＆ FOX ★（http://ex7.2ch.net/news4vip/）                  #
;# ＆ 開発菌 ★（http://yy10.kakiko.com/beta/）               #
;# ＆ 開発豚猪 ★（http://yy10.kakiko.com/beta/）             #
;# ＆ Level3-BBS Script（http://www.3lab.org/）               #
;# ＆ 0ch BBS Script（http://tolkien.s7.xrea.com/）           #
;# ＆ EXPO 2005 AICHI,JAPAN（http://www.expo2005.or.jp/）     #
;# ＆ De La Fantasia（http://www.delafantasia.jp/）           #
;# ＆ 2ch BBS（http://www.2ch.net/）                          #
;##############################################################
use CGI::Carp qw(fatalsToBrowser);
use strict;
package Vip_quality;

;#--------------------------------------------------------------------------------------------------------------------#;

sub vip_quality{
my %form = ();
$form{'from'} = $_[0];
$form{'mail'} = $_[1];
$form{'date'} = $_[2];
$form{'text'} = $_[3];
$form{'version'} = $_[4];
$form{'bbs_name'} = $_[5];
$form{'key'} = $_[6];
#$form{'no_name'} = $_[7];
my %setting = ();
;#
;# [注意]
;# このライブラリはフリーソフトです。このライブラリを使用したことによって
;# 生じた損害に対して作者は一切の責任を負いません。
;# 転んでも泣かない。。。(￣ー￣)ﾆﾔﾘｯ 
;# なお、転載改造は全くもって自由です。
;#
;#［1 Level3-BBS Scriptで使用する場合］
;# このライブラリはbbs.cgiと同じディレクトリに置いて下さい。
;# 実際にこのライブラリを使うにはbbs.cgiにライブラリの呼び出し文と
;# サブルーチンの呼び出し文を追加する必要があります。
;#
;#【ライブラリの呼び出し文の追加】
;# bbs.cgiの"use strict;"の行（8行目辺り）の直前に
;#
;# require './Vip_quality.pl';#「VIP クオリティ」モジュールの読み込み
;#
;# という1行を追加して下さい。
;#
;#【サブルーチンの呼び出し文の追加】
;#
;# bbs.cgiのsuball.txtをこーしんブロックの
;# "$THREAD{'BBS'} = $FORM{'bbs'};"の行（421行目辺り）の直後に
;#
;# #「VIP クオリティ」名無し制御サブルーチンの実行
;# $FORM{'FROM'} = Vip_quality::vip_quality_new_treed($FORM{'FROM'},$FORM{'bbs'},$FORM{'key'});
;#
;# という文を、またIDの表示ブロックとHOSTの表示
;#（両方とも書き込み処理セクションにあります）の間（503行目辺り）に
;#
;# #「VIP クオリティ」サブルーチンの実行
;#  my (@vip);
;# ($FORM{'FROM'},$FORM{'mail'},$DATE,$FORM{'MESSAGE'}) = Vip_quality::vip_quality($FORM{'FROM'},$FORM{'mail'},$DATE,$FORM{'MESSAGE'},$version,$FORM{'bbs'},$FORM{'key'});
;#
;# という文を追加して下さい。
;#
;#
;#［2 0ch BBS Script（test041030.zip）で使用する場合］
;# このライブラリはmoduleディレクトリ（varda.plと同じディレクトリ）に置いて下さい。
;# 実際にこのライブラリを使うにはvarda.plにライブラリの呼び出し文と
;# サブルーチンの呼び出し文を追加する必要があります。
;#
;#【ライブラリの呼び出し文の追加】
;# varda.plの"require('./module/denethor.pl');';"の行（20行目辺り）の次に
;#
;# require('./module/Vip_quality.pl');#「VIP クオリティ」モジュールの読み込み
;#
;# という1行を追加して下さい。
;#
;#【サブルーチンの呼び出し文の追加】
;# varda.plの書き込み処理 - WriteData
;# "$work = "$name<>$mail<>$date<>$text<>$subj\n";"の行（451行目辺り）の直前に
;# 
;# #「VIP クオリティ」名無し制御サブルーチンの実行
;# if ($M->Get('MODE') == 2){
;# 	$S->Set('FROM',Vip_quality::vip_quality_new_treed($S->Get('FROM'),$M->Get('BBS'),$M->Get('KEY')));
;# }
;# #「VIP クオリティ」サブルーチンの実行
;# my (@vip);
;# ($name,$mail,$date,$text) = Vip_quality::vip_quality($name,$mail,$date,$text,$M->Get('VERSION'),$M->Get('BBS'),$M->Get('KEY'));
;#
;# という文を追加して下さい。
;#
;#
;#［3 0ch BBS Script（test050403.zip）で使用する場合］
;# このライブラリはmoduleディレクトリ（vara.plと同じディレクトリ）に置いて下さい。
;# [★簡単モード　～機能拡張プラグインとして使用する～]
;# コネクタモジュールである0ch_vip_quality.plと0ch_vip_quality_new_treed.plを
;# test/pluginディレクトリに置いて、管理画面から有効にすることによって
;# 殆どの機能を簡単に使えるように設定することが出来ます。
;# 
;# （0ch_vip_quality.plの拡張機能名称には「それがVIPクオリティ（名無し制御）」、拡張機能説明には「VIPクオリティ機能
;# （名無し制御）;# 使える機能の詳細はVip_quality.plを参照。」と、拡張機能名称には「それがVIPクオリティ」、
;# 拡張機能説明には「VIPクオリティ機能使える機能の詳細はVip_quality.plを参照。」とそれぞれ表示されます）
;# 
;# 但し、簡単モードの場合は機能拡張プラグインシステムの制約により、
;# !noidと!year・!mon・!day・!hour・!min・!secと!omikuji（機能2）と!damaは使えません。
;#
;# [★拡張モード　～モジュールを直接書き換える～]
;# 実際にこのライブラリの"全て"の機能を使うにはvara.plにライブラリの呼び出し文と
;# サブルーチンの呼び出し文を追加する必要があります。
;#
;#【ライブラリの呼び出し文の追加】
;# vara.plの"package	VARA;"の行（9行目辺り）の次に
;#
;# require('./module/Vip_quality.pl');#「VIP クオリティ」モジュールの読み込み
;#
;# という1行を追加して下さい。
;#
;#【サブルーチンの呼び出し文の追加】
;# vara.plの書き込み処理 - WriteData
;# "$data		= "$elem[1]<>$elem[2]<>$date<>$elem[3]<>$elem[0]\n";"の行（136行目辺り）の直前に
;# 
;# #「VIP クオリティ」名無し制御サブルーチンの実行 
;# if ($oSys->Equal('MODE',1)){ 
;# 	$elem[1] = Vip_quality::vip_quality_new_treed($elem[1],$oSys->Get('BBS'),$oSys->Get('KEY')); 
;# } 
;# #「VIP クオリティ」サブルーチンの実行 
;# my (@vip); 
;# ($elem[1],$elem[2],$date,$elem[3]) = Vip_quality::vip_quality($elem[1],$elem[2],$date,$elem[3],$oSys->Get('VERSION'),$oSys->Get('BBS'),$oSys->Get('KEY')); 
;#
;# という文を追加して下さい。
;# 拡張モードの場合は!noidと!year・!mon・!day・!hour・!min・!secと!omikuji（機能2）と!damaも使えるようになります。
;#
;#
;# あとはVip_quality.plの基本設定を行えばVIP クオリティが楽しめるようになります。
;# なお、このモジュールに関してのパーミッション設定は不要（644でOK）です。
;#
;#
;# ▼サブルーチン仕様
;# Vip_quality::vip_quality(投稿者名,メール欄,日付,本文,bbs.cgiのバージョン,bbs名,スレッドキー,（将来は板のデフォルト名無しを追加予定）);
;# 	サブルーチンに渡された投稿内容に対して、ニュース速報(VIP)＠2ch掲示板の
;# 	伝説の機能1～3の多くの機能をを適用し（ships.cgiファイルの保存あり）、その処理結果を返す。
;# 戻り値：投稿者名,本文,日付,メール欄
;#
;# Vip_quality::vip_quality_new_treed(投稿者名,bbs名,スレッドキー);
;# 	サブルーチンに渡された投稿者名内容の中から、ニュース速報(VIP)＠2ch掲示板の
;# 	伝説の機能1の名無し制御に関する部分を抜き取って第2スレッド情報ファイル（スレッドキー.pl）に保存し、
;# 	残りの部分を返す。
;# 戻り値：投稿者名
;#
;# ※基本的には他の2ch型掲示板でも値をちゃんと渡して受け取れるように設定すれば使えるはずです。
;#
;# v1.0よりlite版の開発を終了しました。
;# lite版っぽく使いたい人は引数および戻り値の本文の部分を適当な変数（$null等）に変えて使用して下さい。
;#
;#
;# ▼ディレクトリ構成
;# 掲示板ルートディレクトリ
;#        |
;#        +--掲示板ディレクトリ（各板のindex.html等があるディレクトリ）/ ships.cgi（自動生成）
;#        |           |
;#        |           +--dat（datデータ等が置かれます）/ 1000000000.pl等の第2スレッド情報ファイル（自動生成／不定期的に削除して下さい）
;#        |
;#        +--bbs.cgiのあるディレクトリ（大抵の場合はtest）/ Vip_quality.pl（Level3-BBSで使用する場合）←注目！
;#                  |
;#                  +--setting（Level3-BBS Scriptの場合は管理スクリプト等で使用する設定ファイルがここに置かれます）/
;#                  |     |
;#                  |   　+--vip_quality/ base.cgi, body.cgi, do.cgi, 3do.cgi, etc.cgi, expo.cgi, food.cgi, kakari.cgi, kote.cgi, mibun.cgi, omikuji.cgi, poke.cgi, sute.cgi, where.cgi, 3where.cgi, who.cgi
;#                  |                   （足りないファイルおよびanime.cgi, user1.cgi, user2.cgi, user3.cgiは利用者側で用意）
;#                  |
;#                  +--module（varda.plのあるディレクトリ）/ Vip_quality.pl（0ch BBSで使用する場合）←注目！
;#                  |
;#                  +--plugin（0ch BBS 機能拡張プラグイン置き場）/ 0ch_vip_quality.pl, 0ch_vip_quality_new_treed.pl（0ch BBS人柱版使用時に簡単モードで設置する場合のみ）
;#
;#
;# ▼機能詳細
;# 	▽伝説の機能1
;# 	▼スレ立て時の設定 !774!3（第２スレッド情報ファイル（1000000000.plなど）を使用）
;# 	!774!force!normal!3 だとそのスレは全ての機能無効（$setting{'valid'}を"v00000"にしちゃいます）
;# 	!noid そのスレッドはIDなし（!forceと併用しないと使えない。）（拡張モードのみ）
;# 	!sage そのスレッドは強制sage（!forceと併用しないと使えない。）
;# 	!force 名前欄は何か入れても、********* で上書き
;# 	（!774!noid!force********!3 でそのスレはID無しで名無しが強制的に********になる。）
;# 	▼コードは全て名前欄に記入すること－
;# 	@RRGGBB@　色替え（RR,GG,BBのところにカラーコードを16進で入力。名前欄の先頭に記入すること。）
;# 	!omikuji　おみくじ 【神】の上に【女神】がある。ただしめったにでない
;# 	!ver　bbs.cgi／bbs.plのバージョン情報
;# 	!tt　本文文字が<tt>タグで囲まれる（多くの場合小さくなる）
;# 	!pre　本文文字が<pre>タグで囲まれる（等幅フォントになるためＡＡのずれに注意）
;# 	▼以下のコードは本文でも反映する。
;# 	!power　数字が出る0～999（４桁もあり）
;# 	!hungry　食事がランダムで表示される
;# 	!food　食事がランダムで表示される
;# 	!who　人物（動物等も）がランダムで表示される
;# 	!where　場所がランダムに表示される
;# 	!do　動詞(行動)がランダムで表示される
;# 	!num　１桁の数字が斜体で出る
;# 	!sign　符号が出る（+か-がランダムで）
;# 	!money　ランダムな通貨単位
;# 	!year・!mon・!day・!hour・!min・!sec　年・月・日・時・分・秒（拡張モードのみ）
;# 	!when・!whena・!whenb　今とかがランダムで
;# 	!body　体の一部分 
;# 	!base　打席の結果がランダムで表示される（独自拡張あり）
;# 	!calc　＋－×÷＝のうちのいずれかがランダムに出る
;#
;# 	▽伝説の機能2
;# 	▼コードは全て名前欄に記入すること－
;# 	!omikuji　おみくじ 【神】の上に【女神】がある。ただしめったにでない
;# 	!dama　お年玉　たまにたくさんもらえることも
;#
;# 	▽伝説の機能3
;# 	◆名前で有効 
;# 	◎IPで毎回固定
;# 	!IQ　　　　IQ
;# 	!kote　　コテ
;# 	◎毎回変更
;# 	!kakari　係り
;# 	!sute　　コテ
;# 	◆どちらでも有効
;# 	!mibun 　身分
;# 	!anime　アニメキャラ
;# 	◆レス欄で有効
;# 	!card　トランプ
;# 	!do　 動作（伝説の機能1との衝突を避けるため実際は!3doでの動作になります））
;# 	!mibun 　身分
;# 	!where 　場所（伝説の機能1との衝突を避けるため実際は!3whereでの動作になります）
;# 	◆船ゲーム（レス欄で有効）
;# 	!create Yamato 　船を作る、Yamatoは自分の船の名前、IQが低いと作れない
;# 	!attack Yamato 攻撃、Yamatoは攻撃先の船に直す
;# 	!list　　　　　　　　　船一覧
;#
;# 	▽伝説の機能独自版
;# 	▼コードは全て名前欄に記入すること－
;# 	tasukeruyo 運用情報板の機能 fusianasan＋HTTP_USER_AGENT＋SERVER_PROTOCOL
;# 	▼以下のコードは本文でも反映する。
;# 	!expo　愛知万博のパビリオンや飲食店などがランダムで表示される ささしまサテライトも収録
;# 	!yakyu　三振とかバントホームランとか
;# 	!poke　ポケモンの種族名（ｗ がランダムで表示される
;# 	!whenc　日時とかがランダム表示される
;# 	!etc　「オレ、第③京浜 60km  外環 某入口 50km じゃ」の改変コピペを表示
;# 	!user1　ユーザー独自設定内容を表示その1
;# 	!user2　ユーザー独自設定内容を表示その2
;# 	!user3　ユーザー独自設定内容を表示その3
;# 
;# !money、!sign、!calc、!num、!base、!whena、!whenb、!when、!who、!body、!hungry、!food、!do、!where、!power、!year、!mon、!day、!hour、!min、!sec、!mibun、!where、!card、!do、!anime、!expo、!yakyu、!poke、!whenc、!etc、!user1、!user2、!user3は複数回使用可能
;# 複数回使用可能なコードおよび船ゲームなどのファイルを扱い負荷のかかる機能は、基本設定で設定した回数券発行枚数まで使用可能。
;#
;#
;# ▼コードの優先順位（というか処理順序）
;# 伝説の機能1（名無し制御） ＞ 伝説の機能1（それ以外） ＞ 伝説の機能2 ＞ 伝説の機能3 ＞ 伝説の機能独自版
;# 伝説の機能1（名無し制御）内の設定
;# !774!normal!3 ＞ !774!force!noid!3 ＞ !774!force!sage!3 ＞ !774!forcename!3
;# 
;# 伝説の機能1（それ以外）内の設定
;# @******@ ＝ !omikuji ＝ !ver ＝ !tt ＝ !pre
;# ＞ !money ＞ !sign ＞ !calc ＞ !num ＞ !base ＞ !yakyu＞ !whena
;# ＞ !whenb ＞ !when ＞ !who ＞ !body ＞ !hungry ＝ !food ＞ !do
;# ＞ !where ＞ !power＞ !year ＞ !mon ＞ !day ＞ !hour ＞ !min ＞ !sec
;#
;# 伝説の機能2内の設定
;# !omikuji ＝ !dama
;#
;# 伝説の機能3内の設定
;# !IQ ＞ !kote ＞ !kakari ＞ !sute
;# !mibun ＞ !where ＞ !card ＞ !do ＞ !anime ＞ !create Yamato ＝ !list ＞ !attack Yamato
;#
;# 伝説の機能独自版内の設定
;# tasukeruyo ＞ !expo ＞ !yakyu ＞ !poke ＞ !whenc ＞ !etc ＞ !user1 ＞ !user2 ＞ !user3
;#
;# 1回しか使えない機能は優先順位高く（船ゲームを除く）、複数回使える機能は順位が低い。
;# @******@、!omikuji、!ver、!tt、!pre、!omikuji、!dama、!IQ、!kote、!kakari、!sute、tasukeruyoは
;# 1回しか使えないが、使用した機能の個数に含まれない（船ゲームを除く）。
;# ※本文入力可能なコードをコピペ可能なテンプレとして表示させるには。
;# 先頭に
;# !money!money!money!money!money!money!money!money!money!money!money!money!money!money!money!money!money!money
;# と（回数券発行枚数より多くの）コードを打ってからテンプレを貼ると優先順位の関係で、きちんと表示される。

;######################
;#  基本設定ここから  #
;######################

;#共通設定
;# 特殊機能専用回数券発行枚数（複数回使える機能を使える回数）
;# 負荷を考えると16以上大きくしない方が無難かも
$setting{'vip_tickets'} = 16;

;# 有効にする機能群の設定
;# 現在、機能は5つに分類されていますので5桁の数字の各桁を変えることによって設定します。
;# 有効にしない場合→0
;# 有効にする場合→1
;# ［左から1桁目]機能0 2004年の9月および10月ごろVIPに存在した実験スクリプトの一部のうち名無し制御に関する部分です。
;# ［左から2桁目]機能1 2004年の9月および10月ごろVIPに存在した実験スクリプトの一部です。
;# ［左から3桁目]機能2 2005年1月1日に限り2ch全板で存在した実験スクリプトです。
;# ［左から4桁目]機能3 2005年1月21日、平日の朝っぱらからVIPで実験が始まったスクリプトです。
;# ［左から5桁目]機能独自版 機能1を参考に、こんな機能が欲しいと思ったものを勝手に付け加えたスクリプトです。
;# それぞれの詳細は上の方の説明をお読み下さい。
;# 例 全部を有効にする場合　$setting{'valid'} = "v11111";
$setting{'valid'} = "v11111";

;# 表示項目ファイルのパスを設定
$setting{'$file_path'} = './setting/vip_quality/';
;# 0ch BBS Script（test041030.zipとtest050403.zip）で使用する場合は↑をコメントアウトし、↓をコメント解除
#$setting{'$file_path'} = './module/setting/vip_quality/';

;# 掲示板設置ルートディレクトリ（大抵はtestディレクトリがあるディレクトリ）を設定
$setting{'$bbs_path'} = '../';

;# IPアドレス取得
my @host;
($host[0],$host[1],$host[2],$host[3]) = split(/\./,$ENV{'REMOTE_ADDR'});

;#--------------------------------------------------------#;
;#伝説の機能1の設定
;# !omikujiコード表示項目のファイル名を設定
$setting{'file_omikuji'} = 'omikuji.cgi';

;# !moneyコード表示項目の設定
my @money = ('￥','＄','￠','￡','㌦','円',"&euro;");

;# !signコード表示項目の設定
my @sign = ('+','-');

;# !calcコード表示項目の設定
my @calc = ('＋','－','×','÷','＝');

;# !numコードで表示する数の上限を設定
$setting{'num'} = 9;

;# !baseコード表示項目ファイルリストのファイル名を設定（このファイル内に!baseコード表示項目ファイル名と確率を指定）
;#（ファイルの書式は"ファイル名 確率（‰）" 確率（‰）の合計は1000にすること）
$setting{'file_base'} = 'base.cgi';

;# !when（!whena、!whenb）コード表示項目のファイル名を設定
$setting{'file_when'} = 'when.cgi';

;# !whoコード表示項目のファイル名を設定
$setting{'file_who'} = 'who.cgi';

;# !bodyコードの表示項目のファイル名を設定
$setting{'file_body'} = 'body.cgi';

;# !hungry／!foodコード表示項目のファイル名を設定
$setting{'file_food'} = 'food.cgi';

;# !doコードの表示項目のファイル名を設定
$setting{'file_do'} = 'do.cgi';

;# !whereコード表示項目のファイル名を設定
$setting{'file_where'} = 'where.cgi';

;# !powerで表示する数の上限を設定
$setting{'power_set'} = 1024;

;# 使用しているBBS Scriptが秒数表示（生成）に対応しているか
;# ※秒数表示対応化改造に関しては当ライブラリ配布ページの
;# 「それはbbs.cgiやmoduleディレクトリにあるライブラリを直接いじるべきではないか？」の「秒数表示」部分を参照
;# 対応している→0
;# 対応していない→1
$setting{'$sec_ok'} = 0;

;#--------------------------------------------------------#;
;#伝説の機能2の設定
;# !omikujiコード表示項目のファイル名設定は伝説の機能1の設定で行います
;# 伝説の機能2のおみくじができる日を1日だけ指定（0で毎日できます） ※伝説の機能1のおみくじは毎日でき、そちらが優先されます
$setting{'omikuji_day'} = 0;

;# お年玉がもらえる月を1月だけ指定（もらえる日は伝説の機能2のおみくじができる日と同じです／0で毎月もらえます）
$setting{'dama_mon'} = 0;

;# お年玉のあげる金額を設定（largeの方を多く、littleの方を少なく）
my %dama = ();
$dama{'very_very_large'} = 200000;
$dama{'very_large'} = 100000;
$dama{'large'} = 20000;
$dama{'normal'} = 10000;
$dama{'little'} = 5000;
$dama{'very_little'} = 2000;
$dama{'poor'} = 1000;

;#--------------------------------------------------------#;
;#伝説の機能3の設定
;# !koteコード表示項目のファイル名を設定
$setting{'file_kote'} = 'kote.cgi';

;# !kakariコード表示項目のファイル名を設定
$setting{'file_kakari'} = 'kakari.cgi';

;# !suteコード表示項目のファイル名を設定
$setting{'file_sute'} = 'sute.cgi';

;# !cardコード表示項目の設定
my @card = ("&spades;","&clubs;","&hearts;","&diams;");

;# !mibunコード表示項目のファイル名を設定
$setting{'file_mibun'} = 'mibun.cgi';

;# !whereコード表示項目のファイル名を設定
$setting{'file_3where'} = '3where.cgi';

;# !doコードの表示項目のファイル名を設定
$setting{'file_3do'} = '3do.cgi';

;# !animeコードの表示項目のファイル名を設定
$setting{'file_anime'} = 'anime.cgi';

;# shipsファイルのファイル名を設定
;# ※各datディレクトリの直上に置かれますので、bbsで使用するファイル名（特にpassword.cgi）にはしないこと
$setting{'file_ships'} = 'ships.cgi';

;# 船を建造することのできる最小のIQを設定
$setting{'ships_iq_limit'} = 140;

;# 船名の長さを設定
$setting{'ships_name'} = 16;

;# 建造できる船の数を設定
$setting{'port_capacity'} = 5;

;# 船の初期HP固定値をランク別に設定
my @ships_hp = ();
$ships_hp[0] =  5000; #poor
$ships_hp[1] = 10000; #very_little
$ships_hp[2] = 15000; #little
$ships_hp[3] = 20000; #short_little
$ships_hp[4] = 25000; #futsu
$ships_hp[5] = 30000; #normal
$ships_hp[6] = 35000; #short_large
$ships_hp[7] = 40000; #large
$ships_hp[8] = 45000; #very_large
$ships_hp[9] = 50000; #very_very_large

;# 船の初期HPをランダムにするかどうか
;# しない→0
;# する→1
$setting{'ships_hp_rand_flag'} = 1;

;# 船の初期HPをランダムにする場合の振れ幅を設定
$setting{'ships_hp_rand'} = 3000;

;# 与えられるダメージ量の最大固定値をランク別に設定
my @dame = ();
$dame[0] =    0; #normal
$dame[1] =   50; #short_large
$dame[2] =  500; #large
$dame[3] = 5000; #very_large

;# 与えられるダメージ量をランダムにするかどうか
;# しない→0
;# する→1
$setting{'ships_dame_rand_flag'} = 1;

;# 与えられるダメージ量をランダムにする場合の振れ幅を設定
$setting{'ships_dame_rand'} = 300;
0
;# クリティカルヒット時に与えるダメージの倍率を設定
$setting{'critical_hit'} = 2;

;#--------------------------------------------------------#;
;#伝説の機能独自版の設定
;# !expoコード表示項目のファイル名を設定
$setting{'file_expo'} = 'expo.cgi';

;# !yakyuコード表示項目ファイルのパスを設定
$setting{'file_yakyu'} = 'yakyu.cgi';

;# !pokeコード表示項目のファイル名を設定
$setting{'file_poke'} = 'poke.cgi';

;# !whencコードで"$whenc_time世紀前"～"$whenc_time世紀後"が出た時に表示する数の上限を設定
my $whenc_set = 60;

;# ※ここは触らないこと。
my $whenc_time = int(rand $whenc_set);

;# !whencコード表示項目の設定
my @whenc = ("$whenc_time世紀前","$whenc_time年前","$whenc_time月前","$whenc_time週間前","$whenc_time日前","$whenc_time時間前","$whenc_time秒前","$whenc_time秒後","$whenc_time分後","$whenc_time時間後","$whenc_time日後","$whenc_time週間後","$whenc_time月後","$whenc_time年後","$whenc_time世紀後");

;# !etcコードの表示項目のファイル名を設定
$setting{'file_etc'} = 'etc.cgi';

;# ETCレーンで出せる最高速度を指定
;#（レーン進入時で時速20Km以下が目安・・・でも、オレ、第③京浜 60km 外環 某入口 50km じゃ by 最速伝説■ETC通過速度■チャレンジ 3ゲート目（http://hobby7.2ch.net/test/read.cgi/car/1103428131/））
$setting{'etc_speed'} = 80;

;# !user1コード表示項目のファイル名を設定（ファイルは利用者側で用意して下さい）
$setting{'file_user1'} = 'user1.cgi';

;# !user1コードのコード名を指定
$setting{'user1_com'} = '!user1';

;# !user2コード表示項目のファイル名を設定（ファイルは利用者側で用意して下さい）
$setting{'file_user2'} = 'user2.cgi';

;# !user2コードのコード名を指定
$setting{'user2_com'} = '!user2';

;# !user3コード表示項目のファイル名を設定（ファイルは利用者側で用意して下さい）
$setting{'file_user3'} = 'user3.cgi';

;# !user3コードのコード名を指定
$setting{'user3_com'} = '!user3';

;# ※ここは触らないこと。
$setting{'$host'} = \@host;
$setting{'list_money'} = \@money;
$setting{'list_sign'} = \@sign;
$setting{'list_calc'} = \@calc;
$setting{'list_dama'} = \%dama;
$setting{'ships_hp'} = \@ships_hp;
$setting{'dame'} = \@dame;
$setting{'list_card'} = \@card;
$setting{'list_whenc'} = \@whenc

;######################
;#  基本設定ここまで  # ※この先483行目にも設定部分があります
;######################

;######################
;#    実行ここから    #
;######################
	if(scalar(substr($setting{'valid'},1,1)) == 1){
		($form{'from'},$form{'mail'},$form{'date'},$form{'text'},$setting{'valid'}) = &vip0_20040905(\%form,\%setting);
	}
	if(scalar(substr($setting{'valid'},2,1)) == 1){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip1_20040905(\%form,\%setting);
	}
	if(scalar(substr($setting{'valid'},3,1)) == 1){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip2_20050101(\%form,\%setting);
	}
	if(scalar(substr($setting{'valid'},4,1)) == 1){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip3_20050121(\%form,\%setting);
	}
	if(scalar(substr($setting{'valid'},-1,1)) == 1){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_orig(\%form,\%setting);
	}

# ここは2005年のエイプリルフールで色々やっていた時のごみですｗ
#my $year0 = 2002;
#my $year1 = scalar(substr($form{'date'},0,4));
#my $year2 = scalar(substr($form{'date'},4));
#my $year3 = "ぬるぽ暦";
#my $year4 = $year1 - 2001;
#日付変更
#$form{'date'} = sprintf("%s%02d%s",$year3,$year4,$year2);

	#返り値
	return($form{'from'},$form{'mail'},$form{'date'},$form{'text'});
;######################
;#  実行ここまで（ｗ  #
;######################
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能1―名無し制御に関する部分（スレ立て時）
sub vip_quality_new_treed{
	my %form = ();
	$form{'from'} = $_[0];
	$form{'bbs_name'} = $_[1];
	$form{'key'} = $_[2];

	my %setting = ();
### 設定ここから ##
;# 掲示板設置ルートディレクトリ（大抵はtestディレクトリがあるディレクトリ）を設定
	$setting{'$bbs_path'} = '../';
### 設定ここまで ##

	my %file_set = ();
	$form{'from'} =~ s/(\t)/\s/;
	if($form{'from'} =~ /(\!774.+\!3)/){
		my ($name_set);
		$name_set = $3;

;#!normal VIPクオリティ強制解除機能
		if($form{'from'} =~ /(\!normal)/){
			$file_set{'normal'} = "normal";
			$form{'from'} =~ s/(\!normal)//;
		}
		else{
			$file_set{'normal'} = "vip";
		}

;#!force その他の強制機能の保存
		if($form{'from'} =~ /(\!force)/){
			$file_set{'force'} = "force";
			$form{'from'} =~ s/(\!force)//;
		}
		else{
			$file_set{'force'} = "null";
		}

;#!force!noid 強制ID無し機能の保存
		if($form{'from'} =~ /(\!noid)/){
			$file_set{'noid'} = "noid";
			$form{'from'} =~ s/(\!noid)//;
		}
		else{
			$file_set{'noid'} = "null";
		}

;#!force!sage 強制sage機能の保存
		if($form{'from'} =~ /(\!sage)/){
			$file_set{'sage'} = "sage";
			$form{'from'} =~ s/(\!sage)//;
		}
		else{
			$file_set{'sage'} = "null";
		}

;#!force name 強制名無しさん機能の保存
		$form{'from'} =~ /(\!774.*\!3)/;
		$file_set{'name'} = $1;
		$file_set{'name'} =~ s/(\!)//g;
		$form{'from'} =~ s/(\!774.*\!3)//;

		open (SET,">>"."$setting{'$bbs_path'}$form{'bbs_name'}/dat/$form{'key'}.pl") or return($form{'from'});
		eval{flock(SET,2);};
		print SET "$file_set{'normal'}\t$file_set{'force'}\t$file_set{'noid'}\t$file_set{'sage'}\t$file_set{'name'}\n";
		close(SET);
	}
	return($form{'from'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能1―名無し制御に関する部分（レス時）
sub vip0_20040905{
	my ($form,$setting) = @_;
	my %form;
	my %setting;
	%form = %$form;
	%setting = %$setting;

	my %name_setting = ();
	my ($in_file,$noid_days,$noid_hours);
	open(SET,"$setting{'$bbs_path'}$form{'bbs_name'}/dat/$form{'key'}.pl") or return($form{'from'},$form{'mail'},$form{'date'},$form{'text'},$setting{'valid'});
	$in_file = <SET>;
	$in_file =~ s/\n//g;
	($name_setting{'normal'},$name_setting{'force'},$name_setting{'noid'},$name_setting{'sage'},$name_setting{'name'}) = split(/\t/,$in_file);
	close(SET);

;#!normal VIPクオリティ強制解除機能の判定
	unless($name_setting{'normal'} =~ /(normal)/){

;#!force その他の強制機能の判定
		if ($name_setting{'force'} =~ /(force)/){

;#!noid 強制ID無し機能
			if ($name_setting{'noid'} =~ /(noid)/){
				($noid_days,$noid_hours,$form{'null'}) = split(/\s/,$form{'date'});
				$form{'date'} = "$noid_days $noid_hours";
			}

;#!sage 強制sage機能
			if ($name_setting{'sage'} =~ /(sage)/){
				$form{'mail'} = "sage $form{'mail'}";
			}

;#!force name 強制名無しさん機能
			unless($name_setting{'name'} =~ 7743){
				$name_setting{'name'} =~ s/(774)(.+)(3)/$2/;
				$form{'from'} = $name_setting{'name'};
				$form{'from'} =~ s/fusianasan/<\/b>$ENV{'REMOTE_HOST'}<b>/
			}
		}
	}
	else{

;#!normal VIPクオリティ強制解除機能の処理
		$setting{'valid'} = "v00000";
	}

#返り値
return($form{'from'},$form{'mail'},$form{'date'},$form{'text'},$setting{'valid'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能1―それ以外
sub vip1_20040905{
	my ($form,$setting) = @_;
	my %form;
	my %setting;
	%form = %$form;
	%setting = %$setting;

;#@RRGGBB@　色替え（RR,GG,BBのところにカラーコードを16進で入力。アルファベットは大文字小文字どっちでもおk。）[名前欄のみ対応]
	if($form{'from'} =~ /(@[0-9A-F]{6}@)/i){
		my ($color,$color_temp);
		$color = $1;
		$form{'from'} =~ s/($1)//i;
		$color =~ s/\@//g;
		$form{'from'} = "<font color=\"\#$color\">$form{'from'}<\/font>";
	}

;#!omikuji　おみくじ 【神】の上に【女神】がある。ただしめったにでない[名前欄のみ対応]
	if($form{'from'} =~ /(\!omikujing)/){
		my (@omikuji,$rand_out,$omikuji_out);
		open(FILE,"$setting{'$file_path'}$setting{'file_omikuji'}") or @omikuji = ('omikujiファイルが開けなかったぽ。。');
		unless($omikuji[0] =~ /(omikujiファイルが開けなかったぽ。。)/){
			while (<FILE>){
				$_ =~ s/\n//g;
				@omikuji = (@omikuji, $_);
			}
		}
		close(FILE);
		$rand_out = int(rand(scalar @omikuji));
		$omikuji_out = $omikuji[$rand_out];
		if(rand(6400) < 1){
			$omikuji_out = "NullPointerException";
		}
		elsif(rand(3200) < 1){
			$omikuji_out = "ぬるぽ";
		}
		elsif(rand(1600) < 1){
			$omikuji_out = "女神";
		}
		elsif(rand(800) < 1){
			$omikuji_out = "神";
		}
		$form{'from'} =~ s/(\!omikuji)/ <\/b>【$omikuji_out】<b> /;
	}

;#!ver　bbs.cgiのバージョン情報（トリップ併用可）[名前欄のみ対応]
	if($form{'from'} =~ /(\!ver)/){
		$form{'from'} =~ s/(\!ver)/ <\/b>$form{'version'}<b>/;
	}

;#!tt　本文文字が<tt>タグで囲まれる（多くの場合小さくなる）[名前欄入力で本文のみ対応]
	if($form{'from'} =~ /(\!tt)/){
		$form{'from'} =~ s/(\!tt)//g;
		$form{'text'} = "<tt>$form{'text'}<\/tt>";
	}

;#!pre　本文文字が<pre>タグで囲まれる（等幅フォントになるためＡＡのずれに注意）[名前欄入力で本文のみ対応]
	if($form{'from'} =~ /(\!pre)/){
		$form{'from'} =~ s/(\!pre)//g;
		$form{'text'} = "<pre>$form{'text'}<\/pre>";
	}
;#ここまでの機能は1書き込みにつき1回のみ使用可

;#この先の特殊機能を実行するには回数券が必要／回数券がある限り複数回使用可
;#!money　【リストからランダムに選択するサブルーチン使用】ランダムな通貨単位
	if($form{'from'} =~ /(\!money)/ or $form{'text'} =~ /(\!money)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_list("\!money",$$setting{'list_money'},$form{'from'},$form{'text'},$setting{'vip_tickets'});
	}

;#!sign　【リストからランダムに選択するサブルーチン使用】符号が出る（+か-がランダムで）
	if($form{'from'} =~ /(\!sign)/ or $form{'text'} =~ /(\!sign)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_list("\!sign",$$setting{'list_sign'},$form{'from'},$form{'text'},$setting{'vip_tickets'});
	}

;#!calc　【リストからランダムに選択するサブルーチン使用】＋－×÷＝のうちのいずれかがランダムに出る
	if($form{'from'} =~ /(\!calc)/ or $form{'text'} =~ /(\!calc)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_list("\!calc",$$setting{'list_calc'},$form{'from'},$form{'text'},$setting{'vip_tickets'});
	}

;#!num　１桁の数字が斜体で出る
	if($form{'from'} =~ /(\!num)/ or $form{'text'} =~ /(\!num)/){
		my ($num_out);
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!num)/){
				$num_out = int(rand $setting{'num'});
				$form{'from'} =~ s/(\!num)/ <\/b><i>$num_out<\/i><b> /;
			}
			elsif($form{'text'} =~ /(\!num)/){
				$num_out = int(rand $setting{'num'});
				$form{'text'} =~ s/(\!num)/ <b><i>$num_out<\/i><\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
	}

;#!base　【確率付きファイルからデータと確率を読み込んでランダムに選択するサブルーチン使用】打席の結果がランダムで表示される（ファイルの書式は"表示項目 確率（‰）" 確率（‰）の合計は1000にすること）
	if($form{'from'} =~ /(\!base)/ or $form{'text'} =~ /(\!base)/){
		my $error1 = "$setting{'file_base'}ファイルが開けなかったぽ。。";
		my $error2 = "乱闘（$setting{'file_base'}ファイルが何か変です、確率の合計が1000‰になっているか確認して下さい。。）";
		my $file_temp_path = &vip_rand1000_file_select("$setting{'$file_path'}$setting{'file_base'}");
		if($file_temp_path =~ /(NULL)/){
			$form{'from'} =~ s/(\!base)/ <\/b>$error1<b> /;
			$form{'text'} =~ s/(\!base)/ <b>$error1<\/b> /;
		}
		elsif($file_temp_path =~ /(ERROR)/){
			$form{'from'} =~ s/(\!base)/ <\/b>$error2<b> /;
			$form{'text'} =~ s/(\!base)/ <b>$error2<\/b> /;
		}
		else{
			($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand1000_file("\!base","$setting{'$file_path'}$file_temp_path",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$file_temp_pathファイルが開けなかったぽ。。","乱闘（$file_temp_pathファイルが何か変です、確率の合計が1000‰になっているか確認して下さい。。）",$file_temp_path);
		}
	}

;#!whena／!whenb／!when　【ファイルからランダムに選択するサブルーチン使用】今とかがランダムで1、2、3
	if($form{'from'} =~ /(\!whena|!whenb|!when)/ or $form{'text'} =~ /(\!whena|!whenb|!when)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!whena","$setting{'$file_path'}$setting{'file_when'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_when'}ファイルが開けなかったぽ。。");
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!whenb","$setting{'$file_path'}$setting{'file_when'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_when'}ファイルが開けなかったぽ。。");
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!when","$setting{'$file_path'}$setting{'file_when'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_when'}ファイルが開けなかったぽ。。");
	}

;#!who　【ファイルからランダムに選択するサブルーチン使用】人物（動物等も）がランダムで表示される
	if($form{'from'} =~ /(\!who)/ or $form{'text'} =~ /(\!who)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!who","$setting{'$file_path'}$setting{'file_who'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_who'}ファイルが開けなかったぽ。。");
	}


;#!body　【ファイルからランダムに選択するサブルーチン使用】体の一部分
	if($form{'from'} =~ /(\!body)/ or $form{'text'} =~ /(\!body)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!body","$setting{'$file_path'}$setting{'file_body'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_body'}ファイルが開けなかったぽ。。");
	}

;#!hungry／!food　【ファイルからランダムに選択するサブルーチン使用】食事がランダムで表示される
	if($form{'from'} =~ /(\!hungry|!food)/ or $form{'text'} =~ /(\!hungry|!food)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!hungry|!food","$setting{'$file_path'}$setting{'file_food'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_food'}ファイルが開けなかったぽ。。");
	}

;#!do　【ファイルからランダムに選択するサブルーチン使用】動詞(行動)がランダムで表示される
	if($form{'from'} =~ /(\!do)/ or $form{'text'} =~ /(\!do)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!do","$setting{'$file_path'}$setting{'file_do'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_do'}ファイルが開けなかったぽ。。");
	}

;#!where　【ファイルからランダムに選択するサブルーチン使用】場所がランダムに表示される
	if($form{'from'} =~ /(\!where)/ or $form{'text'} =~ /(\!where)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!where","$setting{'$file_path'}$setting{'file_where'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_where'}ファイルが開けなかったぽ。。");
	}

;#!power　数字が出る0～999（４桁もあり）
	if($form{'from'} =~ /(\!power)/ or $form{'text'} =~ /(\!power)/){
		my ($power);
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!power)/){
				$power = int(rand $setting{'power_set'});
				$form{'from'} =~ s/(\!power)/ <\/b>$power<b> /;
			}
			elsif($form{'text'} =~ /(\!power)/){
				$power = int(rand $setting{'power_set'});
				$form{'text'} =~ s/(\!power)/ <b>$power<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
	}

;#!year／!mon／!day／!hour／!min／!sec 年／月／日／時／分／秒
	if($form{'from'} =~ /(\!year|!mon|!day|!hour|!min|!sec)/ or $form{'text'} =~ /(\!year|!mon|!day|!hour|!min|!sec)/){
		my ($days,$hours,$year,$mon,$day,$hour,$min,$sec);
		($days,$hours,$form{'null'}) = split(/\s/,$form{'date'});
		$year = scalar(substr($days,0,4));
		$mon = scalar(substr($days,5,2));
		$day = scalar(substr($days,8,2));
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!year)/){
				$form{'from'} =~ s/(\!year)/ <\/b>$year<b> /;
			}
			elsif($form{'text'} =~ /(\!year)/){
				$form{'text'} =~ s/(\!year)/ <b>$year<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!mon)/){
				$form{'from'} =~ s/(\!mon)/ <\/b>$mon<b> /;
			}
			elsif($form{'text'} =~ /(\!mon)/){
				$form{'text'} =~ s/(\!mon)/ <b>$mon<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!day)/){
				$form{'from'} =~ s/(\!day)/ <\/b>$day<b> /;
			}
			elsif($form{'text'} =~ /(\!day)/){
				$form{'text'} =~ s/(\!day)/ <b>$day<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
		$hour = scalar(substr($hours,0,2));
		$min = scalar(substr($hours,3,2));
		if($setting{'$sec_ok'} == 0){
			$sec = scalar(substr($hours,6,2));
		}
		else{
			$sec = "このBBSは秒数表\示に対応しておりません。。。(￣ー￣)ﾆﾔﾘｯ";
		}
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!hour)/){
				$form{'from'} =~ s/(\!hour)/ <\/b>$hour<b> /;
			}
			elsif($form{'text'} =~ /(\!hour)/){
				$form{'text'} =~ s/(\!hour)/ <b>$hour<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!min)/){
				$form{'from'} =~ s/(\!min)/ <\/b>$min<b> /;
			}
			elsif($form{'text'} =~ /(\!min)/){
				$form{'text'} =~ s/(\!min)/ <b>$min<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!sec)/){
				$form{'from'} =~ s/(\!sec)/ <\/b>$sec<b> /;
			}
			elsif($form{'text'} =~ /(\!sec)/){
				$form{'text'} =~ s/(\!sec)/ <b>$sec<\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
	}

#返り値
return($form{'from'},$form{'text'},$setting{'vip_tickets'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能2
sub vip2_20050101{
	my ($form,$setting) = @_;
	my %form;
	my %setting;
	%form = %$form;
	%setting = %$setting;

;#!omikuji　おみくじ 【神】の上に【女神】がある。ただしめったにでない
	my $day_day = scalar(substr($form{'date'},8,2));
	if($day_day == $setting{'omikuji_day'} or $setting{'omikuji_day'} == 0){
		if($form{'from'} =~ /(\!omikuji)/){
			my (@omikuji,$rand_out,$omikuji_out);
			open(FILE,"$setting{'$file_path'}$setting{'file_omikuji'}") or @omikuji = ('omikujiファイルが開けなかったぽ。。');
			unless($omikuji[0] =~ /(omikujiファイルが開けなかったぽ。。)/){
				while (<FILE>){
					$_ =~ s/\n//g;
					@omikuji = (@omikuji, $_);
				}
			}
			close(FILE);
			$rand_out = int(rand(scalar @omikuji));
			$omikuji_out = $omikuji[$rand_out];
			if(rand(6400) < 1){
				$omikuji_out = "NullPointerException";
			}
			elsif(rand(3200) < 1){
				$omikuji_out = "ぬるぽ";
			}
			elsif(rand(1600) < 1){
				$omikuji_out = "女神";
			}
			elsif(rand(800) < 1){
				$omikuji_out = "神";
			}
			$form{'from'} =~ s/(\!omikuji)/ <\/b>【$omikuji_out】<b> /;
		}

;#!dama　お年玉　たまにたくさんもらえることも
		my $mon_mon = scalar(substr($form{'date'},5,2));
		if($mon_mon == $setting{'dama_mon'} or $setting{'dama_mon'} == 0){
			if($form{'from'} =~ /(\!dama)/){
				my ($dama_out,$dama_ref);
				$dama_ref = $$setting{'list_dama'};
				if(rand(10000) < 1){
					$dama_out = int(rand $$dama_ref{'very_very_large'});
				}
				elsif(rand(5000) < 1){
					$dama_out = int(rand $$dama_ref{'very_large'});
				}
				elsif(rand(1000) < 2){
					$dama_out = int(rand $$dama_ref{'large'});
				}
				elsif(rand(500) < 2){
					$dama_out = int(rand $$dama_ref{'normal'});
				}
				elsif(rand(100) < 10){
					$dama_out = int(rand $$dama_ref{'little'});
				}
				elsif(rand(10) < 3){
				$dama_out = int(rand $$dama_ref{'very_little'});
				}
				else{
				$dama_out = int(rand $$dama_ref{'poor'});
					}
				$form{'from'} =~ s/(\!dama)/ <\/b>【$dama_out円】<b> /;
			}
		}
	}

#返り値
return($form{'from'},$form{'text'},$setting{'vip_tickets'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能3
sub vip3_20050121{
	my ($form,$setting) = @_;
	my %form;
	my %setting;
	%form = %$form;
	%setting = %$setting;

;#!IQ　IQ[名前欄のみ対応]リモートホスト[2]
	if($form{'from'} =~ /(\!IQ)/){
		$form{'from'} =~ s/(\!IQ)/ <\/b>【IQ$$setting{'$host'}[2]】<b> /;
	}

;#!kote　【ファイルからランダムに選択するサブルーチン使用】コテ[名前欄のみ対応]リモートホスト[0]
	if($form{'from'} =~ /(\!kote)/){
		my (@kote,$kote_count,$host_out);
		open(FILE,"$setting{'$file_path'}$setting{'file_kote'}") or @kote = ('koteファイルが開けなかったぽ。。');
		unless($kote[0] =~ /(koteファイルが開けなかったぽ。。)/){
			while (<FILE>){
				$_ =~ s/\n//g;
				@kote = (@kote, $_);
			}
		}
		close(FILE);
		$kote_count = @kote;
		$host_out = $$setting{'$host'}[0];
		if($kote_count == 1){
			$host_out = $kote[0];
		}
		else{
			while ($host_out > @kote){
				$host_out = int($host_out / @kote);
			}
		}
		$form{'from'} =~ s/(\!kote)/ <\/b>【$kote[$host_out]】<b> /;
	}

;#!kakari　係り[名前欄のみ対応]リモートホスト[3]
	if($form{'from'} =~ /(\!kakari)/){
		my (@kakari,$kakari_count,$host_out);
		open(FILE,"$setting{'$file_path'}$setting{'file_kakari'}") or @kakari = ('kakariファイルが開けなかったぽ。。');
		unless($kakari[0] =~ /(kakariファイルが開けなかったぽ。。)/){
			while (<FILE>){
				$_ =~ s/\n//g;
				@kakari = (@kakari, $_);
			}
		}
		close(FILE);
		$kakari_count = @kakari;
		$host_out =0;# $$setting{'$host'}[3];
		if($kakari_count == 1){
			$host_out = $kakari[0];
		}
		else{
			while ($host_out > @kakari){
				$host_out = int($host_out / @kakari);
			}
		}
		$form{'from'} =~ s/(\!kakari)/ <\/b> $kakari[$host_out] <b> /;
	}

;#!sute　コテ[名前欄のみ対応]
	if($form{'from'} =~ /(\!sute)/){
		my (@sute,$rand_out);
		open(FILE,"$setting{'$file_path'}$setting{'file_sute'}") or @sute = ('suteファイルが開けなかったぽ。。');
		unless($sute[0] =~ /(suteファイルが開けなかったぽ。。)/){
			while (<FILE>){
				$_ =~ s/\n//g;
				@sute = (@sute, $_);
			}
		}
		close(FILE);
		$rand_out = int(rand(scalar @sute));
		$form{'from'} =~ s/(\!sute)/ <\/b>《$sute[$rand_out]》<b> /;
	}

;#!mibun　【ファイルからランダムに選択するサブルーチン使用】身分
	if($form{'from'} =~ /(\!mibun)/ or $form{'text'} =~ /(\!mibun)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!mibun","$setting{'$file_path'}$setting{'file_mibun'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_mibun'}ファイルが開けなかったぽ。。");
	}

;#!where　【ファイルからランダムに選択するサブルーチン使用】場所
	if($form{'text'} =~ /(\!3where)/){
		($form{'null'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!3where","$setting{'$file_path'}$setting{'file_3where'}",0,$form{'text'},$setting{'vip_tickets'},"$setting{'file_3where'}ファイルが開けなかったぽ。。");
	}

;#!card　トランプ
	if($form{'text'} =~ /(\!card)/){
		my ($card_ref,$rand_out1,$rand_out2);
		$card_ref = $$setting{'list_card'};
		while ($setting{'vip_tickets'} > 0){
			if($form{'text'} =~ /(\!card)/){
				if(rand(54) < 2){
					$form{'text'} =~ s/(\!card)/ <b>JOKER<\/b> /;
				}
				else{
					$rand_out1 = int(rand (scalar @$card_ref));
					$rand_out2 = int(rand 13) + 1;
					if($rand_out2 == 11){
						$rand_out2 = "J";
					}
					elsif($rand_out2 == 12){
						$rand_out2 = "Q";
					}
					elsif($rand_out2 == 13){
						$rand_out2 = "K";
					}
					$form{'text'} =~ s/(\!card)/ <b>$$card_ref[$rand_out1]$rand_out2<\/b> /;
				}
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
	}

;#!do　【ファイルからランダムに選択するサブルーチン使用】動詞(行動)がランダムで表示される
	if($form{'text'} =~ /(\!3do)/){
		($form{'null'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!3do","$setting{'$file_path'}$setting{'file_3do'}",0,$form{'text'},$setting{'vip_tickets'},"$setting{'file_3do'}ファイルが開けなかったぽ。。");
	}

;#!anime　【ファイルからランダムに選択するサブルーチン使用】アニメキャラ（権利の問題がないとは言い切れないのでanime.cgiファイルは各自用意して下さい。）
	if($form{'from'} =~ /(\!anime)/ or $form{'text'} =~ /(\!anime)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!anime","$setting{'$file_path'}$setting{'file_anime'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_anime'}ファイルが開けなかったぽ。。");
	}

#!create Yamato　船を作る・Yamatoは自分の船の名前・IQが低いと作れない
	if($form{'text'} =~ /(\!create\s\w+)/ and $setting{'vip_tickets'} > 0){
		my (@ships_list,$ships_name,$ships_hp,$count,$doble_flag);
		($form{'null'},$ships_name,$form{'null'}) = split(/\s/,$1);
		$doble_flag = 0;
		if ($$setting{'$host'}[2] < $$setting{'ships_iq_limit'}){
			$form{'text'} =~ s/(\!create\s\w+)/ <font color="green">知能\が低くて建造できませんでした。<\/font>($ships_name) /;
		}
		elsif (length($ships_name) > $setting{'ships_name'}){
			$form{'text'} =~ s/(\!create\s\w+)/ <font color="green">船名が長すぎます。<\/font>($ships_name) /;
		}
		else{
			open (SHIPS,"$setting{'$bbs_path'}$form{'bbs_name'}/$setting{'file_ships'}") or open (SHIPS,"+<"."$setting{'$bbs_path'}$form{'bbs_name'}/$setting{'file_ships'}");
			while (<SHIPS>){
				$_ =~ s/\n//g;
				($_,$form{'null'}) = split(/\s/,$_);
				@ships_list = (@ships_list, $_);
			}
			$count = 0;
			close(SHIPS);
			while ($count < @ships_list){
				if ($ships_name =~ /($ships_list[$count])/){
					$doble_flag = 1;
					last;
				}
				$count++;
			}
			if ($doble_flag == 1){
				$form{'text'} =~ s/(\!create\s\w+)/ <font color="green">同名の船が既に存在します。<\/font>($ships_name) /;
			}
			elsif ($count > $setting{'port_capacity'} - 1){
				$form{'text'} =~ s/(\!create\s\w+)/ <font color="green">これ以上建造できません。<\/font>($ships_name) /;
			}
			else{
				if ($setting{'ships_hp_rand_flag'} == 1){
					$ships_hp = int(rand($setting{'ships_hp_rand'})) - ($setting{'ships_hp_rand'} / 2);
				}
				$ships_hp = $ships_hp + $$setting{'ships_hp'}[int(rand(10))];
				open (SHIPS,">>"."$setting{'$bbs_path'}$form{'bbs_name'}/$setting{'file_ships'}");
				eval{flock(SHIPS,2);};
				print SHIPS "$ships_name $ships_hp\n";
				close(SHIPS);
				$form{'text'} =~ s/(\!create\s\w+)/ <font color="blue"><b>$ships_name<\/b> created. (HP $ships_hp)<\/font> /;
			}
		}
		$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
	}

;#!list　船一覧
	if($form{'text'} =~ /(\!list)/ and $setting{'vip_tickets'} > 0){
		my ($bbs_name,$ships_hp_temp,$ships_count,$ships_list_out,$ships_list_out_temp);
		if($form{'text'} =~ /(\!list\s\w+)/){
			($form{'null'},$bbs_name,$form{'null'}) = split(/\s/,$1);
			open (SHIPS,"$setting{'$bbs_path'}$bbs_name/$setting{'file_ships'}") or $ships_list_out = ('shipsファイルが開けなかったぽ。。');
			unless($ships_list_out =~ /(shipsファイルが開けなかったぽ。。)/){
				$ships_list_out = 1;
					while (<SHIPS>){
					$_ =~ s/\n//g;
					($_,$ships_hp_temp) = split(/\s/,$_);
					if ($ships_list_out == 1){
						$ships_list_out = "\# <font color=\"blue\">$_<\/font> $ships_hp_temp";
					}
					else{
						$ships_list_out_temp = "\# <font color=\"blue\">$_<\/font> $ships_hp_temp";
						$ships_list_out = join(" <br> ",$ships_list_out,$ships_list_out_temp);
					}
					$ships_count++;
				}
				close(SHIPS);
				$form{'text'} =~ s/(\!list\s\w+)/ <font color="green" face="Arial"><b>current ships<\/b><\/font>($ships_count) $bbs_name軍 <br> $ships_list_out <br> \!list/;
			}
			else{
				close(SHIPS);
				$form{'text'} =~ s/(\!list\s\w+)/ <font color="green" face="Arial"><b>current ships<\/b><\/font> <br> $ships_list_out <br> \!list/;
			}
		}
		$ships_list_out = 0;
		$ships_count = 0;
		open (SHIPS,"$setting{'$bbs_path'}$form{'bbs_name'}/$setting{'file_ships'}") or $ships_list_out = ('shipsファイルが開けなかったぽ。。');
		unless($ships_list_out =~ /(shipsファイルが開けなかったぽ。。)/){
			$ships_list_out = 1;
			while (<SHIPS>){
				$_ =~ s/\n//g;
				($_,$ships_hp_temp) = split(/\s/,$_);
				if ($ships_list_out == 1){
					$ships_list_out = "\# <font color=\"blue\">$_<\/font> $ships_hp_temp";
				}
				else{
					$ships_list_out_temp = "\# <font color=\"blue\">$_<\/font> $ships_hp_temp";
					$ships_list_out = join(" <br> ",$ships_list_out,$ships_list_out_temp);
				}
				$ships_count++;
			}
			close(SHIPS);
			$form{'text'} =~ s/(\!list)/ <font color="green" face="Arial"><b>current ships<\/b><\/font>($ships_count) $form{'bbs_name'}軍 <br> $ships_list_out <br> /;
		}
		else{
			close(SHIPS);
			$form{'text'} =~ s/(\!list)/ <font color="green" face="Arial"><b>current ships<\/b><\/font> <br> $ships_list_out /;
		}
		$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
	}

;#!attack Yamato　攻撃・Yamatoは攻撃先の船に直す
	if($form{'text'} =~ /(\!attack\s[\w@]+)/ and $setting{'vip_tickets'} > 0){
		my ($ships_attack_name,$ships_bbs_name,$ships_attack_out,$ships_bbs_name_out,$ships_hp_temp,$ships_attack_ref,@ships_attack_list,$dame,$dame_ref,$output_flag,$yajirushi);
		$dame_ref = $$setting{'dame'};
		($form{'null'},$ships_attack_name,$form{'null'}) = split(/\s/,$1);
		$output_flag = 0;
		$yajirushi = "---&gt;";
		($ships_attack_name,$ships_bbs_name) = split(/@/,$ships_attack_name);
		unless($form{'text'} =~ /(\!attack\s\w+@\w+)/){
			$ships_bbs_name = $form{'bbs_name'};
		}
		else{
			$ships_bbs_name_out = "\@$ships_bbs_name";
			$form{'text'} =~ s/(\!attack\s\w+)(@\w+)/$1/;
		}
		open (SHIPS,"$setting{'$bbs_path'}$ships_bbs_name/$setting{'file_ships'}") or $ships_attack_out = ('shipsファイルが開けなかったぽ。。');
		unless($ships_attack_out =~ /(shipsファイルが開けなかったぽ。。)/){
			while (<SHIPS>){
				$_ =~ s/\n//g;
				($_,$ships_hp_temp) = split(/\s/,$_);
				$ships_attack_ref = [$_, $ships_hp_temp];
				push @ships_attack_list, $ships_attack_ref;
			}
			close(SHIPS);
			foreach $ships_attack_ref (@ships_attack_list) {
				if ($ships_attack_name =~ /($ships_attack_ref->[0])/){
					if ($setting{'ships_dame_rand_flag'} == 1){
						$dame = int(rand($setting{'ships_dame_rand'})) - ($setting{'ships_dame_rand'} / 2);
					}
					$dame = $dame + (255 - $$setting{'$host'}[0]) * 4 + $$dame_ref[0];
					if(rand(10) < 1){
						$dame = $dame + $$dame_ref[1];
					}
					if(rand(100) < 1){
						$dame = $dame + $$dame_ref[2];
					}
					if(rand(100) < 1){
						$dame = $dame + $$dame_ref[3];
					}
					if(rand(10) < 1){
						$form{'text'} =~ s/(\!attack\s\w+)/ Attack $ships_attack_ref->[0] ---> Missed. /;
					}
					elsif (rand(15) < 1){
						$ships_attack_ref->[1] = $ships_attack_ref->[1] + $dame;
						$form{'text'} =~ s/(\!attack\s\w+)/ <font color="green">Attack $ships_attack_ref->[0]$ships_bbs_name_out $yajirushi Missed. (+$dame)<\/font>Recovery! /;
					}
					elsif (rand(50) < 1){
						$dame = $dame * $setting{'critical_hit'};
						$ships_attack_ref->[1] = $ships_attack_ref->[1] - $dame;
						if ($ships_attack_ref->[1] < 1){
							$form{'text'} =~ s/(\!attack\s\w+)/ <font color="yellow">Attack $ships_attack_ref->[0]$ships_bbs_name_out $yajirushi Success. <\/font>Critical HIT!! <font color="red">撃沈!!<\/font> /;
						}
						else{
							$form{'text'} =~ s/(\!attack\s\w+)/ <font color="yellow">Attack $ships_attack_ref->[0]$ships_bbs_name_out $yajirushi Success. (-$dame)<\/font>Critical HIT!! /;
						}
					}
					else{
						$ships_attack_ref->[1] = $ships_attack_ref->[1] - $dame;
						if ($ships_attack_ref->[1] < 1){
							$form{'text'} =~ s/(\!attack\s\w+)/ Attack $ships_attack_ref->[0]$ships_bbs_name_out $yajirushi Success. <font color="red">撃沈!!<\/font> /;
						}
						else{
							$form{'text'} =~ s/(\!attack\s\w+)/ <font color="blue">Attack $ships_attack_ref->[0]$ships_bbs_name_out $yajirushi Success. (-$dame)<\/font> /;
						}
					}
					$output_flag = 1;
					last;
				}
			}
			if ($output_flag == 1){
				open (SHIPS,">"."$setting{'$bbs_path'}$ships_bbs_name/$setting{'file_ships'}");
				eval{flock(SHIPS,2);};
				foreach $ships_attack_ref (@ships_attack_list) {
					if($ships_attack_ref->[1] < 1){
						next;
					}
					print SHIPS "$ships_attack_ref->[0] $ships_attack_ref->[1]\n";
				}
				close(SHIPS);
			}
			else{
					$form{'text'} =~ s/(\!attack\s\w+)/ Attack $ships_attack_name$ships_bbs_name_out ---> Missed. /;
			}
		}
		else{
			close(SHIPS);
			$form{'text'} =~ s/(\!attack\s\w+)/ <font color="green">$ships_attack_out<\/font> /;
		}
		$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
	}

#返り値
return($form{'from'},$form{'text'},$setting{'vip_tickets'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#伝説の機能独自版
sub vip_orig{
	my ($form,$setting) = @_;
	my %form;
	my %setting;
	%form = %$form;
	%setting = %$setting;

;#tasukeruyo 運用情報板の機能 fusianasan＋HTTP_USER_AGENT＋SERVER_PROTOCOL
	if($form{'from'} =~ /(tasukeruyo)/){
		$form{'from'} =~ s/tasukeruyo/ <\/b>$ENV{'REMOTE_HOST'}<b> /;
		$form{'text'} = "$form{'text'} <hr> <font color=\"blue\">$ENV{'HTTP_USER_AGENT'} $ENV{'SERVER_PROTOCOL'}<\/font> ";
	}

;#!expo　【ファイルからランダムに選択するサブルーチン使用】!expo　愛知万博のパビリオンや飲食店などがランダムで表示される ささしまサテライトも収録
	if($form{'from'} =~ /(\!expo)/ or $form{'text'} =~ /(\!expo)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!expo","$setting{'$file_path'}$setting{'file_expo'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_expo'}ファイルが開けなかったぽ。。");
	}

;#!yakyu　【ファイルからランダムに選択するサブルーチン使用】三振とかバントホームランとか
	if($form{'from'} =~ /(\!yakyu)/ or $form{'text'} =~ /(\!yakyu)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!yakyu","$setting{'$file_path'}$setting{'file_yakyu'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"yakyuファイルが開けなかったぽ。。");
	}

;#!poke　【ファイルからランダムに選択するサブルーチン使用】ポケモンの種族名がランダムで表示される
	if($form{'from'} =~ /(\!poke)/ or $form{'text'} =~ /(\!poke)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("\!poke","$setting{'$file_path'}$setting{'file_poke'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_poke'}ファイルが開けなかったぽ。。");
	}

;#!whenc　【リストからランダムに選択するサブルーチン使用】日時とかがランダム表示される
	if($form{'from'} =~ /(\!cwhen)/ or $form{'text'} =~ /(\!cwhen)/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_list("\!cwhen",$$setting{'list_whenc'},$form{'from'},$form{'text'},$setting{'vip_tickets'});
	}

;#!etc　「オレ、第③京浜 60km <br> 外環 某入口 50km じゃ」の改変コピペを表示
	if($form{'from'} =~ /(\!etc)/ or $form{'text'} =~ /(\!etc)/){
		my (@etc,$etc_rand1,$etc_rand2,$etc_rand3,$etc_rand4,$etc_out1,$etc_out2);
		open(FILE,"$setting{'$file_path'}$setting{'file_etc'}") or @etc = ("$setting{'file_etc'}ファイルが開けなかったぽ。。");
		unless($etc[0] =~ /("$setting{'file_etc'}ファイルが開けなかったぽ。。")/){
			while (<FILE>){
				$_ =~ s/(\n)//g;
				@etc = (@etc, $_);
			}
		}
		close(FILE);
		while ($setting{'vip_tickets'} > 0){
			if($form{'from'} =~ /(\!etc)/){
				$etc_rand1 = int(rand (scalar @etc));
				$etc_rand2 = int(rand ($setting{'etc_speed'}));
				$etc_out1 = "$etc_rand2 km";
				if($etc_rand2 == 0){
					$etc_out1 = "一時停止";
				}
				$etc_rand3 = int(rand (scalar @etc));
				$etc_rand4 = int(rand ($setting{'etc_speed'}));
				$etc_out2 = "$etc_rand4 km";
				if($etc_rand4 == 0){
					$etc_out2 = "一時停止";
				}
				$form{'from'} =~ s/(\!etc)/ <\/b>オレ、$etc[$etc_rand1] $etc_out1　 $etc[$etc_rand3] $etc_out2 じゃ<b> /;
			}
			elsif($form{'text'} =~ /(\!etc)/){
				$etc_rand1 = int(rand (scalar @etc));
				$etc_rand2 = int(rand ($setting{'etc_speed'}));
				$etc_out1 = "$etc_rand2 km";
				if($etc_out1 == 0){
					$etc_out1 = "一時停止";
				}
				$etc_rand3 = int(rand (scalar @etc));
				$etc_rand4 = int(rand ($setting{'etc_speed'}));
				$etc_out2 = "$etc_rand4 km";
				if($etc_out2 == 0){
					$etc_out2 = "一時停止";
				}
				$form{'text'} =~ s/(\!etc)/ <b> <br> オレ、$etc[$etc_rand1] $etc_out1 <br> $etc[$etc_rand3] $etc_out2 じゃ <br> <\/b> /;
			}
			else{
				last;
			}
			$setting{'vip_tickets'}--;#ここで回数券を1枚もぎ取ります
		}
	}

;#!user1　【ファイルからランダムに選択するサブルーチン使用】ユーザー独自設定内容を表示その1
	if($form{'from'} =~ /($setting{'user1_com'})/ or $form{'text'} =~ /($setting{'user1_com'})/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("$setting{'user1_com'}","$setting{'$file_path'}$setting{'file_user1'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_user1'}ファイルが開けなかったぽ。。");
	}

;#!user2　【ファイルからランダムに選択するサブルーチン使用】ユーザー独自設定内容を表示その2
	if($form{'from'} =~ /($setting{'user2_com'})/ or $form{'text'} =~ /($setting{'user2_com'})/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("$setting{'user2_com'}","$setting{'$file_path'}$setting{'file_user2'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_user2'}ファイルが開けなかったぽ。。");
	}

;#!user3　【ファイルからランダムに選択するサブルーチン使用】ユーザー独自設定内容を表示その3
	if($form{'from'} =~ /($setting{'user3_com'})/ or $form{'text'} =~ /($setting{'user3_com'})/){
		($form{'from'},$form{'text'},$setting{'vip_tickets'}) = &vip_rand_file("$setting{'user3_com'}","$setting{'$file_path'}$setting{'file_user3'}",$form{'from'},$form{'text'},$setting{'vip_tickets'},"$setting{'file_user3'}ファイルが開けなかったぽ。。");
	}

#返り値
return($form{'from'},$form{'text'},$setting{'vip_tickets'});
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#【リストからランダムに選択するサブルーチン】
sub vip_rand_list{
	my ($vip_com,$list_reference,$form_from,$form_text,$vip_tickets) = @_;
	my (@list,$rand_out);
	while ($vip_tickets > 0){
		if($form_from =~ /($vip_com)/){
			$rand_out = int(rand (scalar @$list_reference));
			$form_from =~ s/($vip_com)/ <\/b>$$list_reference[$rand_out]<b> /;
		}
		elsif($form_text =~ /($vip_com)/){
			$rand_out = int(rand (scalar @$list_reference));
			$form_text =~ s/($vip_com)/ <b>$$list_reference[$rand_out]<\/b> /;
		}
		else{
			last;
		}
		$vip_tickets--;#ここで回数券を1枚もぎ取ります
	}
	return($form_from,$form_text,$vip_tickets);
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#【ファイルからランダムに選択するサブルーチン】
sub vip_rand_file{
	my ($vip_com,$file_path,$form_from,$form_text,$vip_tickets,$error1) = @_;
	my (@list,$rand_out);
	open(FILE,$file_path) or @list = $error1;
	unless($list[0] =~ /($error1)/){
		while (<FILE>){
			$_ =~ s/\n//g;
			@list = (@list, $_);
		}
	}
	close(FILE);
	while ($vip_tickets > 0){
		if($form_from =~ /($vip_com)/){
			$rand_out = int(rand (scalar @list));
			$form_from =~ s/($vip_com)/ <\/b>$list[$rand_out]<b> /;
		}
		elsif($form_text =~ /($vip_com)/){
			$rand_out = int(rand (scalar @list));
			$form_text =~ s/($vip_com)/ <b>$list[$rand_out]<\/b> /;
		}
		else{
			last;
		}
		$vip_tickets--;#ここで回数券を1枚もぎ取ります
	}
	return($form_from,$form_text,$vip_tickets);
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#【確率付きファイルからファイル名と確率を読み込んでランダムに選択するサブルーチン】
sub vip_rand1000_file_select{
	my ($file_path) = @_;
	my (@list,@list_temp,@list_kakuritsu,$list_sum,$rand_out,$list_out,$list_count,$list_kakuritsu_out);
	my $rand_seed = 1000;
	open(FILE,$file_path) or $list_out = "NULL";
	unless($list_out =~ /NULL/){
		while (<FILE>){
			$_ =~ s/\n//g;
			@list_temp = split(/\s/,$_);
			@list = (@list,$list_temp[0]);
			@list_kakuritsu = (@list_kakuritsu,(scalar $list_temp[1]));
		}
		$list_sum = @list;
	}
	close(FILE);
	unless($list_out =~ /NULL/){
		$rand_out = int(rand $rand_seed)+1;
		$list_count = 0;
		$list_kakuritsu_out = $list_kakuritsu[$list_count];
		while(1){
			if($rand_out <= $list_kakuritsu_out){
				$file_path = $list[$list_count];
				last;
			}
			$list_count++;
			$list_kakuritsu_out = $list_kakuritsu_out + $list_kakuritsu[$list_count];
			if($list_count == $list_sum or $list_kakuritsu_out > $rand_seed){
				$file_path = "ERROR";
				last;
			}
		}
	}
	else{
		$file_path = "NULL";
	}
	return($file_path);
}

;#--------------------------------------------------------------------------------------------------------------------#;

;#【確率付きファイルからデータと確率を読み込んでランダムに選択するサブルーチン】
sub vip_rand1000_file{
	my ($vip_com,$file_path,$form_from,$form_text,$vip_tickets,$error1,$error2,$check) = @_;
	my (@list,@list_temp,@list_kakuritsu,$list_sum,$rand_out,$list_out,$list_count,$list_kakuritsu_out);
	my $rand_seed = 1000;
	open(FILE,$file_path) or $list_out = "NULL";
	unless($list_out =~ /NULL/){
		while (<FILE>){
			$_ =~ s/\n//g;
			@list_temp = split(/\s/,$_);
			@list = (@list,$list_temp[0]);
			@list_kakuritsu = (@list_kakuritsu,(scalar $list_temp[1]));
		}
		$list_sum = @list;
	}
	else{
		$list[0] = $error1;
		$list_kakuritsu[0] = 1000;
	}
	close(FILE);
	while ($vip_tickets > 0){
		if($form_from =~ /($vip_com)/){
			$rand_out = int(rand $rand_seed)+1;
			$list_count = 0;
			$list_kakuritsu_out = $list_kakuritsu[$list_count];
			while(1){
				if($rand_out <= $list_kakuritsu_out){
					$list_out = $list[$list_count];
					last;
				}
				$list_count++;
				$list_kakuritsu_out = $list_kakuritsu_out + $list_kakuritsu[$list_count];
				if($list_count == $list_sum or $list_kakuritsu_out > $rand_seed){
					$list_out = $error2;
					last;
				}
			}
			$form_from =~ s/($vip_com)/ <\/b><span title=\"$check\">$list_out<\/span><b> /;
		}
		elsif($form_text =~ /($vip_com)/){
			$rand_out = int(rand $rand_seed)+1;
			$list_count = 0;
			$list_kakuritsu_out = $list_kakuritsu[$list_count];
			while(1){
				if($rand_out <= $list_kakuritsu_out){
					$list_out = $list[$list_count];
					last;
				}
				$list_count++;
				$list_kakuritsu_out = $list_kakuritsu_out + $list_kakuritsu[$list_count];
				if($list_count == $list_sum or $list_kakuritsu_out > $rand_seed){
					$list_out = $error2;
					last;
				}
			}
			$form_text =~ s/($vip_com)/ <b><span title=\"$check\">$list_out<\/span><\/b> /;
		}
		else{
			last;
		}
		$vip_tickets--;#ここで回数券を1枚もぎ取ります
	}
	return($form_from,$form_text,$vip_tickets);
}

;#--------------------------------------------------------------------------------------------------------------------#;
;# END
;#--------------------------------------------------------------------------------------------------------------------#;
1;
