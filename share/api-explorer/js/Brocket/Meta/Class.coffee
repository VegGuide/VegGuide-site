_             = require "underscore"
Attribute     = require "./Attribute"
Cache         = require "./Cache"
HasAttributes = require "./Mixin/HasAttributes"
HasMethods    = require "./Mixin/HasMethods"
HasRoles      = require "./Mixin/HasRoles"
Helpers       = require "../Helpers"
Role          = require "./Role"
util          = require "util"

class Class
  for own key of HasAttributes.prototype
    Class.prototype[key] = HasAttributes.prototype[key]

  for own key of HasMethods.prototype
    Class.prototype[key] = HasMethods.prototype[key]

  for own key of HasRoles.prototype
    Class.prototype[key] = HasRoles.prototype[key]

  constructor: (args) ->
    @_name = args.name
    throw new Error "You must provide a name when constructing a class" unless @_name

    args.cache = true unless args.cache? && ! args.cache

    if args.cache && Cache.metaObjectExists args.name
      meta = Cache.getMetaObject args.name
      unless meta instanceof Class
        error = "Found an existing meta object named #{ args.name } which is not a Class object."
        if meta instanceof Role
          error += " You cannot create a Class and a Role with the same name."
        throw new Error error

      return meta

    @_buildMethodProperties args
    @_buildAttributeProperties args
    @_buildRoleProperties args

    @_superclasses = []

    @_class = @_makeClass args._class

    Cache.storeMetaObject @ if args.cache

    return

  _makeClass: (klass) ->
    meta = @

    if !klass
      klass = ->
        args = [@].concat Array.prototype.slice.call arguments
        meta.constructInstance.apply meta, args

    klass.meta           = => meta
    klass.prototype.meta = => meta

    klass.prototype._super = ->
      error = new Error

      caller = meta._callerFromError error, "_super"

      ancestors = meta.linearizedInheritance()
      for supermeta in ancestors
        superclass = supermeta.class()
        if Object.prototype.hasOwnProperty.call superclass.prototype, caller
          return superclass.prototype[caller].apply @, Array.prototype.slice.call arguments

      name = (s) -> s.name()
      supernames = (name s for s in ancestors)

      throw new Error "No #{caller} method found in any superclasses of #{ meta.name() } - superclasses are #{ supernames.join(', ') }"

    return klass

  @newFromClass = (klass) ->
    cache = true
    name = Helpers.className klass

    unless name?
      name = "__Anon__"
      cache = false

    return new @ { name: name, _class: klass, cache: cache }

  setSuperclasses: (supers) ->
    supers = [supers] unless supers instanceof Array

    constructor = @constructor
    metaFor = (s) ->
      meta = Helpers.findMeta s, constructor
      unless meta instanceof Class
        throw new Error "Cannot have a superclass which is a #{ Helpers.className meta }"
      return meta

    @_superclasses = (metaFor s for s in supers)

    @_checkMetaclassCompatibility()

    for meta in @_superclasses
      for own name, method of meta._methodMap()
        continue if @hasMethod name
        continue unless method.isInheritable()
        @addMethod method.clone()

    return

  _checkMetaclassCompatibility: (klass) ->
    return

  constructInstance: (instance, params) ->
    params =
      if instance.BUILDARGS?
        instance.BUILDARGS params
      else
        params

    for own name, attr of @attributes()
      attr.initializeInstanceSlot instance, params

    instance.BUILDALL params if instance.BUILDALL?

    return instance

  # XXX - this needs to be redone to use the C3 algorithm (or we can just not
  # support multiple inheritance, which is ok too).
  linearizedInheritance: ->
    metas = [];

    for supermeta in @superclasses()
      metas.push supermeta;

      for meta in supermeta.linearizedInheritance()
        metas.push meta

    return metas

  selfAndParents: ->
    metas = @linearizedInheritance()
    metas.unshift @

    return metas

  _attachMethod: (method) ->
    method.attachToMeta @
    @class().prototype[ method.name() ] = method.body()
    return

  _detachMethod: (method) ->
    method.detachFromMeta @
    delete @class().prototype[ method.name() ]
    return

  methodNamed: (name) ->
    methods = @_methodMap()
    return methods[name] if methods[name]?

    if @class().prototype[name]? && typeof @class().prototype[name] == "function"
      @addMethod name: name, body: @class().prototype[name]

    return methods[name]

  # XXX - once there's an immutabilization hook this method should just cache
  # the methods
  _methodMap: ->
    methods = @_methodsObj()

    for own name, body of @class().prototype
      continue if methods[name]?
      # XXX - this is kind of gross - maybe have some sort of way of marking a
      # method as hidden or something?
      continue if name == "_super"

      @addMethod name: name, body: @class().prototype[name], source: @

    return @_methodsObj()

  _attachAttribute: (attribute) ->
    attribute.attachToClass @
    @addMethod method for method in attribute.methods()
    return

  _detachAttribute: (attribute) ->
    attribute.detachFromClass @
    @removeMethod method for method in attribute.methods()
    return

  roles: ->
    classes = @linearizedInheritance()
    classes.unshift @

    roles = []

    for klass in classes
      for role in klass.localRoles()
        roles = roles.concat role.roles()

    return _.uniq roles

  _callerFromError: (error, ignoreBefore) ->
    re = new RegExp "\\.#{ignoreBefore} \\("
    for line in error.stack.split /\n+/
      if re.test(line)
        next = true
        continue
      else
        continue unless next
        return line.match( /\.(\w+) \(/ )[1]

    return

  _defaultAttributeClass: ->
    Attribute

  name: ->
    @_name

  superclasses: ->
    @_superclasses

  class: ->
    @_class

module.exports = Class
