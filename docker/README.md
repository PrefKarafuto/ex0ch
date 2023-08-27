## 使い方
### Perl版
プロジェクトのルートディレクトリで以下のコマンドを実行することでDocker上で掲示板を動かせます。
```
$ docker-compose -f docker-compose.perl.yml up
```

ソースコードを変更した際は、以下のコマンドを実行してください。
```
$ docker-compose -f docker-compose.perl.yml up --build
```
ブラウザで[http://localhost:8080/test/admin.cgi](http://localhost:8080/test/admin.cgi)にアクセスして、その後は`Readme.txt`に従ってください。
