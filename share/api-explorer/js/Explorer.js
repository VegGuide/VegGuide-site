(function () {
     var Explorer = (
         function () {
             var E = function () {
                 this._baseURI = window.location.protocol + '//' + window.location.host;
             };

             E.prototype.initPage = function () {
                 var baseURI = this._baseURI;

                 $("ul.entry-points a.entry-point-uri").each(
                     function () {
                         var origText = $(this).text()
                         $(this).text( baseURI + origText );
                         $(this).click(
                             function () {
                                 $("#uri").attr( "value", origText );
                                 return false;
                             }
                         );
                     }
                 );

                 $("span.base-uri").text(baseURI);
             };

             return E;
         }
     )();

     var e = new Explorer;
     $(document).ready( function () { e.initPage() } );
})();
