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

    VegGuide.FrontPageGeolocation.nearby.innerHTML = "<p>Finding nearby restaurants ...</p>";

    if ( navigator.geolocation ) {
        navigator.geolocation.getCurrentPosition( VegGuide.FrontPageGeolocation._setNavigatorCoordinates );
    }
    else {
        VegGuide.FrontPageGeolocation.noGeolocation = true;
    }

    geoip2.omni( VegGuide.FrontPageGeolocation._setGeoIPCoordinates );

    VegGuide.FrontPageGeolocation.timeout =
        window.setTimeout( VegGuide.FrontPageGeolocation._getNearbyList, 2000 );
};

VegGuide.FrontPageGeolocation._setNavigatorCoordinates = function (position) {
    VegGuide.FrontPageGeolocation.geolocation = position;

    if ( VegGuide.FrontPageGeolocation.geoip ) {
        VegGuide.FrontPageGeolocation._getNearbyList();
    }
}

VegGuide.FrontPageGeolocation._setGeoIPCoordinates = function (geoip) {
    VegGuide.FrontPageGeolocation.geoip = geoip;

    if (  VegGuide.FrontPageGeolocation.noGeolocation || VegGuide.FrontPageGeolocation.geolocation ){
        VegGuide.FrontPageGeolocation._getNearbyList();
    }
}

VegGuide.FrontPageGeolocation._getNearbyList = function () {
    window.clearTimeout( VegGuide.FrontPageGeolocation.timeout );

    /* Sometimes this gets called twice (at least in Firefox) */
    if ( VegGuide.FrontPageGeolocation.fetching ) {
        return;
    }

    VegGuide.FrontPageGeolocation.fetching = 1;

    var latitude, longitude;

    var geoip = VegGuide.FrontPageGeolocation.geoip;
    var geolocation = VegGuide.FrontPageGeolocation.geolocation;

    if ( geoip && geolocation ) {
        if ( geoip.location.accuracy_radius < ( geolocation.coords.accuracy / 1000 ) ) {
            latitude = geoip.location.latitude;
            longitude = geoip.location.longitude;
        }
        else {
            latitude = geolocation.coords.latitude;
            longitude = geolocation.coords.longitude;
        }
    }
    else if (geoip) {
        latitude = geoip.location.latitude;
        longitude = geoip.location.longitude;
    }
    else if (geolocation) {
        latitude = geolocation.coords.latitude;
        longitude = geolocation.coords.longitude;
    }

    if ( typeof latitude === "undefined" ) {
        VegGuide.FrontPageGeolocation.nearby.innerHTML = "<p>Sorry, we can't figure out your location. Did you disable geolocation on your system or deny VegGuide.org permission to locate you?</p>";
        return;
    }

    var uri = "/entry/near/"
              + latitude + "%2C" + longitude
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
            list = list + '<li><a href="'
                + response.entries[i].uri
                + '">' + response.entries[i].name
                + " - " + response.entries[i].distance
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
