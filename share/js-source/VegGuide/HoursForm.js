JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('Form.Serializer');
JSAN.use('HTTP.Request');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.HoursForm = {};

VegGuide.HoursForm.Days = [ "Monday", "Tuesday", "Wednesday",
                            "Thursday", "Friday", "Saturday", "Sunday" ];

VegGuide.HoursForm.instrumentPage = function () {
    if ( ! $("hours-form") ) {
        return;
    }

    for ( var d = 0; d <= 6; d++ ) {
        var hours0 = $( "hours-" + d + "-0" );

        DOM.Events.addListener( hours0, "blur", VegGuide.HoursForm._FetchDescriptions );

        var hours1 = $( "hours-" + d + "-1" );
        DOM.Events.addListener( hours1, "blur", VegGuide.HoursForm._FetchDescriptions );

        var checkbox = $( "is-closed-" + d );

        var closed_toggler_func = VegGuide.HoursForm._makeTextFieldEnabledToggler(d);

        DOM.Events.addListener( checkbox, "change", closed_toggler_func );
        DOM.Events.addListener( checkbox, "change", VegGuide.HoursForm._FetchDescriptions );

        closed_toggler_func( { target: checkbox } );

        var and_link = $( "and-" + d );
        
        var and_toggler_func = VegGuide.HoursForm._makeSecondaryHoursToggler(d);

        DOM.Events.addListener( and_link, "click", and_toggler_func );

        if ( hours1.value.length ) {
            var mock_event = { preventDefault: function () { } };
            and_toggler_func(mock_event);
        }
    }

    VegGuide.HoursForm._FetchDescriptions();
};

VegGuide.HoursForm._makeTextFieldEnabledToggler = function (day) {
    var d = day;

    var func = function (e) {
        var dis = e.target.checked ? true : false;

        var hours0 = $( "hours-" + d + "-0" );

        hours0.disabled = dis;

        if (dis) {
            DOM.Element.addClassName( hours0, "disabled" );
        }
        else {
            DOM.Element.removeClassName( hours0, "disabled" );
        }

        var hours1 = $( "hours-" + d + "-1" );

        if (hours1) {
            hours1.disabled = dis;

            if (dis) {
                DOM.Element.addClassName( hours1, "disabled" );
            }
            else {
                DOM.Element.removeClassName( hours1, "disabled" );
            }
        }
    };

    return func;
};

VegGuide.HoursForm._makeSecondaryHoursToggler = function (day) {
    var d = day;

    var func = function (e) {
        var sec = $( "secondary-hours-" + d );
        DOM.Element.toggle(sec);

        if ( sec.style.display == "none" ) {
            $( "hours-" + d + "-1" ).value = "";

            VegGuide.HoursForm._FetchDescriptions();
        }

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    return func;
};

VegGuide.HoursForm._FetchDescriptions = function () {
    var ser = new Form.Serializer("hours-form");

    var req = new HTTP.Request( {
        parameters: ser.queryString(),
        method:     "get",
        onSuccess:  VegGuide.HoursForm._updateDescriptions
        }
    );

    var uri = "/hours-descriptions";
    req.request(uri);
};

VegGuide.HoursForm._updateDescriptions = function (res) {
    var descriptions = eval( "(" + res.responseText + ")" );

    for ( var d = 0; d <= 6; d++ ) {
        if ( ! descriptions[d] ) {
            continue;
        }

        if ( descriptions[d].s0 == "closed" ) {
            var checkbox = $( "is-closed-" + d );
            checkbox.checked = true;

            var mock_event = { target: checkbox, preventDefault: function () { } };
            VegGuide.HoursForm._makeTextFieldEnabledToggler(d)(mock_event);
        }

        var hours0 = $( "hours-" + d + "-0" );
        var hours1 = $( "hours-" + d + "-1" );

        if ( typeof descriptions[d].error != "undefined" ) {
            DOM.Element.addClassName( hours0, "error" );
            DOM.Element.addClassName( hours1, "error" );

            var error = $( "error-" + d );
            error.appendChild( document.createTextNode( descriptions[d].error ) );
            DOM.Element.show(error);

            continue;
        }
        else {
            DOM.Element.removeClassName( hours0, "error" );
            DOM.Element.removeClassName( hours1, "error" );

            var error = $( "error-" + d );
            DOM.Element.hide(error);

            if ( error.firstChild ) {
                error.removeChild( error.firstChild );
            }
        }

        hours0.value = descriptions[d].s0;

        if ( descriptions[d].s1 ) {
            hours1.value = descriptions[d].s1;
            DOM.Element.show( $( "secondary-hours-" + d ) );
        }
    };
};

VegGuide.HoursForm._replaceTextWith = function ( elt, text ) {
    while ( elt.firstChild ) {
        elt.removeChild( elt.firstChild );
    }

    elt.appendChild( document.createTextNode(text) );
};
