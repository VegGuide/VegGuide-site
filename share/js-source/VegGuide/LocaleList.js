JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.LocaleList = {};

VegGuide.LocaleList.instrumentPage = function () {
    /* We don't need this div, but it's a marker that we're on the
       right page. */
    if ( ! $("new-locale") ) {
        return;
    }

    var toggles = DOM.Find.getElementsByAttributes( { tagName: "A",
                                                      className: /locale-edit-toggle/ } );

    for ( var i = 0; i < toggles.length; i++ ) {
        VegGuide.LocaleList._instrumentToggle( toggles[i] );
    }      
};

VegGuide.LocaleList._instrumentToggle = function (link) {
    var matches = link.href.match( /#(\d+)$/ );
    var locale_id = matches[1];

    var form = $( "locale-form-" + locale_id );
    DOM.Events.addListener(
        link,
        "click",
        function (e) {
            DOM.Element.toggle(form);

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );
};
