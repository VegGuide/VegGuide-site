_      = require "underscore"
Method = require "../Method"
util   = require "util"

class HasMethods
  _buildMethodProperties: (args) ->
    @__methodsObj = {}
    @_methodClass = args.methodClass ? Method

  addMethod: (method) ->
    if method not instanceof Method
      mclass = @methodClass()
      method.source ?= @
      method = new mclass method

    @_methodsObj()[ method.name() ] = method
    @_attachMethod method

    return

  removeMethod: (method) ->
    method = @methodNamed method unless method instanceof Method

    delete @_methodsObj()[ method.name() ]
    @_detachMethod method

    return

  hasMethod: (name) ->
    return @_methodMap()[name]?

  methodNamed: (name) ->
    return @_methodMap()[name]

  methods: ->
    _.values @_methodMap()

  _methodsObj: ->
    @__methodsObj

  methodClass: ->
    @_methodClass

module.exports = HasMethods