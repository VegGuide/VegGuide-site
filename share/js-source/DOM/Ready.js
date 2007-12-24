if ( typeof DOM == "undefined" ) {
    DOM = {};
}

DOM.Ready = {};

DOM.Ready.VERSION = "0.16";

DOM.Ready.finalTimeout = 15;
DOM.Ready.timerInterval = 50;

DOM.Ready._checkDOMReady = function () {
    if ( DOM.Ready._isReady ) {
        return DOM.Ready._isReady;
    }

    if (    typeof document.getElementsByTagName != "undefined"
         && typeof document.getElementById != "undefined" 
         && ( document.getElementsByTagName("body")[0] !== null
              || document.body !== null ) ) {

        DOM.Ready._isReady = 1;
    }

    return DOM.Ready._isReady;

};

/* See near the end of the module for where _isDone could be set. */
DOM.Ready._checkDOMDone = function () {
    if ( DOM.Ready._isDone ) {
        return DOM.Ready._isDone;
    }

    /* Safari and Opera(?) only */

    /*@cc_on
       /*@if (@_win32)
    try {
        document.documentElement.doScroll("left");
        DOM.Ready._isDone = 1;
    } catch (e) {}
          @else @*/
    if ( document.readyState
         && ( /interactive|complete|loaded/.test( document.readyState ) )
       ) {
        DOM.Ready._isDone = 1;
    }
      /*@end
    @*/

    return DOM.Ready._isDone;
};

/* Works for Mozilla, and possibly nothing else */
if ( document.addEventListener ) {
    document.addEventListener(
        "DOMContentLoaded", function () { DOM.Ready._isDone = 1; }, false );
}

DOM.Ready.onDOMReady = function (callback) {
    if ( DOM.Ready._checkDOMReady() ) {
        callback();
    }
    else {
        DOM.Ready._onDOMReadyCallbacks.push(callback);
    }
};

DOM.Ready.onDOMDone = function (callback) {
    if ( DOM.Ready._checkDOMDone() ) {
        callback();
    }
    else {
        DOM.Ready._onDOMDoneCallbacks.push(callback);
    }
};

DOM.Ready.onIdReady = function ( id, callback ) {
    if ( DOM.Ready._checkDOMReady() ) {
        var elt = document.getElementById(id);
        if (elt) {
            callback(elt);
            return;
        }
    }

    var callback_array = DOM.Ready._onIdReadyCallbacks[id];
    if ( ! callback_array ) {
        callback_array = [];
    }
    callback_array.push(callback);

    DOM.Ready._onIdReadyCallbacks[id] = callback_array;
};

DOM.Ready._runDOMReadyCallbacks = function () {
    for ( var i = 0; i < DOM.Ready._onDOMReadyCallbacks.length; i++ ) {
        DOM.Ready._onDOMReadyCallbacks[i]();
    }

    DOM.Ready._onDOMReadyCallbacks = [];
};

DOM.Ready._runDOMDoneCallbacks = function () {
    for ( var i = 0; i < DOM.Ready._onDOMDoneCallbacks.length; i++ ) {
        DOM.Ready._onDOMDoneCallbacks[i]();
    }

    DOM.Ready._onDOMDoneCallbacks = [];
};

DOM.Ready._runIdCallbacks = function () {
    for ( var id in DOM.Ready._onIdReadyCallbacks ) {
        // protect against changes to Object (ala prototype's extend)
        if ( ! DOM.Ready._onIdReadyCallbacks.hasOwnProperty(id) ) {
            continue;
        }

        var elt = document.getElementById(id);

        if (elt) {
            for ( var i = 0; i < DOM.Ready._onIdReadyCallbacks[id].length; i++) {
                DOM.Ready._onIdReadyCallbacks[id][i](elt);
            }

            delete DOM.Ready._onIdReadyCallbacks[id];
        }
    }
};

DOM.Ready._runReadyCallbacks = function () {
    if ( DOM.Ready._inRunReadyCallbacks ) {
        return;
    }

    DOM.Ready._inRunReadyCallbacks = 1;

    if ( DOM.Ready._checkDOMReady() ) {
        DOM.Ready._runDOMReadyCallbacks();

        DOM.Ready._runIdCallbacks();
    }

    if ( DOM.Ready._checkDOMDone() ) {
        DOM.Ready._runDOMDoneCallbacks();
    }

    DOM.Ready._timePassed += DOM.Ready._lastTimerInterval;

    if ( ( DOM.Ready._timePassed / 1000 ) >= DOM.Ready.finalTimeout ) {
        DOM.Ready._stopTimer();
    }

    DOM.Ready._inRunReadyCallbacks = 0;
};

