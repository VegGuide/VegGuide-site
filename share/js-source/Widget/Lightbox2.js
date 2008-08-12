JSAN.use("DOM.Element");
JSAN.use("DOM.Events");
JSAN.use('DOM.Find');
JSAN.use('VegGuide.Browser');

if ( typeof Widget == "undefined" ) {
    Widget = {};
}

Widget.Lightbox2 = function (params) {
    this.browser = new VegGuide.Browser;
    this._initialize(params);

    return this;
};

Widget.Lightbox2.prototype._initialize = function (params) {
    var overlay = document.createElement("div");

    var opacity_val = params.opacity;
    if ( typeof opacity_val == "undefined" ) {
        opacity_val = 0.7;
    }

    var color_val = params.color;
    if ( typeof color_val == "undefined" ) {
        color_val = "#333";
    }

    /* AFAICT this is really an X driver issue, but we'll use having
       Firefox 3 as a proxy for having relatively modern drivers. Hopefully
       this hack can be removed entirely once Firefox 4 is out! */
    if ( navigator.userAgent.indexOf('Linux') > -1
         && navigator.userAgent.indexOf('Firefox/3') == -1 ) {
        color_val = "#D9FFB9";
        opacity_val = 1;
    }

    DOM.Element.hide(overlay);

    var body = document.getElementsByTagName("body")[0];

    body.appendChild(overlay);

    with ( overlay.style ) {
        position = "fixed";
        width    = "100%";
        height   = "100%";
        top      = 0;
        left     = 0;
        padding  = 0;
        margin   = 0;
        border   = 0;
        zIndex   = 1000;
        opacity  = opacity_val;
        backgroundColor = color_val;

        /* IE */
        if ( this.browser.isIE || this.browser.isWebKit ) {
            filter = "alpha(opacity=" + ( opacity_val * 100 ) + ")";
            position = "absolute";
        }

        if ( this.browser.isIE ) {
            height = document.documentElement.clientHeight + "px";
            width = document.documentElement.clientWidth + "px";
        }
    }

    if ( this.browser.isIE ) {
        this.iframe = document.createElement("iframe");

        with ( this.iframe.style ) {
            position = "absolute";
            top      = 0;
            left     = 0;
            padding  = 0;
            margin   = 0;
            border   = 0;
            zIndex   = 999;

            filter = 'progid:DXImageTransform.Microsoft.Alpha(style=0,opacity=0)';

            height = document.documentElement.clientHeight + "px";
            width = document.documentElement.clientWidth + "px";
        }

        DOM.Element.hide(this.iframe);

        body.appendChild(this.iframe);
    }

    var content = params.sourceElement;
    if ( ! content ) {
        throw "Must provide a sourceElement parameter when making a Widget.Lightbox2 object";
    }

    DOM.Element.hide(content);

    content.style.zIndex = 1001;

    var closers = DOM.Find.getElementsByAttributes( { className: "lightbox2-close" }, content )
    if ( closers && closers.length ) {
        var self = this;
        for ( var i = 0; i < closers.length; i++ ) {
            DOM.Events.addListener(
                closers[i],
                "click",
                function (e) {
                    self.hide();

                    e.preventDefault();
                    if ( e.stopPropogation ) {
                        e.stopPropagation();
                    }
                }
            );
        }
    }

    this.overlay = overlay;
    this.content = content;
};

Widget.Lightbox2.prototype.show = function () {
    if ( this.iframe ) {
        DOM.Element.show( this.iframe );
    }

    DOM.Element.show( this.overlay );
    DOM.Element.show( this.content );

    var left = ( document.body.clientWidth - this.content.offsetWidth ) / 2;
    this.content.style.left = left + "px";

    window.scroll( 0, 0 );
};

Widget.Lightbox2.prototype.hide = function () {
    DOM.Element.hide( this.content );
    DOM.Element.hide( this.overlay );

    if ( this.iframe ) {
        DOM.Element.hide( this.iframe );
    }

};
