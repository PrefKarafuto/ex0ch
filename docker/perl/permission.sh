#!/bin/sh

# パーミッションを設定するシェルスクリプト
# http://sourceforge.jp/projects/zerochplus/wiki/Permissionを参考にしました

#testディレクトリを置く場所
ROOT_DIR=/usr/local/apache2/htdocs

chmod 707 $ROOT_DIR/

chmod 705 $ROOT_DIR/test/

chmod 705 $ROOT_DIR/test/datas/
chmod 604 $ROOT_DIR/test/datas/*
chmod 600 $ROOT_DIR/test/datas/index.html

chmod 707 $ROOT_DIR/test/info/
chmod 604 $ROOT_DIR/test/info/.auth/*
chmod 604 $ROOT_DIR/test/info/.ninpocho/*
chmod 604 $ROOT_DIR/test/info/.session/*
chmod 604 $ROOT_DIR/test/info/IP_List/*
chmod 606 $ROOT_DIR/test/info/*cgi
chmod 600 $ROOT_DIR/test/info/index.html

chmod 705 $ROOT_DIR/test/module/
chmod 604 $ROOT_DIR/test/module/*.pl
chmod 600 $ROOT_DIR/test/module/index.html

chmod 705 $ROOT_DIR/test/plugin/
chmod 604 $ROOT_DIR/test/plugin/0ch_*.pl
chmod 600 $ROOT_DIR/test/plugin/index.html

chmod 707 $ROOT_DIR/test/plugin_conf/
chmod 606 $ROOT_DIR/test/plugin_conf/0ch_*.cgi
chmod 600 $ROOT_DIR/test/plugin_conf/index.html

chmod 705 $ROOT_DIR/test/perllib/
chmod 705 $ROOT_DIR/test/perllib/*/
chmod 604 $ROOT_DIR/test/perllib/*.*
chmod 600 $ROOT_DIR/test/perllib/index.html

chmod 705 $ROOT_DIR/test/template/*.tt
chmod 604 $ROOT_DIR/test/template/index.html

chmod 705 $ROOT_DIR/test/*.cgi
chmod 600 $ROOT_DIR/test/index.html
