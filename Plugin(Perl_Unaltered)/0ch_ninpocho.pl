#============================================================================================================
#
#	拡張機能 - 忍法帖プラグイン
#	0ch_ninpocho.pl
#
#============================================================================================================
package ZPL_ninpocho;

use CGI::Cookie;
use CGI::Session;


#------------------------------------------------------------------------------------------------------------
#	拡張機能名称取得
#------------------------------------------------------------------------------------------------------------
sub getName
{
	return '忍法帖プラグイン';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	return '忍法帖プラグイン';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#------------------------------------------------------------------------------------------------------------
sub getType
{
	return 16;
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	return {};
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my $this = shift;
	my ($Sys, $Form, $type) = @_;
	
	# 0ch本家では実行しない
	return 0 if (!$this->{'is0ch+'});

	if ($type == 16) {
		# infoディレクトリ
		my $infoDir = $Sys->Get('INFO');

		# IPアドレスを取得
		my $ipAddr = "$ENV{'REMOTE_ADDR'}";

		# Cookie管理モジュールを用意
		my $Cookie = $Sys->Get('MainCGI')->{'COOKIE'};

		# CookieからセッションIDを取得
		my $sid = $Cookie->Get('countsession');
		if ($sid eq '') {
			%cookies = fetch CGI::Cookie;
			if (exists $cookies{'countsession'}) {
				$sid = $cookies{'countsession'}->value;
				$sid =~ s/"//g;
			}
		}

		# 忍法帖データディレクトリを設定
		my $ninDir = ".$infoDir/.nin/";
		mkdir $ninDir if ! -d $ninDir;

		# IPアドレスを記録
		my $ssPath = "${ninDir}cgisess_${sid}";
		$sid = '' if ! -f $ssPath;
		my $ipPath = "${ninDir}ip_${ipAddr}";
		if ($sid ne '' && ! -f $ipPath) {
			open(my $fh, ">", $ipPath);
			print $fh $sid;
			close($fh);
		}
		if (-f $ipPath && open(my $fh, "<", $ipPath)) {
			my $sidData = <$fh>;
			$sid = $sidData if $sidData ne '';
			my $ssPath = "${ninDir}cgisess_${sid}";
			$sid = '' if ! -f $ssPath;
			if ($sid eq '' && -f $ipPath) {
				open(my $fh, ">", $ipPath);
				print $fh '';
				close($fh);
			} else {
				$total_code .= 'ｲ' if $sid ne '';
			}
			close($fh);
		}
		if ($sid eq '' && -d $ninDir) {
			my $fsrslt = fsearch($ninDir, $ipAddr);
			if ($fsrslt =~ /cgisess_/) {
				$sid = $fsrslt;
        $sid =~ s|.+?cgisess_||;
				$total_code .= 'ｲ';
			}
		}

    # セッションを読み込む
    my $session = CGI::Session->new('driver:file;serializer:default', $sid, { Directory => $ninDir }) || 0;

    # セッションから忍法帖Lvを取得
    $ninLv = $session->param('ninLv') || 1;

		# セッションから書き込み数を取得
		my $count = $session->param('count') || 0;

    # 書き込んだ時間を取得
		my $resTime = time();
    # 書き込んだ時間の23時間後を取得
		my $time23h = time() + 82800;
		# セッションから前回レベルアップしたときの時間を取得
		my $lvUpTime = $session->param('lvuptime') || $time23h;

    # 書き込み数をカウント
		$count++;

		# レベルの上限
		my $lvLim = 40;

    # 前回のレベルアップから23時間以上経過していればレベルアップ
    if ($resTime >= $lvUpTime && $ninLv < $lvLim) {
      $ninLv++;
      $lvUpTime = $time23h;
    }

		# セッションに記録
		if ($session) {
			$session->param('count', $count);
			$session->param('ninLv', $ninLv);
			$session->param('lvuptime', $lvUpTime);
		}

		# セッションIDをクッキーに出力
		if ($sid eq '') {
			$sid = $session->id();
		}
		$Cookie->Set('countsession', $sid);

		# 名前欄取得
		my $name = $Form->Get('FROM');

		# 名前欄書き換え
		$name =~ s|!ninja|</b>【忍法帖Lv.$ninLv】<b>|g;
		$name =~ s|!total|</b>【総カキコ数:$count】<b>|g;

		# 名前欄再設定
		$Form->Set('FROM', $name);
  }

	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	ファイル全文検索
#------------------------------------------------------------------------------------------------------------
sub fsearch {
  my($dir, $word) = @_;
	my $result = '';

  opendir(DIR, $dir);
  my @dir = sort { $a cmp $b } readdir(DIR);
  closedir(DIR);

  foreach my $file (@dir) {
    if ($file eq '.' or $file eq '..') {
      next;
    }

    my $target = "$dir$file";

    if (-d $target) {
      &search("$target/", $word);
    } else {
      my $flag = 0;

      open(FH, $target);
      while (my $line = <FH>) {
        if (index(lc($line), lc($word)) >= 0) {
          $flag = 1;
        }
      }
      close(FH);

      if ($flag) {
        $result = $target;
				last;
      }
    }
  }

  return $result;
}

#------------------------------------------------------------------------------------------------------------
#	コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my ($Config) = @_;
	
	my $this = {};
	bless $this, $class;
	
	if (defined $Config) {
		$this->{'PLUGINCONF'} = $Config;
		$this->{'is0ch+'} = 1;
	}
	else {
		$this->{'CONFIG'} = $class->getConfig();
		$this->{'is0ch+'} = 0;
	}
	
	return $this;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my $this = shift;
	my ($key) = @_;
	if ($this->{'is0ch+'}) {
		return $this->{'PLUGINCONF'}->GetConfig($key);
	}
	elsif (defined $this->{'CONFIG'}->{$key}) {
		return $this->{'CONFIG'}->{$key}->{'default'};
	}
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my $this = shift;
	my ($key, $val) = @_;
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	elsif (defined $this->{'CONFIG'}->{$key}) {
		$this->{'CONFIG'}->{$key}->{'default'} = $val;
	}
	else {
		$this->{'CONFIG'}->{$key} = { 'default' => $val };
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
