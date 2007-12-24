/*

=head1 NAME

DOM.Find - Tools for searching DOM trees.

=head1 SYNOPSIS

// get all input elements of type text in document
var textInputs = getElementsByAttributes({ tagName: 'input', type: 'text' }, document);

=head1 DESCRIPTION

Finds DOM elements matching given criteria relating to their attributes.

C<DOM.Find> does not export any methods by default, but allows you to export either of the
methods described below.

=head3 EXAMPLES

General

      <script type="text/javascript">
      
        // Define the attributes we are looking for
        var attributes = {
                           'tagName':'DIV',                         // scalar   Test
                           'id':(new RegExp('^car_[0-9]+$','i')),   // RegExp   Test
                           'className':(function(value){            // Function Test
                                          if(value.indexOf('car') == -1){
                                            return false;
                                          }
                                          return true;
                                        })
                         }
                         
        // Define where in the DOM we want to start the search
        var startAt = document.getElementByid('cars');
        
        // Find the Nodes!
        var results = getElementsByAttributes(attributes, startAt, undefined, 1);
        
        // Do something with the result set
        for(var x = 0; x < results.length; x++){
          var element = results[x];
          element.style.display = 'none';
        }
        
      </script>
    

'Elements By Id IndexOf'

      // Use 'indexOf' to speed up simple "String Matches"...
    
      var attributes = {'className':function(value){
                                      return (value.indexOf('car') != -1) ? true : false ;
                                    }}
'Elements By Id Regex'

      var attributes = {'id':(new RegExp('^car_[0-9]+$','i'))}

'Elements by ClassName'

      var attributes = {'className':(new RegExp('car','i'))}

'Elements By Input Type'

      var attributes = { tagName: 'input', type: 'text' }

=head2 Package Methods

=cut

*/

if ( typeof DOM == "undefined") DOM = {};

DOM.Find = {

  VERSION: 1.00,

  EXPORT: [ 'checkAttributes','getElementsByAttributes', 'geba' ],


/*

=head3 C<checkAttributes(<tests:Object>, <node:Node>)>

Checks DOM element against {proptery: value} pairs...

<tests:Object>

    Properties:
        A DOM Node property.
        Examples: 'className', 'id', 'style.marginLeft', 'style.position' etc...
    Values:
        Either a Scalar, RegExp, or Function.

        Scalar
            If neither a RegExp or Function is detected.
            Then the value will be processed via a Scalar test.
            Example: `{'id':'car_50'}`
        RegExp
            Must be a RegExp Object...
            Example: `{'id':(new RegExp('^car_[0-9]+$','i'))}`
        Function
            Must be a refence to a Function...
            It must explicitly return true/false...
            Absence of either will result in false!
            Property's "value" will be passed as a single argument.
            Example: `{'id':(function(value){return value.indexOf('car') != -1})}`

<node:Node>
    DOM element in question. 

=cut

*/

  checkAttributes: function(hash,el){
  
      // Check that passed arguments make sense
 
      if( el === undefined || el === null )
        throw("Second argument to checkAttributes should be a DOM node or the ID of a DOM Node");
  
      if( el.constructor === String )
        el = document.getElementById(el);
    
      if( el === null || !el.nodeType ) // Make sure el is a Node
        throw("Second argument to checkAttributes should be a DOM node or the ID of a DOM Node");

      if(! (hash instanceof Object))
        throw("First argument to checkAttributes should be an Object of attribute/test pairs. See the documentation for more information.");

      // If we're still here, check the test pairs

      for(key in hash){
  
        /*
          Prepare the "pointer"
        */
        
        // Check to make sure property chain is valled
        // Provides easy declaration of nested propteries
        // Example: {'style.position':'absolute'}
    
        var pointer = el      // pointer
        var last    = null;   // last pointer used to aplly() later
        
        var pieces  = key.split('.');                   // break up the property chain
        
        for(var i=0; i<pieces.length; i++){             // loop property chain
          // There can be no match
          // if the attribute does not exist
          if(!pointer[pieces[i]]) return false;         // test the pointer exists
          // Save the current pointer
          last    = pointer;                            // backup current pointer
          // Develope the pointer
          pointer = pointer[pieces[i]];                 // stack the pointer
        }
        
        // Check if the pointer is actually a function
        // Provides easy declaration of methods
        // Example: {'hasChildNodes':true}
        // Example: {'firstChild.hasChildNodes':true}
        
        // Does not work in IE
        // IE returns Object instead of Function
        if( pointer instanceof Function )
          try {
            pointer = pointer.apply(last);
          }catch(error){
            throw("First agrument to checkAttributes included a Function Refrence which caused an ERROR: " +  error);
          }
    
        /*
          Test "pointer" against "value"
        */
    
        // Perform one of 3 tests
        // Regex, Function, Scalar
    
        // Check against a regex
        if( hash[key] instanceof RegExp ){
          if( !hash[key].test( pointer ) )
             return false;
        
        // Check against a function
        }else if( hash[key] instanceof Function ){
          if( !hash[key]( pointer ) )
            return false;

        // Or check against a scalar value
        }else if( hash[key] != pointer ){
          return false;
        }    
        
      }

      return true;
  },

/*

=head3 C<getElementsByAttributes(<tests:Object>, <startAt:Node>, <resultsLimit:integer>, <depthLimit:integer>)>

Searches DOM for elements tested against {proptery: value} pairs...

<tests:Object>
    (See below for more details)
[<startAt:Node>]
    The DOM starting point, defaults to `document`.
[<resultsLimit:integer>]
    Stops searching for further nodes once it has reached the limit.
[<depthLimit:integer>]
    Will not proceed deeper into the DOM heirarchy. 

=cut

*/

  getElementsByAttributes: function( searchAttributes, startAt, resultsLimit, depthLimit ) {

     // if we haven't been deep enough yet
     if(depthLimit !== undefined && depthLimit <= 0) return [];
   
     // if no startAt is provided use document as default
     if(startAt === undefined){
       startAt = document;
   
     // if startAt is a string convert it to a domref
     }else if(typeof startAt == 'string'){
       startAt = document.getElementById(startAt);
     }
 
     // check the startAt element
     var results = DOM.Find.checkAttributes(searchAttributes, startAt) ? [ startAt ] : [];
   
     // return the results right away if they only want 1 result
     if(resultsLimit == 1 && results.length > 0) return results;

     // Scan the childNodes of startAt
     if (startAt.childNodes)
       for( var i = 0; i < startAt.childNodes.length; i++){
         // concat onto results any childNodes that match
         results = results.concat( 
            DOM.Find.getElementsByAttributes( searchAttributes, startAt.childNodes[i], (resultsLimit) ? resultsLimit - results.length : undefined, (depthLimit) ? depthLimit -1 : undefined )
         )
         if (resultsLimit !== undefined && results.length >= resultsLimit) break;
       }
      
     return results;
  }

}

/*

=head1 AUTHOR

Daniel, Aquino <mr.danielaquino@gmail.com>.

=head1 COPYRIGHT

  Copyright (c) 2007 Daniel Aquino.
  Released under the Perl Licence:
  http://dev.perl.org/licenses/

=cut

Creation Date Roughly: 07/10/06
Last Update:           1/06/07

*/
