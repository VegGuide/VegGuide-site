JSAN.use('DOM.Element');
JSAN.use('Widget.PairedMultiSelect');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

if ( typeof VegGuide.Widget == "undefined" ) {
    VegGuide.Widget = {};
}

VegGuide.Widget.PairedMultiSelect = {};

VegGuide.Widget.PairedMultiSelect._savedOrder = {};

VegGuide.Widget.PairedMultiSelect.instrumentWPMS = function (name, label) {
    var poss_name = "possible_" + name;

    var selected_elt = document.getElementById(name);
    var possible_elt = document.getElementById(poss_name);

    if ( ! ( selected_elt && possible_elt ) ) {
        return;
    }

    var selected_opts = selected_elt.options;

    VegGuide.Widget.PairedMultiSelect._savedOrder[label] = {};
    for ( var i = 0; i < selected_opts.length; i++ ) {
        VegGuide.Widget.PairedMultiSelect._savedOrder[label][ selected_opts[i].text ] = i;

        var selected = selected_opts[i].selected;
        /* This works around a very odd bug in Firefox (2.0 only?)
           where the option is not marked as selected when the page is
           reloaded. */
        if ( selected_opts[i].getAttribute("selected") ) {
            selected = true;
        }

        var option = new Option( selected_opts[i].text,
                                 selected_opts[i].value,
                                 false,
                                 selected
                               );

        possible_elt[i] = option;
    }

    selected_opts.length = 0;

    var opts = {
        firstId:  poss_name,
        secondId: name,
        selectedFirstToSecondId: name + "-first-to-second",
        selectedSecondToFirstId: name + "-second-to-first"
    };

    var sort_function = eval ( "VegGuide.Widget.PairedMultiSelect._" + label + "Sort" );
    if (sort_function ) {
        opts.sortFunction = sort_function;
    }

    new Widget.PairedMultiSelect(opts);

    var div = document.getElementById( name + "-wpms" );
    div.style.display = "block";

    var optgroup = document.createElement("optgroup");
    optgroup.label = "Click to select";
    possible_elt.insertBefore( optgroup, possible_elt.firstChild );

    optgroup = document.createElement("optgroup");
    optgroup.label = "Selected " + label;
    selected_elt.insertBefore( optgroup, selected_elt.firstChild );

    DOM.Element.show(possible_elt);

    VegGuide.Widget.PairedMultiSelect.resizeWPMS( selected_elt, possible_elt, div );
};

VegGuide.Widget.PairedMultiSelect.resizeWPMS = function (select1, select2, context_elt) {
    var longest_string = "";

    for ( var i = 0; i < select1.options.length; i++ ) {
        if ( select1.options[i].text.length > longest_string.length ) {
            longest_string = select1.options[i].text;
        }
    }

    for ( var i = 0; i < select2.options.length; i++ ) {
        if ( select2.options[i].text.length > longest_string.length ) {
            longest_string = select2.options[i].text;
        }
    }

    if ( longest_string.length ) {
        var text = document.createTextNode(longest_string);
        var span = document.createElement("span");
        span.appendChild(text);

        var option = select1.options.length ? select1.options[0] : select2.options[0];

        if (option) {
            var styles;

            var multiplier = 1.4;
            /* IE */
            if ( option.currentStyle ) {
                styles = option.currentStyle;
                multiplier = 1.5;
            }
            /* Safari */
            else if ( option.style ) {
                styles = option.style;
            }
            /* FF */
            else {
                styles = document.defaultView.getComputedStyle( option, "" );
            }

            span.fontFamily = styles.fontFamily;
            span.fontWeight = styles.fontWeight;
            span.fontSize = styles.fontSize;
        }

        /* The element has to actually be in the document or it will
           not have an offsetWidth */
        context_elt.appendChild(span);

        var width = span.offsetWidth * multiplier;
        context_elt.removeChild(span);

        select1.style.width = width + "px";
        select2.style.width = width + "px";
    }
};

VegGuide.Widget.PairedMultiSelect._cuisinesSort = function ( a, b ) {
    return VegGuide.Widget.PairedMultiSelect._sortOnOriginalOrder( "cuisines", a, b );
};

VegGuide.Widget.PairedMultiSelect._sortOnOriginalOrder = function( key, a, b ) {
    var a_order = VegGuide.Widget.PairedMultiSelect._savedOrder[key][ a.text ];
    var b_order = VegGuide.Widget.PairedMultiSelect._savedOrder[key][ b.text ];

    if ( a_order < b_order ) return -1;
    if ( a_order > b_order ) return  1;
                             return  0;
};

VegGuide.Widget.PairedMultiSelect._featuresSort = function ( a, b ) {
    if ( a.text < b.text ) return -1;
    if ( a.text > b.text ) return  1;
                           return  0;
};

VegGuide.Widget.PairedMultiSelect._optionsSort = function ( a, b ) {
    if ( a.text < b.text ) return -1;
    if ( a.text > b.text ) return  1;
                           return  0;

};
