_                 = require "underscore"
Attribute         = require "./Attribute"
Cache             = require "./Cache"
ConflictingMethod = require "./Role/ConflictingMethod"
HasAttributes     = require "./Mixin/HasAttributes"
HasMethods        = require "./Mixin/HasMethods"
HasRoles          = require "./Mixin/HasRoles"
Helpers          = require "./Mixin/HasRoles"
RequiredMethod    = require "./Role/RequiredMethod"
RoleAttribute     = require "./Role/Attribute"
ToClass           = require "./Role/Application/ToClass"
ToInstance        = null #require "./Role/Application/ToInstance"
ToRole            = require "./Role/Application/ToRole"
util              = require "util"

Class     = null
Composite = null

class Role
  for own key of HasAttributes.prototype
    Role.prototype[key] = HasAttributes.prototype[key]

  for own key of HasMethods.prototype
    Role.prototype[key] = HasMethods.prototype[key]

  for own key of HasRoles.prototype
    Role.prototype[key] = HasRoles.prototype[key]

  constructor: (args) ->
    @_name = args.name
    throw new Error "You must provide a name when constructing a role" unless @_name

    args.cache = true unless args.cache? && ! args.cache

    # This is necessary to avoid a circular dependency issue between Class &
    # Role. One of them has to be loaded later.
    Class ?= require "./Class"

    if args.cache && Cache.metaObjectExists args.name
      meta = Cache.getMetaObject args.name
      unless meta instanceof Role
        message = "Found an existing meta object named #{ args.name } which is not a Role object."
        if meta instanceof Class
          message += " You cannot create a Class and a Role with the same name."
        throw new Error message

      return meta

    @_buildMethodProperties args
    @_buildAttributeProperties args
    @_buildRoleProperties args

    @_requiredMethods = []

    @_requiredMethodClass    = args.requiredMethodClass ? RequiredMethod
    @_conflictingMethodClass = args.conflictingMethodClass ? ConflictingMethod

    @_applicationToClassClass    = args.applicationToClassClass ? ToClass
    @_applicationToRoleClass     = args.applicationToRoleClass ? ToRole
    @_applicationToInstanceClass = args.applicationToInstanceClass ? ToRole

    @_appliedAttributeClass = args.appliedAttributeClass ? Attribute

    @_localRoles = []

    Cache.storeMetaObject @ if args.cache

    return

  @Combine = (rolesWithArgs) ->
    Composite ?= require "./Role/Composite"

    roles = []
    args  = {}

    for i in [ 0 .. rolesWithArgs.length - 1 ] by 2
      role = rolesWithArgs[i]
      roles.push role
      args[ role.name() ] = rolesWithArgs[ i + 1 ]

    # XXX - need to allow each role to provide traits to be applied to the
    # Composite class
    composite = new Composite roles: roles
    return composite.applyCompositionArgs roleParams: args

  _defaultAttributeClass: ->
    RoleAttribute

  _attachAttribute: (attr) ->
    attr.attachToRole @
    return

  _detachAttribute: (attr) ->
    attr.detachFromRole @
    return

  _attachMethod: (method) ->
    method.attachToMeta @
    return

  _detachMethod: (method) ->
    method.detachFromMeta @
    return

  # Unlike a class, methods can only be added to a role explicitly, so we
  # don't need to check an associated prototype for implicit methods.
  _methodMap: ->
    return @_methodsObj()

  addRequiredMethod: (method) ->
    rmclass = @requiredMethodClass()
    unless method instanceof rmclass
      method = new rmclass name: method

    @requiredMethods().push method

    return;

  addConflictingMethod: (method) ->
    rmclass = @conflictingMethodClass()
    unless method instanceof rmclass
      method = new rmclass method

    @requiredMethods().push method

    return;

  apply: (other, args) ->
    args ?= {}

    if other instanceof Class
      appClass = @applicationToClassClass()
    else if other instanceof Role
      appClass = @applicationToRoleClass()
    else if other instanceof Object
      appClass = @applicationToInstanceClass()
    else
      throw new Error "Cannot apply a role to a #{ other.toString() }"

    (new appClass args).apply @, other

    return

  roles: ->
    roles = [@].concat @localRoles()

    seen = {}
    for role in roles
      continue if seen[ role.name() ]
      seen[ role.name() ] = role
      roles.push role.localRoles()

    return _.values seen

  _roleForCombination: ->
    return @

  name: ->
    return @_name

  requiredMethods: ->
    return @_requiredMethods

  requiredMethodClass: ->
    return @_requiredMethodClass

  conflictingMethods: ->
    cmclass = @conflictingMethodClass()
    return ( m for m in @requiredMethods() when m instanceof cmclass )

  conflictingMethodClass: ->
    return @_conflictingMethodClass

  applicationToClassClass: ->
    return @_applicationToClassClass

  applicationToRoleClass: ->
    return @_applicationToRoleClass

  applicationToInstanceClass: ->
    return @_applicationToInstanceClass

  appliedAttributeClass: ->
    return @_appliedAttributeClass

module.exports = Role
