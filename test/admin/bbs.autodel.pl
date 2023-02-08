#============================================================================================================
#
#   掲示板管理 - 一括レス削除 モジュール
#   bbs.autodel.pl
#   ---------------------------------------------------------------------------
#   2004.02.07 start
#
#============================================================================================================
package MODULE;
 
use strict;
use utf8;
binmode(STDOUT,":encoding(utf8)")
#use warnings;
#------------------------------------------------------------------------------------------------------------
#
#   レス一括削除設定画面表示
#   -------------------------------------------------------------------------------------
#   @param  $Page   ページコンテキスト
#   @param  $SYS    システム変数
#   @param  $Form   フォーム変数
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResAutoDelete
{
    my ($Page, $SYS, $Form, $BBS) = @_;
    my ($common);
    my ($name, $dir);
    my ($sMODE, $sBBS, $sKEY, $sWORD, @sTYPE, @cTYPE, $types, $BBSpath, @bbsSet, $id);
   
    my $sanitize = sub {
        $_ = shift;
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&#34;/g;#"
        return $_;
    };
   
    $sMODE  = "BBS";#&$sanitize($Form->Get('SMODE', ''));
    $sBBS = &$sanitize($Form->Get('SBBS', ''));
    $sKEY   = &$sanitize($Form->Get('KEY', ''));
    $sWORD  = &$sanitize($Form->Get('WORD'));
    @sTYPE  = $Form->GetAtArray('TYPE', 0);
    $id = $Form->Get('TARGET_BBS', '');
    $types = ($sTYPE[0] || 0) | ($sTYPE[1] || 0) | ($sTYPE[2] || 0);
    $cTYPE[0] = ($types & 1 ? 'checked' : '');
    $cTYPE[1] = ($types & 2 ? 'checked' : '');
    $cTYPE[2] = ($types & 4 ? 'checked' : '');
   
    $SYS->Set('_TITLE', 'Res Auto Delete');
   
    $Page->Print("<center><table border=0 cellspacing=2 width=\"100%\">\n");
    $Page->Print("  <tr><td colspan=2>以下の各条件に当てはまるレスを削除します。</td></tr>\n");
    $Page->Print("  <tr><td colspan=2><hr></td></tr>\n");
    $Page->Print("  <tr>\n");
    $Page->Print("    <td class=\"DetailTitle\" style=\"width:150\">条件</td>\n");
    $Page->Print("    <td class=\"DetailTitle\">条件設定値</td></tr>\n");
    $Page->Print("</select></td></tr>\n");
    $Page->Print("<input type=hidden name=SBBS value=$id>");
    $Page->Print(<<HTML);
  <!--<tr>
    <td>指定スレッドキー</td>
    <td><input type=text size=20 name=KEY value="$sKEY"></td>
  </tr>-->
  <tr>
    <td>検索ワード(正規表\現)</td>
    <td>
HTML
    $Page->Print("<input type=text size=60 name=WORD onkeydown=\"go(event.keyCode);\" value=\"$sWORD\" accept-charset=\"UTF-8\">");
   
    $common = "DoSubmit('bbs.thread','DISP','AUTORESDEL')";
   
    $Page->Print(<<HTML);
    </td>
  </tr>
  <tr>
    <td>検索種別</td>
    <td>
      <input type="checkbox" name="TYPE" value="2" $cTYPE[1] checked>本文検索<br>
      <input type="checkbox" name="TYPE" value="1" $cTYPE[0]>名前検索<br>
      <input type="checkbox" name="TYPE" value="4" $cTYPE[2]>ID・日付検索<br>
    </td>
  </tr>
  <tr>
    <td colspan=2><hr></td>
  </tr>
  <tr>
    <td colspan=2 align=right>
      <input type=button value="　検索　" onclick="$common" style="float: left;">
    </td>
  </tr>
</table>
HTML
   
    # 検索ワードがある場合は検索を実行する
    if ($Form->Get('WORD', '') ne '') {
        Search($SYS, $Form, $Page,$BBS); #ここを実装する
    }
   
    $Page->Print(<<HTML);
  <script>
    function go(keyCode){
      if(keyCode==13) DoSubmit('bbs.thread','DISP','AUTORESDEL');
    }
  </script>
HTML
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索結果出力 - Search
#   ------------------------------------------------
#   引　数：なし
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub Search
{
    my ($Sys, $Form, $Page,$BBS) = @_;
    my ($Search, $Mode, $Result, @elem, $n, $base, $word, $id, $dir);
    my (@types, $Type);
    my (@resList, %bbsCount, %threadCount);
   
    require './module/admin_search.pl';
    $Search = ADMIN_SEARCH->new;
   
    #$Mode = 0 if ($Form->Equal('SMODE', 'ALL'));
    #$Mode = 1 if ($Form->Equal('SMODE', 'BBS'));
    #$Mode = 2 if ($Form->Equal('SMODE', 'THREAD'));
    my $Mode = 1;
    #my $BBS = $Sys->Get('BBS');
   
    @types = $Form->GetAtArray('TYPE', 0);
    $Type = ($types[0] || 0) | ($types[1] || 0) | ($types[2] || 0);
   
    my $sanitize = sub {
        $_ = shift;
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        return $_;
    };
   
    $id = $Form->Get('SBBS', '');
    $dir = $BBS->Get('DIR', $id);
   
    # 検索オブジェクトの設定と検索の実行
    $Search->Create($Sys, $Mode, $Type, $id, $dir, $Form->Get('KEY', ''));
    $Search->Run(&$sanitize($Form->Get('WORD')));
   
    if ($@ ne '') {
        PrintSystemError($Page, $@);
        return;
    }
   
    # 検索結果セット取得
    $Result = $Search->GetResultSet();
    $n      = $Result ? @$Result : 0;
    $base   = $Sys->Get('BBSPATH');
    $word   = $Form->Get('WORD');
   
    PrintResultHead($Page, $n);
   
    # 検索ヒットが1件以上あり
    if ($n > 0) {
        require './module/data_utils.pl';
        my $Conv = DATA_UTILS->new;
        $n = 1;
        # スレッドごとにソート
        @resList = ();
        #threadCount
        foreach (@$Result) {
            @elem = split(/<>/);
            push @resList, [$elem[1], $_];
        }
       
        foreach (@$Result) {
            @elem = split(/<>/);
            #$Page->Print("<tr><td colspan=2 bgcolor=blue>$_</td></tr>");
 
            # Print BBS Header
            if (!$bbsCount{$elem[0]}++) {
                #PrintBBSHeader($Page, $BBS, $Conv, $n, $base, \@elem);
                %threadCount = ();
            }
            #PrintBBSHeader($Page, $BBS, $Conv, $n, $base, \@elem) if !$bbsCount{$elem[0]}++;
            PrintThreadHeader($Page, $Sys, $BBS, $Conv, $n, $base, \@elem) if !$threadCount{$elem[1]}++;
            PrintResult($Sys, $Page, $BBS, $Conv, $n, $base, \@elem);
            $n++;
        }
    }
    # 検索ヒット無し
    else {
        PrintNoHit($Page);
        $Page->Print("</table>\n");
        return;
    }
    if($Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))){
        PrintResultFoot($Page);
    }
    else{
        $Page->Print("</table>\n");
    }
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索結果ヘッダ出力 - PrintResultHead
#   ------------------------------------------------
#   引　数：Page : 出力モジュール
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResultHead
{
    my ($Page, $n) = @_;
   
    $Page->Print(<<HTML);
<style>
.res{   background-color: yellow;
        font-weight : bold;
}
</style>
<table border=0 cellspacing=2 width=100% align="center">
 <tr>
  <td colspan=2>
  <div class="hit" style="margin-top:1.2em;">
   <b>
   【ヒット数：$n】
   <font size="+0" color="red">検索結果</font>
   </b>
  </div>
  </td>
 </tr>
HTML
}
 
