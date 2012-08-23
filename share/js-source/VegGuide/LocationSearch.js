JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('VegGuide.Form');
JSAN.use('VegGuide.InlineSearchForm');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.LocationSearch = {};

VegGuide.LocationSearch.instrumentPage = function () {
    new VegGuide.InlineSearchForm( "location", "/region/search", VegGuide.LocationSearch._populateLocationList );
};

VegGuide.LocationSearch._populateLocationList = function ( res, div ) {
    var locations = eval( "(" + res.responseText + ")" );

    if ( ! locations.length ) {
        div.appendChild( document.createTextNode( "No matching locations found." ) );
        return;
    }

    var ul = document.createElement("ul");
    ul.className = "inline-search";

    for ( var i = 0; i < locations.length; i++ ) {
        var loc = locations[i];
        var matches = loc.uri.match( /\/(\d+)$/ );
        var location_id = matches[1];

        var radio = document.createElement("input");

        radio.type  = "radio";
        radio.name  = "location_id";
        radio.value = location_id;
        radio.id    = "location_id-" + location_id;
        radio.className = "radio";

        var label = document.createElement("label");
        label.htmlFor = radio.id;

        var text = loc.name;
        if ( loc.parent ) {
            text += ", " + loc.parent.name;
        }

        if ( loc.cities ) {
            text += " (has cities which match the name you provided)";
        }

        label.appendChild( document.createTextNode(text) );

        var li = document.createElement("li");

        li.appendChild(radio);
        li.appendChild( document.createTextNode(" ") );
        li.appendChild(label);

        ul.appendChild(li);
    }

    DOM.Element.hide(div);

    div.appendChild(ul);

    DOM.Element.show(div);

    VegGuide.Form.resizeRadioOrCheckboxList("location-search-results");
};
