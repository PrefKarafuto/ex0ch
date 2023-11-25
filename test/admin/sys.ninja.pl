#============================================================================================================
#
#	忍法帖管理 - ニンジャ モジュール ！作成中！
#	sys.ninja.pl
#	---------------------------------------------------------------------------
#	2023.11.10 start
#
#============================================================================================================
package	MODULE;

use strict;
use utf8;
use open IO => ':encoding(cp932)';
use warnings;

#------------------------------------------------------------------------------------------------------------
#
#	コンストラクタ
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	モジュールオブジェクト
#
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($obj, @LOG);
	
	$obj = {
		'LOG'	=> \@LOG
	};
	bless $obj, $this;
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#
#	表示メソッド
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Form	FORM
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoPrint
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $BASE, $Page);
	
	require './admin/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	
	# 管理情報を登録
	$Sys->Set('ADMIN', $pSys);
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys);
	
	if ($subMode eq 'LIST') {														# 忍法帖一覧画面
		PrintNinjaList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'EDIT') {													# 忍法帖確認・編集画面
		PrintNinjaEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SEARCH') {													# 忍法帖確認・編集画面
		PrintNinjaSearch($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# 処理完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('忍法帖処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 処理失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	elsif ($subMode eq 'DELETE') {                                             # 忍法帖削除画面
        PrintNinjaDelete($Page, $Sys, $Form);
    }
	$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	$Page->HTMLInput('hidden', 'TARGET_THREAD', $Form->Get('TARGET_THREAD'));
	$BASE->Print($Sys->Get('_TITLE'), 1);
}

#------------------------------------------------------------------------------------------------------------
#
#	機能メソッド
#	-------------------------------------------------------------------------------------
#	@param	$Sys	SYSTEM
#	@param	$Form	FORM
#	@param	$pSys	管理システム
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub DoFunction
{
	my $this = shift;
	my ($Sys, $Form, $pSys) = @_;
	my ($subMode, $err);
	
	# 管理情報を登録
	$Sys->Set('ADMIN', $pSys);
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 0;
	
	if ($subMode eq 'DELETE') {														# 削除
		$err = FunctionNinjaDelete($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'SAVE') {													# 保存
		$err = FunctionNinjaSave($Sys, $Form, $this->{'LOG'}, 0);
	}
	elsif ($subMode eq 'BAN') {													# BAN
		$err = FunctionNinjaBan($Sys, $Form, $this->{'LOG'}, 1);
	}
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"THREAD($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"THREAD($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	$this->DoPrint($Sys, $Form, $pSys);
}

#------------------------------------------------------------------------------------------------------------
#
#	メニューリスト設定
#	-------------------------------------------------------------------------------------
#	@param	$Base	ADMIN_CGI_BASE
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub SetMenuList
{
	my ($Base, $pSys, $bbs) = @_;

	$Base->SetMenu('忍法帖を検索', "'sys.ninja','DISP','SEARCH'");

}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinjaList
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadSet, $ThreadNum, $key, $res, $file_name, $i);
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base);
	my ($common, $common2, $n, $Threads, $mtime,$last_mod);
	
	$SYS->Set('_TITLE', 'Ninpocho List');
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 10);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	my $infoDir = $SYS->Get('INFO');
	my $ninDir = ".$infoDir/.nin/"; #三男用忍法帖ディレクトリ。今後は.ninpochoに移行予定
    my @session_files = sort { (stat($b))[9] <=> (stat($a))[9] } glob($ninDir.'cgisess_*');
    my $sessnum = @session_files;
    $dispEd		= (($dispSt + $dispNum) > $sessnum ? $sessnum : ($dispSt + $dispNum));
	
	
	# 権限取得(未実装)
	my $isNinjaView	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJAVIEW, $SYS->Get('BBS'));
	my $isNinjaEdit	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJAEDIT, $SYS->Get('BBS'));
	my $isNinjaDelete	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJADELETE, $SYS->Get('BBS'));
	
	# ヘッダ部分の表示
	$common = "DoSubmit('sys.ninja','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3><b><a href=\"javascript:SetOption('DISPST', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('DISPST', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("忍法帖総数：$sessnum　");
	$Page->Print("表\示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"><a href=\"javascript:toggleAll('NINPOCHO')\">全</a></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250px\">忍法帖ID</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30px\">最終更新</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:20px\">Level</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">書き込み内容を閲覧</td></tr>\n");
    
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$n		= $i + 1;
		$file_name		= $session_files[$i];
		$file_name	=~ /cgisess_([0-9a-f]+)/;
        my $id = $1;
        $mtime = (stat($file_name))[9];
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
        $year += 1900;
        $mon++;
        $last_mod = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
		my $level = "";
		$common = "\"javascript:SetOption('NINJA_ID','$id');";
		$common .= "DoSubmit('sys.ninja','DISP','EDIT')\"";
		
		$Page->Print("<tr bgcolor=$bgColor>");
		$Page->Print("<td><input type=checkbox name=NINPOCHO value=$id></td>");
		$Page->Print("<td>$n: <a href=$common>$id</a></td>");
		$Page->Print("<td align=center>$last_mod</td><td align=center>$level</td>");
		$Page->Print("<td></td></tr>\n");# 検索
	}
	$common		= "onclick=\"DoSubmit('sys.ninja','DISP'";
	$common2	= "onclick=\"DoSubmit('sys.ninja','FUNC'";
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");
	$Page->Print("<input type=button value=\"一覧更新\" $common,'LIST')\"> ");
	$Page->Print("<input type=button value=\"　削除　\" $common2,'DELETE')\" class=\"delete\"> ") if ($isNinjaDelete);
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'NINJA_ID', '');
}

