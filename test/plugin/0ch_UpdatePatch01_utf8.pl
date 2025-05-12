#-----------------------------------------------------------------------------------------
#   UPDATE PATCH for v0.10.1 -> v0.11.0
#-----------------------------------------------------------------------------------------
package ZPL_UpdatePatch01;
use utf8;
use open IO =>':encoding(cp932)';

## プラグインをパッチとして使うための設定
sub new{my $this = shift;my ($Config) = @_;my ($obj);$obj = {};bless $obj, $this;
$obj->{'PLUGINCONF'} = $Config;$obj->{'is0ch+'} = 1;return $obj;}
sub getType{my $this = shift;return 64;}
sub getConfig{my $this = shift;my %config = ('patch_status'=> {'default'=>'','valuetype'=> 0,});return \%config;}

#-----------------------------------------------------------------------------------------
#   Patch本体
#-----------------------------------------------------------------------------------------
sub getName{my $this = shift;           return 'ex0ch Update Patch 01 2025/10/01';}
sub getExplanation{my $this = shift;    return 'v0.10.2以前のバージョンからアップデートする際、本パッチを適応してください。ex0ch新規導入の場合は不要です。';}
sub execute
{
	my	$this = shift;
    my	($sys, $form, $type) = @_;
    return if $this->{'PLUGINCONF'}->GetConfig('patch_status') || $type != 64;
	
    # Patchの処理
    # １：忍法帖移行
    use lib './perllib';

    use Digest::MD5;
    use File::Glob ':bsd_glob';
    use MIME::Base64;
    use Storable qw(lock_store lock_retrieve);

    use CGI::Session;

    # 仕様が変わったので追々実装
=pod
    sub SetHash {
        #my $this = shift;
        my ($key, $value, $time ,$filename) = @_;
        my $hash_table = {};

        if (-e $filename) {
        $hash_table = lock_retrieve($filename);
        }else {
                $hash_table = {};
            }

        $hash_table->{$key} = {
        value => $value,
        time => $time,
        };
        lock_store($hash_table, $filename);
        chmod 0600, $filename,
    }

    my $ninDir = "../test/info/.ninpocho/";

    while (my $file = glob("../test/info/.ninpocho/cgisess_*")) {
        my $sid = (split "cgisess_", $file, 2)[1];
        print $file . " " . $sid . "\n";
        my $session = CGI::Session->load("driver:file;serializer:storable", $sid, {Directory => $ninDir});
        if ($session->is_empty) {
            next;
        }
        if ($session->param('password_file_hash')) {
            # スキップ
            next;
        } elsif ($session->param('password')) {
            # hash/password.cgi にまとめて保存していたパスワード（のハッシュ）
            # パスワードのb64digestが入ってるからhexに変換する
            my $ctx3_hexdigest = unpack('H*', decode_base64($session->param('password')));
            print $session->param('password') . "\n";
            print $ctx3_hexdigest . "\n";

            my $pass_file = $ninDir . 'hash/pw-' . $ctx3_hexdigest . '.cgi';

            SetHash('sid', $sid, time, $pass_file);
            $session->param('password_file_hash', $ctx3_hexdigest);
            $session->flush();
        }
    }
=cut

    # ２：不足フォルダ作成
    require './module/bbs_info.pl';
    require './module/file_utils.pl';
	$BBS = BBS_INFO->new;
	$BBS->Load($sys);
    my @bbsSet;
    $BBS->GetKeySet('ALL', '', \@bbsSet);

    foreach my $id (@bbsSet){
        my $dir = '../'.$BBS->Get('DIR', $id).'/info';
	    FILE_UTILS::CreateDirectory("$dir/timeline", $sys->Get('PM-ADIR'));
        FILE_UTILS::CreateDirectory("$dir/attr", $sys->Get('PM-ADIR'));
    }

	$this->{'PLUGINCONF'}->SetConfig('patch_status', '適用済み');
	return 0;
}

# Patch End
1;
