JSAN.use('HTTP.Request');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.FrontPageGeolocation = {};

VegGuide.FrontPageGeolocation.instrumentPage = function () {
    VegGuide.FrontPageGeolocation.nearby = $("nearby");

    if ( ! VegGuide.FrontPageGeolocation.nearby ) {
        return;
    }

    if ( ! navigator.geolocation && navigator.geolocation.getCurrentPosition ) {
        return;
    }

    VegGuide.FrontPageGeolocation.nearby.innerHTML = "<p>Finding nearby restaurants ...</p>";

    navigator.geolocation.getCurrentPosition( VegGuide.FrontPageGeolocation._getNearbyList );
};

VegGuide.FrontPageGeolocation._getNearbyList = function (location) {
    /* Sometimes this gets called twice (at least in Firefox) */
    if ( VegGuide.FrontPageGeolocation.fetching ) {
        return;
    }

    VegGuide.FrontPageGeolocation.fetching = 1;

    var uri = "/entry/near/"
              + location.coords.latitude + "%2C" + location.coords.longitude
              + "/filter/category_id=1;veg_level=2;allow_closed=0";

    var req = new HTTP.Request( {
        parameters: "limit=10;order_by=distance;address=Your+location",
        method:     "get",
        onSuccess:  VegGuide.FrontPageGeolocation._updateNearbyList
        }
    );

    req.request(uri);
};

VegGuide.FrontPageGeolocation._updateNearbyList = function (res) {
    var response = eval( "(" + res.responseText + ")" );

    if ( response.entries && response.entries.length ) {
        var list = "<ul>";

        for ( var i = 0; i < response.entries.length; i++ ) {
            var distance10 = parseFloat( response.entries[i].distance, 10 ) * 10;
            list = list + '<li><a href="'
                + response.entries[i].uri
                + '">' + response.entries[i].name
                + " - " + ( Math.round(distance10) / 10 )
                + "</a></li>";
        }

        var loc_name = response.location.name;
        if ( response.location.parent ) {
            loc_name = loc_name + ", " + response.location.parent;
        }

        if ( response.location.search_uri ) {
            list = list + '<li><a href="' + response.location.search_uri + '">';
            list = list + response.count + " ";
            list = list + ( response.count > 1 ? "restaurants" : "restaurant" );
            list = list + " near " + loc_name + "</a></li>";
        }

        list = list + "</ul>";

        var p = "<p>" + 'Browse all entries in <a href="';
        p = p + response.location.uri;
        p = p + '">' + loc_name;
        p = p + "</a>, including grocers, organizations, etc.</p>";

        VegGuide.FrontPageGeolocation.nearby.innerHTML = list + p;
    }
    else {
        VegGuide.FrontPageGeolocation.nearby.innerHTML = '<p>We don\'t have any restaurants near your current location. Please <a href="/site/help#editing">add some</a> if you can!</p>';
    }
};
