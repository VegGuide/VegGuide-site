Helpers = require "../Brocket/Helpers"
Role    = require "../Brocket/Meta/Role"
util    = require "util"

_has = (meta, name, attr) ->
  clone = name: name
  for own key, val of attr
    clone[key] = val

  meta.addAttribute clone

_method = (meta, name, body) ->
  meta.addMethod name: name, body: body, source: meta

_with = (meta, roles) ->
  Helpers.applyRoles meta, roles

_consumes = (meta, name, options) ->

module.exports.makeRole = (name, definition) ->
  role = new Role name: name

  B = {}
  B.has        = (name, attr)    -> _has role, name, attr
  B.method     = (name, body)    -> _method role, name, body
  B.with       = (roles...)      -> _with role, roles
  B.consumes   = (role, options) -> _consumes role, role, options

  definition ?= -> return

  definition.call @, B

  return role
