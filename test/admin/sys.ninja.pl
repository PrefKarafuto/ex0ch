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
	elsif ($subMode eq 'SEARCH') {													# 忍法帖検索
		PrintNinjaSearch($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'NIN_SEARCH') {													# 忍法帖検索
		PrintNinjaSearchResult($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'SID_SEARCH') {												# セッションID検索
		PrintNinjaSidSearch($Page, $Sys, $Form);
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
	#$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	#$Page->HTMLInput('hidden', 'TARGET_THREAD', $Form->Get('TARGET_THREAD'));
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
		$err = FunctionNinjaDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'LIMDELETE') {													# BAN
		$err = FunctionNinjaLimDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'SAVE') {													# 保存
		$err = FunctionNinjaSave($Sys, $Form, $this->{'LOG'});
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
	my ($common, $common2, $n, $Threads, $mtime, $ctime, $last_mod, $crt_time);
	use POSIX qw(strftime);
	
	$SYS->Set('_TITLE', 'Ninpocho List');
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 10);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	my $infoDir = $SYS->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/"; 
	my @session_files = sort { (stat($b))[9] <=> (stat($a))[9] } glob($ninDir.'cgisess_*');
	my $sessnum = @session_files;
	$dispEd		= (($dispSt + $dispNum) > $sessnum ? $sessnum : ($dispSt + $dispNum));
	
	
	# 権限取得
	my $isAuth	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_SYSADMIN, '*');

	# ヘッダ部分の表示
	$common = "DoSubmit('sys.ninja','DISP','LIST');";
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%><tr><td colspan=3 style=\"font-size:1.2em\">");
	PrintPagenation($Page, $sessnum, $dispNum ,$dispSt, $common);
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("忍法帖総数：$sessnum　");
	$Page->Print("表示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:180px\">SessionID</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:10px\">Size</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:80px\">Last Update</td></tr>\n");
	
	for ($i = $dispSt ; $i < $dispEd ; $i++) {
		$n		= $i + 1;
		$file_name		= $session_files[$i];
		$file_name	=~ /cgisess_([0-9a-f]+)/;
		my $id = $1;
		$mtime = strftime "%Y-%m-%d %H:%M:%S", localtime((stat($file_name))[9]);
		my $size = (stat($file_name))[7];
		
		$Page->Print("<tr bgcolor=$bgColor>");
		if($isAuth){
			$Page->Print("<td><input type=checkbox name=NINPOCHO value=$id></td>");

			$common = "\"javascript:SetOption('NINJA_ID','$id');";
			$common .= "DoSubmit('sys.ninja','DISP','EDIT')\"";
			$Page->Print("<td>$n: <a href=$common>$id</a></td>");
		}else{
			$Page->Print("<td></td><td>$n: $id</td>");
		}
		$Page->Print("<td>$size</td><td>$mtime</td></tr>\n");
	}
	$common		= "onclick=\"DoSubmit('sys.ninja','DISP'";
	$common2	= "onclick=\"DoSubmit('sys.ninja','FUNC'";
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");
	$Page->Print("<input type=button value=\"一覧更新\" $common,'LIST')\"> ");
	$Page->Print("<input type=button value=\"　期限切れの忍法帖をクリア　\" $common2,'LIMDELETE')\"> ");
	$Page->Print("<input type=button value=\"　削除　\" $common2,'DELETE')\" class=\"delete\"> ") if ($isAuth);
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
	my ($Page, $SYS, $Form) = @_;
	my (@threadList, $Ninja, $id, $subj, $res);
	my ($common, $text);
	use POSIX qw(strftime);

	$SYS->Set('_TITLE','Ninpocho Edit');

	# 権限チェック
	{
		my $SEC	= $SYS->Get('ADMIN')->{'SECINFO'};
		my $chkID = $SYS->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	
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
	my $today_count = int(time / (60 * 60 * 24)) == int($Ninja->Get('last_wtime') / (60 * 60 * 24)) ? $Ninja->Get('today_count') : 0 ;
	my $thread_count = $Ninja->Get('thread_count');
	my $lvuptime = $Ninja->Get('lvuptime') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('lvuptime')) : '';
	my $ninID = crypt($sid,$sid);

	my $newmes = $Ninja->Get('new_message');
	my $c_bbsdir = $Ninja->Get('c_bbsdir');
	my $c_threadkey = $Ninja->Get('c_threadkey');
	my $c_addr = $Ninja->Get('c_addr');
	my $c_host = $Ninja->Get('c_host');
	my $c_ua = $Ninja->Get('c_ua');

	my $is_auth = $Ninja->Get('auth') ? '済み' : 'なし';
	my $auth_time = $Ninja->Get('auth_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('auth_time')) : '';

	my $load_message = $Ninja->Get('load_message');
	my $load_from = $Ninja->Get('load_from');
	my $load_time = $Ninja->Get('load_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('load_time')) : '';
	my $load_bbsdir = $Ninja->Get('load_bbsdir');
	my $load_threadkey = $Ninja->Get('load_threadkey');
	my $load_count = $Ninja->Get('load_count');
	my $load_addr = $Ninja->Get('load_addr');
	my $load_host = $Ninja->Get('load_host');
	my $load_ua = $Ninja->Get('load_ua');

	my $last_addr = $Ninja->Get('last_addr');
	my $last_host = $Ninja->Get('last_host');
	my $last_ua = $Ninja->Get('last_ua');
	my $last_wtime = $Ninja->Get('last_wtime') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_wtime')) : '';
	my $last_makethread_time = $Ninja->Get('last_mthread_time') ? strftime "%Y-%m-%d %H:%M:%S", localtime($Ninja->Get('last_mthread_time')) : '';
	my $last_message = $Ninja->Get('last_message');
	my $lasr_bbsdir = $Ninja->Get('last_bbsdir');
	my $last_threadkey = $Ninja->Get('last_threadkey');

	my $ban = $Ninja->Get('ban');
	my $selBanNone = $ban eq '' ? 'selected' : '';
	my $selBanEnable = $ban eq 'ban' ? 'selected' : '';
	my $selBanMakeThread = $ban eq 'thread' ? 'selected' : '';

	my $is_ban_command = $Ninja->Get('ban_command') ? 'checked' : '';
	my $is_force_sage = $Ninja->Get('force_sage') ? 'checked' : '';
	my $is_force_kote = $Ninja->Get('force_kote');
	my $is_force_774 = $Ninja->Get('force_774') ? 'checked' : '';
	my $is_force_captcha = $Ninja->Get('force_captcha') ? 'checked' : '';

	my $password = $Ninja->Get('password_is_randomized');
	my $description = $Ninja->Get('user_desc');

	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	if($SESSION_ID){
		$Page->Print("<tr><td colspan=3>ID:$sid\の忍法帖を確認します。(${SESSION_ATIME}時点)</td></tr>");
		$Page->Print("<tr><td colspan=3><hr></td></tr>\n");

		$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■User Description (Key)</td></tr>\n");
		$Page->Print("<tr><td>説明　(user_desc)</td>");
		$Page->Print("<td><input type=text size=60 name=DESCRIPTION value=\"$description\" maxlength=60></td></tr>\n");

		$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■User Information (Key)</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">忍法帖ID　(ninID)</td><td>$ninID</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">忍法帖Lv　(ninLv)</td><td>$lv</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">前回LvUP日時　(lvuptime)</td><td>$lvuptime</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">作成日時　(_SESSION_CTIME)</td><td>$SESSION_CTIME</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">作成時の書き込み　(new_message)</td><td>$newmes</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">作成時のIP　(c_addr)</td><td>$c_addr</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">作成時のHOST　(c_host)</td><td>$c_host</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">作成時のUA　(c_ua)</td><td>$c_ua</td></tr>\n");
		#$Page->Print("<tr><td class=\"DetailTitle\">ユーザー認証　(auth)</td><td>$is_auth</td></tr>\n");
		#$Page->Print("<tr><td class=\"DetailTitle\">最終認証日時　(auth_time)</td><td>$auth_time</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最終スレ立て日時　(last_mthread_time)</td><td>$last_makethread_time</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新書き込み日時　(last_wtime)</td><td>$last_wtime</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新書き込み　(last_message)</td><td>$last_message</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新IP　(last_addr)</td><td>$last_addr</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新HOST　(last_host)</td><td>$last_host</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新UA　(last_ua)</td><td>$last_ua</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">パスワードのハッシュ　(password)</td><td>$password</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新ロード時刻　(load_time)</td><td>$load_time</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">ロード元の忍法帖ID　(load_from)</td><td>$load_from</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">ロード時の書き込み　(load_message)</td><td>$load_message</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新ロードIP　(load_addr)</td><td>$load_addr</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新ロードHOST　(load_host)</td><td>$load_host</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">最新ロードUA　(load_ua)</td><td>$load_ua</td></tr>\n");

		$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>■Statistics (Key)</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">合計書き込み数　(count)</td><td>$count</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">今日の書き込み数</td><td>$today_count</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">スレ立て数　(thread_count)</td><td>$thread_count</td></tr>\n");
		$Page->Print("<tr><td class=\"DetailTitle\">忍法帖ロード回数　(load_count)</td><td>$load_count</td></tr>\n");

		$Page->Print("<tr bgcolor=silver><td colspan=2 class=\"DetailTitle\">■Regulation (Key)</td></tr>\n");
		$Page->Print("<tr><td>書き込み禁止　(ban)</td>");
		$Page->Print("<td><select name=BAN>");
		$Page->Print("<option value=\"\" $selBanNone>無効</option>");
		$Page->Print("<option value=ban $selBanEnable>有効</option>");
		$Page->Print("<option value=thread $selBanMakeThread>スレッド作成のみ禁止</option>");
		$Page->Print("</select></td></tr>\n");
		$Page->Print("<tr><td>コマンド禁止　(ban_command)</td>");
		$Page->Print("<td><input type=checkbox name=BAN_COM value=on $is_ban_command></td></tr>\n");
		$Page->Print("<tr><td>URL禁止　(ban_url)</td>");
		$Page->Print("<td><input type=checkbox name=BAN_URL value=on disabled></td></tr>\n");
		$Page->Print("<tr><td>強制sage　(force_sage)</td>");
		$Page->Print("<td><input type=checkbox name=FORCE_SAGE value=on $is_force_sage></td></tr>\n");
		$Page->Print("<tr><td>Captcha強制　(force_captcha)</td>");
		$Page->Print("<td><input type=checkbox name=FORCE_CAPTCHA value=on $is_force_captcha></td></tr>\n");
		$Page->Print("<tr><td>名無し強制　(force_774)</td>");
		$Page->Print("<td><input type=checkbox name=FORCE_774 value=on  $is_force_774></td></tr>\n");
		$Page->Print("<tr><td>強制コテ　(force_kote)<small>(名無し強制優先、名前欄用コマンド使用可)</small></td>");
		$Page->Print("<td><input type=text name=FORCE_KOTE value=\"$is_force_kote\"></td></tr>\n");
	}else{
		$Page->Print("<tr><td colspan=3>ID:$sid\の忍法帖データは存在しません。</td></tr>");
	}

	$Page->HTMLInput('hidden', 'SID', $sid);
	
	$Page->Print("<tr><td colspan=3><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=3>");
	$Page->Print('<input type=button value="　書き込みを検索　" onclick="DoSubmit(\'sys.ninja\',\'DISP\',\'SID_SEARCH\');">');
	$Page->Print('<input type=button value="　保存　" onclick="DoSubmit(\'sys.ninja\',\'FUNC\',\'SAVE\');" class="delete">') ;#if $mode;
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");

}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖検索画面 - PrintNinjaSearch
#   ------------------------------------------------
#   引　数：なし
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinjaSearch
{
	my ($Page, $SYS, $Form, $BBS) = @_;
	my ($sKEY, $sWORD);
   
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;#"
		return $_;
	};
   
	$sKEY   = &$sanitize($Form->Get('KEY', ''));
	$sWORD  = &$sanitize($Form->Get('WORD'));
   
	$SYS->Set('_TITLE', 'Ninpocho Search');
   
	$Page->Print("<center><table border=0 cellspacing=2 width=\"100%\">\n");
	$Page->Print("  <tr><td colspan=2>以下の条件に当てはまる忍法帖を検索します。</td></tr>\n");
	$Page->Print("  <tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("  <tr>\n");
	$Page->Print("    <td class=\"DetailTitle\" style=\"width:150\">条件</td>\n");
	$Page->Print("    <td class=\"DetailTitle\">条件設定値</td></tr>\n");
	$Page->Print("</td></tr>\n");
	$Page->Print(<<HTML);
  <tr>
	<td>検索キー</td>
	<td>
	<input type=text size=20 name=KEY onkeydown="go(event.keyCode);" value="$sKEY">
	</td>
  </tr>
  <tr>
	<td>検索ワード</td>
	<td>
	  <input type=text size=60 name=WORD onkeydown="go(event.keyCode);" value="$sWORD">
	</td>
  </tr>
  <tr>
	<td colspan=2><hr></td>
  </tr>
  <tr>
	<td colspan=2 align=right>
	  <input type=button value="　検索　" onclick="DoSubmit('sys.ninja','DISP','NIN_SEARCH')" style="float: left;">
	</td>
  </tr>
</table>
HTML
   
	# 検索ワードがある場合は検索を実行する
	if ($Form->Get('WORD', '') ne '') {
		#Search($SYS, $Form, $Page,$BBS); #ここを実装する
	}
   
	$Page->Print("<script>function go(keyCode).
	{if(keyCode==13) DoSubmit('sys.ninja','DISP','NIN_SEARCH');.
	}</script>");

}

#------------------------------------------------------------------------------------------------------------
#
#   忍法帖検索結果出力 - PrintNinjaSearchResult
#   ------------------------------------------------
#   引　数：なし
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinjaSearchResult
{
	my ($Page, $Sys, $Form) = @_;
	my ($Search, $Mode, $Result, @elem, $BBS, $n, $base, $word, $id, $key);
	my (@types, $Type);
	my (@resList, %bbsCount, %threadCount);

	$Sys->Set('_TITLE','Ninpocho Search');
   
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&#34;/g;#"
		return $_;
	};
   
	require './module/admin_search.pl';
	$Search = ADMIN_SEARCH->new;
	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	$BBS->Load($Sys);
	$word   = &$sanitize($Form->Get('WORD'));
	$key = &$sanitize($Form->Get('KEY'));
	
   
	# 検索オブジェクトの設定と検索の実行
	$Search->Create($Sys, 3);
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>Key:[$key] Word:[$word] の忍法帖検索結果</td></tr>");
	if ($@ ne '') {
		PrintSystemError($Page, $@);
		return;
	}

	# 検索結果セット取得
	if($key ne 'ninID' && $word){
		$Result = $Search->NinSearch($Form->Get('KEY'),$Form->Get('WORD'),undef);
	}elsif((!$key && $word =~ /[0-9a-f]{32}/) || ($key eq 'ninID' && length($word) == 13)){
		$Result = $Search->NinSearch(undef,undef,$Form->Get('WORD'));
	}
	
	$n      = $Result ? @$Result : 0;
	my $res = $Result->[0];
	# 検索ヒットが1件以上あり
	if ($n > 0) {
		my $dispNum	= $Form->Get('DISPNUM', 10);
		my $dispSt		= $Form->Get('DISPST', 0) || 0;
		$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
		my $infoDir = $Sys->Get('INFO');
		my $ninDir = ".$infoDir/.ninpocho/"; 
		my @session_files = @$Result;
		my $dispEd		= (($dispSt + $dispNum) > $n ? $n : ($dispSt + $dispNum));
		
		# ヘッダ部分の表示
		my $common = "DoSubmit('sys.ninja','DISP','NIN_SEARCH');";
		
		$Page->Print("<center><table border=0 cellspacing=2 width=100%><tr><td colspan=3 style=\"font-size:1.2em\">");
		PrintPagenation($Page, $n, $dispNum ,$dispSt, $common);
		$Page->Print("</td><td colspan=2 align=right>");
		$Page->Print("合計：$n");
		$Page->Print("表示数<input type=text name=DISPNUM size=4 value=$dispNum>");
		$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
		$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
		$Page->Print("<tr><th style=\"width:30px\"></th>");
		$Page->Print("<td class=\"DetailTitle\" style=\"width:180px\">SessionID</td>");
		$Page->Print("<td class=\"DetailTitle\" style=\"width:10px\">Size</td>");
		$Page->Print("<td class=\"DetailTitle\" style=\"width:80px\">Last Update</td></tr>\n");

		for (my $i = $dispSt ; $i < $dispEd ; $i++) {
			my $id = $session_files[$i];
			my $num = $i + 1;
			my $file_name		= '.'.$Sys->Get('INFO').'/.ninpocho/cgisess_'.$id;
			my $mtime = strftime "%Y-%m-%d %H:%M:%S", localtime((stat($file_name))[9]);
			my $size = (stat($file_name))[7];

			$Page->Print("<tr>");
			$Page->Print("<td><input type=checkbox name=NINPOCHO value=$id></td>");
			$common = "\"javascript:SetOption('NINJA_ID','$id');";
			$common .= "DoSubmit('sys.ninja','DISP','EDIT')\"";
			$Page->Print("<td>$num: <a href=$common>$id</a></td>");
			$Page->Print("<td>$size</td><td>$mtime</td></tr>\n");
		}
	}
	# 検索ヒット無し
	else {
		PrintNoHit($Page);
		$Page->Print("</table>\n");
		return;
	}
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'NINJA_ID', '');
	$Page->HTMLInput('hidden', 'KEY', $Form->Get('KEY'));
	$Page->HTMLInput('hidden', 'WORD', $Form->Get('WORD'));
	if($Sys->Get('ADMIN')->{'SECINFO'}->IsAuthority($Sys->Get('ADMIN')->{'USER'}, $ZP::AUTH_RESDELETE, $Sys->Get('BBS'))){
		$Page->Print(<<HTML);
  <tr>
	<td colspan=4 align=right>
	<hr>
	<br>
	 <input type=button value="　削除　" disabled onclick="DoSubmit('sys.ninja','FUNC','DELNINJA')" class="delete">
	</td>
  </tr>
HTML
	}
	$Page->Print("</table>\n");
}
 
