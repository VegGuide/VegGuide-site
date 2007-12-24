JSAN.use('DOM.Element');
JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('Form.Serializer');
JSAN.use('HTTP.Request');
JSAN.use('VegGuide.Widget.PairedMultiSelect');
JSAN.use('Widget.Lightbox2');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.EntryFilters = {};

VegGuide.EntryFilters.instrumentPage = function () {
    var lb_content = $("region-filter-lightbox");
    var show_link = $("filter-toggle");

    if ( ! ( lb_content && show_link ) ) {
        return;
    }

    var browser = new VegGuide.Browser;

    if ( browser.isIE ) {
        VegGuide.EntryFilters._instrumentFilterForms();
        VegGuide.EntryFilters._instrumentFilterToggles();
    }

    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "category_id", "categories" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "cuisine_id", "cuisines" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "payment_option_id", "options" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "attribute_id", "features" );

    if ( ! browser.isIE ) {
        VegGuide.EntryFilters._instrumentFilterForms();
        VegGuide.EntryFilters._instrumentFilterToggles();
    }

    show_link.href = "#";

    var lb = new Widget.Lightbox2( { sourceElement: lb_content } );

    var showed = 0;
    DOM.Events.addListener(
        show_link,
        "click",
        function (e) {
            if ( ! showed ) {
                var form = VegGuide.EntryFilters._getForms()[0];

                VegGuide.EntryFilters._makeSubmitFunction(form)( e, form );

                showed = 1;
            }

            lb.show();

            /* This has to happen after we show the lightbox, or else
               nothing happens because the browser thinks the forms
               are already hidden */
            VegGuide.EntryFilters._hideAllFilterForms();

            VegGuide.EntryFilters._makeShowFunction("category-form")(e);

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );
};

VegGuide.EntryFilters._hideAllFilterForms = function () {
    var toggles = document.getElementsByClassName("filter-toggle");
    for ( var i = 0; i < toggles.length; i++ ) {
        toggles[i].parentNode.className = "";
    }

    var forms = VegGuide.EntryFilters._getForms();

    for ( var i = 0; i < forms.length; i++ ) {
        DOM.Element.hide( forms[i] );
    }
};

VegGuide.EntryFilters._getForms = function () {
    if ( ! VegGuide.EntryFilters._filterForms ) {
        VegGuide.EntryFilters._filterForms = document.getElementsByClassName("filter-form");
    }

    return VegGuide.EntryFilters._filterForms;
}

VegGuide.EntryFilters._instrumentFilterForms = function () {
    var forms = VegGuide.EntryFilters._getForms();

    for ( var i = 0; i < forms.length; i++ ) {
        var form = forms[i];

        DOM.Events.addListener(
            form,
            "submit",
            VegGuide.EntryFilters._makeSubmitFunction(form)
        );
    }
};

VegGuide.EntryFilters._instrumentFilterToggles = function () {
    var toggles = document.getElementsByClassName("filter-toggle");

    for ( var i = 0; i < toggles.length; i++ ) {
        var link = toggles[i];

        var form_id = link.id.replace( /-toggle$/, '-form' );

        DOM.Events.addListener(
            link,
            "click",
            VegGuide.EntryFilters._makeShowFunction(form_id)
       );
    }
};

/* For some reason this needs to be done in a separate function in
   order to create a proper closure. Defining this anonymous function
   inline in the call to addListener does not capture the value of
   form_id. */
VegGuide.EntryFilters._makeShowFunction = function (form_id) {
    /* Cannot return the function directly */
    var func = function (e) {
        VegGuide.EntryFilters._showForm( e, form_id );
    };

    return func;
};

VegGuide.EntryFilters._showForm = function( e, form_id ) {
    VegGuide.EntryFilters._hideAllFilterForms();

    e.target.parentNode.className = "current";

    DOM.Element.show(form_id);

    var divs = VegGuide.EntryFilters._getWPMSDivs( $(form_id) );

    if ( divs && divs[0] && divs[0].id ) {
        var match = divs[0].id.match(/^(\w+)-wpms$/);

        if ( match && ! VegGuide.EntryFilters._resized[ match[1] ] ) {
            VegGuide.Widget.PairedMultiSelect.resizeWPMS(
                $( "possible_" + match[1] ),
                $( match[1] ),
                $( divs[0].id )
            );

            VegGuide.EntryFilters._resized[ match[1] ] = true;
        }
    }

    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }
};

