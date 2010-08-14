package CustomEditorButton2;
use strict;
use JSON;
use MT;
use MT::Author;

my $new_meta = MT::Plugin::CustomEditorButton2->new_meta;

sub build_buttons {
    my $app = shift;
    my $btns = $app->registry('buttons');
    my $code;
    my %btns;
    my $static_url = $app->config('StaticWebPath');
    foreach my $btn_id (keys %$btns) {
        my $btn = $btns->{$btn_id};
        $code .= $btn->{code} . "\n\n";
        $btns{$btn_id} = { id    => $btn_id,
                           title => $btn->{title}, };
        my $img_path;
        if ( exists( $btn->{image}) ){
            $img_path = $btn->{plugin}->envelope . '/' . $btn->{image};
            $btns{$btn_id}->{img} = $img_path;
        }
        else {
            $btns{$btn_id}->{face} = $btn->{face_text};
        }
    }
    my $btn_json = objToJson(\%btns);
    my $order = get_order($app, $btns);
    my $order_json = objToJson($order);
    return "\n$code\nvar BTNS = $btn_json\nvar BTN_ORDER = $order_json\n";
}

sub get_order {
    my ($app, $btns) = @_;
    my @order;
    my $saved = $new_meta ? $app->user->ceb_button_order
                          : $app->user->meta('ceb_button_order');
        
    if ( $saved ) {
        @order = split /:/, $saved;
        @order = grep { exists $btns->{$_} } @order;
    }
    else{
        foreach my $btn_id (keys %$btns) {
            push @order, $btn_id;
        }
    }
    return \@order;
}

{
    use vars qw ( $builtin_code );

    sub load_builtin_code {
        local $/;
        $builtin_code = <DATA>;
    }

    sub transformer {
        my ($eh, $app, $tmpl_ref) = @_;
        my @buttons;
        &load_builtin_code unless $builtin_code;

        my $begin_block = '<script type="text/javascript">';
        my $end_block = '</script>';
        my $txt = $begin_block . build_buttons($app) . "$end_block$builtin_code";
        $$tmpl_ref =~ s!</head>!$txt</head>!;

        $$tmpl_ref =~ s!</body>!<div id="ceb-sysmessage-container"></div><a id="dragging-button" class="hidden"></a></body>!;
    }

}

