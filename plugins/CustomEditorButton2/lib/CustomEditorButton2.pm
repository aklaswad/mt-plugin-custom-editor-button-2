package CustomEditorButton2;
use strict;
use JSON;
use MT::Author;

# Say hey, but we really just wanted the module loaded.
sub init_app { 1 }

MT::Author->install_meta({
    columns => [
        'ceb_order',
    ],
});

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
    $btns{save_ceb_prefs} = { id => 'save_ceb_prefs',
                              hdlr => 'save_ceb_prefs', };
    my $btn_json = objToJson(\%btns);
    my $order = get_order($app, $btns);
    my $order_json = objToJson($order);
    
    return "\n@codes\nvar BTNS = $btn_json\nvar BTN_ORDER = $order_json\n";
}

sub get_order {
    my ($app, $btns) = @_;
    my @order;
    if (my $saved = $app->user->meta('ceb_button_order')) {
        @order = split /:/, $saved;
    }
    else{
        foreach my $btn_id (keys %$btns) {
            push @order, $btn_id;
        }
    }
    return \@order;
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

sub save_prefs {
    my $app = shift;
    my $order = $app->param('order');
    $app->user->meta('ceb_button_order', $order);
    $app->user->save;
    $app->json_result({}); 
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
    div.id = "ceb-container";
    DOM.addClassName(div, 'ceb-container');
    for (var i = 0;i<BTN_ORDER.length;i++) {
        var id = BTN_ORDER[i];
        var btn_data = BTNS[id];
        var btn = document.createElement('a');
        btn.btn_id = btn_data.id;
        btn.btn_order = i;
        btn.innerHTML = btn_data.id;
        DOM.addClassName(btn, 'command-' + btn_data.id);
        DOM.addClassName(btn, 'toolbar');
        DOM.addClassName(btn, 'ceb-button');
        DOM.addEventListener( btn, 'mousedown', button_drag_start, 1 );
        btn.style.backgroundImage = 'url(' + btn_data.img + ')';
        btn.setAttribute('href', 'javascript: void 0;');
        div.appendChild(btn);
    }

    var sv = document.createElement('a');
    sv.btn_id = 'save_ceb_prefs';
    DOM.addClassName(sv, 'command-save_ceb_prefs');
    DOM.addClassName(sv, 'toolbar');
    DOM.addClassName(sv, 'ceb-button');
    DOM.addClassName(sv, 'ceb-system-button');
    sv.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/save_prefs.png)';
    sv.setAttribute('href', 'javascript: void 0;');
    div.appendChild(sv);
    return div;
}

var DRAGGING;
var DRAG_START_X;
var DRAG_START_Y;
var ORIGINAL_ORDER;
var BTN_ORDER_CHANGED = 0;

function button_drag_start(evt) {
    DOM.addEventListener(document, 'mouseup', button_drag_end, 1);
    DOM.addEventListener(document, 'mousemove', button_drag_move, 1);
    DRAGGING = this.btn_id;
    ORIGINAL_ORDER = this.btn_order;
    DRAG_START_X = evt.pageX;
    DRAG_START_Y = evt.pageY;
    dbg(DRAGGING);
    return true;
}

function button_drag_move(evt) {
    var box = getByID('ceb-container');
    var x = evt.clientX - box.offsetLeft;
    var y = evt.clientY - box.offsetTop;
    dbg(DRAGGING + ': ' + x + ':' + y);
    return false;
}

function button_drag_end(evt) {
    DOM.removeEventListener(document, 'mouseup', button_drag_end, 1);
    DOM.removeEventListener(document, 'mousemove', button_drag_move, 1);
    if(!DRAGGING) return true;
    if (DRAG_START_X == evt.pageX && DRAG_START_Y == evt.pageY){
        DRAGGING = null;
        return true;
    }
    var btn_id = DRAGGING;
    DRAGGING = null;
    var box = DOM.getDimensions(getByID('ceb-container'));
    var x = evt.pageX - box.offsetLeft;
    var y = evt.pageY - box.offsetTop;
    if ( x < 0 || box.offsetWidth < x || y < 0 || box.offsetHeight < y )
        return false;
    var new_order = Math.floor(x / 24 + 0.5);
    if (ORIGINAL_ORDER < new_order) new_order--;
    if (ORIGINAL_ORDER != new_order)
        button_move(btn_id, new_order);
    return false;
}

function button_move(btn_id, new_order) {
    for(var i=0;i<BTN_ORDER.length;i++) {
        if (BTN_ORDER[i] == btn_id){
            BTN_ORDER.splice(i,1);
            break;
        }
    }
    BTN_ORDER.splice(new_order,0,btn_id);
    rebuild_buttons();
    BTN_ORDER_CHANGED = 1;
}

function dbg (s){
    getByID('title').value = s;
}

function rebuild_buttons() {
    var content = build_buttons();
    var parent = getByID('editor-content-toolbar');
    parent.removeChild(getByID('ceb-container'));
    parent.appendChild(content);
}

function init_buttons() {
    var content = build_buttons();
    var parent = getByID('editor-content-toolbar');
    parent.appendChild(content);
}

function save_ceb_prefs() {
    if (!BTN_ORDER_CHANGED) return;
    var order = BTN_ORDER[0];
    for (var i = 1; i<BTN_ORDER.length;i++) {
        order += ':' + BTN_ORDER[i];
    }
    var args = { 'order': order,
                 '__mode': 'save_ceb_prefs',
                 'magic_token': '<mt:var name="magic_token">' };
    TC.Client.call({
        'load': ceb_prefs_saved,
        'error': function() {alert('error saving button prefs')},
        'method': 'POST',
        'uri': ScriptURI,
        'arguments': args
    });
}

function ceb_prefs_saved(c, r) {

}

TC.attachLoadEvent( init_buttons );

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

a.ceb-system-button {
    float: right;
}

</style>
