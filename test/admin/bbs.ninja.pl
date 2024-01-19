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
	
	if ($subMode eq 'SEARCH') {														# 検索
		$err = FunctionNinjaSearch($Sys, $Form, $this->{'LOG'}, 1);
	}
	elsif ($subMode eq 'SAVE') {													# 保存
		$err = FunctionNinjaSave($Sys, $Form, $this->{'LOG'}, 0);
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
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Ninja, $id, $subj, $res);
	my ($common, $text);
	use POSIX qw(strftime);

	$SYS->Set('_TITLE','Ninpocho Edit');

	my $isNinjaAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NINJAEDIT, $SYS->Get('BBS'));
	
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

	my $auth_time = $Ninja->Get('auth_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('auth_time')) : 'N/A';

	my $load_message = $Ninja->Get('load_message');
	my $load_from = $Ninja->Get('load_from');
	my $load_time = $Ninja->Get('load_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('load_time')) : 'N/A';
	my $load_bbsdir = $Ninja->Get('load_bbsdir');
	my $load_threadkey = $Ninja->Get('load_threadkey');
	my $load_count = $Ninja->Get('load_count');
	my $load_addr = $Ninja->Get('load_addr');
	my $load_host = $Ninja->Get('load_host');
	my $load_ua = $Ninja->Get('load_ua');

	my $last_addr = $Ninja->Get('last_addr');
	my $last_host = $Ninja->Get('last_host');
	my $last_ua = $Ninja->Get('last_ua');
	my $last_wtime = $Ninja->Get('last_wtime') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_wtime')) : 'N/A';
	my $last_makethread_time = $Ninja->Get('last_mthread_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_mthread_time')) : 'N/A';
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
	my $is_force_captcha = $Ninja->Get('force_captcha') ? 'checked' : '';

	my $password = $Ninja->Get('password');
	my $description = $Ninja->Get('user_desc');

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>ID:$sid\の忍法帖を確認します。(${SESSION_ATIME}時点)</td></tr>");
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");

	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■User Description</td></tr>\n");
	$Page->Print("<tr><td>説明</td>");
	$Page->Print("<td><input type=text size=60 name=DESCRIPTION value=\"$description\" maxlength=60></td></tr>\n");

	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■User Information</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">忍法帖ID</td><td>$ninID</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">忍法帖Lv</td><td>$lv</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">作成日時</td><td>$SESSION_CTIME</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">作成時の書き込み</td><td>$newmes</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">作成時のIP</td><td>$c_addr</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">作成時のHOST</td><td>$c_host</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">作成時のUA</td><td>$c_ua</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新書き込み日時</td><td>$last_wtime</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新書き込み</td><td>$last_message</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新IP</td><td>$last_addr</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新HOST</td><td>$last_host</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新UA</td><td>$last_ua</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">パスワード(Hash)</td><td>$password</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新ロード時刻</td><td>$load_time</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">ロード元の忍法帖ID</td><td>$load_from</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">ロード時の書き込み</td><td>$load_message</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新ロードIP</td><td>$load_addr</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新ロードHOST</td><td>$load_host</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">最新ロードUA</td><td>$load_ua</td></tr>\n");

	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■Statistics</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">書き込み数</td><td>$count</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">スレ立て数</td><td>$thread_count</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">忍法帖ロード回数</td><td>$load_count</td></tr>\n");

	$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">■Regulation</td></tr>\n");
	$Page->Print("<tr><td>書き込み禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN value=on $is_ban></td></tr>\n");
    $Page->Print("<tr><td>スレ立て禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_MTHREAD value=on $is_ban_mthread></td></tr>\n");
    $Page->Print("<tr><td>コマンド禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_COM value=on $is_ban_command></td></tr>\n");
    $Page->Print("<tr><td>URL禁止</td>");
	$Page->Print("<td><input type=checkbox name=BAN_URL value=on disabled></td></tr>\n");
    $Page->Print("<tr><td>強制sage</td>");
	$Page->Print("<td><input type=checkbox name=FORCE_SAGE value=on $is_force_sage></td></tr>\n");
	$Page->Print("<tr><td>ユーザー認証</td>");
	$Page->Print("<td><input type=checkbox name=IS_AUTH value=on $is_auth></td></tr>\n");
    $Page->Print("<tr><td>Captcha強制</td>");
	$Page->Print("<td><input type=checkbox name=FORCE_CAPTCHA value=on $is_force_captcha></td></tr>\n");
    $Page->Print("<tr><td>名無し強制</td>");
	$Page->Print("<td><input type=checkbox name=FORCE_774 value=on  $is_force_774></td></tr>\n");
    $Page->Print("<tr><td>強制コテ<small>(名無し強制優先、名前欄用コマンド使用可)</small></td>");
	$Page->Print("<td><input type=text name=FORCE_KOTE value=\"$is_force_kote\"></td></tr>\n");

    $Page->HTMLInput('hidden', 'SID', $sid);
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3>");
	$Page->Print('<input type=button value="　書き込みを検索　" disabled onclick="DoSubmit(\'sys.ninja\',\'DISP\',\'SEARCH\');">');
	$Page->Print('<input type=button value="　保存　" onclick="DoSubmit(\'sys.ninja\',\'FUNC\',\'SAVE\');" class="delete">') if $isNinjaAuth;
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");

}

sub FunctionNinjaSave
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Ninja);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_NINJAEDIT, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = qw(BAN BAN_MTHREAD BAN_COM BAN_URL FORCE_SAGE FORCE_774 FORCE_CAPTCHA FORCE_KOTE);
		foreach (@inList) {
			my $set = $Form->Get($_) ? '有効' : '無効';
			push @$pLog, "「$_」を${set}に設定";
		}
	}
	require './module/ninpocho.pl';
	$Ninja = NINPOCHO->new;
	$Ninja->LoadOnly($Sys,$Form->Get('SID'));
	
	$Ninja->Set('user_desc', $Form->Get('DESCRIPTION'));
	$Ninja->Set('ban', $Form->Get('BAN'));
	$Ninja->Set('ban_mthread', $Form->Get('BAN_MTHREAD'));
	$Ninja->Set('ban_command', $Form->Get('BAN_COM'));
	$Ninja->Set('ban_url', $Form->Get('BAN_URL'));
	$Ninja->Set('force_sage', $Form->Get('FORCE_SAGE'));
	$Ninja->Set('force_774', $Form->Get('FORCE_774'));
	$Ninja->Set('force_captcha', $Form->Get('FORCE_CAPTCHA'));
	$Ninja->Set('force_kote', $Form->Get('FORCE_KOTE'));
	$Ninja->Set('auth', $Form->Get('IS_AUTH'));
	
	$Ninja->SaveOnly();
	
	return 0;
}
#============================================================================================================
#	Module END
#============================================================================================================
1;
