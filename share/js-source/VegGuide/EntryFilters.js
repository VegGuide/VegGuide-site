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
    var toggle = $("more-filters-toggle");

    if (! toggle) {
        return;
    }

    VegGuide.EntryFilters._instrumentMoreFiltersToggle();
    VegGuide.EntryFilters._instrumentFilterToggles();
};

VegGuide.EntryFilters._instrumentMoreFiltersToggle = function () {
    var toggle = $("more-filters-toggle");

    var more_div = $("more-filters");

    var orig_text = toggle.innerHTML;

    DOM.Events.addListener(
        toggle,
        "click",
        function () {
            if ( more_div.style.display ) {
                DOM.Element.show(more_div);
                toggle.innerHTML = "Hide filters";
            }
            else {
                DOM.Element.hide(more_div);
                toggle.innerHTML = orig_text;
            }
        }
    );
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

    var forms = VegGuide.EntryFilters._getForms();

    DOM.Element.show( forms[0] );
};

/* For some reason this needs to be done in a separate function in
   order to create a proper closure. Defining this anonymous function
   inline in the call to addListener does not capture the value of
   form_id. */
VegGuide.EntryFilters._makeShowFunction = function (form_id) {
    var id = form_id;

    /* Cannot return the function directly */
    var func = function (e) {
        VegGuide.EntryFilters._showForm( e, id );

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    return func;
};

VegGuide.EntryFilters._showForm = function( e, form_id ) {
    VegGuide.EntryFilters._hideAllFilterForms();

    e.target.parentNode.className = "current";

    DOM.Element.show(form_id);

    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }
};

VegGuide.EntryFilters._hideAllFilterForms = function () {
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