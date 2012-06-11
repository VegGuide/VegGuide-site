JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
JSAN.use('HTTP.Request');
JSAN.use('Widget.Lightbox2');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.EntryImageSlideshow = function (lb) {
    this._init(lb);
};

VegGuide.EntryImageSlideshow._loaderImage = ( function() {
    var img = document.createElement("img");

    img.src = "/images/loader.gif";
    img.className = "loader";
    img.height = 32;
    img.width = 32;

    return img;
} )();

VegGuide.EntryImageSlideshow.instrumentPage = function () {
    var main_image = $("main-image");

    if ( ! main_image ) {
        return;
    }

    var lb = new Widget.Lightbox2( { sourceElement: $("slideshow-lightbox") } );

    var show = new VegGuide.EntryImageSlideshow (lb);

    var links =
        DOM.Find.getElementsByAttributes( { tagName:   "A",
                                            className: /activate-slideshow/
                                          },
                                          $("entry-images") );

    for ( var i = 0; i < links.length; i++ ) {
        var matches = links[i].className.match( /js-display-order-(\d+)/ );

        var show_func =
            VegGuide.EntryImageSlideshow._makeShowFunction( show, matches[1] );

        DOM.Events.addListener(
            links[i],
            "click",
            show_func
        );
    }
};

VegGuide.EntryImageSlideshow._makeShowFunction = function ( show, order ) {
    var s = show;
    var o = order;

    var show_func = function (e) {
        s.start(o);

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    return show_func;
};

VegGuide.EntryImageSlideshow.prototype._init = function (lb) {
    this.lb = lb;

    var matches = lb.content.className.match( /slideshow-for-(\d+)/ );
    if ( ! matches ) {
        return;
    }

    this.imageContainer       = $("slideshow-image-container");
    this.captionContainer     = $("slideshow-caption-container");
    this.attributionContainer = $("slideshow-attribution-container");
    this.controlsContainer    = $("slideshow-controls-container");
    this.prevContainer        = $("slideshow-prev-container");
    this.nextContainer        = $("slideshow-next-container");

    this.vendor_id = matches[1];

    this.images = [];
};

VegGuide.EntryImageSlideshow.prototype.start = function (order) {
    if ( ! this.vendor_id ) {
        return;
    }

    this.lb.show();

    this._showImage(order);
};

VegGuide.EntryImageSlideshow.prototype._showImage = function (imageNumber) {
    this._showLoader();

    var image = this._getImage(imageNumber);

    var img = document.createElement("img");

    img.src    = image.uri;
    img.alt    = "";
    img.height = image.height;
    img.width  = image.width;
    img.style.marginTop  = image.margin_top;
    img.style.marginLeft = image.margin_left;

    this._emptyElt( this.imageContainer );

    var link = document.createElement("a");
    link.title  = "View the full size image";
    link.href   = image.original_uri;
    link.target = "_new";

    link.appendChild(img);

    this.imageContainer.appendChild(link);

    this._emptyElt( this.captionContainer );
    if ( image.caption ) {
        var caption = document.createTextNode( image.caption );
        this.captionContainer.appendChild(caption);
    }

    this._emptyElt( this.attributionContainer );

    var attribution = document.createTextNode( ' Uploaded by ' );
    var user_link = document.createElement("a");
    user_link.href = image.user.uri;
    user_link.appendChild( document.createTextNode( image.user.name ) );

    this.attributionContainer.appendChild(attribution);
    this.attributionContainer.appendChild(user_link);

    var prev_link;
    if ( image.previous ) {
        prev_link = this._makeControLink( "previous", image.previous );
    }

    var next_link;
    if ( image.next ) {
        next_link = this._makeControLink( "next", image.next );
    }

    this._emptyElt( this.prevContainer );
    this._emptyElt( this.nextContainer );

    if (next_link) {
        this.nextContainer.appendChild(next_link);
    }

    if (prev_link) {
        this.prevContainer.appendChild(prev_link);
    }

    if ( prev_link || next_link ) {
        DOM.Element.removeClassName( this.controlsContainer, "empty" );
    }
    else {
        DOM.Element.addClassName( this.controlsContainer, "empty" );
    }
}

VegGuide.EntryImageSlideshow.prototype._getImage = function (imageNumber) {
    if ( ! this.images[ imageNumber - 1 ] ) {
        var req = new HTTP.Request( {
            asynchronous: false,
            method:       "get"
            }
        );

        var uri = "/entry/" + this.vendor_id + "/image/" + imageNumber;
        req.request(uri);

        var image = eval( "(" + req.transport.responseText + ")" );

        var container_height = this.imageContainer.offsetHeight;
        var container_width  = this.lb.content.offsetWidth;

        image.margin_top  = ( ( container_height - image.height ) / 2 ) + "px";
        image.margin_left = ( ( container_width - image.width ) / 2 ) + "px";

        this.images[ imageNumber - 1 ] = image;
    }

    return this.images[ imageNumber - 1 ];
};

VegGuide.EntryImageSlideshow.prototype._showLoader = function () {
    this._emptyElt( this.imageContainer );

    this.imageContainer.appendChild( VegGuide.EntryImageSlideshow._loaderImage );
};

VegGuide.EntryImageSlideshow.prototype._emptyElt = function (elt) {
    while ( elt.firstChild ) {
        elt.removeChild( elt.firstChild );
    }
};

VegGuide.EntryImageSlideshow.prototype._makeControLink = function ( text, number ) {
    var link = document.createElement("a");
    link.appendChild( document.createTextNode(text) );
    link.className = "action-button-medium " + text;
    link.href = "#";

    DOM.Events.addListener(
        link,
        "click",
        this._makeShowFunction(number)
    );

    return link;
}


VegGuide.EntryImageSlideshow.prototype._makeShowFunction = function (number) {
    var self = this;

    var func = function (e) {
        self._showImage(number);

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    return func;
};

