_             = require "underscore"
AttributeCore = require "../Mixin/AttributeCore"
util          = require "util"

class Attribute
  for own key of AttributeCore.prototype
    Attribute.prototype[key] = AttributeCore.prototype[key]

  constructor: (args) ->
    @_buildAttributeCore args

    if args._originalRole?
      @__originalRole = args._originalRole
      delete args._originalRole

    @__originalArgs = args

    return

  attributeForClass: ->
    aclass = @originalRole().appliedAttributeClass()
    return new aclass @_originalArgs()

  attachToRole: (role) ->
    @_associatedRole = role
    return;

  detachFromRole: (role) ->
    delete @_associatedRole
    return;

  associatedRole: ->
    return @_associatedRole

  clone: ->
    argsCopy = {}
    for own prop, val of @_originalArgs()
      argsCopy[prop] = val

    argsCopy._originalRole = @_originalRole()

    constructor = @constructor
    return new constructor argsCopy

  originalRole: ->
    orig = @_originalRole()
    return orig if orig?
    return @associatedRole()

  _originalArgs: ->
    return @__originalArgs

  _originalRole: ->
    return @__originalRole

module.exports = Attribute