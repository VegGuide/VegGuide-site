JSAN.use("DOM.Events");
JSAN.use("VegGuide.Element");

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.SitewideSearch = {};

VegGuide.SitewideSearch._defaultValue = "name, city, or address";

VegGuide.SitewideSearch.instrumentPage = function () {
    var input = $("sitewide-search-input");

    /* XXX - this happens with IE. Why? */
    if ( ! input ) {
        return;
    }

    if ( input.value == undefined || ! input.value.length ) {
        input.value = VegGuide.SitewideSearch._defaultValue;
    }

    var help_div = $("sitewide-search-help");

    DOM.Events.addListener(
        input,
        "focus",
        function (e) {
            if ( e.target.value == VegGuide.SitewideSearch._defaultValue ) {
                e.target.value = "";
            }

            VegGuide.SitewideSearch._positionHelpDiv( e.target, help_div );
            DOM.Element.show(help_div);
        }
    );

    DOM.Events.addListener(
        $("sitewide-search-help-close"),
        "click",
        function (e) {
            input.focus();
            DOM.Element.hide(help_div);

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );

    /* The timeout thing is a hack so that the click handler above has
       a chance to do its thing before the blur handler does its
       thing. It also lets links in the help text work. */
    DOM.Events.addListener(
        input,
        "blur",
        function (e) {
            setTimeout( "DOM.Element.hide($('sitewide-search-help'))", 500 );
        }
    );
};

VegGuide.SitewideSearch._positionHelpDiv = function ( input, div ) {
    var pos = VegGuide.Element.realPosition(input);

    var top = pos.top;
    top += input.offsetHeight - 2;

    div.style.top = top + "px";
    div.style.left = pos.left + "px";

    /* XXX - I have no idea why this multiplier is necessary, but it
       seems to work (with FF2) */
    div.style.width = ( input.offsetWidth * 0.958 ) + "px";
};