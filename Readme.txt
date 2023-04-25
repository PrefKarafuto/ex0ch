
ぜろちゃんねるプラス Ver0.8.x
https://github.com/PrefKarafuto/New_0ch_Plus/

■はじめに
  このファイルは、2002年に開発開始された「ぜろちゃんねる(http://0ch.mine.nu/)」のスクリプトを２ちゃんねる仕様に改造するという
  目的で2010年はじまったプロジェクト「ぜろちゃんねるプラス(http://zerochplus.osdn.jp/)」がv0.7.4で開発停止したことを受けて
  2023年に発足した「ぜろちゃんねるプラス再開発プロジェクト」による、スクリプト取扱説明書です。
　このファイルは本家ぜろちゃんねるの/readme/readme.txtを元に編集された0ch+の/Readme/Readme.txtから作成しており、一部原文
  ままの部分があります。
  
■ぜろちゃんねるプラス(v0.8.x)とは
  スレッドフロート型掲示板を動作させるPerlスクリプトとして製作されたぜろちゃんねるの機能改善版「ぜろちゃんねるプラス」の有志再開発版です。
  これまでのぜろちゃんねるプラスと同じく５ちゃんねる専用ブラウザでも書き込みと閲覧、またv0.7.4(v0.7.5)からのアップデートが可能です。
  
■動作環境
  ★必須環境
    ・CGIの動作が可能なHTTPDが入っており，Perl 5.22以上(Perl 6/Rakuは含まない)もしくはそのディ
      ストリビューション系ソフトウェアが動作するOS
    ・5MB以上のディスクスペース 
  ★推奨環境
    ・suEXECでCGI動作が可能なApache HTTP Serverが入っており，Perl 5.22以上(Perl 6/Rakuは含まな
      い)が動作するUNIX系もしくはLinux系のOS
    ・10MB以上のディスクスペース
    
■配布ファイル構成
zerochplus_0.8.x/
 + test/                      - ぜろちゃんねるプラス動作ディレクトリ
    + *.cgi                   - 基本動作用CGI
    + datas/                  - 初期データ・固定データ格納用
    |  + 1000.txt
    |  + 2000000000.dat
    |  :
    + info/
    |  + category.cgi         - 掲示板カテゴリの初期定義ファイル
    |  + errmes.cgi           - エラーメッセージ定義ファイル
    |  + users.cgi            - 初期ユーザ(Administrator)定義ファイル
    + module/
    |  + *.pl                 - ぜろちゃんねるモジュール
    + admin/
    |  + *.pl                 - 管理CGI用モジュール
    + plugin/
    |  + 0ch_*_utf8.pl        - プラグインスクリプト
    + plugin_conf/
    |  + *.cgi                - プラグイン設定情報ファイル
    + perllib/
       + *                    - ぜろちゃんねるプラスに必要なパッケージ
       
       以下ぜろちゃんねるプラスのReadme.txtから引用
■設置方法概略
　Wikiにて画像つきの設置方法の解説を公開しています。
  ・Install - ぜろちゃんねるプラス Wiki
    http://sourceforge.jp/projects/zerochplus/wiki/Install

1.スクリプト変更

	・構成ファイルtest直下の.cgiファイルを開き、1行目に書いてあるperlパス
	  を環境に合わせて変更します。
	
	※以下のようになっている場所を変更します。
	
		#!/usr/bin/perl

2.スクリプトアップロード

	・構成ファイルのtest以下すべてを設置サーバにアップロードします。
	・アップロード後パーミッションを適切な値に設定します。
	
	※パーミッションの値については以下のページを参照
	・Permission - ぜろちゃんねるプラス
	  http://sourceforge.jp/projects/zerochplus/wiki/Permission

3.設定

	・[設置サーバ]/test/admin.cgiにアクセスします。
	・ユーザ名"Administrator",パス"zeroch"でログインします。
	・画面上部の"システム設定"メニューを選択します。
	・画面左側の"基本設定"メニューを選択します。
	・項目[稼動サーバ]を適切な値に設定し、[設定]ボタンを押します。
	・再度画面左側の"基本設定"メニューを選択して、稼動サーバが更新されていることを確認し
	  てください。
	  （もしされていない場合はパーミッションの設定に問題があるかもしれません）
	・画面上部の"ユーザー"メニューを選択します。
	・画面中央の[User Name]列の"Administrator"を選択します。
	・ユーザ名、パスワードを変更して[設定]ボタンを押します。
	・画面上部の"ログオフ"を選択します。

4.掲示板作成

	・先ほど設定した管理者ユーザでログインします。
	・画面上部の"掲示板"メニューを選択します。
	・画面左側の"掲示板作成"メニューを選択します。
	・必要項目を記入して[作成]ボタンを押します。

5.掲示板設定

	・画面上部の"掲示板"メニューを選択します。
	・掲示板一覧より、設定する掲示板を選択します。
	・画面上部の"掲示板設定"を選択します。
	・各項目を設定します。

-----------------------------------------------------------------------
※注意：
	・設置後のAdministratorユーザは必ず変更を行ってください。設置直後は
	  ユーザ名とパスワードが固定なので、放置しておくと管理者以外に管理
	  権限でログインされてしまう危険があります。
-----------------------------------------------------------------------


■ライセンス
　本スクリプトのライセンスは本家ぜろちゃんねると同じ扱いとします。以下は本家ぜろちゃんね
る /readme/readme.txt からの引用です。

> 本スクリプトは自由に改造・再配布してもらってかまいません。また、本スクリプトによって出
力されるクレジット表示(バージョン表示)などの表示も消して使用してもらっても構いません。
> ただし、作者は本スクリプトと付属ファイルに関する著作権を放棄しません。また、作者は本ス
クリプト使用に関して発生したいかなるトラブルにも責任を負いかねますのでご了承ください。

　またremake.cgiの著作権･ライセンスは別の方にあり、remake.cgiの作者に著作権･ライセンスを
帰属します。

以上引用

■バージョンアップについて
  旧v0.7.x系列からのアップデートの際は、必ず事前にバックアップをとってください。
  testフォルダ内を新しいファイルで上書きしてください。(infoフォルダ内のファイルはerrmsg.cgiのみ上書きすること)

■ヘルプ・サポート
　基本的なことは変わっておりませんので、以下のページを参考にしてください。
  ・ヘルプ - ぜろちゃんねるプラス
    http://zerochplus.sourceforge.jp/help/
  ・ぜろちゃんねるプラスWiki
    http://sourceforge.jp/projects/zerochplus/wiki/

  不具合報告などしていただける場合は以下のページからissueを作成してください。
  ・サポート - ぜろちゃんねるプラス再開発プロジェクト
    https://github.com/PrefKarafuto/New_0ch_Plus/issues
    
■謝辞
　本家ぜろちゃんねる開発者「精神衰弱◆kwSzvOHE」氏並びにぜろちゃんねるプラス開発者「windyakin◆windyaking」氏を初めとする
  両スクリプトの開発陣の方々、そして再開発に協力して頂いた皆様に心からの謝意を表します。

■GitHub(公式)
　https://github.com/PrefKarafuto/New_0ch_Plus/

■同梱のPerlモジュール
Digest-SHA-PurePerl
Perl implementation of SHA-1/224/256/384/512
    Version:    5.72
    Released:   2012-09-24
    Author:     Mark Shelor <mshelor@cpan.org>
    License:    The Perl 5 License (Artistic 1 & GPL 1)
    CPAN:       http://search.cpan.org/dist/Digest-SHA-PurePerl-5.72/

Net-DNS-Lite
a pure-perl DNS resolver with support for timeout
    Version:    0.09
    Released:   2012-06-20
    Author:     Kazuho Oku <kazuhooku@gmail.com>
    License:    The Perl 5 License (Artistic 1 & GPL 1)
    CPAN:       http://search.cpan.org/dist/Net-DNS-Lite-0.09/

List-MoreUtils
Provide the stuff missing in List::Util
    Version:    0.33
    Released:   2011-08-04
    Author:     Adam Kennedy <adamk@cpan.org>
    License:    The Perl 5 License (Artistic 1 & GPL 1)
    CPAN:       http://search.cpan.org/dist/List-MoreUtils-0.33/

CGI-Session
Persistent session data in CGI applications
    Version:    4.48
    Released:   2011-07-11
    Author:     Mark Stosberg <mark@summersault.com>
    License:    Artistic License 1.0
    CPAN:       http://search.cpan.org/dist/CGI-Session-4.48/
    
--------------------------------------------------------------------------------------
2023 ぜろちゃんねるプラス再開発プロジェクト(https://github.com/PrefKarafuto/New_0ch_Plus/)
 by 樺太庁長官◆i5oJWq7F9Gmc
