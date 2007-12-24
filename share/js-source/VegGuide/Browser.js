if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.Browser = function () {
    if ( VegGuide.Browser._Singleton ) {
        return VegGuide.Browser._Singleton;
    }

    ua = navigator.userAgent;

    this.isIE     = !! window.attachEvent && ! window.opera;
    this.isOpera  = !! window.opera;
    this.isWebKit = !! ( ua.indexOf('AppleWebKit/') > -1 );
    this.isGecko  = !! ( ua.indexOf('Gecko') > -1 && ua.indexOf('KHTML') == -1 );
    this.isKHTML  = !! ( ua.indexOf('KHTML') > -1 );

    this.requiresPngFilter = this._requiresPngFilter();

    VegGuide.Browser._Singleton = this;
};

VegGuide.Browser._Singleton = null;

VegGuide.Browser.prototype._requiresPngFilter = function () {
    if ( ! this.isIE ) {
        return false;
    }

    var version = navigator.appVersion.split("MSIE");
    var version_num = parseFloat( version[1] );

    if ( version_num >= 5.5 && version_num < 7 ) {
        return true;
    }

    return false;
};
