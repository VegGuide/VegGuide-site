JSAN.use('DOM.Element');
JSAN.use('DOM.Events');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.LoginForm = function () {
    this.standard = $("standard-log-in");
    this.openid = $("openid-log-in");
    this.toggle = $("switch-log-in");
    this.orig_toggle_text = this.toggle.innerHTML;
    this.is_standard = 1;

    var self = this;
    DOM.Events.addListener(
        this.toggle,
        "click",
        function (e) {
            self._switchForms();

            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }
        }
    );

    if ( $("openid_uri").value ) {
        this._switchForms();
    }
};


VegGuide.LoginForm.instrumentPage = function () {
    if ( ! $("standard-log-in") ) {
        return;
    }

    new VegGuide.LoginForm();
};

VegGuide.LoginForm.prototype._switchForms = function () {
    if ( this.is_standard ) {
        DOM.Element.hide( this.standard );
        DOM.Element.show( this.openid );

        this.toggle.innerHTML = "Or log with your email address and password.";

        this.is_standard = 0;
    }
    else {
        DOM.Element.hide( this.openid );
        DOM.Element.show( this.standard );

        this.toggle.innerHTML = this.orig_toggle_text;

        this.is_standard = 1;
    }
};
