JSAN.use("DOM.Element");
JSAN.use("DOM.Events");
JSAN.use("DOM.Find");
JSAN.use("HTTP.Request");
JSAN.use("VegGuide.Browser");
JSAN.use("VegGuide.Element");

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.RatingStars = {};

VegGuide.RatingStars._ratingsDescriptions = [ "terrible", "fair", "good", "great", "excellent" ];

VegGuide.RatingStars.instrumentPage = function () {
    var stars_container = document.getElementsByClassName("rating-star-set");

    if ( ! stars_container.length ) {
        return;
    }

    VegGuide.RatingStars._makeStars();

    for ( var i = 0; i < stars_container.length; i++ ) {
        var stars =
            DOM.Find.getElementsByAttributes( { tagName: "IMG",
                                                className: /rate-\d+/ },
                                              stars_container[i] )[0];

        new VegGuide.RatingStarSet( stars_container[i].parentNode, stars );
    }
};

VegGuide.RatingStars._makeStars = function () {
    var browser = new VegGuide.Browser;

    var blue_stars = [];
    for ( var i = 1; i <= 5; i++ ) {
        var stars = new Image();
        stars.src = "/images/ratings/blue-" + i + "-00.png";

        if ( browser.requiresPngFilter ) {
            stars.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + stars.src + "', sizing='scale')";
            stars.src = "/images/transparent.gif";
        }

        stars.height = 18;
        stars.width = 90;

        blue_stars.push(stars);
    }

    VegGuide.RatingStars._blueStars = blue_stars;
};

VegGuide.RatingStarSet = function ( container, stars ) {
    this.original_image = stars;

    this.help_div = $("rating-help");

    if ( this.help_div ) {
        this.original_help_text = this.help_div.innerHTML;
    }

    var match = stars.className.match( /rate-(\d+)/ );
    this.vendor_id = match[1];

    this.current_rating = 0;

    this._instrumentStars(stars);
};

VegGuide.RatingStarSet.prototype._instrumentStars = function (stars) {
    var parent = stars.parentNode;

    var match = stars.className.match( /rate-\d+/ );

    var input = document.createElement("input");
    input.type = "image";
    input.src = stars.src;

    input.style.width = stars.width + "px";
    input.style.height = stars.height + "px";

    if ( stars.style.filter ) {
        input.style.filter = stars.style.filter;
    }

    this.input = input;

    var self = this;

    DOM.Events.addListener(
        input,
        "mouseover",
        function (e) {
            self._showRating(e);
        }
    );

    DOM.Events.addListener(
        input,
        "mousemove",
        function (e) {
            self._showRating(e);
        }
    );

    DOM.Events.addListener(
        input,
        "mouseout",
        function (e) {
            self._mouseOut();
        }
    );

    DOM.Events.addListener(
        input,
        "click",
        function (e) {
            e.target.blur();
            self._submitRating( e.target.value );

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );

    parent.replaceChild( input, stars );
};

VegGuide.RatingStarSet.prototype._showRating = function (e) {
    var pos = VegGuide.Element.realPosition( e.target );
    var x = e.pageX - pos.left;

    var rating = Math.floor( x / 18 );
    rating += 1;

    /* This seems to be a possible off-by-one problem that pops up
       different in each browser. Pixel-perfect accuracy doesn't
       matter that much here, so this hack works fine. */
    if ( rating < 1 ) {
        rating = 1;
    }
    else if ( rating > 5 ) {
        rating = 5;
    }

    if ( this.current_rating == rating ) {
        return;
    }

    this.current_rating = rating;

    e.target.value = rating;

    var blue = VegGuide.RatingStars._blueStars[ rating - 1 ];
    if ( ! blue ) {
        alert(rating);
    }
    e.target.src = blue.src;

    if ( blue.style.filter ) {
        e.target.style.filter = blue.style.filter;
    }

    if ( this.help_div ) {
        var desc = VegGuide.RatingStars._ratingsDescriptions[ rating - 1 ];

        this.help_div.innerHTML = desc.substring( 0, 1 ).toUpperCase() + desc.substring(1);
    }
};

VegGuide.RatingStarSet.prototype._mouseOut = function () {
    this._restoreImage();

    if ( this.help_div ) {
        this.help_div.innerHTML = this.original_help_text;
    }
};

VegGuide.RatingStarSet.prototype._restoreImage = function () {
    this.input.src = this.original_image.src;

    if ( this.original_image.style.filter ) {
        this.input.style.filter = this.original_image.style.filter;
    }

    this.current_rating = 0;
}

VegGuide.RatingStarSet.prototype._submitRating = function (rating) {
    var uri = "/entry/" + this.vendor_id + "/rating";

    var req = new HTTP.Request( {
        parameters: "rating=" + rating,
        asynchronous: false,
        method:       "post"
        }
    );

    req.request(uri);

    var response = eval( "(" + req.transport.responseText + ")" );

    if ( response.uri ) {
        window.location.href = response.uri;
        return;
    }

    var avg = $( "weighted-average-" + this.vendor_id );
    if (avg) {
        avg.innerHTML = response.weighted_average;
    }

    var sep = $("average-and-count-separator");
    if (sep) {
        DOM.Element.show(sep);
    }

    var count = $( "vote-count-" + this.vendor_id );
    if (count) {
        count.innerHTML = response.vote_count;
    }

    this.original_image = VegGuide.RatingStars._blueStars[ rating - 1 ];

    this._restoreImage();

    if ( this.help_div ) {
        this.help_div.innerHTML = this.original_help_text;
    }
};
