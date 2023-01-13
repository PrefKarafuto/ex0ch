# New_0ch_Plus
これは更新停止したぜろちゃんねるプラスの再開発を目的としたプロジェクトです。  
testフォルダの内容はVer0.7.5の物と同一です。心ある方々の協力を切に望む。  
  
今後の開発予定機能  
・NGワードで正規表現を使用可能に  
・UAフィルター・"＞"による書き込み強調・画像表示プラグイン等を本体に取り込み  
・NGワード・NGIP等の規制に引っかかった書き込みのログを取得・表示し、かつどこが引っかかったのか管理画面から確認できるようにする 
  ⇒管理メニューの”各種編集”から、規制関係を分離  
・スレ・レス検索機能の改良・掲示板毎にsearch.cgiでの検索可否を設定できるように  
・掲示板全体の書き込みを管理画面から検索出来るようにし、一括で削除出来るようにする  
  
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
    + mordor/  
    |  + *.pl                 - 管理CGI用モジュール  
    + plugin/  
    |  + 0ch_*.pl             - プラグインスクリプト  
    + perllib/  
       \+ \*                    - ぜろちゃんねるプラスに必要なパッケージ  
         
