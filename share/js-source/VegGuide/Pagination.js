JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.Pagination = {};

VegGuide.Pagination.instrumentPage = function () {
    var table = $("entries-table");
    if ( ! table ) {
        return;
    }

    var selects = document.getElementsByClassName("entries-per-page");

    for ( var i = 0; i < selects.length; i++ ) {
        VegGuide.Pagination._instrumentSelect( selects[i] );
    }
};

VegGuide.Pagination._instrumentSelect = function (select) {
    var node = select;
    while ( node = node.parentNode ) {
        if ( node.tagName == "THEAD" ) {
            return;
        }
        else if ( node.tagName == "TFOOT" ) {
            break;
        }
    }

    DOM.Events.addListener(
        select,
        "change",
        VegGuide.Pagination._submitForm
    );

    DOM.Element.show( select.form );
};

VegGuide.Pagination._submitForm = function (e) {
    var select = e.target;

    select.form.submit();
};
