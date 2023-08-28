FROM httpd:latest

#必要なperlのライブラリをインストール
RUN apt update && apt install libcgi-session-perl libwww-perl -y

#apacheの設定を転送
COPY ./docker/perl/httpd.conf /usr/local/apache2/conf/

#ルートパスで表示させるhtmlを転送
COPY ./docker/perl/index.html /usr/local/apache2/htdocs/

RUN chmod 707 /usr/local/apache2/htdocs/

#testディレクトリ下のファイルを転送
COPY ./test /usr/local/apache2/htdocs/test/

#パーミッションを設定するためのシェルスクリプトを転送
COPY ./docker/perl/permission.sh /home/

#パーミッションを設定
RUN /home/permission.sh