JSAN.use("DOM.Ready");
JSAN.use("DOM.Events");

if ( typeof Widget == "undefined" ) Widget = {};

Widget.PairedMultiSelect = function (params) {
    this._initialize(params);
}

Widget.PairedMultiSelect._defaultSort = function (a, b) {
    if ( a.value < b.value ) return -1;
    if ( a.value > b.value ) return  1;
                             return  0;
}

Widget.PairedMultiSelect.newFromPrefix = function (prefix, sortFunction) {
    return new Widget.PairedMultiSelect
        ( { firstId: prefix + "-first",
            secondId: prefix + "-second",
            selectedFirstToSecondId: prefix + "-to-second",
            selectedSecondToFirstId: prefix + "-to-first",
            allFirstToSecond: prefix + "-all-to-second",
            allSecondToFirstId: prefix + "-all-to-first",
            sortFunction: sortFunction
          }
        );
}

Widget.PairedMultiSelect.VERSION = "0.10";

Widget.PairedMultiSelect.prototype._initialize = function (params) {
    if ( ! params ) {
        throw new Error("Cannot create a new Widget.PairedMultiSelect without parameters");
    }

    if ( ! params["firstId"] && ! params["secondId"] ) {
        throw new Error("Widget.PairedMultiSelect requires at least firstId and secondId parameters");
    }

    this._params = params;

    if ( typeof params.sortFunction == "function" ) {
        this._sortFunction = params.sortFunction;
    }
    else {
        this._sortFunction = Widget.PairedMultiSelect._defaultSort;
    }

    var self = this;

    DOM.Ready.onIdReady
        ( params.firstId,
          function (elt) {
              self.first = elt;
              self._attachOnSubmitToForm(elt);

              if ( self.second ) {
                  self.moveSelectedFirstToSecond();
              }

              DOM.Events.addListener( elt, "change",
                                      function () { self.moveSelectedFirstToSecond() } );
          }
        );

    DOM.Ready.onIdReady
        ( params.secondId,
          function (elt) {
              self.second = elt;

              if ( self.first ) {
                  self.moveSelectedFirstToSecond();
              }

              DOM.Events.addListener( elt, "change",
                                      function () { self.moveSelectedSecondToFirst() } );
          }
        );

    DOM.Ready.onIdReady
        ( params.selectedFirstToSecondId,
          function (elt) {
              DOM.Events.addListener( elt, "click",
                                      function () { self.moveSelectedFirstToSecond(); return false; } )
          }
        );

    DOM.Ready.onIdReady
        ( params.selectedSecondToFirstId,
          function (elt) {
              DOM.Events.addListener( elt, "click",
                                      function () { self.moveSelectedSecondToFirst(); return false; } )
          }
        );

    DOM.Ready.onIdReady
        ( params.allFirstToSecond,
          function (elt) {
              DOM.Events.addListener( elt, "click",
                                      function () { self.moveAllFirstToSecond(); return false; } )
          }
        );

    DOM.Ready.onIdReady
        ( params.allSecondToFirstId,
          function (elt) {
              DOM.Events.addListener( elt, "click",
                                      function () { self.moveAllSecondToFirst(); return false; } )
          }
        );
};

Widget.PairedMultiSelect.prototype._attachOnSubmitToForm = function (elt) {
    var firstId = this._params.firstId;
    var secondId = this._params.secondId;

    var node = elt;
    while ( node = node.parentNode ) {
        if ( new String( node.tagName ).match( /form/i ) ) {
            DOM.Events.addListener
                ( node,
                  "submit",
                  function () {
                      var first = document.getElementById(firstId);
                      for ( var i = 0; i < first.options.length; i++ ) {
                          first.options[i].selected = true;
                      }

                      var second = document.getElementById(secondId);
                      for ( var i = 0; i < second.options.length; i++ ) {
                          second.options[i].selected = true;
                      }

                      return true;
                  }
                );

            break;
        }
    }
}

Widget.PairedMultiSelect.prototype.moveSelectedFirstToSecond = function () {
    this._move( this.first, this.second );
}

Widget.PairedMultiSelect.prototype.moveSelectedSecondToFirst = function () {
    this._move( this.second, this.first );
}

Widget.PairedMultiSelect.prototype.moveAllFirstToSecond = function () {
    this._move( this.first, this.second, true );
}

Widget.PairedMultiSelect.prototype.moveAllSecondToFirst = function () {
    this._move( this.second, this.first, true );
}