#------------------------------------------------------------------------------------------------------------
#
#   BBSごとのヘッダ出力 - PrintBBSHeader
#   ------------------------------------------------
#   引　数：Page : 出力モジュール
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintBBSHeader
{
    my ($Page, $BBS, $Conv, $n, $base, $pResult) = @_;
    my ($name, @bbsSet);
   
    #$BBS->GetKeySet('DIR', $$pResult[0], \@bbsSet);
    $name = $BBS->Get('NAME', $$pResult[0]);
   
    $Page->Print(<<HTML);
 <tr>
   <td colspan=2>
   </td>
 </tr>
HTML
}
 
#------------------------------------------------------------------------------------------------------------
#
#   スレッドごとのヘッダ出力 - PrintThreadHeader
#   ------------------------------------------------
#   引　数：Page : 出力モジュール
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintThreadHeader
{
    my ($Page, $SYS, $BBS, $Conv, $n, $base, $pResult) = @_;
    my ($Threads, $dir, $subj);
   
    require './module/thread.pl';
    $Threads = THREAD->new;
    $dir = $BBS->Get('DIR', $$pResult[0]);
    $SYS->Set('BBS', $dir);
    $Threads->Load($SYS);
   
    $subj = $Threads->Get('SUBJECT', $$pResult[1]);
    if (! ($subj =~ /[^\s　]/) || $subj eq '') {
        $subj = '(空欄もしくは空白のみ)';
        #$subj = $$pResult[1];
    }
   
    $Page->Print(<<HTML);
 <tr>
   <td colspan=2>
     <h1 style="color:#FF0000;font-size:larger;font-weight:normal;background-color:#efefef">$subj</h1>
   </td>
 </tr>
HTML
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索結果内容出力
#   -------------------------------------------------------------------------------------
#   @param  $Page   THORIN
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResult
{
    my ($Sys, $Page, $BBS, $Conv, $n, $base, $pResult) = @_;
    my ($bbsID, $bbsDir, $bbsName, @bbsSet, $value, $isAbone,$checkbox);
    $isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
    $checkbox = $isAbone ? '<td class=Response valign=top><input type=checkbox name=RESS value="$value" checked=checked></td>' : '';
    $bbsID = $$pResult[0];
    $bbsDir = $BBS->Get('DIR', $bbsID);
    $bbsName = $BBS->Get('NAME', $bbsID);
   
    if ($bbsID) {
        #$name = $BBS->Get('NAME', $bbsSet[0]);
        $value = "$bbsID/$$pResult[1]/$$pResult[2]";
       
        $Page->Print(<<HTML);
  <tr>
      $checkbox
    <td class=Response >
    <dt>
    <a target="_blank" href="./read.cgi/$bbsDir/$$pResult[1]/$$pResult[2]"> $$pResult[2]</a>：<b>
HTML
        if ($$pResult[4] eq '') {
            $Page->Print("<font color=\"green\">$$pResult[3]</font>");
        }
        else {
            $Page->Print("<a href=\"mailto:$$pResult[4]\">$$pResult[3]</a>");
        }
       
    $Page->Print(<<HTML);
 </b>：$$pResult[5]</dt>
    <dd>
    $$pResult[6]
    <br>
    </dd>
  </td>
</tr>
HTML
    }
}
 
#------------------------------------------------------------------------------------------------------------
#
#   検索結果フッタ出力
#   -------------------------------------------------------------------------------------
#   @param  $Page   THORIN
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResultFoot
{
    my ($Page) = @_;
    my ($common);
   
    $common = "onclick=\"DoSubmit('bbs.thread','DISP'"; #,'ABONELUMPRES')\"";
   
    $Page->Print(<<HTML);
  <tr>
    <td colspan=2 align=right>
      <input type=button value="　あぼ〜ん　" $common,'ABONELUMPRES')">
     <input type=button value="　透明あぼ〜ん　" $common,'DELLUMPRES')">
    </td>
  </tr>
