# リネーム対応表
## moduleフォルダ  
パッケージ名は各ファイル名を大文字にしたものとし、1ファイル中に複数パッケージが含まれる場合は下表に記載する。
before|after|機能 (旧パッケージ名⇒現パッケージ名) 
---|---|---  
athelas     |plugin     |プラグイン管理  
baggins     |thread     |スレッド情報管理
---|---|BILBO⇒THREAD
---|---|FRODO⇒POOL_THREAD
balrogs     |search     |検索  
celeborn    |archive    |過去ログ管理  
cidr_list   |cidr_list   |携帯IPのCIDRチェック  
constant    |constant    |定数の定義情報  
denethor    |banner    |バナー管理  
earendil    |file_utils    |ファイル操作ユーティリティ  
elves       |security       |管理セキュリティの管理  
---|--- | GLORFINDEL⇒USER_INFO
---|--- | GILDOR⇒GROUP_INFO
---|---|  ARWEN⇒SECURITY
faramir     |user     |アクセスユーザ管理  
galagriel   |data_utils   |汎用データ変換・取得  
gandalf     |notice     |ユーザ通知管理  
gondor      |dat      |datファイル管理  
httpservice |http_service |httpサービス  
imrahil     |log     |ログ管理  
isildur     |setting     |SETTINGデータ管理  
legolas     |header_footer_meta     |ヘッダ・フッタ・META管理  
melkor      |system      |システムデータ管理  
nazguls     |bbs_info     |掲示板情報管理 
---|---|ANGMAR⇒CATEGORY_INFO
newrelease  |update_notice  |アップデート通知  
orald       |error_info       |エラー情報管理モジュール  
peregrin    |manager_log    |管理ログデータの管理  
radagast    |cookie    |cookie管理  
samwise     |form     |フォーム情報管理  
session     |session     |セッション管理  
thorin      |buffer_output      |バッファ出力管理  
ungoliants  |cap  |キャップ管理  
---|---|UNGOLIANT⇒CAP
---|---|SHELOB⇒CAP_GROUP
---|---|SECURITY⇒CAP_SECURITY
vara        |post_service        |掲示板書き込み支援  
varda       |bbs_service       |bbs.cgi支援  
wormtongue  |ng_word  |NGワード管理

## adminフォルダ（旧mordorフォルダ）
before 	|after| 	機能
--|--|--
sauron |	admin_cgi_base |	管理CGIのベース
