if ( typeof Form == "undefined" ) {
    Form = {};
}

Form.Serializer = function (name) {
    return this._initialize(name);
};

Form.Serializer.VERSION = "0.14";

Form.Serializer.ElementTypes = [ "input", "textarea", "select" ];

Form.Serializer.prototype._initialize = function (form) {
    if ( typeof form == "object" ) {
        this.form = form;
        return;
    }

    this.form = document.getElementById(form);

    if ( ! this.form ) {
        for ( var i = 0; i < document.forms.length; i++ ) {
            if ( document.forms[i].name == form ) {
                this.form = document.forms[i];
                break;
            }
        }
    } 

    if ( ! this.form ) {
        throw new Error( "Cannot find a form with the name or id '" + name + "'" );
    }
};

Form.Serializer.prototype.pairsArray = function () {
    var pairs = new Array;

    for ( var i = 0; i < Form.Serializer.ElementTypes.length; i++ ) {
        var type = Form.Serializer.ElementTypes[i];
        var elements = this.form.getElementsByTagName(type);

        for ( var j = 0; j < elements.length; j++ ) {

            var p = eval( "this._serialize_" + type + "(elements[j])" );

            if (p) {
                for ( var k = 0; k < p.length; k++ ) {
                    pairs.push( p[k] );
                }
            }
        }
    }

    return pairs;
}

Form.Serializer.prototype._serialize_input = function (elt) {
    switch (elt.type.toLowerCase()) {
      case "hidden":
      case "password":
      case "text":
          return this._simple(elt);

      case "checkbox":  
      case "radio":
          return this._simple_if_checked(elt);

      default:
          return false;
    }
}

Form.Serializer.prototype._simple = function (elt) {
    return [ [ elt.name, elt.value ] ];
}

Form.Serializer.prototype._simple_if_checked = function (elt) {
    if ( ! elt.checked ) {
        return;
    }

    return this._simple(elt);
}

Form.Serializer.prototype._serialize_textarea = function (elt) {
    return this._simple(elt);
}

Form.Serializer.prototype._serialize_select = function (elt) {
    var options = elt.options;

    var serialized = new Array;
    for ( var i = 0; i < options.length; i++ ) {
        if ( options[i].selected ) {
            serialized.push( [ elt.name, options[i].value ] );
        }
    }
        
    return serialized;
}

Form.Serializer.prototype.queryString = function () {
    var pairs = this.pairsArray();

    var queryPairs = new Array;
    for ( var i = 0; i < pairs.length; i++ ) {
        queryPairs.push(   encodeURIComponent( pairs[i][0] )
                         + "=" 
                         + encodeURIComponent( pairs[i][1] ) );
    }

    var sep = arguments.length ? arguments[0] : ";";
    return queryPairs.join(sep);
}

Form.Serializer.prototype.keyValues = function (forceArray) {
    var pairs = this.pairsArray();

    var named = {};
    for ( var i = 0; i < pairs.length; i++ ) {
        var k = pairs[i][0];
        var v = pairs[i][1];

        if ( named[k] ) {
            if ( typeof named[k] == 'object' ) {
                named[k].push(v);
            }
            else {
                named[k] = [ named[k], v ];
            }
        }
        else {
            if (forceArray) {
                named[k] = [v];
            }
            else {
                named[k] = v;
            }
        }
    }

    return named;
}

/*

*/