HTML
    $Page->Print("</table>\n");
}
 
#------------------------------------------------------------------------------------------------------------
#
#   NoHit出力
#   -------------------------------------------------------------------------------------
#   @param  $Page   THORIN
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNoHit
{
    my ($Page) = @_;
   
    $Page->Print(<<HTML);
<dd>
 <br>
 <br>
<font size="+0" color="red">Hitなし</font><br>
 <br>
</dd>
HTML
}
 
#------------------------------------------------------------------------------------------------------------
#
#   レス一括削除確認画面
#   -------------------------------------------------------------------------------------
#   @param  $Page   ページコンテキスト
#   @param  $SYS    システム変数
#   @param  $Form   フォーム変数
#   @param  $Dat    dat変数
#   @return なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintResLumpDelete
{
    my ($Page, $Sys, $Form, $BBS, $mode) = @_;
    my (@valueSet, @bbsSet, @threadSet, @resSet, @elem, $pRes, $num, $common, $isAbone);
    my ($bbsID, $threadKey, $bbsResNum, @keyAndResSet, $keyAndRes, %wholeSet);
    my ($Threads, $DAT);
   
    require './module/thread.pl'; # read Threads
   
    $Sys->Set('_TITLE', 'Res Delete Confirm');
   
    %wholeSet = ();
    # 選択レスを取得
    #$wholeSet{12}{34} = (56, 78);
    #$wholeSet{12}{35} = (58, 79);
    #$Page->Print(%wholeSet."AA<br>");
    @valueSet = $Form->GetAtArray('RESS');
    foreach (@valueSet){
        ($bbsID, $threadKey, $bbsResNum) = split /\//;
        if (!exists($wholeSet{$bbsID}{$threadKey})){
            @{$wholeSet{$bbsID}{$threadKey}} = ();
        }
        push @{$wholeSet{$bbsID}{$threadKey}}, $bbsResNum;
    }
   
    # 権限取得
    $isAbone = $Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'));
   
    $Page->Print("<center><dl><table border=0 cellspacing=2 width=100%>");
    $Page->Print("<tr><td>以下のレスを" . ($mode ? 'あぼ〜ん' : '削除') . "します。</td></tr>\n");
    $Page->Print("<tr><td><hr></td></tr>\n");
    $Page->Print("<tr><td class=\"DetailTitle\">Contents</td></tr>\n");
   
    foreach my $bbsID (keys %wholeSet){
        my $bbsName = $BBS->Get('NAME', $bbsID);
        my $bbsDir = $BBS->Get('DIR', $bbsID);
        $Sys->Set('BBS', $bbsDir);
        $Page->Print("<tr><td><div class=\"FuncTitle\">$bbsName</div></td></tr>\n");
        foreach my $threadID (keys %{$wholeSet{$bbsID}}){
            $Threads = THREAD->new;
            $Threads->Load($Sys);
            my $threadSubj = $Threads->Get('SUBJECT', $threadID);
            if (! ($threadSubj =~ /[^\s　]/) || $threadSubj eq '') {
                $threadSubj = '(空欄もしくは空白のみ)';
            }
           
            # datの読み込み
            require './module/dat.pl';
            $DAT = DAT->new;
           
            $Sys->Set('KEY', $threadID);
            my $datPath = $Sys->Get('BBSPATH') . '/' . $bbsDir . '/dat/' . $threadID . '.dat';
            $DAT->Load($Sys, $datPath, 1);
            $Page->Print("<tr><td><h1 style=\"color:#FF0000;font-size:larger;font-weight:normal;background-color:#efefef\">$threadSubj</h1></td></tr>\n");
            foreach my $resNum (@{$wholeSet{$bbsID}{$threadID}}){
                my $pRes = $DAT->Get($resNum - 1);
                my $value = "$bbsID/$threadID/$resNum";
                if(!$pRes){
                    $Page->Print("<tr><td>Dat reading Error</td></tr>");
                    $Page->Print("<tr><td>$value</td></tr>");
                } else {
                @elem   = split(/<>/, $$pRes);
                $Page->Print("<tr><td class=\"Response\"><dt>" . ($resNum));
                $Page->Print("：<font color=forestgreen><b>$elem[0]</b></font>[$elem[1]]");
                $Page->Print("：$elem[2]</dt><dd>$elem[3]<br><br></dd></td></tr>\n");
                $Page->HTMLInput('hidden', 'RESS', $value);
                }
            }
        }
    }
    $Page->Print("<tr><td><hr></td></tr>\n");
   
    # システム権限有無による表示抑制
    if ($isAbone) {
        $common = "onclick=\"DoSubmit('bbs.thread','FUNC','";
        $common = $common . ($mode ? 'ABONELUMPRES' : 'DELLUMPRES') . "')\"";
        $Page->Print("<tr><td align=right>");
        $Page->Print("<input type=button value=\"　実行　\" $common> ");
        $Page->Print("</td></tr>\n");
    }
    $Page->Print("</table></dl><br>");
}
 
