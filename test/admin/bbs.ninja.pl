#============================================================================================================
#
#	掲示板メニュー用忍法帖管理 - ニンジャ モジュール ！作成中！
#	bbs.ninja.pl
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
	
	if ($subMode eq 'EDIT') {													# 忍法帖確認・編集画面
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
	$BASE->Print($Sys->Get('_TITLE'), 4);
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
	use POSIX qw(strftime);

	$SYS->Set('_TITLE', ($mode ? 'Ninpocho Edit' : 'Ninpocho View'));
	$text = ($mode ? '編集' : '確認');
    my $isDisabled = $mode ? '' : 'disabled';   # 編集すべきでない項目
    my $isDisabledVmode = $mode == -1 ? '': 'disabled';    # 編集可の項目
	
	require './module/ninpocho.pl';
	$Ninja = NINPOCHO->new;
	
    my $sid = $Form->Get('NINJA_ID');
	$Ninja->LoadOnly($SYS,$sid);

	#既定で保存されるセッション情報
	my $SESSION_ID = $Ninja->Get('_SESSION_ID');
	my $SESSION_REMOTE_ADDR = $Ninja->Get('_SESSION_REMOTE_ADDR');
	my $SESSION_ATIME = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('_SESSION_ATIME'));
	my $SESSION_CTIME = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('_SESSION_CTIME'));
	
	#忍法帖の情報
	my $lv = $Ninja->Get('ninLv');
	my $count = $Ninja->Get('count');
	my $thread_count = $Ninja->Get('thread_count');
	my $lvuptime = $Ninja->Get('lvuptime');
	my $ninID = crypt($sid,$sid);

	my $newmes = $Ninja->Get('new_message');
	my $c_bbsdir = $Ninja->Get('c_bbsdir');
	my $c_threadkey = $Ninja->Get('c_threadkey');
	my $c_addr = $Ninja->Get('c_addr');
	my $c_host = $Ninja->Get('c_host');
	my $c_ua = $Ninja->Get('c_ua');

	my $load_message = $Ninja->Get('load_message');
	my $load_from = $Ninja->Get('load_from');
	my $load_time = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('load_time'));
	my $load_bbsdir = $Ninja->Get('load_bbsdir');
	my $load_threadkey = $Ninja->Get('load_threadkey');
	my $load_count = $Ninja->Get('load_count');
	my $load_addr = $Ninja->Get('load_addr');
	my $load_host = $Ninja->Get('load_host');
	my $load_ua = $Ninja->Get('load_ua');

	my $last_addr = $Ninja->Get('last_addr');
	my $last_host = $Ninja->Get('last_host');
	my $last_ua = $Ninja->Get('last_ua');
	my $last_wtime = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_wtime'));
	my $last_makethread_time = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_mthread_time'));
	my $last_message = $Ninja->Get('last_message');
	my $lasr_bbsdir = $Ninja->Get('last_bbsdir');
	my $last_threadkey = $Ninja->Get('last_threadkey');

	my $is_ban = $Ninja->Get('ban') ? 'checked' : '';
	my $is_ban_mthread = $Ninja->Get('ban_mthread') ? 'checked' : '';
	my $is_ban_command = $Ninja->Get('ban_command') ? 'checked' : '';
	my $is_force_sage = $Ninja->Get('force_sage') ? 'checked' : '';
	my $is_force_kote = $Ninja->Get('force_kote');
	my $is_force_774 = $Ninja->Get('force_774') ? 'checked' : '';
	my $is_auth = $Ninja->Get('auth') ? 'checked' : '';
	my $auth_time = strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('auth_time'));
	my $is_force_captcha = $Ninja->Get('force_captcha') ? 'checked' : '';

	my $password = $Ninja->Get('password');
	my $description = $Ninja->Get('user_desc');

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>ID:$sid\の忍法帖を$text\します。</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	
    $Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">ユーザー情報</td></tr>\n");
	$Page->Print("<tr><td>忍法帖ID</td>");
	$Page->Print("<td><input type=text size=60 name=NINID value=\"$ninID\" $isDisabled></td></tr>\n");

    $Page->Print("<tr><td>忍法帖Lv</td>");
	$Page->Print("<td><input type=text size=60 name=NINLV value=\"$lv\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>説明</td>");
	$Page->Print("<td><input type=text size=60 name=DESCRIPTION value=\"$description\" $isDisabledVmode></td></tr>\n");
    $Page->Print("<tr><td>作成日時</td>");
	$Page->Print("<td><input type=text size=60 name=DATE value=\"$SESSION_CTIME\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時の書き込み内容</td>");
	$Page->Print("<td><input type=text size=60 name=MESSAGE value=\"$newmes\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>作成時のIPアドレス</td>");
	$Page->Print("<td><input type=text size=60 name=ADDR value=\"$c_addr\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時のHOST</td>");
	$Page->Print("<td><input type=text size=60 name=HOST value=\"$c_host\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>作成時のユーザーエージェント</td>");
	$Page->Print("<td><input type=text size=60 name=UA value=\"$c_ua\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終更新日時</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_DATE value=\"$SESSION_ATIME\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>最新書き込み時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_DATE value=\"$last_wtime\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新書き込み内容</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_MESSAGE value=\"$last_message\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>最新IPアドレス</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_ADDR value=\"$last_addr\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新HOST</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_HOST value=\"$last_host\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最新ユーザーエージェント</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_UA value=\"$last_ua\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>パスワード</td>");
	$Page->Print("<td><input type=text size=60 name=LOAD_PASS value=\"$password\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>ロード元の忍法帖ID</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LOAD_ID value=\"$load_from\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終ロード時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LOAD value=\"$load_time\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>最終LvUp時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_LVUP value=\"$lvuptime\" $isDisabled></td></tr>\n");
