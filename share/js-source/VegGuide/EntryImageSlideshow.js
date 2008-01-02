JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('HTTP.Request');
JSAN.use('Widget.Lightbox2');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.EntryImageSlideshow = function (lb) {
    this._init(lb);
};

VegGuide.EntryImageSlideshow.instrumentPage = function () {
    var main_image = $("main-image");

    if ( ! main_image ) {
        return;
    }

    var slideshow_link = document.createElement("a");
    slideshow_link.title = "Click on this link to see a larger version of this and other images";
    slideshow_link.href = "#";

    var container = main_image.parentNode;

    container.removeChild(main_image);

    slideshow_link.appendChild(main_image);

    container.insertBefore( slideshow_link, container.firstChild );

    var lb = new Widget.Lightbox2( { sourceElement: $("slideshow-lightbox") } );

    var show = new VegGuide.EntryImageSlideshow (lb);

    var show_func = function (e) {
        show.start();

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    DOM.Events.addListener(
        slideshow_link,
        "click",
        show_func
    );

    DOM.Events.addListener(
        $( "show-slideshow" ),
        "click",
        show_func
    );
};

VegGuide.EntryImageSlideshow.prototype._init = function (lb) {
    this.lb = lb;

    var matches = lb.content.className.match( /slideshow-for-(\d+)/ );
    if ( ! matches ) {
        return;
    }

    this.imageContainer    = $("slideshow-image-container");
    this.captionContainer  = $("slideshow-caption-container");
    this.controlsContainer = $("slideshow-controls-container");
    this.prevContainer     = $("slideshow-prev-container");
    this.nextContainer     = $("slideshow-next-container");

    this.vendor_id = matches[1];

    this.images = [];
    this.currentImage = 1;
};

VegGuide.EntryImageSlideshow.prototype.start = function () {
    if ( ! this.vendor_id ) {
        return;
    }

    this.lb.show();

    this._showImage( this.currentImage );
};

VegGuide.EntryImageSlideshow.prototype._showImage = function (imageNumber) {
    var image = this._getImage(imageNumber);

    var img = document.createElement("img");

    img.src    = image.uri;
    img.alt    = "";
    img.height = image.height;
    img.width  = image.width;
    img.style.marginTop  = image.margin_top;
    img.style.marginLeft = image.margin_left;

    this._emptyElt( this.imageContainer );

    this.imageContainer.appendChild(img);

    this._emptyElt( this.captionContainer );
    if ( image.caption ) {
        var caption = document.createTextNode( image.caption );
        this.captionContainer.appendChild(caption);
    }

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

    this.currentImage = imageNumber;

    return this.images[ imageNumber - 1 ];
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

