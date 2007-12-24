/*

*/

try {
    JSAN.use( 'DOM.Utils' );
} catch (e) {
    throw "DOM.Element requires JSAN to be loaded";
}

if ( typeof( DOM ) == 'undefined' ) {
    DOM = {};
}

/*

*/

/*

*/

DOM.Element = {

    /*

    =item * hide()

    This function make sure that every element passed to it is hidden via use of CSS.

    =cut

    */

    hide: function() {
        for (var i = 0; i < arguments.length; i++) {
            var element = $(arguments[i]);
            if ( element && element.nodeType == 1 ) {
                element.style.display = 'none';
            }
        }
    }

    /*

    =item * show()

    This function make sure that every element passed to it is visible via use of CSS.

    =cut

    */

   ,show: function() {
        for (var i = 0; i < arguments.length; i++) {
            var element = $(arguments[i]);
            if ( element && element.nodeType == 1 ) {
                element.style.display = '';
            }
        }
    }

    /*

    =item * toggle()

    For each element passed to it, this function calls hide() if the element is visible and show() if it's hidden.

    =cut

    */

   ,toggle: function() {
        for (var i = 0; i < arguments.length; i++) {
            var element = $(arguments[i]);
            if ( element && element.nodeType == 1 )
                element.style.display = 
                    (element.style.display == 'none' ? '' : 'none');
        }
    }

    /*

    =item * remove()

    This function removes() all the elements specified from the DOM tree.

    =cut

    */

   ,remove: function() {
        for (var i = 0; i < arguments.length; i++) {
            element = $(arguments[i]);
            if ( element )
                element.parentNode.removeChild(element);
        }
    }
   
    /*

    =item * getHeight()

    This function returns the offsetHeight.

    This function only accepts one argument.

    =cut

    */

   ,getHeight: function(element) {
        element = $(element);
        if ( !element ) return;
        return element.offsetHeight; 
    }

    /*

    =item * hasClassName()

    This function returns true or false depending on if the element has the classname.

    This function takes two arguments - the element and the classname.

    =cut

    */

   ,hasClassName: function(element, className) {
        element = $(element);
        if ( !element || element.nodeType != 1 ) return;
        var a = element.className.split(' ');
        for (var i = 0; i < a.length; i++) {
            if (a[i] == className)
                return true;
        }
        return false;
    }

    /*

    =item * addClassName()

    This function adds the classname to the element classlist.

    This function takes two arguments - the element and the classname.

    =cut

    */

   ,addClassName: function(element, className) {
        element = $(element);
        if ( !element || element.nodeType != 1 ) return;
        DOM.Element.removeClassName(element, className);
        element.className += ' ' + className;
    }

    /*

    =item * removeClassName()

    This function removes the classname from the element classlist.

    This function takes two arguments - the element and the classname.

    =cut

    */

   ,removeClassName: function(element, className) {
        element = $(element);
        if ( !element || element.nodeType != 1 ) return;

        var newClassnames = new Array();
        var a = element.className.split(' ');
        for (var i = 0; i < a.length; i++) {
            if (a[i] != className) {
                newClassnames.push( a[i] );
            }
        }
        element.className = newClassnames.join(' ');
    }
  
    /*

    =item * cleanWhitespace()

    This function returns true or false dependeing on if the element has the classname.

    This function takes two arguments - the element and the classname.

    =cut

    */

   ,cleanWhitespace: function() {
        var element = $(element);
        if ( !element ) return;
        for (var i = 0; i < element.childNodes.length; i++) {
            var node = element.childNodes[i];
            if (node.nodeType == 3 && !/\S/.test(node.nodeValue)) 
                DOM.Element.remove(node);
        }
    }

/*

*/

};

/*

*/
