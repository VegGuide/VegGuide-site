_    = require "underscore"
util = require "util"

class RequiredMethod
  constructor: (args) ->
    @_name = args.name

    return

  name: ->
    return @_name

module.exports = RequiredMethod