VegGuide.EntryFilters._cache = { wpms_divs: {} };

VegGuide.EntryFilters._getWPMSDivs = function (form) {
    var id = form.id;

    if ( VegGuide.EntryFilters._cache.wpms_divs[id] ) {
        return VegGuide.EntryFilters._cache.wpms_divs[id];
    }

    var divs = DOM.Find.getElementsByAttributes( { id: /-wpms$/ }, form );

    VegGuide.EntryFilters._cache.wpms_divs[id] = divs;

    return divs;
};

VegGuide.EntryFilters._makeSubmitFunction = function (form) {
    var func = function (e) {
        VegGuide.EntryFilters._submitForm( e, form );

        var divs = VegGuide.EntryFilters._getWPMSDivs(form);

        if ( divs && divs[0] ) {
            var options =
                DOM.Find.getElementsByAttributes( { tagName: "OPTION" }, divs[0] );

            if ( options ) {
                for ( var i = 0; i < options.length; i++ ) {
                    options[i].selected = false;
                }
            }
        }
    };

    return func;
};

VegGuide.EntryFilters._resized = {};

VegGuide.EntryFilters._submitForm = function ( e, form ) {
    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }

    var ie_hack = DOM.Find.getElementsByAttributes( { "tagName": "INPUT",
                                                      "name":    "ie-hack" }, form )[0];

    if ( ! ie_hack ) {
        ie_hack = document.createElement("input");
        ie_hack.type = "hidden";
        ie_hack.name = "ie-hack";

        form.appendChild(ie_hack);
    }

    ie_hack.value = new Date().getTime();

    var ser = new Form.Serializer (form);

    VegGuide.EntryFilters._refreshFilters( form.action, ser.queryString() );
};

VegGuide.EntryFilters._refreshFilters = function ( uri, queryString ) {
    if ( uri.match( /\/region\/\d+$/ ) ) {
        uri += "/filter";
    }

    var req = new HTTP.Request ( {
        parameters: queryString,
        onSuccess:  VegGuide.EntryFilters._handleSubmitSuccess
        }
    );

    req.request(uri);
};

VegGuide.EntryFilters._handleSubmitSuccess = function (res) {
    var search = eval( "(" + res.responseText + ")" );

    var filters = $("current-lightbox-filters");

    while ( filters.firstChild ) {
        filters.removeChild( filters.firstChild );
    }

    if ( search.filters.length ) {
        for ( var i = 0; i < search.filters.length; i++  ) {
            var li = document.createElement("li");

            li.appendChild( VegGuide.EntryFilters._makeDeleteFilterButton( search.filters[i].delete_uri ) );
            li.appendChild( document.createTextNode( " ... " + search.filters[i].description ) );

            filters.appendChild(li);
        }
    }
    else {
        var li = document.createElement("li");
        li.appendChild( document.createTextNode( "No filters applied, showing everything." ) );

        filters.appendChild(li);
    }

    var count_text = "Found " + search.count + " entr";
    count_text += search.count != 1 ? "ies" : "y";
    count_text += ".";

    var show_link = document.createElement("a");
    show_link.href = search.uri;
    show_link.appendChild( document.createTextNode("Show these results") );

    var summary_li = document.createElement("li");
    summary_li.id = "filter-summary";
    summary_li.appendChild( document.createTextNode(count_text) );
    summary_li.appendChild( document.createElement("br") );
    summary_li.appendChild(show_link);

    filters.appendChild(summary_li);

    var forms = VegGuide.EntryFilters._getForms();
    for ( var i = 0; i < forms.length; i++ ) {
        forms[i].action = search.uri;
    }
};

VegGuide.EntryFilters._makeDeleteFilterButton = function (uri) {
    var button = document.createElement("button");
    button.className = "action-button-medium";
    button.title = "delete this filter";

    button.appendChild( document.createTextNode("x") );

    DOM.Events.addListener(
        button,
        "click",
        function (e) {
            VegGuide.EntryFilters._refreshFilters( uri, "" );

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }            
        }
    );

    return button;
};