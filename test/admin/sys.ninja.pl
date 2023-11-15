#============================================================================================================
#
#	忍法帖管理 - ニンジャ モジュール ！作成中！
#	sys.thread.pl
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
		PrintNinjaEdit($Page, $Sys, $Form, 0);
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

	$Base->SetMenu('レス一覧へ戻る', "'thread.res','DISP','LIST'");
	$Base->SetMenu('スレッド一覧へ戻る', "'bbs.thread','DISP','LIST'");
	$Base->SetMenu('掲示板一覧へ戻る', "'sys.bbs','DISP','LIST'");

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
sub PrintNinpochoList
{
	my ($Page, $SYS, $Form) = @_;
	my (@threadSet, $ThreadNum, $key, $res, $file_name, $i);
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base);
	my ($common, $common2, $n, $Threads, $id, $mtime,$last_mod);
	
	$SYS->Set('_TITLE', 'Ninpocho List');
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 10);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $ThreadNum ? $ThreadNum : ($dispSt + $dispNum));
	
	# 権限取得(未実装)
	my $isNinjaView	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJAVIEW, $SYS->Get('BBS'));
	my $isNinjaEdit	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJAEDIT, $SYS->Get('BBS'));
	my $isNinjaDelete	= "";#$SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJADELETE, $SYS->Get('BBS'));
	
	# ヘッダ部分の表示
	$common = "DoSubmit('bbs.ninja','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3><b><a href=\"javascript:SetOption('DISPST', " . ($dispSt - $dispNum));
	$Page->Print(");$common\">&lt;&lt; PREV</a> | <a href=\"javascript:SetOption('DISPST', ");
	$Page->Print("" . ($dispSt + $dispNum) . ");$common\">NEXT &gt;&gt;</a></b>");
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表\示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"><a href=\"javascript:toggleAll('NINPOCHO')\">全</a></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:250px\">忍法帖ID</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30px\">最終更新</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:20px\">Level</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">書き込み内容を閲覧</td></tr>\n");

    my $infoDir = $SYS->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/";
    my @session_files = glob($ninDir.'cgisess_.*');
	
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$n		= $i + 1;
		$file_name		= $session_files[$i];
		$file_name	=~ /cgisses_(.*)/;
        $id = $1;
        $mtime = (stat($file_name))[9];
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
        $year += 1900;
        $mon++;
        $last_mod = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
		my $level = "";
		
		# 表示背景色設定
		#if ($Threads->GetAttr($id, 'stop')) { # use from 0.8.x
		#if ($isstop) {				$bgColor = '#ffcfff'; }	# 停止スレッド
		#elsif ($res > $resmax) {		$bgColor = '#cfffff'; }	# 最大数スレッド
		#elsif ($Threads->GetAttr($id, 'pass')) {$bgColor = '#cfcfff'; }	# パス設定スレッド
		#elsif (DAT::IsMoved("$base/$id.dat")) {	$bgColor = '#ffffcf'; }	# 移転スレッド
		#else {					$bgColor = '#ffffff'; }	# 通常スレッド
		
		$common = "\"javascript:SetOption('NINJA_ID','$id');";
		$common .= "DoSubmit('bbs.ninja','DISP','EDIT')\"";
		
		$Page->Print("<tr bgcolor=$bgColor>");
		$Page->Print("<td><input type=checkbox name=NINPOCHO value=$id></td>");
		if ($isNinjaEdit || $isNinjaView) {
			$Page->Print("<td>$n: <a href=$common>$id</a></td>");
		}
		else {
			$Page->Print("<td>$n: $id</td>");
		}
		$Page->Print("<td align=center>$last_mod</td><td align=center>$level</td>");
		$Page->Print("<td><a href=\"\">検索</a></td></tr>\n");
	}
	$common		= "onclick=\"DoSubmit('bbs.ninja','DISP'";
	$common2	= "onclick=\"DoSubmit('bbs.ninja','FUNC'";
	
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
sub PrintNinpochoEdit
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
# 作成中
#============================================================================================================
#	Module END
#============================================================================================================
1;
