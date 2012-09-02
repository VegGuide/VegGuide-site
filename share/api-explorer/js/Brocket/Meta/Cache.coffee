_    = require "underscore"
util = require "util"

class Cache
  _metaobjects = {}

  @storeMetaObject = (meta) ->
    _metaobjects[ meta.name() ] = meta
    return

  @getMetaObject = (name) ->
    return _metaobjects[name]

  @metaObjectExists = (name) ->
    return _metaobjects[name]?

  @removeMetaObject = (name) ->
    return _metaobjects[name]?

  @allMetaObjects = ->
    return _.values _metaobjects

  @_clearMetaObjects = ->
    _metaobjects = {}
    return

module.exports = Cache