#------------------------------------------------------------------------------------------------------------
#
#   レス削除
#   -------------------------------------------------------------------------------------
#   @param  $Sys    システム変数
#   @param  $Form   フォーム変数
#   @param  $Dat    Dat変数
#   @param  $pLog   ログ用
#   @return エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionResLumpDelete
{
    my ($Sys, $Form, $pLog, $BBS, $mode) = @_;
    my (@resSet, $pRes, $abone, $path, $tm, $user, $delCnt, $num, $datPath, $LOG, $logsize, $lastnum);
    my (@valueSet, @bbsSet, @threadSet, @elem, $common, $isAbone);
    my ($bbsID, $threadKey, $bbsResNum, %wholeSet);
    my ($Threads, $Dat, $logMessage);
    my ($numResInLine); # ログで1行に表示するレスの数
    $numResInLine = 20;
    push @$pLog, '以下のレスを' . ($mode ? 'あぼ〜ん' : '削除') . 'しました。';
   
    require './module/thread.pl'; # read Threads
   
    %wholeSet = ();
    @valueSet = $Form->GetAtArray('RESS');
    foreach (@valueSet){
        #$Page->Print($_."<br>");
        ($bbsID, $threadKey, $bbsResNum) = split /\//;
        if (!exists($wholeSet{$bbsID}{$threadKey})){
            @{$wholeSet{$bbsID}{$threadKey}} = ();
        }
        push @{$wholeSet{$bbsID}{$threadKey}}, $bbsResNum;
    }
   
    foreach my $bbsID (keys %wholeSet){
        my $bbsName = $BBS->Get('NAME', $bbsID);
        my $bbsDir = $BBS->Get('DIR', $bbsID);
        $Sys->Set('BBS', $bbsDir);
        push @$pLog, 'BBS:'.$bbsName;
       
        # 権限チェック
        {
            my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
            my $chkID   = $Sys->Get('ADMIN')->{'USER'};
           
            if (($SEC->IsAuthority($chkID, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))) == 0) {
                return 1000;
            }
        }
       
        # あぼ〜ん時は削除名を取得
        if ($mode) {
            my $Setting;
            require './module/setting.pl';
            $Setting = SETTING->new;
            $Setting->Load($Sys);
            $abone  = $Setting->Get('BBS_DELETE_NAME');
        }
       
        foreach my $threadID (keys %{$wholeSet{$bbsID}}){
            $Sys->Set('KEY', $threadID);
            $Threads = THREAD->new;
            $Threads->Load($Sys);
            my $threadSubj = $Threads->Get('SUBJECT', $threadID);
            if (! ($threadSubj =~ /[^\s　]/) || $threadSubj eq '') {
                $threadSubj = '(空欄もしくは空白のみ)';
            }
           
            push @$pLog, '「'.$threadSubj.'」の';
           
            # datの読み込み
            require './module/dat.pl';
            $Dat = DAT->new;
           
            $Sys->Set('KEY', $threadID);
            my $datPath = $Sys->Get('BBSPATH') . '/' . $bbsDir . '/dat/' . $threadID . '.dat';
            $Dat->Load($Sys, $datPath, 1);
           
            if (!$mode) {
                require './module/manager_log.pl';
                $LOG = MANAGER_LOG->new;
                $LOG->Load($Sys, 'WRT', $Sys->Get('KEY'));
                $logsize = $LOG->Size();
                $lastnum = $Dat->Size() - 1;
            }
           
            # 各値を設定
            @resSet = @{$wholeSet{$bbsID}{$threadID}};
            $datPath= $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/dat/' . $Sys->Get('KEY') . '.dat';
            $path   = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/log/del_' . $Sys->Get('KEY') . '.cgi';
            $tm     = time;
            $user   = $Form->Get('UserName');
            $delCnt = 0;
           
            # datを書き込みモードで読み直す
            $Dat->Close();
            $Dat->Load($Sys, $datPath, 0);
           
            # ログの設定
            $delCnt = 0;
            $logMessage = '';
           
            # 削除と同時に削除ログへ削除した内容を保存する
            chmod($Sys->Get('PM-LOG'), $path);
            if (open(my $f_dellog, '>>:encoding(utf8)', $path)) {
                flock($f_dellog, 2);
                binmode($f_dellog);
                # レス番号が0から始まるようにする
                @resSet = map {$_ - 1} @resSet;
                foreach $num (sort {$b <=> $a} @resSet) {
                    next if ($num == 0);
                    if ($delCnt > $numResInLine) {
                        push @$pLog, $logMessage;
                        $logMessage = '';
                        $delCnt = 0;
                    }
                    else {
                        $logMessage .= ($num + 1) . ', ';
                        $delCnt ++;
                    }
                    $pRes = $Dat->Get($num);
                    print $f_dellog "$tm<>$user<>$num<>$mode<>$$pRes";
                    if ($mode) {
                        $Dat->Set($num, "$abone<>$abone<>$abone<>$abone<>$abone\n");
                    }
                    else {
                        $Dat->Delete($num);
                        $_ = $logsize - 1 + $num - $lastnum;
                        if ($_ >= 0) {
                            $LOG->Delete($_);
                            $logsize --;
                        }
                        $lastnum --;
                    }
                }
                push @$pLog, $logMessage;
                close($f_dellog);
                chmod($Sys->Get('PM-LOG'), $path);
               
                # 保存
                $Dat->Save($Sys);
                $LOG->Save($Sys) if (! $mode);
            }
        }
    }
   
   
    return 0;
}
 
#============================================================================================================
#   Module END
#============================================================================================================
1;


