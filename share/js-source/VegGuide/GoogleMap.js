JSAN.use("DOM.Element");
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.GoogleMap = function ( div_id, is_tiny ) {
    var map_div = $(div_id);

    if ( ! ( map_div && GBrowserIsCompatible() ) ) {
        return;
    }

    VegGuide.GoogleMap._makeIcons();
    this._createGoogleMap( map_div, is_tiny );
}

VegGuide.GoogleMap.prototype._createGoogleMap = function ( map_div, is_tiny ) {
    var map = new GMap2(map_div);

    map.addControl( new GSmallMapControl() );
    if (! is_tiny) {
        map.addControl( new GMapTypeControl() );
    }

    this.map = map;
    this.info_width = is_tiny ? 130 : 400;
    this.markers = [];
};

VegGuide.GoogleMap.prototype.addMarkers = function (points) {
    this.map.setCenter( new GLatLng( points[0].latitude, points[0].longitude ), 13 );

    for ( var i = 0; i < points.length; i++ ) {
        var point = points[i];

        var ll = new GLatLng ( point.latitude, point.longitude );

        if ( point.info_div ) {
            var div = $( point.info_div ).cloneNode(true);
            DOM.Element.show(div);
        }

        var marker = this._createMarker( ll, point, div );

        if ( point.info_div ) {
            var show_link = $( "show-" + point.info_div );
            if (show_link) {
                this._instrumentShowLink( show_link, marker, div );
            }
        }

        this.map.addOverlay(marker);

        this.markers.push(marker);
    }
};

VegGuide.GoogleMap.prototype.showFirstInfoWindow = function () {
    GEvent.trigger( this.markers[0], "click" );
};

VegGuide.GoogleMap._Icons = {};

VegGuide.GoogleMap._makeIcons = function () {
    var base_icon = new GIcon();

    base_icon.iconSize = new GSize( 29, 40 );
    base_icon.iconAnchor = new GPoint( 15, 40 );
    base_icon.infoWindowAnchor = new GPoint( 5, 1 );
    base_icon.shadow = "/images/map-icons/shadow.png";
    base_icon.shadowSize = new GSize( 60, 40 );

    /* The first element in each pair is the key and the second is the
       icon name. The keys are category ids, and things like "1.1"
       mean category_id = 1, veg_level = 1 */
    var icons = [ [ "c1",   "restaurant" ],
                  [ "c1.1", "restaurant1" ],
                  [ "c1.2", "restaurant2" ],
                  [ "c1.3", "restaurant3" ],
                  /* not a typo ;) */
                  [ "c1.4", "restaurant3" ],
                  [ "c1.5", "restaurant5" ],
                  [ "c2",   "grocery" ],
                  [ "c3",   "catering" ],
                  [ "c4",   "organization" ],
                  [ "c5",   "coffee" ],
                  [ "c6",   "bar" ],
                  [ "c7",   "general_store" ],
                  [ "c8",   "other" ],
                  [ "c9",   "food_court" ],
                  [ "c10",  "lodging" ] ];

    for ( var i = 0; i < icons.length; i++ ) {
        var key  = icons[i][0];
        var name = icons[i][1];

        var image_uri = "/images/map-icons/" + name + ".png";
        VegGuide.GoogleMap._Icons[key] = new GIcon( base_icon, image_uri );
    }
};

VegGuide.GoogleMap.prototype._createMarker = function ( ll, point, div ) {
    var marker;

    if ( point.category_id && point.veg_level ) {
        var keys = [ "c" + point.category_id + "." + point.veg_level,
                     "c" + point.category_id ];

        var icon;
        for ( var i = 0; i < keys.length; i++ ) {
            if ( VegGuide.GoogleMap._Icons[ keys[i] ] ) {
                icon = VegGuide.GoogleMap._Icons[ keys[i] ];
                break;
            }
        }

        marker = new GMarker( ll, { icon: icon } );
    }
    else {
        marker = new GMarker( ll, { title: point.title } );
    }

    var width = this.info_width;

    var self = this;

    if (div) {
        marker.bindInfoWindow( div, { maxWidth: this.info_width } );
    }

    return marker;
};

VegGuide.GoogleMap.prototype._instrumentShowLink = function ( link, marker ) {
    var width = this.info_width;

    var self = this;

    DOM.Events.addListener(
        link,
        "click",
        function (e) {
            GEvent.trigger( marker, "click" );

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );
};

VegGuide.GoogleMap.prototype.showDirectionsFromForm = function (form) {
    var directions = new GDirections( this.map, $("google-maps-directions-text") );

    var query = "from: " + form.elements["from"].value + " to: " + form.elements["to"].value;
    directions.load(query);
};

DOM.Ready.onDOMDone( function () {
    if ( window.GUnload ) {
        DOM.Events.addListener(
            window,
            "unload",
            window.GUnload
        );
    }
} );
