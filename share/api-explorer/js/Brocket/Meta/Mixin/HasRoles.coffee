_    = require "underscore"
util = require "util"

Role = null

class HasRoles
  _buildRoleProperties: ->
    Role ?= require "../Role"

    @_localRoles = []
    @_roleApplications = []

  addRole: (role) ->
    @localRoles().push role
    return

  doesRole: (role) ->
    name =
     if role instanceof Role
        role.name()
      else
        role

    for role in @roles()
      return true if role.name() == name

    return false

  addRoleApplication: (application) ->
    @roleApplications().push application
    return

  localRoles: ->
    @_localRoles

  roleApplications: ->
    @_roleApplications

module.exports = HasRoles
