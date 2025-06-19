#============================================================================================================
#
#	拡張機能 - Markdown
#	0ch_markdown_utf8.pl
#	---------------------------------------------------------------------------
#	2025.06.18 start
#
#============================================================================================================
package ZPL_markdown;
use utf8;
use open IO =>':encoding(cp932)';
#------------------------------------------------------------------------------------------------------------
#	コンストラクタ
#------------------------------------------------------------------------------------------------------------
sub new
{
	my $this = shift;
	my ($Config) = @_;
	my ($obj);
	
	$obj = {};
	bless $obj, $this;
	
	if (defined $Config) {
		$obj->{'PLUGINCONF'} = $Config;
		$obj->{'is0ch+'} = 1;
	}
	else {
		$obj->{'CONFIG'} = $this->getConfig();
		$obj->{'is0ch+'} = 0;
	}
	
	return $obj;
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能名称取得
#	-------------------------------------------------------------------------------------
#	@return	名称文字列
#------------------------------------------------------------------------------------------------------------
sub getName
{
	my	$this = shift;
	return 'Markdown';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能説明取得
#	-------------------------------------------------------------------------------------
#	@return	説明文字列
#------------------------------------------------------------------------------------------------------------
sub getExplanation
{
	my	$this = shift;
	return 'Markdown記述を使えるようにします。コマンド欄に !markdown と入力すると有効になります。';
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能タイプ取得
#	-------------------------------------------------------------------------------------
#	@return	拡張機能タイプ
#			(スレ立て:1, レス:2, read.cgi:4, index.html:8, 書き込み前処理:16, 書き込み後処理:32, Patch:64)
#------------------------------------------------------------------------------------------------------------
sub getType
{
	my	$this = shift;
	return (16);
}

#------------------------------------------------------------------------------------------------------------
#	設定リスト取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	なし
#	@return	設定ハッシュリファレンス
#		\%config = (
#			'設定名'	=> {
#				'default'		=> 初期値,			# 真偽値の場合は on/true: 1, off/false: 0
#				'valuetype'		=> 値のタイプ,		# 数値: 1, 文字列: 2, 真偽値: 3, 内部用: 0
#				'description'	=> '設定の説明',	# 無くても構いません
#			},
#		);
#------------------------------------------------------------------------------------------------------------
sub getConfig
{
	my	$this = shift;
	my	%config;
	
	%config = (
		'bbs'	=> {
			'default'		=> '',
			'valuetype'		=> 2,
			'description'	=> '有効化対象BBSディレクトリ名',
		},
        'module'	=> {
			'default'		=> 'Text::MultiMarkdownモジュールが必要です。',
			'valuetype'		=> 2,
		},
		# プロセッサオプション
		use_metadata => {
			default     => 0,    # boolean: メタデータオプションを有効にするかどうか
			valuetype   => 3,
			description => 'メタデータオプションを有効にするかどうかを制御します。',           # :contentReference[oaicite:0]{index=0}
		},
		strip_metadata => {
			default     => 0,    # boolean: 入力文書内のメタデータを出力から除去
			valuetype   => 3,
			description => '入力文書内のメタデータを出力から除去します。',                     # :contentReference[oaicite:1]{index=1}
		},
		empty_element_suffix => {
			default     => '>', # string: 空要素タグのサフィックス（
			valuetype   => 2,
			description => '空要素タグのサフィックス（既定は ">" で HTML 用、xHTML 用に "/>" を指定可能）。',  # :contentReference[oaicite:2]{index=2}
		},
		img_ids => {
			default     => 1,    # boolean: <img> タグに id 属性を付与
			valuetype   => 3,
			description => '<img> タグに id 属性を付与するかどうかを制御します。',               # :contentReference[oaicite:3]{index=3}
		},
		heading_ids => {
			default     => 1,    # boolean: <hX> タグに id 属性を付与
			valuetype   => 3,
			description => '<hX> タグに id 属性を付与するかどうかを制御します。',               # :contentReference[oaicite:4]{index=4}
		},
		bibliography_title => {
			default     => 'Bibliography',  # string: 参考文献セクションのタイトル
			valuetype   => 2,
			description => '生成される参考文献セクションのタイトルを指定します。',           # :contentReference[oaicite:5]{index=5}
		},
		tab_width => {
			default     => 4,    # number: インデント幅
			valuetype   => 1,
			description => '生成されるマークアップのインデント幅を指定します。',               # :contentReference[oaicite:6]{index=6}
		},
		disable_tables => {
			default     => 0,    # boolean: テーブル機能の無効化
			valuetype   => 3,
			description => 'テーブル機能を無効化します。',                               # :contentReference[oaicite:7]{index=7}
		},
		disable_footnotes => {
			default     => 0,    # boolean: 脚注機能の無効化
			valuetype   => 3,
			description => '脚注機能を無効化します。',                                 # :contentReference[oaicite:8]{index=8}
		},
		disable_bibliography => {
			default     => 0,    # boolean: 参考文献/引用機能の無効化
			valuetype   => 3,
			description => '参考文献/引用機能を無効化します。',                         # :contentReference[oaicite:9]{index=9}
		},
		disable_definition_lists => {
			default     => 0,    # boolean: 定義リスト機能の無効化
			valuetype   => 3,
			description => '定義リスト機能を無効化します。',                           # :contentReference[oaicite:10]{index=10}
		},

		# Metadata オプション
		document_format => {
			default     => 'fragment',  # string: 'complete' で完全ページ、その他は断片
			valuetype   => 2,
			description => '"complete" で完全な XHTML ページを生成し、それ以外は断片を生成します。',  # :contentReference[oaicite:11]{index=11}
		},
		use_wikilinks => {
			default     => 0,    # boolean: WikiWord リンク生成
			valuetype   => 3,
			description => 'WikiWord リンク機能を有効にします（"1" または "on"）。',          # :contentReference[oaicite:12]{index=12}
		},
		base_url => {
			default     => '',   # string: Wiki リンクのベース URL
			valuetype   => 2,
			description => 'Wiki リンクのベース URL を指定します。未指定時は相対リンクになります。',  # :contentReference[oaicite:13]{index=13}
		},
		self_url => {
			default     => '',   # string: 脚注アンカーに付加する URL
			valuetype   => 2,
			description => '脚注のアンカーに URL を付加します。',                         # :contentReference[oaicite:14]{index=14}
		},
	);
	
	return \%config;
}

#------------------------------------------------------------------------------------------------------------
#	拡張機能実行インタフェイス
#	-------------------------------------------------------------------------------------
#	@param	$sys	SYSTEM
#	@param	$form	FORM
#	@param	$type	実行タイプ
#	@return	正常終了の場合は0
#------------------------------------------------------------------------------------------------------------
sub execute
{
	my	$this = shift;
	my	($sys, $form, $type) = @_;
	my $target_bbs = $this->GetConf('bbs');
	my $bbs = $sys->Get('BBS');
	
	if ($type & (16)) {
		if((!$target_bbs||$target_bbs =~ /$bbs/) && $form->Get('mail') =~ /!markdown/){
			my $has_mmd = eval {
				require Text::MultiMarkdown;
				Text::MultiMarkdown->import('markdown');
				1;
			};
			if($has_mmd){
                $this->SetConf('module','Text::MultiMarkdownモジュールはインストールされています。');
                my $text = $form->Get('MESSAGE');
				my $plugin_conf = $this->{'PLUGINCONF'}->GetConfig();

                my @skip_keys = qw(
                    bbs
                    module
                );
                my %skip = map { $_ => 1 } @skip_keys;
                my %option;
                while ( my ($k, $v) = each %$plugin_conf ) {
                    next if $skip{$k};
                    $option{$k} = $v;
                }
                require Text::MultiMarkdown;
                $text =~ s/<br>/\n/g;
				my $html = Text::MultiMarkdown::markdown($text,\%option);
				$html =~ s/\n//g;

				$form->Set('MESSAGE',$html);
			}
		}
	}
	return 0;
}

#------------------------------------------------------------------------------------------------------------
#	設定値取得 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@return	設定値
#------------------------------------------------------------------------------------------------------------
sub GetConf
{
	my	$this = shift;
	my	($key) = @_;
	my	($val);
	
	if ($this->{'is0ch+'}) {
		$val = $this->{'PLUGINCONF'}->GetConfig($key);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$val = $this->{'CONFIG'}->{$key}->{'default'};
		}
		else {
			$val = undef;
		}
	}
	
	return $val;
}

#------------------------------------------------------------------------------------------------------------
#	設定値設定 (0ch+ Only)
#	-------------------------------------------------------------------------------------
#	@param	$key	設定名
#	@param	$val	設定値
#	@return	なし
#------------------------------------------------------------------------------------------------------------
sub SetConf
{
	my	$this = shift;
	my	($key, $val) = @_;
	
	if ($this->{'is0ch+'}) {
		$this->{'PLUGINCONF'}->SetConfig($key, $val);
	}
	else {
		if (defined $this->{'CONFIG'}->{$key}) {
			$this->{'CONFIG'}->{$key}->{'default'} = $val;
		}
		else {
			$this->{'CONFIG'}->{$key} = { 'default' => $val };
		}
	}
}

#============================================================================================================
#	Module END
#============================================================================================================
1;
