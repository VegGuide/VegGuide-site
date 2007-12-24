JSAN.use("VegGuide.Browser");

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.IEPngFilter = {};

(function () {
    var blank = new Image;
    blank.src = "/images/transparent.gif";

    VegGuide.IEPngFilter._blankImage = blank;
})();

VegGuide.IEPngFilter.instrumentPage = function () {
    var browser = new VegGuide.Browser;
    if ( ! browser.requiresPngFilter ) {
        return;
    }

    var images = document.images;

    for ( var i = 0; i < images.length; i++ ) {
        var image = images[i];

        if ( ! /png-filter/.test( image.className ) ) {
            continue;
        }

        var new_image = VegGuide.IEPngFilter._blankImage.cloneNode(true);
        new_image.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + image.src + "', sizing='scale')";
        new_image.className = image.className;
        new_image.className.replace( /png-filter/, "" );
        new_image.height = image.height;
        new_image.width = image.width;

        var parent = image.parentNode;
        parent.insertBefore( new_image, image );
        parent.removeChild(image);
    }
};