=pod
    $Page->Print("<tr><td>最終注意時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_CAUTION value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終警告時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_WARN value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>最終規制時刻</td>");
	$Page->Print("<td><input type=text size=60 name=LAST_BAN value=\"\" $isDisabled></td></tr>\n");
=cut
	$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">統計</td></tr>\n");
	$Page->Print("<tr><td>書き込み数</td>");
	$Page->Print("<td><input type=text name=TOTAL_COUNT value=\"$count\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>スレ建て回数</td>");
	$Page->Print("<td><input type=text name=MAKE_THREAD_COUNT value=\"$thread_count\" $isDisabled></td></tr>\n");
=pod
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
=cut
    $Page->Print("<tr><td>忍法帖ロード回数</td>");
	$Page->Print("<td><input type=text name=LOAD_COUNT value=\"$load_count\" $isDisabled></td></tr>\n");
=pod
    $Page->Print("<tr><td>注意回数</td>");
	$Page->Print("<td><input type=text name=CAUTION_COUNT value=\"\" $isDisabled></td></tr>\n");
    $Page->Print("<tr><td>警告回数</td>");
	$Page->Print("<td><input type=text name=WARN_COUNT value=\"\" $isDisabled></td></tr>\n");
	$Page->Print("<tr><td>規制回数</td>");
	$Page->Print("<td><input type=text name=BAN_COUNT value=\"\" $isDisabled></td></tr>\n");
=cut
	$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">規制</td></tr>\n");
	$Page->Print("<tr><td>書き込み禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN value=on $isDisabledVmode $is_ban></td></tr>\n");
    $Page->Print("<tr><td>スレ立て禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_THREAD value=on $isDisabledVmode $is_ban_mthread></td></tr>\n");
    $Page->Print("<tr><td>コマンド禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_COM value=on $isDisabledVmode $is_ban_command></td></tr>\n");
=pod
    $Page->Print("<tr><td>URL禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_URL value=on $isDisabledVmode></td></tr>\n");
=cut
    $Page->Print("<tr><td>強制sage</td>");
	$Page->Print("<td><input type=checkbox name=FORCE_SAGE value=on $isDisabledVmode $is_force_sage></td></tr>\n");
    $Page->Print("<tr><td>Captcha強制</td>");
	$Page->Print("<td><input type=text name=FORCE_CAPTCHA value=on $isDisabledVmode $is_force_captcha></td></tr>\n");
    $Page->Print("<tr><td>名無し強制</td>");
	$Page->Print("<td><input type=checkbox name=FORCE_774 value=on $isDisabledVmode $is_force_774></td></tr>\n");
    $Page->Print("<tr><td>強制コテ<small>(名前欄用コマンド使用可)</small></td>");
	$Page->Print("<td><input type=text name=FORCE_KOTE value=\"$is_force_kote\" $isDisabledVmode></td></tr>\n");
=pod
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
=cut

    $Page->HTMLInput('hidden', 'NINPOCHO', $id);
	$common = "DoSubmit('sys.ninja','FUNC','SAVE')";
	my $common2 = "DoSubmit('sys.ninja','DISP','SEARCH')";
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3>");
	$Page->Print('<input type=button value="　書き込みを検索　" disabled onclick=\"'.$common2.';\">');
	$Page->Print('<input type=button value="　保存　" disabled onclick=\"'.$common.';\" class="delete">') ;#if $mode;
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");

}
# 作成中
#============================================================================================================
#	Module END
#============================================================================================================
1;
