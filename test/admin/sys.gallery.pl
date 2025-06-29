#============================================================================================================
#
#	画像管理 - API設定 モジュール
#	sys.gallery.pl
#	---------------------------------------------------------------------------
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
		'LOG' => \@LOG
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
	
	if ($subMode eq 'LIST') {														# アップロード一覧
		PrintPhotoList($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'GALLERY') {													# ギャラリー
		PrintPhotoGallery($Page, $Sys, $Form);
	}
	elsif ($subMode eq 'COMPLETE') {												# 設定完了画面
		$Sys->Set('_TITLE', 'Process Complete');
		$BASE->PrintComplete('設定処理', $this->{'LOG'});
	}
	elsif ($subMode eq 'FALSE') {													# 設定失敗画面
		$Sys->Set('_TITLE', 'Process Failed');
		$BASE->PrintError($this->{'LOG'});
	}
	
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
	
	if ($subMode eq 'DELETE') {														# 画像削除
		$err = FunctionPhotoDelete($Sys, $Form, $this->{'LOG'});
	}
	elsif ($subMode eq 'REFRESH') {													# 履歴再読み込み
		$err = FunctionHistoryRefresh($Sys, $Form, $this->{'LOG'});
	}
	
	# 処理結果表示
	if ($err) {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"SYSTEM_SETTING($subMode)", "ERROR:$err");
		push @{$this->{'LOG'}}, $err;
		$Form->Set('MODE_SUB', 'FALSE');
	}
	else {
		$pSys->{'LOGGER'}->Put($Form->Get('UserName'),"SYSTEM_SETTING($subMode)", 'COMPLETE');
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
	my ($Base, $pSys) = @_;
	
	$Base->SetMenu('画像一覧', "'sys.gallery','DISP','LIST'");
	$Base->SetMenu('ギャラリー', "'sys.gallery','DISP','GALLERY'");
	# システム管理権限のみ
	#if ($pSys->{'SECINFO'}->IsAuthority($pSys->{'USER'}, $ZP::AUTH_SYSADMIN, '*')) {
	#}
}

#------------------------------------------------------------------------------------------------------------
#
#	アップロード画像一覧の表示
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintPhotoList
{
	my ($Page, $SYS, $Form) = @_;
	my (@histSet, $PhotoNum, $key, $url, $date, $i);
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base, $title);
	my ($common, $common2, $common3, $n, $Threads, $id, $is_checked);
	
	$SYS->Set('_TITLE', 'Photo List');

	require './module/imgur.pl';
	my $Img = IMGUR->new;
	$Img->Load($SYS);
	@histSet = $Img->GetHist();
	$PhotoNum = scalar(@histSet);
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 15);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $PhotoNum ? $PhotoNum : ($dispSt + $dispNum));

	# 権限取得
	my $isDelete	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_TREADDELETE, $SYS->Get('BBS'));
	
	# ヘッダ部分の表示
	$common = "DoSubmit('sys.gallery','DISP','LIST');";
	
	# ページャーの出力開始
	$Page->Print("<center><table border=0 cellspacing=2 width=100%><tr><td colspan=3 style=\"font-size:1.2em\">");
	PrintPagenation($Page, $PhotoNum, $dispNum ,$dispSt, $common);
	$Page->Print("</td><td colspan=2 align=right>");
	$Page->Print("表示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>\n");
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><th style=\"width:30px\"><a href=\"javascript:toggleAll('PHOTOS')\">全</a></th>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:60px\">Photo</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">URL</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:30px\">Upload Date</td>");
	$Page->Print("<td class=\"DetailTitle\" style=\"width:100px\">Information</td></tr>\n");

	my @slice = @histSet[ $dispSt .. $dispEd - 1 ];
	for my $offset (0 .. $#slice) {
		#$n  = $dispSt + $offset + 1;
		$id = $slice[$offset]->{deletehash};
		$url = $slice[$offset]->{link};
		$date = $slice[$offset]->{time};
		$title = $slice[$offset]->{title};

		$bgColor = '#ffffff'; 
		$Page->Print("<tr bgcolor=$bgColor>");
		$Page->Print("<td><input type=checkbox name=PHOTOS value=$id></td>");
		$Page->Print("<td align=center><img src=\"$url\" alt=\"\" style=\"max-height:50px; max-width:50px\"></td>");
		$Page->Print("<td align=center>$url</td><td align=center>$date</td>");
		$Page->Print("<td>[画像情報]</a></td></tr>\n");
		
	}
	$common	= "onclick=\"DoSubmit('sys.gallery','FUNC'";
	
	$Page->Print("<tr><td colspan=5><hr></td></tr>\n");
	$Page->Print("<tr><td colspan=5 align=left>");
	if($SYS->Get('IMGUR_ID') && $SYS->Get('IMGUR_SECRET') && $SYS->Get('UPLOAD') eq 'imgur'){
		$Page->Print("<input type=button value=\" 履歴更新 \" $common,'REFRESH')\"> ");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ")if ($isDelete);
	}
	$Page->Print("</td></tr>\n");
	$Page->Print("</table><br>");
	
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'TARGET_PHOTO', '');
	
}

