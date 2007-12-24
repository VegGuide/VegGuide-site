/*

=head1 NAME

List.Utils

=head1 DESCRIPTION

This module provides functions to operate on lists.

Most function can operate on elements of JavaScript Arrays or on properties
of generic Objects.

=cut

*/

if (typeof(List) == "undefined") List = {};

if (!List.Utils) {
    List.Utils = {
        VERSION: "0.04",
        EXPORT: [ 'grep', 'map', 'iterate', 'findInList', 'defined',
                  'any', 'all', 'bsearch', 'insertIntoList',
                  'removeFromList' ],
/*

=head2 List.Utils.grep(FUNCTION, DATA, [RESULT])

This function selects elements from list DATA for which function FUNCTION
returns non-false value and stores in RESULT list. Each call to FUNCTION
passes two arguments: value of processed element and its index (array index
or property name depending of DATA type).

If this function is used without RESULT argument new container is created,
its type is this same as type of DATA.

     grep(function(a){return a>5}, [1,2,3,4,5,6,7,8,9]) = [6,7,8,9]
     grep(function(a){return a>5}, [1,3,5,7,9], {}) = {3: 7, 4: 9}
     grep(function(a,b){return b&1}, {1:"a",2:"b",3:"c"], []) = ["a","c"]

=cut

 */
        grep: function (fun, data, result)
        {
            var i;
            var nl = data.item && data.length != null;

            if (!data || !fun || typeof(data) != "object" && !nl)
                return [];

            if (data instanceof Array || nl) {
                result = result || [];

                for (i = 0; i < data.length; i++) {
                    if (fun(data[i], i))
                        if (result instanceof Array)
                            result.push(data[i]);
                        else
                            result[i] = data[i];
                }
            } else {
                result = result || {};

                for (i in data)
                    if (fun(data[i], i))
                        if (result instanceof Array)
                            result.push(data[i]);
                        else
                            result[i] = data[i];
            }

            return result;
        },

/*

=head2 List.Utils.map(FUNCTION, DATA, [RESULT])

This function returns new list created from DATA list elements by
FUNCTION function. Each call to FUNCTION passes two arguments: value
of processed element and its index (array index or property name
depending of DATA type).

If this function is used without RESULT argument new container is created,
its type is this same as type of DATA.

     map(function(a){return a*2}, [1,2,3,4,5]) = [2,4,6,8,10]
     map(function(a,b){return a+b}, {1:3, 2:2, 3:1}, []) = [4,4,4]

=cut

 */

        map: function(fun, data, result)
        {
            var i;

            var nl = data.item && data.length != null;

            if (!data || !fun || typeof(data) != "object" && !nl)
                return [];

            if (data instanceof Array || nl) {
                result = result || [];

                for (i = 0; i < data.length; i++)
                    if (result instanceof Array)
                        result.push(fun(data[i], i));
                    else
                        result[i] = fun(data[i], i);
            } else {
                result = result || {};

                for (i in data)
                    if (result instanceof Array)
                        result.push(fun(data[i], i));
                    else
                        result[i] = fun(data[i], i);
            }

            return result;
        },

/*

=head2 List.Utils.iterate(FUNCTION, DATA)

This function invokes function FUNCTION for each element in list DATA.
Each call to FUNCTION passes two arguments: value of processed element
and its index (array index or property name depending of DATA type).

=cut

*/
        iterate: function(fun, data)
        {
            var i;
            var nl = data.item && data.length != null;

            if (!data || !fun || typeof(data) != "object" && !nl)
                return;

            if (data instanceof Array || nl)
                for (i = 0; i < data.length; i++)
                    fun(data[i], i);
            else
                for (i in data)
                    fun(data[i], i);
        },

/*

=head2 List.Utils.findInList(FUNCTION, DATA)

This function finds index of first element for which function FUNCTION
returns non-false value.

Each call to FUNCTION passes two arguments: value of processed element
and its index (array index or property name depending of DATA type).

    findInList(function(a,b){return a>3}, [1,1,3,3,5,5]) = 4
    findInList(function(a,b){return a>3}, {a:1, b:2, c:3, d:4}) = "d"

=cut

*/
       findInList: function(fun, data) {
            var i;
            var nl = data.item && data.length != null;

            if (!data || !fun || typeof(data) != "object" && !nl)
                return null;

            if (data instanceof Array || nl) {
                for (i = 0; i < data.length; i++)
                        if (fun(data[i], i))
                                return i;
            } else
                for (i in data)
                        if (fun(data[i], i))
                                return i;
            return null;
        },

/*

=head2 List.Utils.defined(DATA, [RESULT])

This function creates new list from LIST elements by removing all C<null>
and C<undefined> elements.

    defined([1,2,null,4,5]) = [1,2,4,5]
    defined({"a":1, "b":null, "c":3}) = {"a": 1, "c": 3]

=cut

*/
        defined: function(data, res) {
            return List.Utils.grep(function(a){return a != null;}, data, res);
        },

/*

=head2 List.Utils.any(FUNCTION, DATA)

This function checks that FUNCTION return non-false value for any LIST
elements.

Each call to FUNCTION passes two arguments: value of processed element
and its index (array index or property name depending of DATA type).

    any(function(a){return a>=4}, [1,2,3,4]) = true
    any(function(a){return a>4}, {1:1, 2:2}) = false

=cut

*/

        any: function(fun, data)
        {
            return List.Utils.findInList(fun, data) != null;
        },

/*

=head2 List.Utils.all(FUNCTION, DATA)

This function checks that FUNCTION return non-false value for all LIST
elements.

Each call to FUNCTION passes two arguments: value of processed element
and its index (array index or property name depending of DATA type).

    all(function(a){return a>=4}, [1,2,3,4]) = false
    all(function(a){return a>4}, {1:5, 2:9}) = true

=cut

*/
        all: function(fun, data)
        {
            var i;
            var nl = data.item && data.length != null;

            if (!data || !fun || typeof(data) != "object" && !nl)
                return;

            if (data instanceof Array || nl) {
                for (i = 0; i < data.length; i++)
                    if (!fun(data[i], i))
                        return false;
            } else
                for (i in data)
                    if (!fun(data[i], i))
                        return false;
            return true;
        },

/*

=head2 List.Utils.bsearch(ARRAY, ELEMENT, COMPARATOR)

This function finds lowest index of ARRAY element which is greater or equal to
ELEMENT.

Two argument function COMPARATOR, which is used as array element comparator,
should return value C<< < 0 >> when its first argument is lower than second,
C<< > 0 >> when second in bigger and C<< 0 >> when both arguments are equal.

     bsearch([1,2,4,6,7], 5, function(a,b){return a - b}) = 3
     bsearch([1,2,3,4,5,6,7], 5, function(a,b){return a - b}) = 4

B<Note:> This function operate only on Arrays

=cut

*/
        bsearch: function(list, element, comparator)
        {
            var a = 0;
            var b = list.length-1;
            var mid, val;

            while (a <= b) {
                mid = (a+b)>>1;
                val = comparator(element, list[mid]);
                if (val == 0)
                    return mid;
                if (val < 0)
                    b = mid-1;
                else
                    a = mid+1;
            }

            return a;
        },

/*

=head2 List.Utils.insertIntoList(ARRAY, ELEMENT, [COMPARATOR])

This function insert element into list only when ARRAY doesn't contains
ELEMENT already.

Two argument function COMPARATOR, which is used to compare array elements
should return C<true> when elements are equal, and C<false> otherwise.

This function returns number of items inserted into array (0 or 1).

    insertIntoList([1,2,3,4], 3) = [1,2,3,4]
 
    insertIntoList([2,3,4], 1) = [2,3,4,1]
 
    insertIntoList([{key:1, value:2}, {key:2, value: 2}],
      {key:2, value: 3}, function(a,b){return a.key == b.key}) =
        [{key:1, value:2}, {key:2, value: 2}]
 
    insertIntoList([{key:1, value:2}, {key:2, value: 2}],
      {key:3, value: 2}, function(a,b){return a.key == b.key}) =
        [{key:1, value:2}, {key:2, value: 2}, {key:3, value: 2}]

B<Note:> This function operate only on Arrays

=cut

*/
        insertIntoList: function(list, element, comparator)
        {
            var i;

            if (comparator) {
                if (!List.Utils.findInList(function(a){return comparator(a, element)}, list)) {
                    list.push(element);
                    return 1;
                }
            } else {
                if (!List.Utils.findInList(function(a){return a==element}, list)) {
                    list.push(element);
                    return 1;
                }
            }

            return 0;
        },

/*

=head2 List.Utils.removeFromList(ARRAY, ELEMENT, [COMPARATOR], [ALL])

This function removes ELEMENT from ARRAY. If multiple ELEMENTs exists in
ARRAY and ALL is non-true only first one will be removed. If ALL is non-false
all elements will be removed.

Two argument function COMPARATOR, which is used to compare array elements
should return C<true> when elements are equal, and C<false> otherwise.

This function returns number of removed elements.

    removeFromList([1,2,3,4,3], 3) = [1,2,4, 3]

    removeFromList([1,2,3,4,3], 3, null, true) = [1,2,4]

    removeFromList([{key:1, value:2}, {key:2, value: 2}], {key:1, value: 5},
      function(a,b){return a.key == b.key}) =
        [{key:2, value: 2}]

B<Note:> This function operate only on Arrays

=cut

*/
        removeFromList: function(list, element, comparator, all)
        {
            var rc = 0;
            var i;

            if (comparator) {
                for (i = 0; i < list.length; i++)
                    if (comparator(element, list[i])) {
                        list.splice(i--, 1);
                        rc++
                        if (!all)
                            return 1;
                    }
            } else {
                for (i = 0; i < list.length; i++)
                    if (list[i] == element) {
                        list.splice(i--, 1);
                        rc++
                        if (!all)
                            return 1;
                    }
            }

            return rc;
        }
    }
}

/*

=head1 AUTHOR

Pawel Chmielowski <prefiks@aviary.pl>

=cut

*/
