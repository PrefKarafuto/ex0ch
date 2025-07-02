# EXぜろちゃんねる
開発が凍結された「ぜろちゃんねるプラス」を有志で開発し、便利な機能を追加していくプロジェクトです。  
  
バグ報告・機能要望・その他サポート用のDiscordはこちら  
https://discord.gg/jXCUpTZgbE

Wikiページ  
https://github.com/PrefKarafuto/ex0ch/wiki  
  
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

## プラグインの互換性について  
[Wikiページ](https://github.com/PrefKarafuto/ex0ch/wiki/%E6%97%A7%E4%BB%95%E6%A7%98%E3%83%97%E3%83%A9%E3%82%B0%E3%82%A4%E3%83%B3%E3%81%AE%E5%AF%BE%E5%BF%9C%E3%81%AE%E3%83%92%E3%83%B3%E3%83%88)を参照。
  
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
