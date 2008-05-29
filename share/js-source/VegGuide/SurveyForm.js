JSAN.use('DOM.Events');
JSAN.use('VegGuide.Form');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.SurveyForm = {};

VegGuide.SurveyForm.instrumentPage = function () {
    if ( ! $("survey-form") ) {
        return;
    }

    VegGuide.Form.resizeRadioOrCheckboxList("frequency");
    VegGuide.Form.resizeRadioOrCheckboxList("diet");
    VegGuide.Form.resizeRadioOrCheckboxList("activities");
    VegGuide.Form.resizeRadioOrCheckboxList("survey-features");
    VegGuide.Form.resizeRadioOrCheckboxList("other-sites");
};
