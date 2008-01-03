JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.Suggestions = {};

VegGuide.Suggestions.instrumentPage = function () {
    var div = $("body");

    if ( ! ( div && div.className.match( /suggestions/ ) ) ) {
        return;
    }

    var rejects = DOM.Find.getElementsByAttributes( { tagName: "INPUT",
                                                      name:    "reject" }, div );
    for ( var i = 0; i < rejects.length; i++ ) {
        VegGuide.Suggestions._instrumentRejectSubmit( rejects[i] );
    }      
};

VegGuide.Suggestions._instrumentRejectSubmit = function (reject) {
    reject.disabled = false;

    var form = reject.form;

    DOM.Events.addListener(
        reject,
        "click",
        function (e) {
            form["accepted"].value = "0";
            form["x-tunneled-method"].value = "DELETE";
        }
    );
};
