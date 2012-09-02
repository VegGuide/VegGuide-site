Class = require "./Meta/Class"
util  = require "util"

class Base
  constructor: ->
    throw new Error "Cannot construct a Brocket/Base object"

  BUILDARGS: (params) ->
    return params ? {}

  BUILDALL: (params) ->
    for meta in @meta().selfAndParents().reverse()
      build = meta.methodNamed "BUILD"
      build.body().call @, params if build?

    return

  DOES: (role) ->
    return @meta().doesRole role

  _meta = new Class { name: "Brocket.Base", _class: @ }
  @meta: -> _meta

module.exports = Base