sub save_prefs {
    my $app = shift;
    my $order = $app->param('order');
    if ( $new_meta ) {
        $app->user->ceb_button_order($order);
    }
    else {
        $app->user->meta('ceb_button_order', $order);
    }
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

var SYS_BTNS = { 'save_ceb_prefs': { id: 'save_ceb_prefs'},
                 'toggle_box': { id: 'toggle_box'} };

/*    Utilities    */

function outerHTML (node) {
    var div = document.createElement('div');
    div.appendChild(node);
    return div.innerHTML;
}

function ceb_sysmessage (message, timeout) {
    var box = document.createElement('div');
    DOM.addClassName(box, 'ceb-sysmessage');
    box.innerHTML = message;
    getByID('ceb-sysmessage-container').appendChild(box);
    var remover = function(){
        getByID('ceb-sysmessage-container').removeChild(box);
    }
    if (timeout) setTimeout(remover, timeout * 1000);
    return box;
}


/* Command Handler */

MT.App.Editor.Toolbar.prototype.extendedCommand = function( command, event ) {
    var isMSIE = /*@cc_on!@*/false;
    if( BTNS[command] || SYS_BTNS[command] ) {
        var iframe = this.editor.mode == "iframe";
        var text = "";
        var args = {};
        if (iframe) {
            var doc = this.editor.iframe;
            var sel = doc.getSelection();
            text = isMSIE ? sel.createRange().text : sel.toString();
            var lazy_innerHTML = function() {
                //return proper HTML in iframe mode;
                var rng;
                if (isMSIE) {
                    rng = sel.createRange();
                    return rng.htmlText;
                }
                else {
                    rng = sel.getRangeAt(0);
                    return outerHTML(rng.cloneContents());
                }
            };
            args = { 'iframe': 1,
                     'innerHTML': lazy_innerHTML,
                     'editor': this.editor };
        }
        else {
            text = this.editor.textarea.getSelectedText();
            args = { 'iframe': 0,
                     'innerHTML': function(){ return text },
                     'editor': this.editor };
        }

        if ( !defined( text ) )
            text = '';
        var funcname = 'ceb_' + command;
        var func = eval( funcname );
        var res = func(text, args);
        if ( defined( res ) ){
            if (typeof(res) == 'string')
                this.editor.insertHTML( res );
            else {
                // res must be a DOM Node Object.
                if(iframe){
                    var sel = doc.getSelection();
                    var rng = isMSIE ? sel.createRange() : sel.getRangeAt(0);
                    rng.deleteContents();
                    rng.insertNode(res);
                }
                else {
                    this.editor.insertHTML( outerHTML(res) );
                }
            }
        }
    }
    else {
        this.editor.execCommand( command );
    }
};

/*   Drag and drop system   */

var DRAGGING;
var DRAGGED;
var DRAG_START_X;
var DRAG_START_Y;
var DRAG_LAYER_X;
var DRAG_LAYER_Y;
var ORIGINAL_ORDER;
var BTN_ORDER_CHANGED = 0;

// fixed version of mt_core DOM.getMouseEventAttribute() 
function getMouseEventAttribute2( ev, a ) {
    if( !a )
        return;
    target = ev.target || ev.srcElement;
    var es = DOM.getAncestors( target, true );
    //% for( var i = 0; i < es.length; i++ ) {
    //%     var e = es[ i ];
    for( var en = new Enumerator( es ); !en.atEnd(); en.moveNext() ) {
        var e = en.item();
        try {
            var v = e.getAttribute ? e.getAttribute( a ) : null;
            if( v ) {
                ev.attributeElement = e;
                ev.attribute = v;
                return v;
            }
        } catch( e ) {}
    }
}

function button_drag_start(evt) {
    DOM.addEventListener(document, 'mouseup', button_drag_end, 1);
    DOM.addEventListener(document, 'mousemove', button_drag_move, 1);
    
    DRAGGING = getMouseEventAttribute2(evt, 'mt:draggable');
    DRAGGED = false;
    ORIGINAL_ORDER = undefined;
    for (var i = 0; i<BTN_ORDER.length; i++) {
        if (BTN_ORDER[i] == DRAGGING) {
            ORIGINAL_ORDER = i;
            break;
        }
    }
    var isMSIE = /*@cc_on!@*/false;
    if (isMSIE) {
        DRAG_START_X = evt.x + document.body.scrollLeft;
        DRAG_START_Y = evt.y + document.body.scrollTop;
        DRAG_LAYER_X = evt.offsetX;
        DRAG_LAYER_Y = evt.offsetY;
    }
    else {
        DRAG_START_X = evt.pageX;
        DRAG_START_Y = evt.pageY;
        DRAG_LAYER_X = evt.layerX;
        DRAG_LAYER_Y = evt.layerY;
    }
    return true;
}

function button_drag_move(evt) {
    if ( DRAGGING ) {
        var btn = getByID('dragging-button');
        if (!DRAGGED) {
            var btn_data = BTNS[DRAGGING];
            if (btn_data.img) {
                btn.style.backgroundImage = 'url(' + StaticURI + btn_data.img + ')';
                DOM.addClassName(btn, 'ceb-button');
                btn.style.position = 'absolute';
            }
            else {
                btn.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/plain_button.png)';
                DOM.addClassName(btn, 'ceb-button-noimage');
                btn.innerHTML = btn_data.face;
            }
            DOM.removeClassName(btn, 'hidden');
            DRAGGED = true;
        }
        var isMSIE = /*@cc_on!@*/false;
        var x,y;
        if (isMSIE) {
            var pos = DOM.getAbsoluteCursorPosition(evt);
            x = pos.x;
            y = pos.y;
        }
        else {
            x = evt.pageX;
            y = evt.pageY;
        }
        btn.style.left = (x - DRAG_LAYER_X) + 'px';
        btn.style.top = (y - DRAG_LAYER_Y) + 'px';
    }
    return false;
}

