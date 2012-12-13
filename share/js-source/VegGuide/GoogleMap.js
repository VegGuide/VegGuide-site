JSAN.use("DOM.Element");
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.GoogleMap = function ( div_id ) {
    var map_div = $(div_id);

    if ( ! map_div ) {
        return;
    }

    VegGuide.GoogleMap._makeIcons();
    this._createGoogleMap( map_div );
}

VegGuide.GoogleMap.prototype._createGoogleMap = function ( map_div ) {
    var map = new google.maps.Map(
        map_div,
        {
            zoom: 13,
            mapTypeControl: true,
            mapTypeControlOptions: {
                style: google.maps.MapTypeControlStyle.DROPDOWN_MENU
            },
            zoomControl: true,
            zoomControlOptions: {
                style: google.maps.ZoomControlStyle.SMALL
            },
            mapTypeId: google.maps.MapTypeId.ROADMAP
        }
    );

    var height;
    if ( typeof window.innerHeight == "number" ) {
        height = window.innerHeight * 0.6;
    }
    else {
        height = document.documentElement.clientHeight * 0.6;
    }

    map_div.style.height = height + "px";

    var vendor_list = $("vendor-list");
    if (vendor_list) {
        vendor_list.style.height = height + "px";
    }

    this.map = map;
};

VegGuide.GoogleMap.prototype.addMarkers = function (points) {
    this.map.setCenter( new google.maps.LatLng( points[0].latitude, points[0].longitude ) );

    for ( var i = 0; i < points.length; i++ ) {
        var point = points[i];

        var ll = new google.maps.LatLng ( point.latitude, point.longitude );

        if ( point.info_div ) {
            var div = $( point.info_div ).cloneNode(true);
            DOM.Element.show(div);
        }

        var marker = this._createMarker( ll, point, div );

        if ( point.info_div ) {
            var show_link = $( "show-" + point.info_div );
            if (show_link) {
                this._instrumentShowLink( show_link, marker );
            }
        }

        this.map.addOverlay(marker);

        if ( ! this.marker ) {
            this.marker = marker;
        }
    }
};

VegGuide.GoogleMap.prototype.showFirstInfoWindow = function () {
    GEvent.trigger( this.marker, "click" );
};

VegGuide.GoogleMap._Icons = {};

VegGuide.GoogleMap._makeIcons = function () {
    var base_icon = new google.maps.Icon();

    base_icon.Size = new google.maps.Size( 29, 40 );
    base_icon.Anchor = new google.maps.Point( 15, 40 );

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
                  [ "c2.1", "grocery1" ],
                  [ "c2.2", "grocery2" ],
                  [ "c2.3", "grocery3" ],
                  [ "c2.4", "grocery3" ],
                  [ "c2.5", "grocery5" ],
                  [ "c3",   "catering" ],
                  [ "c4",   "organization" ],
                  [ "c5",   "coffee" ],
                  [ "c5.1", "coffee1" ],
                  [ "c5.2", "coffee2" ],
                  [ "c5.3", "coffee3" ],
                  [ "c5.4", "coffee3" ],
                  [ "c5.5", "coffee5" ],
                  [ "c6",   "bar" ],
                  [ "c6.1", "bar1" ],
                  [ "c6.2", "bar2" ],
                  [ "c6.3", "bar3" ],
                  [ "c6.4", "bar3" ],
                  [ "c6.5", "bar5" ],
                  [ "c7",   "general_store" ],
                  [ "c7.1", "general_store1" ],
                  [ "c7.2", "general_store2" ],
                  [ "c7.3", "general_store3" ],
                  [ "c7.4", "general_store3" ],
                  [ "c7.5", "general_store5" ],
                  [ "c8",   "other" ],
                  [ "c9",   "food_court" ],
                  [ "c9.1", "food_court1" ],
                  [ "c9.2", "food_court2" ],
                  [ "c9.3", "food_court3" ],
                  [ "c9.4", "food_court3" ],
                  [ "c9.5", "food_court5" ],
                  [ "c10",  "lodging" ],
                  [ "c10.1","lodging1" ],
                  [ "c10.2","lodging2" ],
                  [ "c10.3","lodging3" ],
                  [ "c10.4","lodging3" ],
                  [ "c10.5","lodging5" ]
                ];

    for ( var i = 0; i < icons.length; i++ ) {
        var key  = icons[i][0];
        var name = icons[i][1];

        var image_uri = "/images/map-icons/" + name + ".png";
        VegGuide.GoogleMap._Icons[key] = new google.maps.Icon( base_icon, image_uri );
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

    var self = this;

    if (div) {
        var new_div = div.cloneNode(true);
        new_div.id = "";

        marker.bindInfoWindow(new_div);
    }

    return marker;
};

VegGuide.GoogleMap.prototype._instrumentShowLink = function ( link, marker ) {
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
