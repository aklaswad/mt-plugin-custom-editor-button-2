package MT::Plugin::CustomEditorButton2;

use strict;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );
use vars qw( $PLUGIN_NAME $VERSION );
$PLUGIN_NAME = 'Custom Editor Button 2';
$VERSION = 0.31;

my $plugin = new MT::Plugin::CustomEditorButton2({
    name => $PLUGIN_NAME,
    id   => 'Custom Editor Button 2',
    key  => 'CustomrEditorButton2',
    author_link => 'http://blog.aklaswad.com/',
    author_name => 'aklaswad',
    description => 'add user buttons to cms entry/page editor.',
    version     => $VERSION,
    plugin_link => 'http://blog.aklaswad.com/mtplugins/customeditorbutton2/',
});

MT->add_plugin( $plugin );

sub new_meta {
    MT->VERSION =~ /4\.2/;
}

sub init {
    my $plugin = shift;
    $plugin->SUPER::init(@_);
    if ( !$plugin->new_meta ) {
        MT::Author->install_meta({
            columns => [
                'ceb_button_order',
            ]
        });
    }
};

sub init_registry {
    my $plugin = shift;
    my $r = {
        applications => {
            cms => {
                methods => {
                    save_ceb_prefs => '$CustomEditorButton2::CustomEditorButton2::save_prefs',
                }
            }
        },
        callbacks => {
            'MT::App::CMS::template_output.edit_entry' => '$CustomEditorButton2::CustomEditorButton2::transformer',
        }
    };
    if ( $plugin->new_meta ) {
        $r->{object_types} = {
            author => {
                ceb_button_order => 'string meta',
            }
        };
    }
    $plugin->registry( $r );
}

1;