Widget.PairedMultiSelect.prototype._move = function ( source, target, alwaysMove ) {
    var s_options = source.options;
    var t_options = target.options;

    var s_new = new Array;
    var t_new = new Array;

    for ( var i = 0; i < s_options.length; i++ ) {
        var option = new Option( s_options[i].text,
                                 s_options[i].value,
                                 false,
                                 false );

        if ( alwaysMove || s_options[i].selected ) {
            t_new.push(option);
        }
        else {
            s_new.push(option);
        }
    }

    for ( var i = 0; i < t_options.length; i++ ) {
        var option = new Option( t_options[i].text,
                                 t_options[i].value,
                                 false,
                                 false );

        t_new.push(option);
    }

    s_new.sort( this._sortFunction );
    t_new.sort( this._sortFunction );

    s_options.length = 0;
    t_options.length = 0;

    /* This optgroup stuff is a VegGuide-specific hack. In IE6, adding
       options to a select element actually appends them to (the
       first?) optgroup in the select. */
    var source_optgroup;
    if ( source.firstChild && source.firstChild.tagName == "OPTGROUP" ) {
        source_optgroup = source.removeChild( source.firstChild );
    }

    for ( var i = 0; i < s_new.length; i++ ) {
        s_options[i] = s_new[i];
    }

    if (source_optgroup) {
        source.insertBefore( source_optgroup, source.firstChild );
    }

    var target_optgroup;
    if ( target.firstChild && target.firstChild.tagName == "OPTGROUP" ) {
        target_optgroup = target.removeChild( target.firstChild );
    }

    for ( var i = 0; i < t_new.length; i++ ) {
        t_options[i] = t_new[i];
    }

    if (target_optgroup) {
        target.insertBefore( target_optgroup, target.firstChild );
    }
}

/*

=head1 NAME

Widget.PairedMultiSelect - A widget based on a pair of multiple select elements

=head1 SYNOPSIS

  <select name="wpms1" id="wpms-first" multiple="1">
   <option value="1">One</option>
   <option value="2">Two</option>
   <option value="3">Three</option>
  </select>

  <a href="#" id="wpms-selected-first-to-second"><img src="left_to_right.png" /></a>
  <a href="#" id="wpms-selected-second-to-first"><img src="right_to_left.png" /></a>

  <select name="wpms1" id="wpms-second" multiple="1">
   <option value="1">One</option>
   <option value="2">Two</option>
   <option value="3">Three</option>
  </select>

  <script type="text/javascript">
   Widget.PairedMultiSelect.newFromPrefix("wpms");
   # or ...
   new Widget.PairedMultiSelect( { firstId: "wpms-from",
                                   secondId:   "wpms-to",
                                   selectedFirstToSecondId: "wpms-selected-from-to",
                                   selectedSecondToFirstId: "wpms-selected-to-from" } );
  </script>


=head1 DESCRIPTION

This library ties together two multiple C<< <select> >> elements and
some controls to provide a more user-friendly way to handle selection
of multiple items from lists, as opposed to single multiple C<<
<select> >> or a group of checkboxes.

It expects to find these elements already on the page, and will add
the appropriate event listeners for them.

=head1 METHODS

=over 4

=item * new Widget.PairedMultiSelect( { ... } )

Expects an object with the following properties, some of which are
optional:

  { firstId: "first",
    secondId: "second",
    selectedToSecondId, "move-selected-to-second",
    selectedToFirstId, "move-selected-to-first",
    allToSecondId, "move-all-items-to-second",
    allToFirstId, "move-all-items-to-first",
    sortFunction: sortByNumber }

Given an object with the specified properties, the constructor creates
a new widget and attaches the appropriate event handlers to the
specified elements.

The only required properties are "firstId" and "secondId", which
should be the ids of two multiple select form elements.

The other properties, except for "sortFunction", specify element ids
for elements that should have onclick events added which do the
appropriate action.  The event handler will move either the selected
options for all options to one of the two select lists.

In addition, an onsubmit event listener will be added to the form
containing the select elements.  This event listener will select all
of the options in I<both> select lists before the form is submitted.

The two lists of options will be sorted after each move.  The default
sort function sorts by the I<string> representation of each options
C<value> property.  If you provide a "sortFunction" parameter, it will
be used instead.  Your function will be passed two I<Option> objects
for comparison.

When the object is first created, it will call
C<moveSelectedFirstToSecond()> on itself in order to move selected
elements from the first list to the second.

=item * Widget.PairedMultiSelect.newFromPrefix(prefix)

=item * Widget.PairedMultiSelect.newFromPrefix( prefix, sort_func )

This method greatly simplifies creating a new widget, but you have to
follow a specific id name pattern to use it.  The prefix is used to
create a set of element ids, based on this formula:

  firstId:             prefix + "-first"
  secondId:            prefix + "-second"
  selectedToSecondId:  prefix + "-to-second"
  selectedToFirstId:   prefix + "-to-first"
  allToSecondId:       prefix + "-all-to-second"
  allToFirstId:        prefix + "-all-to-first"

This method also accepts an optional sort function as its second
parameter.

=item * moveSelectedFirstToSecond()

=item * moveSelectedSecondToFirst()

Move selected options in one select list to the other.

=item * moveAllFirstToSecond()

=item * moveAllSecondToFirst()

Move all options in one select list to the other.

=back

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>.

=head1 COPYRIGHT

Copyright (c) 2005 Dave Rolsky.  All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as the Perl programming language (your choice of
GPL or the Perl Artistic license).

=cut

*/
