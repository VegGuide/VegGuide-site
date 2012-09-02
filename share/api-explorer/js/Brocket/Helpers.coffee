_    = require "underscore"
util = require "util"

Class = null
Role  = null

module.exports.arrayToObject = (array) ->
  if typeof array == "string"
    obj = {}
    obj[array] = true
    return obj

  obj = {}
  for elt in array
    obj[elt] = true

  return obj

module.exports.className = (klass) ->
  if matches = klass.toString().match( /function\s*(\w+)/ )
    return matches[1]
  else
    return null

module.exports.applyRoles = (applyTo, roles...) ->
  Role ?= require "./Meta/Role"

  if roles[0] instanceof Array
    roles = roles[0]

  rolesWithArgs = module.exports.optList roles, { lhs: Role }

  if rolesWithArgs.length == 2
    role = rolesWithArgs[0]
    args = rolesWithArgs[1]

    role.apply applyTo, args
  else
    (Role.Combine rolesWithArgs).apply applyTo

  return

module.exports.optList = (list, args) ->
  args ?= {}

  lhsTest =
    if args.lhs?
      (item) -> item instanceof args.lhs
    else
      (item) -> typeof item == "string"

  pairs = []
  for item in list
    if lhsTest item
      pairs.push [item]
    else if item instanceof Object
      pairs[ pairs.length - 1 ].push item

  retVal = []
  for pair in pairs
    pair[1] ?= {}
    retVal = retVal.concat pair

  return retVal

module.exports.findMeta = (thing, classClass) ->
  Class ?= require "./Meta/Class"
  Role  ?= require "./Meta/Role"

  return thing if thing instanceof Class
  return thing if thing instanceof Role
  return thing.meta() if thing.meta?

  unless typeof thing == "function"
    throw new Error "Cannot find a metaclass for a #{thing}"

  # Allows callers to pass an alternate metaclass
  classClass ?= Class

  unless classClass.newFromClass?
    name = module.exports.className classClass
    throw new Error "The #{name} class does not have a newFromClass method"

  return classClass.newFromClass thing
