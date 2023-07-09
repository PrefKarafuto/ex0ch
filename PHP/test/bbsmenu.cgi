<?php
header('Content-Type: text/html; charset=Shift_JIS');

$system_dir = './test';
chdir($system_dir);

$SYS = new SYSTEM();
if($SYS->Init() != 0) {
    exit();
}

$time = getdate();
$time['year']++;
$time['mon']++;

$bbsmenu = getbbsmenu();
$url = $SYS->Get('SERVER');
$lastmodified = filemtime('./bbsmenu.cgi');

if($bbsmenu === null) {
    echo "BBSMENUがありません<br>\n";
    exit();
}

echo "<body style=\"border:0px solid #333; position:fixed; left:0em; top:0em; bottom:auto; width:12em; height:100%; z-index:1; margin:0; padding:0; color:#F33; background: #FFF; overflow-y: scroll;font-size:0.81em;\"><font size=\"2\">";
echo "<a href=\"$url\" target=\"_top\">TOP</a><br>";
echo "<a href=\"./search.cgi\" target=\"_top\">レス検索</a><br><br>";

foreach($bbsmenu as $category) {
    echo "<b>{$category['name']}</b><br>\n";
    
    foreach($category['list'] as $bbs) {
        echo "<a href=\"{$bbs['url']}\" target=\"_main\">{$bbs['name']}</a><br>\n";
    }
    
    echo "<br>\n";
}

echo "<b>他のサイト</b><br>";
echo "<a href=\"https://github.com/PrefKarafuto/New_0ch_Plus\" target=\"_top\">ぜろちゃんねるプラス</a><br><br>";
echo "<br>更新日<br>{$time['year']}/{$time['mon']}/{$time['mday']}";
echo "</font></body>";
exit();

function getbbsmenu()
{
    $SYS = new SYSTEM();
    if($SYS->Init() != 0) {
        return null;
    }
    
    $basedir = $SYS->Get('SERVER', '') . DATA_UTILS::MakePath($SYS->Get('CGIPATH', ''), $SYS->Get('BBSPATH', ''));
    
    $BBS = new BBS_INFO();
    $BBS->Load($SYS);
    
    $Category = new CATEGORY_INFO();
    $Category->Load($SYS);
    
    $catSet = $Category->GetKeySet();
    
    $bbsmenu = [];
    
    foreach($catSet as $catid) {
        $catData = [];
        
        $catData['name'] = $Category->Get('NAME', $catid);
        
        $bbslist = [];
        $catData['list'] = $bbslist;
        
        $bbsSet = $BBS->GetKeySet('CATEGORY', $catid);
        
        foreach($bbsSet as $bbsid) {
            $bbsData = [];
            
            $bbsData['name'] = $BBS->Get('NAME', $bbsid);
            
            $bbsDir = $BBS->Get('DIR', $bbsid);
            $bbsData['dir'] = $bbsDir;
            $bbsData['url'] = $basedir.'/'.$bbsDir;
            
            array_push($bbslist, $bbsData);
        }
        
        array_push($bbsmenu, $catData);
    }
    
    return $bbsmenu;
}
?>
