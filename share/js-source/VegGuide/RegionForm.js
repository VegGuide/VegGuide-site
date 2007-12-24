JSAN.use('VegGuide.Form');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.RegionForm = {};

VegGuide.RegionForm.instrumentPage = function () {
    if ( ! $("region-form") ) {
        return;
    }

    VegGuide.Form.resizeRadioOrCheckboxList("maintainers");
};
