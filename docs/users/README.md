# New_0ch_Plusユーザードキュメント
## 前提
本ドキュメントは整備途中です。  

## testフォルダのディレクトリ構成
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
