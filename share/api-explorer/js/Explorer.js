(function () {
     var Response = (
         function () {
             var R = function (explorer) {
                 this._explorer = explorer;
             };

             /* This just exists to preload the image */
             {
                 var spinner = new Image ();
                 spinner.src = "img/spinner.gif";
             }

             var _title = '<h2>Response</h2>';

             var _loadingHTML =
                 _title +
                 '<p>Waiting for response ... <img src="img/spinner.gif"></p>';

             R.prototype.showLoading = function () {
                 $("#response-display").html(_loadingHTML);
             };

             var _responseTemplate =
                 _title +
                 '<dl>' +
                   '<dt>Content-Type:</dt>' +
                   '<dd>{{headers.content_type}}</dd>' +
                 '</dl>' +
                 '<pre class="responseJSON">{{&response}}</code></pre>';

             R.prototype.displayResponse = function (response, xhr) {
                 var self = this;

                 var json =
                     JSON.stringify( response, null, 2 )
                         .replace( /&/g, '&amp;' )
                         .replace( />/g, '&gt;' )
                         .replace( /</g, '&lt;' )
                         .replace( /"/g, '&quot;' )
                         .replace(
                             /((&quot;|_)uri&quot;\s*:\s*&quot;)(.+)(&quot;,?)/g,
                             function (match, p1, p2, uri, p4) {
                                 if ( /\.\w+$/.test(uri) ) {
                                     return p1 + uri + p4;
                                 }

                                 return p1 + self._makeAnchor(uri) + p4;
                             }
                         );

                 var view = {
                     response: json,
                     headers:  { content_type: xhr.getResponseHeader('Content-Type') }
                 };
                 $("#response-display").html( $.mustache( _responseTemplate, view ) );

                 $("#response-display a").each(
                     function () {
                         self._explorer.instrumentAnchor( $(this) );
                     }
                 );
             };

             R.prototype._makeAnchor = function (uri) {
                 /* We need to create a container div because there is no way
                  * I can see to get the _outer_ HTML for an element with
                  * jQuery. The div is a container we can call .html() on to
                  * get the <a> tag. */
                 var div = $("<div/>");
                 var a = $("<a/>");
                 a.attr(
                     {
                         href:  uri,
                         title: "Explore this URI (" + uri + ")"
                     }
                 );
                 a.append(uri);
                 div.append(a);

                 return div.html();
             };

             var _errorTemplate =
                 '<h2>An Error Occurred</h2>' +
                 '<p>{{status}} {{error}}</p>';

             R.prototype.displayError = function (xhr, error) {
                 var self = this;

                 var view = {
                     "status": xhr.status,
                     "error":  error
                 };
                 $("#response-display").html( $.mustache( _errorTemplate, view ) );
             };

             return R;
         }
     )();

     var Request = (
         function () {
             var R = function (baseURI, uri, accept, explorer) {
                 uri = uri.replace( new RegExp ( "^" + baseURI ), "" );

                 this._displayURI = baseURI + uri;

                 this._requestURI = baseURI +
                     _.map(
                         uri.split("/"),
                         function (piece) {
                             if ( ! piece.length ) {
                                 return "";
                             }
                             else {
                                 return encodeURI(piece);
                             }
                         }
                     ).join("/");

                 this._accept = accept;
                 this._explorer = explorer;
             };

             var _displayTemplate =
                 '<dl>' +
                   '<dt>URI:</dt>' +
                   '<dd>{{_displayURI}}</dd>' +
                   '<dt>Accept:</dt>' +
                   '<dd>{{_accept}}</dd>' +
                 '</dl>';

             R.prototype.display = function () {
                 $("#request-display").html( $.mustache( _displayTemplate, this ) );
             };

             R.prototype.submit = function () {
                 this._response = new Response ( this._explorer );
                 this._response.showLoading(); 

                 var self = this;
                 $.ajax(
                     {
                         url:      this._requestURI,
                         accepts:  this._accept,
                         dataType: "json"
                     }
                 ).done(
                     function (response, status, xhr) {
                         self._response.displayResponse( response, xhr );
                     }
                 ).fail(
                     function (xhr, status, error) {
                         self._response.displayError( xhr, error );
                     }
                 );
             };

             return R;
         }
     )();

     var Explorer = (
         function () {
             var E = function () {
                 this._baseURI = window.location.protocol + '//' + window.location.host;
             };

             E.prototype.instrumentAnchor = function (a) {
                 var origText = a.text();
                 var re = new RegExp ( "^" + this._baseURI );

                 if ( ! re.test(origText) ) {
                     a.text( this._baseURI + origText );
                 }

                 a.click(
                     function () {
                         $("#uri").attr( "value", origText.replace( re, "" ) );
                         $("#request-form").submit();
                         return false;
                     }
                 );
             };

             E.prototype._instrumentRequestForm = function () {
                 var self = this;

                 $("#request-form").submit(
                     function () {
                         var request = new Request (
                             self._baseURI,
                             $("#uri").attr("value"),
                             $("#accept").attr("value"),
                             self
                         );

                         request.display();
                         request.submit();

                         return false;
                     }
                 );
             };

             E.prototype._instrumentYourLocation = function () {
                 if ( ! navigator.geolocation ) {
                     $("#your-location-li").remove();
                     return;
                 }

                 var self = this;

                 navigator.geolocation.getCurrentPosition(
                     function (position) {
                         var path =
                             "/search/by-lat-long/" +
                             encodeURI( position.coords.latitude ) +
                             "," +
                             encodeURI( position.coords.longitude );

                         $("#your-location-a").attr( "href", path );
                         $("#your-location-a").text( self._baseURI + path );

                         self.instrumentAnchor( $("#your-location-a") );
                     }
                 );
             };

             E.prototype.initPage = function () {
                 var self = this;

                 $("ul.entry-points a.entry-point-uri").each(
                     function () {
                         if ( $(this).attr("id") == "your-location-a" ) {
                             return;
                         }
                         self.instrumentAnchor( $(this) );
                     }
                 );

                 self._instrumentRequestForm();
                 self._instrumentYourLocation();

                 $("span.base-uri").text( this._baseURI );
             };

             return E;
         }
     )();

     var e = new Explorer;
     $(document).ready( function () { e.initPage() } );
})();