#------------------------------------------------------------------------------------------------------------
#
#	忍法帖編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinjaEdit
{
	my ($Page, $SYS, $Form, $mode) = @_;
	my (@threadList, $Ninja, $id, $subj, $res);
	my ($common, $text);
	
	$SYS->Set('_TITLE', ($mode ? 'Ninpocho Edit' : 'Ninpocho View'));
	$text = ($mode ? '編集' : '確認');
    my $isDisabled = $mode ? '' : 'disabled';   # 編集すべきでない項目
    my $isDisabledVmode = $mode == -1 ? '': 'disabled';    # 編集可の項目
	
	require './module/ninpocho.pl';
	$Ninja = NINPOCHO->new;
	
    my $sid = $Form->Get('NINJA_ID');
	$Ninja->LoadOnly($SYS,$sid);
	my $lv = $Ninja->Get('ninLv');
	my $count = $Ninja->Get('count');
	my $lvuptime = $Ninja->Get('lvuptime');

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>ID:$sid\の忍法帖を$text\します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
    $Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">ユーザー情報</td></tr>\n");
	$Page->Print("<tr><td>忍法帖ID</td>");
	$Page->Print("<td><input type=text size=60 name=NINID value=\"$sid\" $isDisabled></td></tr>\n");

    $Page->Print("<tr><td>忍法帖Lv</td>");
	$Page->Print("<td><input type=text size=60 name=NINLV value=\"$lv\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>説明</td>");
	$Page->Print("<td><input type=text size=60 name=DESCRIPTION value=\"\" $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>作成日時</td>");
	$Page->Print("<td><input type=text size=60 name=DATE value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時の書き込み内容</td>");
	$Page->Print("<td><input type=text size=60 name=MESSAGE value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>作成時のIPアドレス</td>");
	$Page->Print("<td><input type=text size=60 name=ADDR value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時のHOST</td>");
	$Page->Print("<td><input type=text size=60 name=HOST value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時のユーザーエージェント</td>");
	$Page->Print("<td><input type=text size=60 name=UA value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終更新日時</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_DATE value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新書き込み内容</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_MESSAGE value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>最新IPアドレス</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_ADDR value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新HOST</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_HOST value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新ユーザーエージェント</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_UA value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>パスワード</td>");
	$Page->Print("<td><input type=text size=60 name=LOAD_PASS value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>ロード元の忍法帖ID</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LOAD_ID value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終ロード時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LOAD value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>最終LvUp時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LVUP value=\"$lvuptime\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終注意時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_CAUTION value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終警告時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_WARN value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終規制時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_BAN value=\"\" $isDisabled></td></tr>\n");
	
	$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">統計</td></tr>\n");
	$Page->Print("<tr><td>書き込み数</td>");
	$Page->Print("<td><input type=text name=TOTAL_COUNT value=\"$count\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>スレ建て回数</td>");
	$Page->Print("<td><input type=text name=MAKE_THREAD_COUNT value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>経験値</td>");
	$Page->Print("<td><input type=text name=EXP value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>ゴールド</td>");
	$Page->Print("<td><input type=text name=GOLD value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>書き込み失敗回数</td>");
	$Page->Print("<td><input type=text name=FAILD_COUNT value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>スレ建て失敗回数</td>");
	$Page->Print("<td><input type=text name=FAILD_THREAD value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>コマンド発動回数</td>");
	$Page->Print("<td><input type=text name=COM_COUNT value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>IDなしスレ作成回数</td>");
	$Page->Print("<td><input type=text name=NOID_THREAD value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>ID変更スレ作成回数</td>");
	$Page->Print("<td><input type=text name=CHID_THREAD value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>忍法帖ロード回数</td>");
	$Page->Print("<td><input type=text name=LOAD_COUNT value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>注意回数</td>");
	$Page->Print("<td><input type=text name=CAUTION_COUNT value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>警告回数</td>");
	$Page->Print("<td><input type=text name=WARN_COUNT value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>規制回数</td>");
	$Page->Print("<td><input type=text name=BAN_COUNT value=\"\" $isDisabled></td></tr>\n");
	
	$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">規制</td></tr>\n");
	$Page->Print("<tr><td>書き込み禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_WRITE value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>スレ立て禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_THREAD value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>コマンド禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_COM value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>URL禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_URL value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>強制sage</td>");
	$Page->Print("<td><input type=checkbox name=BAN_SAGE value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>連投規制</td>");
	$Page->Print("<td><input type=text name=BAN_CONPIT value=\"\" $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>強制コテ</td>");
	$Page->Print("<td><input type=checkbox name=BAN_FORCE_KOTE value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>コテハン禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_KOTE value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>以下を名前欄に付加する<small>(名前欄用コマンド使用可)</small></td>");
	$Page->Print("<td><input type=text name=FORCE_KOTE_NAME value=\"\" $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>ホワイトリスト<small>(掲示板のディレクトリ名をコンマで区切って入力)</small></td>");
	$Page->Print("<td><input type=text name=WHITE_LIST value=\"\" $isDisabledVmode></td></tr>\n");

    $Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">その他</td></tr>\n");
	$Page->Print("<tr><td>忍法帖を更新しない</td>");
	$Page->Print("<td><input type=checkbox name=NO_UPDATE value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>規制無視</td>");
	$Page->Print("<td><input type=checkbox name=NO_LV value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>コマンド許可</td>");
	$Page->Print("<td><input type=checkbox name=ACCEPT_COM value=on $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>許可するコマンド一覧<small>(2進数ビットフラグで指定)</small></td>");
	$Page->Print("<td><input type=text name=COM_LIST value=\"\" $isDisabledVmode></td></tr>\n");

    $Page->HTMLInput('hidden', 'NINPOCHO', $id);
	$common = "DoSubmit('sys.ninja','FUNC','SAVE')";
	my $common2 = "DoSubmit('sys.ninja','DISP','SEARCH')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3 align=left>");
	$Page->Print('<input type=button value="書き込みを検索" disabled onclick=\"'.$common2.';\">');
	$Page->Print('<input type=button value="　保存　" disabled onclick=\"'.$common.';\">') ;#if $mode;
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");

}
sub PrintNinjaSearch
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
   
    $SYS->Set('_TITLE', 'Ninpocho Search');
   
    $Page->Print("<center><table border=0 cellspacing=2 width=\"100%\">\n");
    $Page->Print("  <tr><td colspan=2>以下の各条件に当てはまる忍法帖を検索します。</td></tr>\n");
    $Page->Print("  <tr><td colspan=2><hr></td></tr>\n");
    $Page->Print("  <tr>\n");
    $Page->Print("    <td class=\"DetailTitle\" style=\"width:150\">条件</td>\n");
    $Page->Print("    <td class=\"DetailTitle\">条件設定値</td></tr>\n");
    $Page->Print("</select></td></tr>\n");
    $Page->Print("<input type=hidden name=SBBS value=$id>");
    $Page->Print(<<HTML);
  <tr>
    <td>検索ワード</td>
    <td>