DOM.Ready._startTimer = function () {
    DOM.Ready._lastTimerInterval = DOM.Ready.timerInterval;
    DOM.Ready._intervalId = setInterval( DOM.Ready._runReadyCallbacks, DOM.Ready.timerInterval );
};

DOM.Ready._stopTimer = function () {
    clearInterval( DOM.Ready._intervalId );
    DOM.Ready._intervalId = null;
};

DOM.Ready._resetClass = function () {
    DOM.Ready._stopTimer();

    DOM.Ready._timePassed = 0;

    DOM.Ready._isReady = 0;
    DOM.Ready._isDone = 0;

    DOM.Ready._onDOMReadyCallbacks = [];
    DOM.Ready._onDOMDoneCallbacks = [];
    DOM.Ready._onIdReadyCallbacks = {};

    DOM.Ready._startTimer();
};

DOM.Ready._resetClass();

DOM.Ready.runCallbacks = function () { DOM.Ready._runReadyCallbacks(); };


/*

=head1 NAME

DOM.Ready - set up callbacks to run when the DOM is ready instead of using onLoad

=head1 SYNOPSIS

  DOM.Ready.onDOMReady( myFunction );
  DOM.Ready.onIdReady( "an_id", myOtherFunction );

=head1 DESCRIPTION

It's a very common case to want to run one or more functions when the
document loads.  The simplest option is to use the window.onLoad to
trigger these functions.

This has several problems.  First, window.onLoad may not happen until
well after the document is mostly loaded, due to delays in fetching
images or other dependencies.  Second, there is no built-in API for
stacking multiple onLoad callbacks.

This module provides several simple functions to register callbacks
that should be run, either when the DOM/document is ready or when a
specific element (found by id) is ready.  This is done through the use
of a recurring interval that checks to see if the callbacks should be
run.

=head1 PROPERTIES

The DOM.Ready class has the following settable properties:

=over 4

=item * DOM.Ready.timerInterval = milliseconds

The number of milliseconds to wait between each readiness check.
Defaults to 50.

=item * DOM.Ready.finalTimeout = seconds

The number of seconds before the recurring readiness checks stop
running.  Defaults to 15 seconds.

=back

=head1 METHODS

DOM.Ready provides the following functions.  None of these are
exportable.

=over 4

=item * onDOMReady( callback )

Provide a callback function to be called once the DOM is ready.  If
the DOM is ready when C<onDOMReady()> is called, then the callback
will be called immediately.

The DOM is considered ready as soon as the DOM API is available and
the opening C<< <body> >> tag has been processed. This does not mean
that any other elements in the DOM will be available.

Use this to replace the use of an "onload" attribute in the body tag,
but do not assume that any specific element will be available.

=item * onDOMDone( callback )

Provide a callback function to be called once the DOM is complete.  If
the DOM is done when C<onDOMDone()> is called, then the callback
will be called immediately.

The DOM is done when all the elements in the DOM have been processed,
but this does not wait for external images to load.

=item * onIdReady( id, callback )

Provide a callback to be called when the given id is found (using
document.getElementById).  The callback will be called with the
element object as its only argument.  If the element is available when
C<onIdReady()> is called, then the callback will be called immediately.

Note that an element might be ready but it's children may not yet have
been inserted. This can lead to intermittent problems where your
callback is called and the element's children do not yet exist. If
this is a problem, use C<onDOMDone()> instead.

=item * runCallbacks()

Explicitly run all callbacks that can be run.  This can be used to run
all the callbacks at a known time, for example just before the close
of a document's C<< </body> >> tag.

=back

=head1 KNOWN ISSUES

If C<onIdReady()> is called after the final timeout has passed and the
specified element is not ready, then the callback will never be
called.

This code has not seen a lot of production use, so be wary of bugs.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>.

=head1 CREDITS

This library was inspired by Brother Cake's domFunction, though it
is entirely new code.

=head1 COPYRIGHT

Copyright (c) 2005-2006 Dave Rolsky.  All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as the Perl programming language (your choice of
GPL or the Perl Artistic license).

=cut

*/
