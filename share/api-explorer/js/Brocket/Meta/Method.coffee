_    = require "underscore"
util = require "util"

class Method
  constructor: (args) ->
    @_name           = args.name
    @_body           = args.body
    @_source         = args.source
    @_associatedMeta = args.associatedMeta

    return

  clone: (args) ->
    args ?= {}

    for prop in [ "name", "body" ]
      args[prop] ?= @[prop]()

    args.source = @source()

    constructor = @constructor

    return new constructor args

  attachToMeta: (meta) ->
    @_setAssociatedMeta meta
    return

  detachFromMeta: (meta) ->
    @_clearAssociatedMeta()
    return

  name: ->
    return @_name

  body: ->
    return @_body

  source: ->
    return @_source

  associatedMeta: ->
    return @_associatedMeta

  _setAssociatedMeta: (meta) ->
    @_associatedMeta = meta
    return

  _clearAssociatedMeta: ->
    delete @_associatedMeta
    return

  # XXX - this is a horrible, horrible, horrible hack - it's necessary because
  # of the wonky way inheritance is currently being handled
  isInheritable: ->
    name = @name()
    if name == "BUILD" || name == "BUILDARGS"
      meta = @associatedMeta()
      return false unless meta? && meta.name() == "Brocket.Base"

    return true

module.exports = Method
