# EXぜろちゃんねる
開発が凍結された「ぜろちゃんねるプラス」を有志で開発し、便利な機能を追加していくプロジェクトです。  
  
バグ報告・機能要望・その他サポート用のDiscordはこちら  
https://discord.gg/jXCUpTZgbE

ドキュメント  
https://prefkarafuto.github.io/docs
  
## 今後の開発予定機能   
- [ ] 過去ログ周りを整備
- [x] タイムラインの実装
- [ ] 検索関連をJSに
- [ ] read.html
- [ ] スクリプトをPHPで書き換え
- [ ] サーバー間でのデータ共有(掲示板連合)
- [ ] ログのDB化
## お知らせ  
v0.10.5から、**CGI.pm**モジュールが必要です。  
もし入っていない場合はcpanからインストールしてください。  
  
2023/1/14 PrefKarafuto  

------------
## testフォルダのディレクトリ構成
 + test/                      - EXぜろちゃんねる動作ディレクトリ  
    + *.cgi                   - 基本動作用CGI  
    + datas/                  - 初期データ・固定データ格納用  
    |  + 1000.txt  
    |  + 2000000000.dat  
    |  :  
    + info/
    |  + .auth/               - 認証情報保存ディレクトリ  
    |  + .ninpocho/           - 忍法帖保存ディレクトリ  
    |  + .session/            - セッション情報保存ディレクトリ
    |  + IP_List/             - IPリスト保存ディレクトリ  
    + module/  
    |  + *.pl                 - EXぜろちゃんねるモジュール  
    + admin/  
    |  + *.pl                 - 管理CGI用モジュール  
    + plugin/  
    |  + 0ch_*.pl             - プラグインスクリプト  
    + perllib/  
       \+ \*                    - EXぜろちゃんねるに必要なパッケージ  
         
------------
## Special Thanks  
精神衰弱 ◆kwSzvOHE氏  
windyakin ◆windyaking氏
