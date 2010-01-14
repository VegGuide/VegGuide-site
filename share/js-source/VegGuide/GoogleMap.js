JSAN.use("DOM.Element");
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.GoogleMap = function (div_id) {
    var map_div = $(div_id);

    if ( ! map_div ) {
        return;
    }

    VegGuide.GoogleMap._makeIcons();
    this._createGoogleMap(map_div);
}

VegGuide.GoogleMap.prototype._createGoogleMap = function (map_div) {
    var map_opts = { "zoom": 13,
                     "mapTypeId": google.maps.MapTypeId.ROADMAP };

    /* There's no sane way to get the div to fill the available height with
     * just CSS. 60% of the viewport seems to produce a reasonable height. */

    var height = window.innerHeight * 0.6;
    if ( height < 350 ) {
        height = 350;
    }
    map_div.style.height = height + "px";


    var map = new google.maps.Map( map_div, map_opts );

    var directions_display = new google.maps.DirectionsRenderer();
    directions_display.setMap(map);
    directions_display.setPanel( $("google-maps-directions-text") );

    var directions_service = new google.maps.DirectionsService();

    this.map = map;
    this.directions_display = directions_display;
    this.directions_service = directions_service;
    this.info_width = 400;
    this.markers = [];
};

VegGuide.GoogleMap.prototype.addMarkers = function (points) {
    this.map.setCenter( new google.maps.LatLng( points[0].latitude, points[0].longitude ) );

    for ( var i = 0; i < points.length; i++ ) {
        var point = points[i];

        var ll = new google.maps.LatLng( point.latitude, point.longitude );

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

        this.markers.push(marker);
    }
};

VegGuide.GoogleMap.prototype.showFirstInfoWindow = function () {
    google.maps.event.trigger( this.markers[0], "click" );
};

VegGuide.GoogleMap._Icons = {};


VegGuide.GoogleMap._makeIcons = function () {
/*
    base_icon.iconSize = new GSize( 29, 40 );
    base_icon.iconAnchor = new GPoint( 15, 40 );
    base_icon.infoWindowAnchor = new GPoint( 5, 1 );
    base_icon.shadow = "/images/map-icons/shadow.png";
    base_icon.shadowSize = new GSize( 60, 40 );
*/
    VegGuide.GoogleMap._shadow =
        new google.maps.MarkerImage(
            "/images/map-icons/shadow.png",
            new google.maps.Size( 60, 40 ),
            new google.maps.Point( 0, 0 ),
            new google.maps.Point( 15, 40 )
        );

    /* The first element in each pair is the key and the second is the
       icon name. The keys are category ids, and things like "c1.1"
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
        VegGuide.GoogleMap._Icons[key] =
            new google.maps.MarkerImage(
                image_uri,
                new google.maps.Size( 29, 40 ),
                new google.maps.Point( 0, 0 ),
                new google.maps.Point( 15, 40 )
            );
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

        marker = new google.maps.Marker(
            { map: this.map,
              position: ll,
              icon: icon,
              shadow: VegGuide.GoogleMap._shadow
            }
        );
    }
    else {
        marker = new google.maps.Marker( { map: this.map, position: ll, title: point.title } );
    }

    var width = this.info_width;

    var self = this;

    if (div) {
        var window = new google.maps.InfoWindow( { content: div,
                                                   maxWidth: this.info_width } );

        var map = this.map;

        var on_click = function() {
            window.open( map, marker );
        };

        google.maps.event.addListener( marker, 'click', on_click );
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
            google.maps.event.trigger( marker, "click" );

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );
};

VegGuide.GoogleMap.prototype.showDirectionsFromForm = function (form) {
    var request =  { origin: form.elements["from"].value,
                     destination: form.elements["to"].value,
                     travelMode: google.maps.DirectionsTravelMode.DRIVING
                   };

    var self = this;
    var on_response = function ( response, status ) {
        if ( status == google.maps.DirectionsStatus.OK ) {
            self.directions_display.setDirections(response);
        }
    };

    this.directions_service.route( request, on_response );
};
