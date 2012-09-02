_           = require "underscore"
Application = require "../Application"
util        = require "util"

class ToRole extends Application
  apply: (appliedRole, receivingRole) ->
    @_appliedRole   = appliedRole
    @_receivingRole = receivingRole

    super

    @receivingRole().addRole @appliedRole()
    @receivingRole().addRoleApplication @

    return

  _checkRequiredMethods: ->
    for method in @appliedRole().requiredMethods()
      continue if @receivingRole().hasMethod method.name()
      @receivingRole().addRequiredMethod method

    return

  _applyAttributes: ->
    for attr in @appliedRole().attributes()
      if @receivingRole().hasAttribute attr.name() && @receivingRole().attributeNamed attr.name() != attr
        unless @receivingrole().attributeNamed attribute.name() == attribute
          message = "There was an attribute conflict while composing" +
            "#{ @appliedRole().name() } into #{ @receivingRole().name() }." +
            "This is a fatal error and cannot be disambiguated." +
            "The conflict attribute is named '#{ attr.name() }'"
          throw new Error message

      @receivingRole().addAttribute attr.clone()

    return

  _applyMethods: ->
    for method in @appliedRole().methods()
      @_applyMethod method

    return

  _applyMethod: (method) ->
    return if @receivingRole().hasMethod method.name()

    @receivingRole().addMethod method.clone()

  appliedRole: ->
    return @_appliedRole

  receivingRole: ->
    return @_receivingRole

module.exports = ToRole