HTML
    $Page->Print("<input type=text disabled size=60 name=WORD onkeydown=\"go(event.keyCode);\" value=\"$sWORD\" accept-charset=\"Shift_JIS\">");
   
    $common = "DoSubmit('bbs.thread','DISP','AUTORESDEL')";
   
    $Page->Print(<<HTML);
    </td>
  </tr>
  <tr>
    <td>検索種別</td>
    <td>
      <input type="checkbox" name="TYPE" value="2" $cTYPE[1] checked disabled >？？？<br>
      <input type="checkbox" name="TYPE" value="1" $cTYPE[0] disabled>？？？<br>
      <input type="checkbox" name="TYPE" value="4" $cTYPE[2] disabled>？？？<br>
    </td>
  </tr>
  <tr>
    <td colspan=2><hr></td>
  </tr>
  <tr>
    <td colspan=2 align=right>
      <input type=button value="　検索　" onclick="$common" style="float: left;" disabled>
    </td>
  </tr>
</table>
HTML
   
    # 検索ワードがある場合は検索を実行する
    if ($Form->Get('WORD', '') ne '') {
        #Search($SYS, $Form, $Page,$BBS); #ここを実装する
    }
   
    $Page->Print("<script>function go(keyCode).
	{if(keyCode==13) DoSubmit('sys.ninja','DISP','SEARCH');.
	}</script>");

}
# 作成中
#============================================================================================================
#	Module END
#============================================================================================================
1;
