#-----------------------------------------------------------------------------------------
#   UPDATE PATCH　テンプレート
#-----------------------------------------------------------------------------------------
package ZPL_PatchTemplete;
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
sub getName{my $this = shift;           return 'ex0ch Update Patch 2025/xx/xx';}
sub getExplanation{my $this = shift;    return 'これはパッチの雛形です。適用しても何も起こりません。';}
sub execute
{
	my	$this = shift;
    my	($sys, $form, $type) = @_;
    return if $this->{'PLUGINCONF'}->GetConfig('patch_status') || $type != 64;
	
    # Patchの処理



	$this->{'PLUGINCONF'}->SetConfig('patch_status', '適用済み');
	return 0;
}

# Patch End
1;
