_    = require "underscore"
util = require "util"

class AttributeCore
  _buildAttributeCore: (args) ->
    @_name = args.name

    @_access = args.access ? "ro"
    @_validateAccess @_access

    @_required  = args.required ? false
    @_lazy      = args.lazy     ? false

    return

  _validateAccess: (access) ->
    return if access in [ "bare", "ro", "rw" ]
    throw new Error "The access value for an attribute must be \"bare, \"ro\" or \"rw\", not \"#{access}\""

  name: ->
    @_name

  access: ->
    @_access

  required: ->
    @_required

  isLazy: ->
    @_lazy

  reader: ->
    @_reader

  hasReader: ->
    @reader()?

  writer: ->
    @_writer

  hasWriter: ->
    return @writer()?

  accessor: ->
    @_accessor

  hasAccessor: ->
    return @accessor()?

  predicate: ->
    @_predicate

  hasPredicate: ->
    @predicate()?

  clearer: ->
    @_clearer

  hasClearer: ->
    @clearer()?

  _defaultFunc: ->
    @__defaultFunc

module.exports = AttributeCore