function button_drag_end(evt) {
    DOM.removeEventListener(document, 'mouseup', button_drag_end, 1);
    DOM.removeEventListener(document, 'mousemove', button_drag_move, 1);
    DOM.addClassName(getByID('dragging-button'), 'hidden');
    if(!DRAGGING) return true;
    var btn_id = DRAGGING;
    DRAGGING = null;
    if (!DRAGGED) return true;

    var isMSIE = /*@cc_on!@*/false;
    var x,y;
    if (isMSIE) {
        var pos = DOM.getAbsoluteCursorPosition(evt);
        x = pos.x - DRAG_LAYER_X;
        y = pos.y - DRAG_LAYER_Y;
    }
    else {
        x = evt.pageX - DRAG_LAYER_X;
        y = evt.pageY - DRAG_LAYER_Y;
    }

    var container_dim = DOM.getAbsoluteDimensions(getByID('ceb-container'));
    var box_dim = DOM.getAbsoluteDimensions(getByID('ceb-box-button'));
    var box_area_dim;
    if (EXIST_BOX) {
        var box_area_dim = DOM.getAbsoluteDimensions(getByID('ceb-box'));
    }
    
    if (is_inside_of_element(x, y, box_dim)) {
        remove_button(btn_id);
    }
    else if (is_inside_of_element(x, y, container_dim)) {
        var xx = x - container_dim.absoluteLeft;
        var new_order = Math.floor( xx / 24 + 0.5);
        if (defined(ORIGINAL_ORDER)) {
            if (ORIGINAL_ORDER < new_order) new_order--;
        }
        if (ORIGINAL_ORDER != new_order)
            move_button(btn_id, new_order);
    }
    else if (EXIST_BOX && is_inside_of_element(x, y, box_area_dim)) {
        remove_button(btn_id);
    }
    return false;
}

function is_inside_of_element(x, y, dim) {
    var xx = x - dim.absoluteLeft;
    var yy = y - dim.absoluteTop;
    if ( xx < -22 || dim.offsetWidth < xx || yy < -22 || dim.offsetHeight < yy )
        return false;
    return true;
}

function move_button(btn_id, new_order) {
    var rmv = false;
    for(var i=0;i<BTN_ORDER.length;i++) {
        if (BTN_ORDER[i] == btn_id){
            BTN_ORDER.splice(i,1);
            rmv = true;
            break;
        }
    }
    var ins = defined(new_order);
    if (ins) {
        BTN_ORDER.splice(new_order,0,btn_id);
    }
    if (ins || rmv) {
        rebuild_buttons();
        BTN_ORDER_CHANGED = 1;
    }
}

function remove_button(btn_id) {
    move_button(btn_id, undefined);
}

function insert_button(btn_id, new_order) {
    move_button(btn_id, new_order);
}

/*   Button Initializers   */

function build_buttons() {
    var div = document.createElement('div');
    div.id = "ceb-container";
    DOM.addClassName(div, 'ceb-container');

    var sv = document.createElement('a');
    sv.btn_id = 'save_ceb_prefs';
    DOM.addClassName(sv, 'command-save_ceb_prefs');
    DOM.addClassName(sv, 'toolbar');
    DOM.addClassName(sv, 'ceb-button');
    DOM.addClassName(sv, 'ceb-system-button');
    sv.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/save_prefs.png)';
    sv.setAttribute('href', 'javascript: void 0;');
    div.appendChild(sv);

    var bx = document.createElement('a');
    bx.btn_id = 'ceb_box';
    bx.id = 'ceb-box-button';
    DOM.addClassName(bx, 'command-toggle_box');
    DOM.addClassName(bx, 'toolbar');
    DOM.addClassName(bx, 'ceb-button');
    DOM.addClassName(bx, 'ceb-system-button');
    bx.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/ceb_box.png)';
    bx.setAttribute('href', 'javascript: void 0;');
    div.appendChild(bx);

    for (var i = 0;i<BTN_ORDER.length;i++) {
        var id = BTN_ORDER[i];
        var btn_data = BTNS[id];
        var btn = document.createElement('a');
        btn.innerHTML = btn_data.id;
        DOM.addClassName(btn, 'command-' + btn_data.id);
        DOM.addClassName(btn, 'toolbar');
        DOM.addEventListener( btn, 'mousedown', button_drag_start, 1 );
        if (btn_data.img) {
            btn.style.backgroundImage = 'url(' + StaticURI + btn_data.img + ')';
            DOM.addClassName(btn, 'ceb-button');
        }
        else {
            btn.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/plain_button.png)';
            DOM.addClassName(btn, 'ceb-button-noimage');
            btn.innerHTML = btn_data.face;
        }
        btn.setAttribute('href', 'javascript: void 0;');
        btn.setAttribute('title', btn_data.title);
        btn.btn_id = btn_data.id;
        btn.setAttribute('mt:draggable', btn_data.id);
        btn.btn_order = i;
        div.appendChild(btn);
    }
    var clr = document.createElement('div');
    clr.style.clear = 'both';
    div.appendChild(clr);
    return div;
}

