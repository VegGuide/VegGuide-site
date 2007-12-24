JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('VegGuide.Form');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.InlineSearchForm = function ( prefix, search_uri, results_function ) {
    var search_button = $( prefix + "-search-submit" );

    if ( ! search_button ) {
        return;
    }
    
    this.search_button = search_button;
    this.search_input  = $( prefix + "-name" );
    this.submit_button = $( prefix + "-search-submit");
    this.results_div   = $( prefix + "-search-results" );
    this.search_uri    = search_uri;
    this.populate_results_function = results_function;

    this._instrumentForm();
};

VegGuide.InlineSearchForm.prototype._instrumentForm = function() {
    var self = this;

    DOM.Events.addListener(
        this.search_input,
        "keypress",
        function (e) {
            self._handleEnterKey(e);
        }
    );

    DOM.Events.addListener(
        this.search_button,
        "click",
        function (e) {
            self._searchRequest(e);
        }
    );

    VegGuide.Form.resizeRadioOrCheckboxList( this.results_div );
};

VegGuide.InlineSearchForm.prototype._handleEnterKey = function (e) {
    if ( e.keyCode != 13 ) {
        return e.keyCode;
    }

    this.submit_button.click();

    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }
}

VegGuide.InlineSearchForm.prototype._searchRequest = function (e) {
    var value = this.search_input.value;

    if ( ! value ) {
        return;
    }

    var self = this;

    var req = new HTTP.Request( {
        parameters: "name=" + encodeURIComponent(value),
        method:     "get",
        onSuccess:  function (r) {
                self._clearResultsDiv();
                self.populate_results_function( r, self.results_div );
            }
        }
    );

    this._showSearchingMessage();

    req.request( this.search_uri );

    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }
};

VegGuide.InlineSearchForm.prototype._showSearchingMessage = function () {
    this._clearResultsDiv();

    var span = document.createElement("span");
    span.className = "transient-ajax-message";

    span.appendChild( document.createTextNode( "Searching ..." ) );

    this.results_div.appendChild(span);
};

VegGuide.InlineSearchForm.prototype._clearResultsDiv = function () {
    while ( this.results_div.firstChild ) {
        this.results_div.removeChild( this.results_div.firstChild );
    }
};