#------------------------------------------------------------------------------------------------------------
#
#   書き込み履歴検索結果出力 - PrintNinjaSidSearch
#   ------------------------------------------------
#   引　数：なし
#   戻り値：なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNinjaSidSearch
{
	my ($Page, $Sys, $Form) = @_;
	my ($Search, $Mode, $Result, @elem, $BBS, $n, $base, $word, $id, $sid, $dir);
	my (@types, $Type);
	my (@resList, %bbsCount, %threadCount);

	$Sys->Set('_TITLE','User Writing History');
   
	require './module/admin_search.pl';
	$Search = ADMIN_SEARCH->new;
	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	$BBS->Load($Sys);
	
	$sid = $Form->Get('SID');
   
	# 検索オブジェクトの設定と検索の実行
	$Search->Create($Sys, 0);
	$Search->Run_LogS(undef,undef,undef,$sid);
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=3>SessionID:$sid\のユーザーの書き込み履歴を表示します。</td></tr>");
   
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
 
			# Print BBS Header
			if (!$bbsCount{$elem[0]}++) {
				PrintBBSHeader($Page, $BBS, $Conv, $n, $base, \@elem);
				%threadCount = ();
			}
			PrintBBSHeader($Page, $BBS, $Conv, $n, $base, \@elem) if !$bbsCount{$elem[0]}++;
			PrintThreadHeader($Page, $Sys, $BBS, $Conv, $n, $base, \@elem) if !$threadCount{$elem[1]}++;
			PrintResult($Sys, $Page, $BBS, $Conv, $n, $base, \@elem);
			$n++;
		}
		$Page->HTMLInput('hidden', 'TARGET_BBS', '');
		$Page->HTMLInput('hidden', 'TARGET_THREAD', '');
		$Page->HTMLInput('hidden', 'DISP_FORMAT', '');
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
   
	$BBS->GetKeySet('DIR', $$pResult[0], \@bbsSet);
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
	$bbsID = $$pResult[0];
	$bbsDir = $BBS->Get('DIR', $bbsID);
	$bbsName = $BBS->Get('NAME', $bbsID);
	
	$Page->Print("<tr><td class=Response valign=top>");
	if ($bbsID) {
	#$name = $BBS->Get('NAME', $bbsSet[0]);
	$value = "$bbsID/$$pResult[1]/$$pResult[2]";
		if($isAbone && $$pResult[2]!=1){
			$Page->Print("<input type=checkbox name=RESS value=\"$value\">");
		}
	$Page->Print(<<HTML);
	</td>
	<td class=Response >
	<dt>
	<a href="javascript:SetOption('TARGET_BBS', '$$pResult[0]');('TARGET_THREAD', '$$pResult[1]');SetOption('DISP_FORMAT', '$$pResult[2]');DoSubmit('thread.res','DISP','LIST');"> $$pResult[2]</a>：<b>
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
	<hr>
	<br>
	  <input type=button value="　あぼ～ん　" $common,'ABONELUMPRES')">
	 <input type=button value="　透明あぼ～ん　" $common,'DELLUMPRES')">
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
sub FunctionNinjaDelete
{
	my ($Sys, $Form, $pLog) =@_;
	require './module/ninpocho.pl';

	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}

	my $Ninja = NINPOCHO->new;
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/"; 
	my @ninList = $Form->GetAtArray('NINPOCHO');
	my $count = @ninList;

	my $result = $Ninja->Delete($Sys,\@ninList);

	push @$pLog, $count == $result ? "${result}個の忍法帖を削除": "選択された${count}個中${result}個の忍法帖を削除";

	return 0;
}
sub FunctionNinjaLimDelete
{
	my ($Sys, $Form, $pLog) =@_;
	require './module/ninpocho.pl';
	my $Ninja = NINPOCHO->new;
	my $infoDir = $Sys->Get('INFO');
	my $ninDir = ".$infoDir/.ninpocho/"; 
	my @session_files = sort { (stat($b))[9] <=> (stat($a))[9] } glob($ninDir.'cgisess_*');
	my $sessnum = @session_files;
	my $count = 0;

	foreach my $sid(@session_files){
		$sid =~ s/^cgisess_//;
		unless($Ninja->LoadOnly($Sys,$sid)){
			$count++;
		}
	}
	push @$pLog, "${count}/${sessnum}の忍法帖が期限切れ削除";

	return 0;
}
sub FunctionNinjaSave
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Ninja);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_SYSADMIN, '*')) == 0) {
			return 1000;
		}
	}
	# 入力チェック
	{
		my @inList = qw(BAN BAN_COM BAN_URL FORCE_SAGE FORCE_774 FORCE_CAPTCHA FORCE_KOTE);
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
