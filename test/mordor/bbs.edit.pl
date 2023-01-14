#============================================================================================================
#
#	掲示板管理 - 各種編集 モジュール
#	bbs.edit.pl
#	---------------------------------------------------------------------------
#	2004.06.23 start
#
#============================================================================================================
package	MODULE;

use strict;
#use warnings;

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
	my ($subMode, $BASE, $BBS, $Page);
	
	require './mordor/admin_cgi_base.pl';
	$BASE = ADMIN_CGI_BASE->new;
	$BBS = $pSys->{'AD_BBS'};
	
	# 掲示板情報の読み込みとグループ設定
	if (! defined $BBS){
		require './module/bbs_info.pl';
		$BBS = BBS_INFO->new;
		
		$BBS->Load($Sys);
		$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
		$pSys->{'SECINFO'}->SetGroupInfo($BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	}
	
	# 管理マスタオブジェクトの生成
	$Page		= $BASE->Create($Sys, $Form);
	$subMode	= $Form->Get('MODE_SUB');
	
	# メニューの設定
	SetMenuList($BASE, $pSys, $Sys->Get('BBS'));
	
	if ($subMode eq 'HEAD') {														# ヘッダ編集画面
		PrintHeaderEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'FOOT') {													# フッタ編集画面
		PrintFooterEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'META') {													# META編集画面
		PrintMETAEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'USER') {													# 規制ユーザ編集画面
		PrintValidUserEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'NGWORD') {													# NGワード編集画面
		PrintNGWordsEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'LAST') {													# 1001編集画面
		PrintLastEdit($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# 設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('各種編集処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 設定失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
	# 掲示板情報を設定
	$Page->HTMLInput('hidden', 'TARGET_BBS', $Form->Get('TARGET_BBS'));
	
	$BASE->Print($Sys->Get('_TITLE') . ' - ' . $BBS->Get('NAME', $Form->Get('TARGET_BBS')), 2);
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
	my ($subMode, $err, $BBS);
	
	require './module/bbs_info.pl';
	$BBS = BBS_INFO->new;
	
	# 管理情報を登録
	$BBS->Load($Sys);
	$Sys->Set('BBS', $BBS->Get('DIR', $Form->Get('TARGET_BBS')));
	$Sys->Set('ADMIN', $pSys);
	$pSys->{'SECINFO'}->SetGroupInfo($Sys->Get('BBS'));
	
	$subMode	= $Form->Get('MODE_SUB');
	$err		= 9999;
	
	if ($subMode eq 'HEAD') {														# ヘッダ編集
		$err = FunctionTextEdit($Sys, $Form, 1, $this->{'LOG'});
	}
	elsif ($subMode eq 'FOOT') {													# フッタ編集
		$err = FunctionTextEdit($Sys, $Form, 2, $this->{'LOG'});
	}
	elsif ($subMode eq 'META') {													# META編集
		$err = FunctionTextEdit($Sys, $Form, 3, $this->{'LOG'});
	}
	elsif ($subMode eq 'USER') {													# 規制ユーザ編集
		$err = FunctionValidUserEdit($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'NGWORD') {													# NGワード編集
		$err = FunctionNGWordEdit($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'LAST') {													# 1001編集
		$err = FunctionLastEdit($Sys, $Form, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "BBS_EDIT($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'), "BBS_EDIT($subMode)", 'COMPLETE');
		$Form->Set('MODE_SUB', 'COMPLETE');
	}
	
	$pSys->{'AD_BBS'} = $BBS;
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
	my ($bAuth) = 0;
	
	$Base->SetMenu('ヘッダの編集', "'bbs.edit','DISP','HEAD'");
	$Base->SetMenu('フッタの編集', "'bbs.edit','DISP','FOOT'");
	$Base->SetMenu('META情報の編集', "'bbs.edit','DISP','META'");
	$Base->SetMenu('<hr>', '');
	
	# 管理グループ設定権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_ACCESUSER, $bbs)) {
		$Base->SetMenu("規制ユーザの編集","'bbs.edit','DISP','USER'");
		$bAuth = 1;
	}
	# 管理グループ設定権限のみ
	if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_NGWORDS, $bbs)) {
		$Base->SetMenu("NGワードの編集","'bbs.edit','DISP','NGWORD'");
		$bAuth = 1;
	}
	if ($bAuth) {
		$Base->SetMenu('<hr>', '');
	}
	$Base->SetMenu('1001の編集', "'bbs.edit','DISP','LAST'");
	$Base->SetMenu('<hr>', '');
	$Base->SetMenu('システム管理へ戻る', "'sys.bbs','DISP','LIST'");
}

#------------------------------------------------------------------------------------------------------------
#
#	ヘッダ編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintHeaderEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Head, $Setting, $pHead, $common, $isAuth, $data);
	
	$SYS->Set('_TITLE', 'BBS Header Edit');
	
	require './module/setting.pl';
	require './module/header_footer_meta.pl';
	$Head = HEADER_FOOTER_META->new;
	$Setting = SETTING->new;
	$Head->Load($SYS, 'HEAD');
	$Setting->Load($SYS);
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_BBSEDIT, $SYS->Get('BBS'));
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>");
	$Page->Print("<tr><td colspan=2 align=center>");
	
	$data = $Form->Get('HEAD_TEXT', '');
	# ヘッダプレビュー表示
	if ($data ne '') {
		$Head->Set(\$data);
	}
	else {
		$pHead = $Head->Get();
		$data = join '', @$pHead;
	}
	
	# プレビューデータの作成
	my $PreviewPage = BUFFER->new;
	$Head->Print($PreviewPage, $Setting);
	$PreviewPage->{'BUFF'} = CreatePreviewData($PreviewPage->{'BUFF'});
	$Page->Merge($PreviewPage);
	
	$Page->Print("</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">内容編集</td><td>");
	$Page->Print("<textarea name=HEAD_TEXT rows=11 cols=80 wrap=off>");
	
	# ヘッダ内容テキストの表示
	$data =~ s/&/&amp;/g;
	$data =~ s/</&lt;/g;
	$data =~ s/>/&gt;/g;
	$Page->Print($data);
	
	$Page->Print("</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　変更　\" $common,'FUNC','HEAD')\"> ");
		$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','HEAD')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	フッタ編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintFooterEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Foot, $common, $isAuth, $data, $pFoot);
	
	$SYS->Set('_TITLE', 'BBS Footer Edit');
	
	require './module/header_footer_meta.pl';
	$Foot = HEADER_FOOTER_META->new;
	$Foot->Load($SYS, 'FOOT');
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_BBSEDIT, $SYS->Get('BBS'));
	
	$Page->Print("<table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>");
	$Page->Print("<tr><td colspan=2 style=\"background-image:url(./datas/default_bac.gif)\">");
	
	$data = $Form->Get('FOOT_TEXT', '');
	# フッタプレビュー表示
	if ($data ne '') {
		$Foot->Set(\$data);
	}
	else {
		$pFoot = $Foot->Get();
		$data = join '', @$pFoot;
	}
	
	# プレビューデータの作成
	my $PreviewPage = BUFFER->new;
	$Foot->Print($PreviewPage, undef);
	$PreviewPage->{'BUFF'} = CreatePreviewData($PreviewPage->{'BUFF'});
	$Page->Merge($PreviewPage);
	
	$Page->Print("</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">内容編集</td><td>");
	$Page->Print("<textarea name=FOOT_TEXT rows=11 cols=80 wrap=off>");
	
	# フッタ内容テキストの表示
	$data =~ s/&/&amp;/g;
	$data =~ s/</&lt;/g;
	$data =~ s/>/&gt;/g;
	$Page->Print($data);
	
	$Page->Print("</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　変更　\" $common,'FUNC','FOOT')\"> ");
		$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','FOOT')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	META情報編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintMETAEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Meta, $common, $isAuth, $data, $pMeta);
	
	$SYS->Set('_TITLE', 'BBS META Edit');
	
	require './module/header_footer_meta.pl';
	$Meta = HEADER_FOOTER_META->new;
	$Meta->Load($SYS, 'META');
	
	$pMeta = $Meta->Get();
	$data = join '', @$pMeta;
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_BBSEDIT, $SYS->Get('BBS'));
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">内容編集</td><td>");
	$Page->Print("<textarea name=META_TEXT rows=11 cols=80 wrap=off>");
	
	# フッタ内容テキストの表示
	$data =~ s/&/&amp;/g;
	$data =~ s/</&lt;/g;
	$data =~ s/>/&gt;/g;
	$Page->Print($data);
	
	$Page->Print("</textarea></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　変更　\" $common,'FUNC','META')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	アクセス規制ユーザ編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintValidUserEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($vUsers, $pUsers, $common, $isAuth, @kind);
	
	$SYS->Set('_TITLE', 'BBS Valid User Edit');
	
	require './module/user.pl';
	$vUsers = USER->new;
	$vUsers->Load($SYS);
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_ACCESUSER, $SYS->Get('BBS'));
	$pUsers = $vUsers->Get('USER');
	
	$kind[0] = $vUsers->Get('TYPE') eq 'disable' ? '' : 'selected';
	$kind[1] = $vUsers->Get('TYPE') eq 'enable' ? '' : 'selected';
	$kind[2] = $vUsers->Get('METHOD') eq 'disable' ? '' : 'selected';
	$kind[3] = $vUsers->Get('METHOD') eq 'host' ? '' : 'selected';
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">記法</td><td style=\"font-size: 14px\">");
	$Page->Print("・ホスト名(正規表\現)<br>");
	$Page->Print("<b style=\"margin-left: 20px\">\\.host\\d+\\.jp\$</b><br>");
	$Page->Print("・IPアドレス(範囲指定あり)<br>");
	$Page->Print("<b style=\"margin-left: 20px\">192.168.0.123</b><br>");
	$Page->Print("<b style=\"margin-left: 20px\">192.168.1.0-192.168.10.255</b><br>");
	$Page->Print("<b style=\"margin-left: 20px\">192.168.0.0/16</b><br>");
	$Page->Print("・端末固有番号<br>");
	$Page->Print("<b style=\"margin-left: 20px\">12345678901234_xx</b> (au)<br>");
	$Page->Print("<b style=\"margin-left: 20px\">AbCd123</b> (docomo)<br>");
	$Page->Print("<span style=\"margin-left: 20px\">その他</span><br>");
	$Page->Print("</td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">対象ホスト・<br>端末識別子一覧</td><td>");
	$Page->Print("<textarea name=VALID_USERS rows=10 cols=70 wrap=off>");
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	foreach (@$pUsers) {
		$Page->Print(&$sanitize($_)."\n");
	}
	
	$Page->Print("</textarea></td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">ユーザ種別</td><td>");
	$Page->Print("<select name=VALID_TYPE>");
	$Page->Print("<option value=enable $kind[0]>限定ユーザ</option>");
	$Page->Print("<option value=disable $kind[1]>規制ユーザ</option>");
	$Page->Print("</select></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">規制方法</td><td>");
	$Page->Print("<select name=VALID_METHOD>");
	$Page->Print("<option value=host $kind[2]>ホスト表\示</option>");
	$Page->Print("<option value=disable $kind[3]>書き込み不可</option>");
	$Page->Print("</select></td></tr>\n");
	
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　設定　\" $common,'FUNC','USER')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintNGWordsEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($Words, $pWords, $pRepls, $common, $isAuth, @kind);
	
	$SYS->Set('_TITLE', 'BBS NG Words Edit');
	
	require './module/ng_word.pl';
	$Words = NG_WORD->new;
	$Words->Load($SYS);
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_NGWORDS, $SYS->Get('BBS'));
	$pWords = $Words->Get('NGWORD');
	$pRepls = $Words->Get('REPLACE');
	
	$kind[0] = $Words->Get('METHOD', '') eq 'disable' ? 'selected' : '';
	$kind[1] = $Words->Get('METHOD', '') eq 'host' ? 'selected' : '';
	$kind[2] = $Words->Get('METHOD', '') eq 'delete' ? 'selected' : '';
	$kind[3] = $Words->Get('METHOD', '') eq 'substitute' ? 'selected' : '';
	$kind[4] = $Words->Get('SUBSTITUTE', '');
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">NGワード一覧");
	$Page->Print("<br><br>NGワード<br>NGワード&lt;&gt;置換文字列</td><td>");
	$Page->Print("<textarea name=NG_WORDS rows=10 cols=70 wrap=off>");
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	foreach my $i (0 .. $#$pWords) {
		$Page->Print(&$sanitize($pWords->[$i]));
		$Page->Print(&$sanitize('<>'.$pRepls->[$i])) if (defined $pRepls->[$i]);
		$Page->Print("\n");
	}
	
	$Page->Print("</textarea></td></tr>\n");
	
	$Page->Print("<tr><td class=\"DetailTitle\">NGワード処理</td><td>");
	$Page->Print("<select name=NG_METHOD>");
	$Page->Print("<option value=disable $kind[0]>書き込み不可</option>");
	$Page->Print("<option value=host $kind[1]>ホスト表\示</option>");
	$Page->Print("<option value=delete $kind[2]>NGワード削除</option>");
	$Page->Print("<option value=substitute $kind[3]>NGワード置換</option>");
	$Page->Print("</select></td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">デフォルト置換文字列</td><td>");
	$Page->Print("<input type=text name=NG_SUBSTITUTE value=\"$kind[4]\" size=60></td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　設定　\" $common,'FUNC','NGWORD')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	1001編集画面の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintLastEdit
{
	my ($Page, $SYS, $Form) = @_;
	my ($common, $isAuth, $data, $isLast, @elem, $path);
	my ($resmax, $resmax1, $resmaxz, $resmaxz1);
	
	$SYS->Set('_TITLE', 'BBS 1001 Edit');
	$Form->DecodeForm(1);
	
	require './module/setting.pl';
	my $Set = SETTING->new;
	$Set->Load($SYS);
	
	$resmax		= $Set->Get('BBS_RES_MAX') || $SYS->Get('RESMAX');
	$resmax1	= $resmax + 1;
	$resmaxz	= $resmax;
	$resmaxz1	= $resmax1;
	$resmaxz	=~ s/([0-9])/"\x82".chr(0x4f+$1)/eg; # 全角数字
	$resmaxz1	=~ s/([0-9])/"\x82".chr(0x4f+$1)/eg; # 全角数字
	
	$data = "$resmaxz1<><>Over $resmax Thread<>このスレッドは$resmaxzを超えました。<br>";
	$data .= 'もう書けないので、新しいスレッドを立ててくださいです。。。<>';
	if (! $Form->IsExist('LAST_FROM')) {
		# 1000.txtの読み込み
		$path = $SYS->Get('BBSPATH') . '/' . $SYS->Get('BBS') . '/1000.txt';
		$isLast = 0;
		
		if (open(my $f_last, '<', $path)) {
			flock($f_last, 2);
			while(<$f_last>) {
				$data = $_;
				last;
			}
			close($f_last);
			chomp $data;
			$isLast = 1;
		}
		@elem = split(/<>/, $data);
		$elem[3] = substr $elem[3], 1 if (substr($elem[3], 0, 1) eq ' ');
		$elem[3] = substr $elem[3], 0, -1 if (substr($elem[3], -1) eq ' ');
	}
	else {
		@elem = (
			$Form->Get('LAST_FROM', ''),
			$Form->Get('LAST_mail', ''),
			$Form->Get('LAST_date', ''),
			$Form->Get('LAST_MESSAGE', ''),
		);
		
		$isLast = 1 if ($elem[3] ne '');
		
		$elem[0] =~ s/\n//g;
		$elem[1] =~ s/\n//g;
		$elem[2] =~ s/\n//g;
		
		if ($Form->Equal('SANIT_NAME', 'on')) {
			$elem[0] =~ s/&/&amp;/g;
			$elem[0] =~ s/</&lt;/g;
			$elem[0] =~ s/>/&gt;/g;
		}
		
		if ($Form->Equal('SANIT_MAIL', 'on')) {
			$elem[1] =~ s/&/&amp;/g;
			$elem[1] =~ s/</&lt;/g;
			$elem[1] =~ s/>/&gt;/g;
			$elem[1] =~ s/"/&quot;/g;
		}
		
		if ($Form->Equal('SANIT_DATE', 'on')) {
			$elem[2] =~ s/&/&amp;/g;
			$elem[2] =~ s/</&lt;/g;
			$elem[2] =~ s/>/&gt;/g;
		}
		
		if ($Form->Equal('SANIT_TEXT', 'on')) {
			$elem[3] =~ s/&/&amp;/g;
			$elem[3] =~ s/</&lt;/g;
			$elem[3] =~ s/>/&gt;/g;
		}
		
		$elem[3] =~ s/\n/ <br> /g;
		$elem[0] =~ s/<>/&lt;&gt;/g;
		$elem[1] =~ s/<>/&lt;&gt;/g;
		$elem[2] =~ s/<>/&lt;&gt;/g;
		$elem[3] =~ s/<>/&lt;&gt;/g;
	}
	for (0 .. 4) {
		$elem[$_] = '' if (! defined $elem[$_]);
	}
	
	# 権限取得
	$isAuth = $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_BBSEDIT, $SYS->Get('BBS'));
	
	$Page->Print("<center><table border=0 cellspacing=2 width=100%>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>Preview</td></tr>");
	$Page->Print("<tr><td colspan=2><center><dl><table border cellspacing=7 bgcolor=#efefef width=100%>");
	$Page->Print("<tr><td>");
	
	# プレビュー表示
	$Page->Print("<dt>$resmax1 名前：<b><font color=green>$elem[0]</font></b>")			if ($elem[1] eq '');
	$Page->Print("<dt>$resmax1 名前：<b><a href=\"mailto:$elem[1]\">$elem[0]</a></b>")	if ($elem[1] ne '');
	$Page->Print("：$elem[2]</dt><dd>$elem[3]<br><br></dd>");
	@elem = ('', '', '', '', '') if (! $isLast);
	
	$elem[3] =~ s/ ?<br> ?/\n/g;
	for (0 .. 4) {
		$elem[$_] =~ s/&/&amp;/g;
		$elem[$_] =~ s/</&lt;/g;
		$elem[$_] =~ s/>/&gt;/g;
		$elem[$_] =~ s/"/&quot;/g;
	}
	
	$Page->Print("</td></tr></table></dl></td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\" colspan=2>内容編集</td></tr>");
	$Page->Print("<tr><td class=\"DetailTitle\">名前</td><td>");
	$Page->Print("<input type=text size=60 name=LAST_FROM value=\"$elem[0]\"><br>");
	$Page->Print("<input type=checkbox name=SANIT_NAME value=on>エスケープ(サニタイズ)を行う。無効でHTML直接編集</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">メール</td><td>");
	$Page->Print("<input type=text size=60 name=LAST_mail value=\"$elem[1]\"><br>");
	$Page->Print("<input type=checkbox name=SANIT_MAIL value=on>エスケープ(サニタイズ)を行う。無効でHTML直接編集</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">日付・ID</td><td>");
	$Page->Print("<input type=text size=60 name=LAST_date value=\"$elem[2]\"><br>");
	$Page->Print("<input type=checkbox name=SANIT_DATE value=on>エスケープ(サニタイズ)を行う。無効でHTML直接編集</td></tr>\n");
	$Page->Print("<tr><td class=\"DetailTitle\">本文</td><td>");
	$Page->Print("<textarea name=LAST_MESSAGE rows=10 cols=70 wrap=off>");
	$Page->Print("$elem[3]</textarea><br>");
	$Page->Print("<input type=checkbox name=SANIT_TEXT value=on>エスケープ(サニタイズ)を行う。無効でHTML直接編集</td></tr>\n");
	$Page->Print("<tr><td colspan=2><hr></td></tr>\n");
	
	# 権限によって表示を抑制
	if ($isAuth) {
		$common = "onclick=\"DoSubmit('bbs.edit'";
		$Page->Print("<tr><td colspan=2 align=left>");
		$Page->Print("<input type=button value=\"　変更　\" $common,'FUNC','LAST')\"> ");
		$Page->Print("<input type=button value=\"　確認　\" $common,'DISP','LAST')\">");
		$Page->Print("</td></tr>\n");
	}
	$Page->Print("</table><br>");
}

#------------------------------------------------------------------------------------------------------------
#
#	テキスト編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$mode	設定モード(1:HEAD 2:FOOT 3:META)
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionTextEdit
{
	my ($Sys, $Form, $mode, $pLog) = @_;
	my ($Texts, $readKey, $formKey, $value);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSEDIT, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	
	# 読み取り用のキーを設定する
	if ($mode == 1) {
		$readKey = 'HEAD';
		$formKey = 'HEAD_TEXT';
		push @$pLog, 'head.txtを設定しました。';
	}
	elsif ($mode == 2) {
		$readKey = 'FOOT';
		$formKey = 'FOOT_TEXT';
		push @$pLog, 'foot.txtを設定しました。';
	}
	elsif ($mode == 3) {
		$readKey = 'META';
		$formKey = 'META_TEXT';
		push @$pLog, 'meta.txtを設定しました。';
	}
	
	require './module/header_footer_meta.pl';
	$Texts = HEADER_FOOTER_META->new;
	$Texts->Load($Sys, $readKey);
	
	$value = $Form->Get($formKey);
	$Texts->Set(\$value);
	
	# 設定の保存
	$Texts->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	規制ユーザ編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionValidUserEdit
{
	my ($Sys, $Form, $pLog) = @_;
	my ($vUsers, @validUsers);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_ACCESUSER, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/user.pl';
	$vUsers = USER->new;
	$vUsers->Load($Sys);
	
	@validUsers = split(/\n/, $Form->Get('VALID_USERS'));
	$vUsers->Set('TYPE', $Form->Get('VALID_TYPE'));
	$vUsers->Set('METHOD', $Form->Get('VALID_METHOD'));
	
	$vUsers->Clear();
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	push @$pLog, '■以下のユーザを指定';
	foreach (@validUsers) {
		$vUsers->Add($_);
		push @$pLog, '　　' . &$sanitize($_);
	}
	push @$pLog, '■指定ユーザ種別：' . $Form->Get('VALID_TYPE');
	push @$pLog, '■指定ユーザ処置：' . $Form->Get('VALID_METHOD');
	
	$vUsers->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	NGワード編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionNGWordEdit
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Words, @ngWords);
	
	# 権限チェック
	{
		my $SEC = $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_NGWORDS, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	require './module/ng_word.pl';
	$Words = NG_WORD->new;
	$Words->Load($Sys);
	
	@ngWords = split(/\n/, $Form->Get('NG_WORDS'));
	$Words->Set('METHOD', $Form->Get('NG_METHOD'));
	$Words->Set('SUBSTITUTE', $Form->Get('NG_SUBSTITUTE'));
	
	$Words->Clear();
	
	my $sanitize = sub {
		$_ = shift;
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		return $_;
	};
	push @$pLog, '■NGワードとして以下を設定';
	foreach (@ngWords) {
		my ($word, $repl) = split(/<>/, $_, -1);
		if ($Words->Add($word, $repl)) {
			push @$pLog, '　　'.&$sanitize($word).(defined $repl ? &$sanitize("<>$repl") : '');
		}
	}
	push @$pLog, '■NGワード処置：' . $Form->Get('NG_METHOD');
	
	$Words->Save($Sys);
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	1001編集
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionLastEdit
{
	my ($Sys, $Form, $pLog) = @_;
	my ($Texts, $readKey, $formKey, $value, $lastPath, $name, $mail, $date, $cont, $forCheck);
	
	# 権限チェック
	{
		my $SEC	= $Sys->Get('ADMIN')->{'SECINFO'};
		my $chkID = $Sys->Get('ADMIN')->{'USER'};
		
		if (($SEC->IsAuthority($chkID, $ZP::AUTH_BBSEDIT, $Sys->Get('BBS'))) == 0) {
			return 1000;
		}
	}
	$Form->DecodeForm(1);
	
	# 1000.txtのパス
	$lastPath = $Sys->Get('BBSPATH') . '/' . $Sys->Get('BBS') . '/1000.txt';
	
	# フォーム情報の取得
	$name = $Form->Get('LAST_FROM', '');
	$mail = $Form->Get('LAST_mail', '');
	$date = $Form->Get('LAST_date', '');
	$cont = $Form->Get('LAST_MESSAGE', '');
	$forCheck = $name . $mail . $date . $cont;
	
	# 全て空欄の場合は1000.txtを削除しデフォルト1001を使用
	if ($forCheck eq ''){
		unlink $lastPath;
		push @$pLog, '■1000.txtを破棄してデフォルトの1001を使用します。';
	}
	# 値が設定された場合は1000.txtを作成する
	else {
		$name =~ s/\n//g;
		$mail =~ s/\n//g;
		$date =~ s/\n//g;
		
		if ($Form->Equal('SANIT_NAME', 'on')) {
			$name =~ s/&/&amp;/g;
			$name =~ s/</&lt;/g;
			$name =~ s/>/&gt;/g;
		}
		
		if ($Form->Equal('SANIT_MAIL', 'on')) {
			$mail =~ s/&/&amp;/g;
			$mail =~ s/</&lt;/g;
			$mail =~ s/>/&gt;/g;
			$mail =~ s/"/&quot;/g;
		}
		
		if ($Form->Equal('SANIT_DATE', 'on')) {
			$date =~ s/&/&amp;/g;
			$date =~ s/</&lt;/g;
			$date =~ s/>/&gt;/g;
		}
		
		if ($Form->Equal('SANIT_TEXT', 'on')) {
			$cont =~ s/&/&amp;/g;
			$cont =~ s/</&lt;/g;
			$cont =~ s/>/&gt;/g;
		}
		
		$cont =~ s/\n/ <br> /g;
		$name =~ s/<>/&lt;&gt;/g;
		$mail =~ s/<>/&lt;&gt;/g;
		$date =~ s/<>/&lt;&gt;/g;
		$cont =~ s/<>/&lt;&gt;/g;
		
		if (open(my $f_last, (-f $lastPath ? '+<' : '>'), $lastPath)) {
			flock($f_last, 2);
			seek($f_last, 0, 0);
			binmode($f_last);
			print $f_last "$name<>$mail<>$date<> $cont <>\n";
			truncate($f_last, tell($f_last));
			close($f_last);
		}
		
		push @$pLog, '■1000.txtを設定しました。';
	}
	
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	プレビューデータの作成
#	-------------------------------------------------------------------------------------
#	@param	$pData	作成元配列の参照
#	@return	プレビューデータの配列
#
#------------------------------------------------------------------------------------------------------------
sub CreatePreviewData
{
	my ($pData) = @_;
	my @temp;
	
	foreach (@$pData) {
		$_ =~ s/<[fF][oO][rR][mM].*?>/<!--form--><br>/g;
		$_ =~ s/<\/[fF][oO][rR][mM]>/<!--\/form--><br>/g;
		$_ =~ s/[nN][aA][mM][eE].*?=/_name_=/g;
		push @temp, $_;
	}
	return \@temp;
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
