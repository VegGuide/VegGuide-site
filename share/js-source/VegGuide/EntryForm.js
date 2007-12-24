JSAN.use('DOM.Events');
JSAN.use('VegGuide.Form');
JSAN.use('VegGuide.Widget.PairedMultiSelect');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.EntryForm = {};

VegGuide.EntryForm.instrumentPage = function () {
    if ( ! $("entry-form") ) {
        return;
    }

    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "category_id", "categories" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "cuisine_id", "cuisines" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "payment_option_id", "options" );
    VegGuide.Widget.PairedMultiSelect.instrumentWPMS( "attribute_id", "features" );

    VegGuide.EntryForm._instrumentCashOnly();

    /* These are resized using JS because using a percentage width in
     * CSS doesn't always get good results with very large or small
     * font sizes */
    VegGuide.EntryForm._resizeHowVeg();

    VegGuide.Form.resizeRadioOrCheckboxList("smoke_free");
    VegGuide.Form.resizeRadioOrCheckboxList("accepts_reservations");
    VegGuide.Form.resizeRadioOrCheckboxList("wheelchair_accessible");
    VegGuide.Form.resizeRadioOrCheckboxList("is_cash_only");
};

VegGuide.EntryForm._resizeHowVeg = function () {
    var hv = $("how-veg");

    if ( ! hv ) {
        return;
    }

    var radio   = $("veg-level-3");
    var longest = $("how-veg-longest");

    var li_width = radio.offsetWidth + longest.offsetWidth;
    li_width *= 1.1;

    hv.style.width = li_width + "px";
};

VegGuide.EntryForm._instrumentCashOnly = function () {
    var is_cash_only_yes = $("is_cash_only-yes");
    var is_cash_only_no = $("is_cash_only-no");

    if ( ! ( is_cash_only_yes && is_cash_only_no ) ) {
        return;
    }

    DOM.Events.addListener( is_cash_only_yes, "click", function () {
            VegGuide.EntryForm._disablePayments();
        } );

    DOM.Events.addListener( is_cash_only_no, "click", function () {
            VegGuide.EntryForm._enablePayments();
        } );

    if ( is_cash_only_yes.checked ) {
        VegGuide.EntryForm._disablePayments();
    }
};

VegGuide.EntryForm._disablePayments = function () {
    VegGuide.EntryForm._setPayments(false);
};

VegGuide.EntryForm._enablePayments = function () {
    VegGuide.EntryForm._setPayments(true);
};

VegGuide.EntryForm._setPayments = function (is_enabled) {
    var payments = $("payment_option_id");
    var poss_payments = $("possible_payment_option_id");

    if (is_enabled) {
        DOM.Element.removeClassName( payments, "disabled" );
        DOM.Element.removeClassName( poss_payments, "disabled" );
    }
    else {
        DOM.Element.addClassName( payments, "disabled" );
        DOM.Element.addClassName( poss_payments, "disabled" );
    }

    payments.disabled = !!is_enabled
    poss_payments.disabled = !!is_enabled;
};
