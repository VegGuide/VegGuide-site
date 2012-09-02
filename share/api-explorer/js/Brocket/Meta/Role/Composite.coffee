_             = require "underscore"
Role          = require "../Role"
RoleSummation = require "./Application/RoleSummation"
util          = require "util"

class Composite extends Role
  constructor: (args) ->
    args.name ?= ( _.map args.roles, (r) -> r.name() ).join "|"
    @_roles = args.roles

    argsCopy = {}
    for own key, val of args
      argsCopy[key] = val

    delete argsCopy.roles
    argsCopy.cache = false

    super argsCopy

    @_roleSummationClass = args.roleSummationClass ? RoleSummation

    return

  applyCompositionArgs: (args) ->
    rsclass = @roleSummationClass()
    (new rsclass args).apply @
    return @

  roles: ->
    @_roles

  roleSummationClass: ->
    @_roleSummationClass

module.exports = Composite
