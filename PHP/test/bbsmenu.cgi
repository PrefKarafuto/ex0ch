<?php
// ブラウザにコンテンツタイプを伝える
header('Content-Type: text/html; charset=Shift_JIS');

// 現在の作業ディレクトリを変更する
$system_dir = './test';
chdir($system_dir);

// SYSTEMクラスのインスタンスを作成し、初期化する
$SYS = new SYSTEM();
if($SYS->Init() != 0) {
    exit();
}

// 現在の年月を取得し、1加算する
$time = getdate();
$time['year']++;
$time['mon']++;

// BBSメニューを取得する
$bbsmenu = getbbsmenu();
// サーバのURLを取得する
$url = $SYS->Get('SERVER');
// bbsmenu.cgiファイルの最終更新時刻を取得する
$lastmodified = filemtime('./bbsmenu.cgi');

// BBSメニューが存在しない場合、エラーメッセージを表示し、スクリプトを終了する
if($bbsmenu === null) {
    echo "BBSMENUがありません<br>\n";
    exit();
}

// HTML出力開始
echo "<body style=\"border:0px solid #333; position:fixed; left:0em; top:0em; bottom:auto; width:12em; height:100%; z-index:1; margin:0; padding:0; color:#F33; background: #FFF; overflow-y: scroll;font-size:0.81em;\"><font size=\"2\">";
echo "<a href=\"$url\" target=\"_top\">TOP</a><br>";
echo "<a href=\"./search.cgi\" target=\"_top\">レス検索</a><br><br>";

// BBSメニューの各カテゴリについて処理する
foreach($bbsmenu as $category) {
    echo "<b>{$category['name']}</b><br>\n";
    
    // 各カテゴリ内の各BBSについて処理する
    foreach($category['list'] as $bbs) {
        echo "<a href=\"{$bbs['url']}\" target=\"_main\">{$bbs['name']}</a><br>\n";
    }
    
    echo "<br>\n";
}

// 他のサイトへのリンクを表示する
echo "<b>他のサイト</b><br>";
echo "<a href=\"https://github.com/PrefKarafuto/New_0ch_Plus\" target=\"_top\">ぜろちゃんねるプラス</a><br><br>";
echo "<br>更新日<br>{$time['year']}/{$time['mon']}/{$time['mday']}";
echo "</font></body>";
exit();

// BBSメニューを取得する関数
function getbbsmenu()
{
    // SYSTEMクラスのインスタンスを作成し、初期化する
    $SYS = new SYSTEM();
    if($SYS->Init() != 0) {
        return null;
    }
    
    // ベースディレクトリのパスを作成する
    $basedir = $SYS->Get('SERVER', '') . DATA_UTILS::MakePath($SYS->Get('CGIPATH', ''), $SYS->Get('BBSPATH', ''));
    
    // BBS_INFOとCATEGORY_INFOクラスのインスタンスを作成し、ロードする
    $BBS = new BBS_INFO();
    $BBS->Load($SYS);
    
    $Category = new CATEGORY_INFO();
    $Category->Load($SYS);
    
    // カテゴリの一覧を取得する
    $catSet = $Category->GetKeySet();
    
    $bbsmenu = [];
    
    // 各カテゴリについて処理する
    foreach($catSet as $catid) {
        $catData = [];
        
        // カテゴリ名を取得する
        $catData['name'] = $Category->Get('NAME', $catid);
        
        $bbslist = [];
        $catData['list'] = $bbslist;
        
        // 指定したカテゴリに属するBBSの一覧を取得する
        $bbsSet = $BBS->GetKeySet('CATEGORY', $catid);
        
        // 各BBSについて処理する
        foreach($bbsSet as $bbsid) {
            $bbsData = [];
            
            // BBSの名前とディレクトリを取得する
            $bbsData['name'] = $BBS->Get('NAME', $bbsid);
            
            $bbsDir = $BBS->Get('DIR', $bbsid);
            $bbsData['dir'] = $bbsDir;
            // BBSへのURLを作成する
            $bbsData['url'] = $basedir.'/'.$bbsDir;
            
            // BBSの情報をリストに追加する
            array_push($bbslist, $bbsData);
        }
        
        // カテゴリの情報をメニューに追加する
        array_push($bbsmenu, $catData);
    }
    
    // 最終的に作成したメニューの情報を返す
    return $bbsmenu;
}
?>
