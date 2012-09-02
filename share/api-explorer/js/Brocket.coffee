Base    = require "./Brocket/Base"
Class   = require "./Brocket/Meta/Class"
Helpers = require "./Brocket/Helpers"
util    = require "util"

_has = (meta, name, attr) ->
  clone = name: name
  for own key, val of attr
    clone[key] = val

  meta.addAttribute clone

_method = (meta, name, body) ->
  meta.addMethod name: name, body: body, source: meta

_subclasses = (meta, supers) ->
  meta.setSuperclasses supers

_with = (meta, roles) ->
  Helpers.applyRoles meta, roles

_consumes = (meta, name, options) ->

module.exports.makeClass = (name, definition) ->
  metaclass = new Class name: name

  metaclass.setSuperclasses(Base)

  klass = metaclass.class()

  B = {}
  B.has        = (name, attr)    -> _has metaclass, name, attr
  B.method     = (name, body)    -> _method metaclass, name, body
  B.subclasses = (supers)        -> _subclasses metaclass, supers
  B.with       = (roles...)      -> _with metaclass, roles
  B.consumes   = (role, options) -> _consumes metaclass, role, options

  definition ?= -> return

  definition.call @, B

  return klass