function build_unused_buttons() {
    var div = document.createElement('div');
    div.id= "ceb-box";
    for (var i in BTNS)
        BTNS[i].disp = 0;
    for (var i=0;i<BTN_ORDER.length;i++) {
        BTNS[BTN_ORDER[i]].disp = 1;
    }
    for (var i in BTNS) {
        var btn_data = BTNS[i];
        if ( btn_data.disp ) continue;
        var btn = document.createElement('a');
        DOM.addClassName(btn, 'command-' + btn_data.id);
        DOM.addClassName(btn, 'toolbar');
        if (btn_data.img) {
            btn.style.backgroundImage = 'url(' + StaticURI + btn_data.img + ')';
            DOM.addClassName(btn, 'ceb-button');
        }
        else {
            btn.style.backgroundImage = 'url(' + StaticURI + 'plugins/CustomEditorButton2/images/plain_button.png)';
            DOM.addClassName(btn, 'ceb-button-noimage');
            btn.innerHTML = btn_data.face;
        }
        DOM.addEventListener( btn, 'mousedown', button_drag_start, 1 );
        btn.setAttribute('href', 'javascript: void 0;');
        btn.setAttribute('title', btn_data.title);
        btn.setAttribute('mt:draggable', btn_data.id);
        btn.btn_id = btn_data.id;
        btn.btn_order = i;
        div.appendChild(btn);
    }
    var clr = document.createElement('div');
    clr.style.clear = 'both';
    div.appendChild(clr);
    return div;
}

var DISP_BOX = 0;
var EXIST_BOX = 0;
function rebuild_buttons() {
    var content = build_buttons();
    var parent = getByID('editor-content-toolbar');
    parent.removeChild(getByID('ceb-container'));
    if (EXIST_BOX) {
        parent.removeChild(getByID('ceb-box'));
        EXIST_BOX = 0;
    }
    parent.appendChild(content);
    if (DISP_BOX) {
        var box = build_unused_buttons();
        parent.appendChild(box);
        EXIST_BOX = 1;
    }
}

function init_buttons() {
    var content = build_buttons();
    var parent = getByID('editor-content-toolbar');
    parent.appendChild(content);
}

function ceb_save_ceb_prefs() {
    if (!BTN_ORDER_CHANGED) return;
    var order = BTN_ORDER[0];
    for (var i = 1; i<BTN_ORDER.length;i++) {
        order += ':' + BTN_ORDER[i];
    }
    //TODO: get magic token from other form.
    var args = { 'order': order,
                 '__mode': 'save_ceb_prefs' };
    TC.Client.call({
        'load': ceb_prefs_saved,
        'error': function() {alert('error saving button prefs')},
        'method': 'POST',
        'uri': ScriptURI,
        'arguments': args
    });
    var mes = ceb_sysmessage('saving prefs... ', 0);
    mes.id = 'ceb-saving-message';
}

function ceb_prefs_saved(c, r) {
    BTN_ORDER_CHANGED = 0;
    var mes = getByID('ceb-saving-message');
    getByID('ceb-sysmessage-container').removeChild(mes);
    ceb_sysmessage('save complete!', 3);
}


function ceb_toggle_box() {
    DISP_BOX = !DISP_BOX;
    rebuild_buttons();
    return;
}

TC.attachLoadEvent( init_buttons );

</script>
<style type="text/css">

div#ceb-container {
    margin-top: 3px;
    min-height: 22px;
}

div#ceb-box {
    margin-top: 3px;
    padding: 4px;
    min-height: 22px;
    border: 1px solid #abc;
    clear: both;
}

.ceb-button {
    display: block;
    overflow: hidden;
    float: left;
    width: 22px;
    height: 22px;
    margin: 0 4px 2px 0;
    padding: 0;
    color: #000;
    text-indent: 1000em;
    min-width: 0;
    -moz-user-select: none !important;
    -moz-user-focus: none !important;
    -moz-outline: none !important;
    -khtml-user-select: none !important;
}

.ceb-button-noimage {
    display: block;
    overflow: hidden;
    float: left;
    width: 22px;
    height: 22px;
    margin: 0 4px 2px 0;
    padding: 0;
    color: #789;
    min-width: 0;
    -moz-user-select: none !important;
    -moz-user-focus: none !important;
    -moz-outline: none !important;
    -khtml-user-select: none !important;
}

a.ceb-system-button {
    float: right;
}

#dragging-button {
    width: 22px;
    height: 22px;
    position: absolute;
    z-index: 10001;
}

#ceb-sysmessage-container {
    position: fixed;
    left: 0;
    top: 0;
}

.ceb-sysmessage {
    position: relative;
    width: 200px;
    background-color: #789;
    color: #fff;
    text-align: left;
    padding: 5px;
    border-width: 0 1px 1px 1px;
    border-style: solid;
    border-color: #abc;
    z-index: 10000;
}
</style>
