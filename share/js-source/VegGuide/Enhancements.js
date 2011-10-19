JSAN.use("DOM.Element");
JSAN.use("DOM.Events");
JSAN.use("DOM.Ready");
JSAN.use("VegGuide.EntryFilters");
JSAN.use("VegGuide.EntryForm");
JSAN.use("VegGuide.EntryImageSlideshow");
JSAN.use("VegGuide.FrontPageGeolocation");
JSAN.use("VegGuide.GoogleMap");
JSAN.use("VegGuide.HoursForm");
JSAN.use("VegGuide.IEPngFilter");
JSAN.use("VegGuide.LocaleList");
JSAN.use("VegGuide.LocationSearch");
JSAN.use("VegGuide.LoginForm");
JSAN.use("VegGuide.Pagination");
JSAN.use("VegGuide.RatingStars");
JSAN.use("VegGuide.RegionForm");
JSAN.use("VegGuide.SitewideSearch");
JSAN.use("VegGuide.Suggestions");
JSAN.use("VegGuide.SurveyForm");
JSAN.use("VegGuide.UserSearch");
JSAN.use("VegGuide.Widget.PairedMultiSelect");

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.Enhancements = {};

VegGuide.Enhancements.instrumentAll = function () {
    VegGuide.IEPngFilter.instrumentPage();

    VegGuide.EntryForm.instrumentPage();
    VegGuide.EntryFilters.instrumentPage();
    VegGuide.EntryImageSlideshow.instrumentPage();
    VegGuide.FrontPageGeolocation.instrumentPage();
    VegGuide.HoursForm.instrumentPage();
    VegGuide.LocaleList.instrumentPage();
    VegGuide.LocationSearch.instrumentPage();
    VegGuide.LoginForm.instrumentPage();
    VegGuide.Pagination.instrumentPage();
    VegGuide.RatingStars.instrumentPage();
    VegGuide.RegionForm.instrumentPage();
    VegGuide.SitewideSearch.instrumentPage();
    VegGuide.Suggestions.instrumentPage();
    VegGuide.SurveyForm.instrumentPage();
    VegGuide.UserSearch.instrumentPage();
};

DOM.Ready.onDOMDone( VegGuide.Enhancements.instrumentAll );
