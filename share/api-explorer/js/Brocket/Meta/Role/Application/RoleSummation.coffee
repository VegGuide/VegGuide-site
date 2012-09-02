_           = require "underscore"
Application = require "../Application"
Helpers     = require "../../../Helpers"
util        = require "util"

class RoleSummation extends Application
  constructor: (args) ->
    @_roleParams = args.roleParams
    return

  apply: (compositeRole) ->
    @_compositeRole = compositeRole
    super

  _checkRequiredMethods: ->
    roles = @compositeRole().roles()

    allRequired = []
    for role in roles
      for m in role.requiredMethods()
        continue if _.any( roles, (r) -> r.hasMethod m.name() )
        allRequired.push m

    for m in allRequired
      @compositeRole().addRequiredMethod m

    return

  _applyAttributes: ->
    allAttributes = []
    for role in @compositeRole().roles()
      allAttributes = allAttributes.concat role.attributes()

    seen = {}
    for attr in allAttributes
      name = attr.name()

      if seen[name]
        role1 = attr.associatedRole().name()
        role2 = seen[name].name()

        message = "We have encountered an attribute conflict with '#{name}'" +
                  " during role composition." +
                  " This attribute is defined in both #{role1} and #{role2}. " +
                  " This is a fatal error and cannot be disambiguated."
        throw new Error message

      seen[ attr.name() ] = attr

    for attr in allAttributes
      @compositeRole().addAttribute attr.clone()

    return

  _applyMethods: ->
    roles = @compositeRole().roles()
    allMethods = []

    for role in roles
      for method in role.methods()
        allMethods.push { role: role, name: method.name(), method: method }

    seen = {}
    conflicts = {}
    methodMap = {}

    for method in allMethods
      continue if conflicts[ method.name ]

      saw = seen[ method.name ]
      if saw?
        if saw.method.body() != method.method.body()
          @compositeRole().addConflictingMethod name: method.name, roles: [ method.role, saw.role ]
          delete methodMap[ method.name ]
          conflicts[ method.name ] = true
          continue

      seen[ method.name ] = method
      methodMap[ method.name ] = method.method

    for name, method of methodMap
      @compositeRole().addMethod method.clone name: name

    return

  roleParams: ->
    @_roleParams

  compositeRole: ->
    @_compositeRole

module.exports = RoleSummation