#------------------------------------------------------------------------------------------------------------
#
#	ギャラリー
#	-------------------------------------------------------------------------------------
#	@param	$Page	ページコンテキスト
#	@param	$SYS	システム変数
#	@param	$Form	フォーム変数
#	@return	なし
#
#------------------------------------------------------------------------------------------------------------
sub PrintPhotoGallery
{
	my ($Page, $SYS, $Form) = @_;
	my (@histSet, $PhotoNum, $key, $url, $date, $i);
	my ($dispSt, $dispEd, $dispNum, $bgColor, $base, $title);
	my ($common, $common2, $common3, $n, $Threads, $id, $is_checked);
	
	$SYS->Set('_TITLE', 'Photo Gallery');

	require './module/imgur.pl';
	my $Img = IMGUR->new;
	$Img->Load($SYS);
	@histSet = $Img->GetHist();
	$PhotoNum = scalar(@histSet);
	
	# 表示数の設定
	$dispNum	= $Form->Get('DISPNUM', 40);
	$dispSt		= $Form->Get('DISPST', 0) || 0;
	$dispSt		= ($dispSt < 0 ? 0 : $dispSt);
	$dispEd		= (($dispSt + $dispNum) > $PhotoNum ? $PhotoNum : ($dispSt + $dispNum));

	# 権限取得
	my $isDelete	= $SYS->Get('ADMIN')->{'SECINFO'}->IsAuthority($SYS->Get('ADMIN')->{'USER'}, $ZP::AUTH_TREADDELETE, $SYS->Get('BBS'));
	
	# ヘッダ部分の表示
	$common = "DoSubmit('sys.gallery','DISP','GALLERY');";
	
	# ページャーの出力開始
	$Page->Print("<center><table border=0 cellspacing=2 width=100%><tr><td style=\"font-size:1.2em\">");
	PrintPagenation($Page, $PhotoNum, $dispNum ,$dispSt, $common);
	$Page->Print("</td><td align=right>");
	$Page->Print("表示数<input type=text name=DISPNUM size=4 value=$dispNum>");
	$Page->Print("<input type=button value=\"　表示　\" onclick=\"$common\"></td></tr>");
	$Page->Print("<tr><td colspan=2><hr><div class=\"gallery\">\n");
	my @slice = @histSet[ $dispSt .. $dispEd - 1 ];
	for my $offset (0 .. $#slice) {
		my $photo = $slice[$offset];
		my $id    = $photo->{deletehash};
		my $url   = $photo->{link};
		my $title = $photo->{title} // '';

		# 各タイルを出力
		$Page->Print(qq{
		<div class="gallery-item">
			<input type="checkbox" name="PHOTOS" value="$id">
			<img src="$url" alt="$title">
			<div class="title">$title</div>
		</div>
		});
	}
	$common	= "onclick=\"DoSubmit('sys.gallery','FUNC'";
	
	$Page->Print("</div><hr></td></tr>\n");
	$Page->Print("<tr><td align=left colspan=2>");
	if($SYS->Get('IMGUR_ID') && $SYS->Get('IMGUR_SECRET') && $SYS->Get('UPLOAD') eq 'imgur'){
		$Page->Print("<input type=button value=\" 履歴更新 \" $common,'REFRESH')\"> ");
		$Page->Print("<input type=button value=\"　削除　\" $common,'DELETE')\" class=\"delete\"> ")if ($isDelete);
	}
	$Page->Print("</td></tr>\n");
	$Page->Print("</table>\n");
	$Page->Print("<div id=\"imageOverlay\" class=\"image-overlay\"></div>\n");
	$Page->Print(<<HTML);
<script>
// ページ読み込み後に実行
document.addEventListener('DOMContentLoaded', function() {
  const overlay = document.getElementById('imageOverlay');

  // ギャラリーの画像を全部取得
  document.querySelectorAll('.gallery-item img').forEach(img => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', function(event) {
      // オーバーレイ内にクリックした画像を表示
      const largeImg = new Image();
      largeImg.src = this.src;
      largeImg.alt = this.alt || '';
      // 既存の子要素をクリア
      overlay.innerHTML = '';
      overlay.appendChild(largeImg);
      // オーバーレイ表示
      overlay.style.display = 'flex';
    });
  });

  // オーバーレイのクリック処理（画像以外をクリックしたら閉じる）
  overlay.addEventListener('click', function(event) {
    // クリックターゲットが overlay 自身なら閉じる
    if (event.target === overlay) {
      overlay.style.display = 'none';
      overlay.innerHTML = '';
    }
  });
});
</script>

HTML
	
	$Page->HTMLInput('hidden', 'DISPST', '');
	$Page->HTMLInput('hidden', 'TARGET_PHOTO', '');
	
}
#------------------------------------------------------------------------------------------------------------
#
#	画像削除
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionPhotoDelete
{
	my ($Sys, $Form, $pLog) = @_;
	my ($BBSAid, $BBS, @photoSet, $id, $bbs, $err);
	
	require './module/imgur.pl';
	my $Img = IMGUR->new;
	$Img->Load($Sys);
	
	@photoSet = $Form->GetAtArray('TARGET_PHOTO');
	foreach $id (@photoSet) {
		if($Img->Delete($id)){
			push @$pLog, "■画像「$id」を削除しました。";
		}else{
			push @$pLog, "■画像「$id」の削除に失敗しました。";
		}
	}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#
#	履歴の更新
#	-------------------------------------------------------------------------------------
#	@param	$Sys	システム変数
#	@param	$Form	フォーム変数
#	@param	$pLog	ログ用
#	@return	エラーコード
#
#------------------------------------------------------------------------------------------------------------
sub FunctionHistoryRefresh
{
	my ($Sys, $Form, $pLog) = @_;
	my ($BBSAid, $BBS, @bbsSet, $id, $bbs, $name);
	
	require './module/imgur.pl';
	my $Img = IMGUR->new;
	$Img->Load($Sys);
	if ($Img->Refresh()){
		push @$pLog, "■アップロード履歴を更新しました。";
	}else{
		push @$pLog, "■履歴の更新に失敗しました。";
	}
	
	return 0;
}

1;