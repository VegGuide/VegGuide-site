JSAN.use('DOM.Element');
JSAN.use("DOM.Find");

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.Form = {};

/* All this show/hide and positioning stuff helps prevent a flickering
   event as the down is shown, then resized. Instead, the resizing
   happens off-screen */

VegGuide.Form.resizeRadioOrCheckboxList = function (name) {
    var div = $(name);

    if ( ! div ) {
        return;
    }

    var ul = DOM.Find.getElementsByAttributes( { "tagName": "UL" }, div )[0];

    if ( ! ul ) {
        return;
    }

    DOM.Element.hide(ul);

    ul.style.position = "absolute";
    ul.style.left     = "-5000px";

    DOM.Element.show(ul);

    var input = DOM.Find.getElementsByAttributes( { "tagName": "INPUT",
                                                    "type"   : /^(radio|checkbox)$/ }, ul )[0];

    if ( ! input ) {
        return;
    }

    var parent_is_li = function (node) {
        if ( node.tagName == "LI" ) {
            return true;
        }

        return false;
    };

    var labels = DOM.Find.getElementsByAttributes( { "tagName":  "LABEL",
                                                     "parentNode": parent_is_li }, ul );

    var longest_width = 0;
    for ( var i = 0; i < labels.length; i++ ) {
        if ( labels[i].offsetWidth > longest_width ) {
            longest_width = labels[i].offsetWidth;
        }
    }

    var li_width = input.offsetWidth + longest_width;
    li_width *= 2.5;

    if ( li_width <  100 ) {
        li_width = 100;
    }
    else if ( li_width > 700 ) {
        li_width = 700;
    }

    ul.style.width = li_width + "px";

    DOM.Element.hide(ul);

    ul.style.position = "";
    ul.style.left     = "";

    DOM.Element.show(ul);
};
