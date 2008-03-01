package CustomEditorButton2;

use JSON;

sub build_buttons {
    my $app = shift;
    my $btns = $app->registry('buttons');
    my @codes;
    my %btns;
    my $static_url = $app->config('StaticWebPath');
    foreach my $btn_id (keys %$btns) {
        my $btn = $btns->{$btn_id};
        push @codes, $btn->{code};
        my $img_path = $static_url . $btn->{plugin}->envelope . '/' . $btn->{image};
        $btns{$btn_id} = { id   => $btn_id,
                           img  => $img_path,
                           hdlr => 'ceb_' . $btn_id,
                         };
    }
    my $btn_json = objToJson(\%btns);
    return "\n@codes\nvar BTNS = $btn_json";
}

sub transformer {
    my ($eh, $app, $tmpl_ref) = @_;
    my @buttons;
    my @lines = <DATA>;

    my $begin_block = '<script type="text/javascript">';
    my $end_block = '</script>';
    my $txt = $begin_block . build_buttons($app) . "$end_block@lines";
    $$tmpl_ref =~ s!</head>!$txt</head>!;
}

1;

__DATA__

<script type="text/javascript">
/*
    custom editor button 2 javascript codes.
                           by Aklaswad 2008.
*/

MT.App.Editor.Toolbar.prototype.extendedCommand = function( command, event ) {
    var text = (this.editor.mode == "iframe")
                 ? this.editor.iframe.getSelection()
                 : this.editor.textarea.getSelectedText();
    if ( !defined( text ) )
        text = '';
    if(BTNS[command]) {
        var funcname = BTNS[command].hdlr;
        var func = eval( funcname );
        var res = func(text);
        if ( !defined( res ) )
            res = '';
        this.editor.insertHTML( res );
    }
    else {
        this.editor.execCommand( command );
    }
};

function build_buttons() {
    var div = document.createElement('div');
    DOM.addClassName(div, 'ceb-container');
    for (var id in BTNS){
        var btn_data = BTNS[id];
        var btn = document.createElement('a');
        btn.innerHTML = btn_data.id;
        DOM.addClassName(btn, 'command-' + btn_data.id);
        DOM.addClassName(btn, 'toolbar');
        DOM.addClassName(btn, 'ceb-button');
        btn.style.backgroundImage = 'url(' + btn_data.img + ')';
        btn.setAttribute('href', 'javascript: void 0;');
        div.appendChild(btn);
    }
    return div;
}

function init_customeditorbutton() {
    var content = build_buttons();
    var parent = getByID('editor-content-toolbar');
    parent.appendChild(content);
}

TC.attachLoadEvent( init_customeditorbutton );

</script>
<style type="text/css">

div.ceb-container {
    margin-top: 3px;
    height: 22px;
}

a.ceb-button {
    display: block;
    overflow: hidden;
    float: left;
    width: 22px;
    height: 22px;
    margin: 0 4px 0 0;
    padding: 0;
    color: #000;
    text-indent: 1000em;
    min-width: 0;
    -moz-user-select: none !important;
    -moz-user-focus: none !important;
    -moz-outline: none !important;
    -khtml-user-select: none !important;
}

</style>
