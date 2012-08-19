JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('VegGuide.Form');
JSAN.use('VegGuide.InlineSearchForm');

if ( typeof VegGuide == "undefined" ) {
    VegGuide = {};
}

VegGuide.UserSearch = {};

VegGuide.UserSearch.instrumentPage = function () {
    new VegGuide.InlineSearchForm( "user", "/user", VegGuide.UserSearch._populateUserList );
};

VegGuide.UserSearch._populateUserList = function ( res, div ) {
    var users = eval( "(" + res.responseText + ")" );

    if ( ! users.length ) {
        div.appendChild( document.createTextNode( "No matching users found." ) );
        return;
    }

    var ul = document.createElement("ul");
    ul.className = "inline-search";

    for ( var i = 0; i < users.length; i++ ) {
        var user = users[i];

        var radio = document.createElement("input");

        radio.type  = "radio";
        radio.name  = "user_id";
        radio.value = user.user_id;
        radio.id    = "user_id-" + user.user_id;
        radio.className = "radio";

        var label = document.createElement("label");
        label.htmlFor = radio.id;

        var text = user.real_name;

        label.appendChild( document.createTextNode(text) );

        var li = document.createElement("li");

        li.appendChild(radio);
        li.appendChild( document.createTextNode(" ") );
        li.appendChild(label);

        ul.appendChild(li);
    }

    DOM.Element.hide(div);

    div.appendChild(ul);

    DOM.Element.show(div);

    VegGuide.Form.resizeRadioOrCheckboxList("user-search-results");
};
