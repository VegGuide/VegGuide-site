/*

*/

if ( typeof( DOM ) == 'undefined' ) {
    DOM = {};
}

/*

*/

DOM.Utils = {
    EXPORT: [ '$' ]
   ,'$' : function () {
        var elements = new Array();

        for (var i = 0; i < arguments.length; i++) {
            var element = arguments[i];

            if (typeof element == 'string')
                element = document.getElementById(element)
                    || document.getElementsByName(element)[0]
//                    || document.getElementsByTagName(element)[0]
                    || undefined
                ;

            if (arguments.length == 1) 
                return element;

            elements.push( element );
        }

        return elements;
    }
};

/* Needed to get this working without real exporting */
window["$"] = DOM.Utils["$"];
$ = window["$"];

/*

*/

document.getElementsByClass = function(className) {
    var children = document.getElementsByTagName('*') || document.all;
    var elements = new Array();
  
    for (var i = 0; i < children.length; i++) {
        var child = children[i];
        var classNames = child.className.split(' ');
        for (var j = 0; j < classNames.length; j++) {
            if (classNames[j] == className) {
              elements.push(child);
              break;
            }
        }
    }
  
    return elements;
};
document.getElementsByClassName = document.getElementsByClass;

/*

*/
