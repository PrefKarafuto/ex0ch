## 使い方
### Perl版
プロジェクトのルートディレクトリで以下のコマンドを実行してDockerイメージを作成してください。
```
$ docker build -t 0ch_plus -f Dockerfile_perl .
```

次に以下のコマンドでイメージからコンテナを作成して掲示板を動かすことができます。ホスト側でリッスンするポート番号を変更したい場合は、`8080`の部分を書き換えて下さい。
```
$ docker run -p 8080:80 0ch_plus
```

ブラウザで[http://localhost:8080/test/admin.cgi](http://localhost:8080/test/admin.cgi)にアクセスして、その後は`Readme.txt`に従ってください。

