# New_0ch_Plusドキュメント
## 前提
本ドキュメントは整備途中です。  

## ユーザーガイド
### testフォルダのディレクトリ構成
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
    |  + 0ch_*.pl             - プラグインスクリプト  
    + perllib/  
       \+ \*                    - ぜろちゃんねるプラスに必要なパッケージ  

## 開発者ガイド
### モジュールについて
https://github.com/PrefKarafuto/New_0ch_Plus/discussions/10#discussioncomment-4699277  
todo: での更新ぶんも含めて上記をここに書き写す(モジュール名変更を反映すること)
  
### 画面とUIの対応付けについて
https://github.com/PrefKarafuto/New_0ch_Plus/discussions/10#discussioncomment-4698789  
todo: 上記をここに書き写す(モジュール名変更を反映すること)
  
## フォーク元からの変更概要
・Cloudflareに対応しました  
[詳細](https://github.com/PrefKarafuto/New_0ch_Plus/issues/1)  
・一部モジュール名を変更しました  
[詳細](https://github.com/PrefKarafuto/New_0ch_Plus/issues/4)  

## ソースコード中の日本語表記に係る"\"について
このスラッシュはファイルの文字コードがShift-JISの場合に文字化け防止用に必要なものであるので、UTF-8に変えた今では不要です。  
抜いてしまって問題ありません。  

## PHPへの移植について
PHP移植はリソースの都合上すぐには着手できません。  
Perlで機能を作り終えてかつ機能をリクエストが1ヶ月来なくなった時点で開始します。  
[詳細](https://github.com/PrefKarafuto/New_0ch_Plus/issues/5)

### リリースについて
重要な機能を1つ実装したらその都度リリースを行う予定です。  
これは価値の提供とフィードバックのループを速めるためです。  