unescapeURL = (s) ->
  decodeURIComponent s.replace(/\+/g, "%20")

getURLParams = ->
  params = {}
  m = window.location.href.match(/[\\?&]([^=]+)=([^&#]*)/g)
  if m
    i = 0
    while i < m.length
      a = m[i].match(/.([^=]+)=(.*)/)
      params[unescapeURL(a[1])] = unescapeURL(a[2])
      i++
  return params

mturkLogin = (hitId, assignmentId, workerId, callback) ->
  Accounts.callLoginMethod
    methodArguments: [{
      hitId: hitId
      assignmentId: assignmentId
      workerId: workerId
    }],
    userCallback: callback

params = getURLParams()

Handlebars.registerHelper "hitParams", -> params

Handlebars.registerHelper "hitIsViewing", ->
  params.assignmentId and params.assignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE"

Meteor.startup ->
  # Remember our previous hit parameters unless they have been replaced
  # TODO make sure this doesn't interfere with actual HITs
  if params.hitId and params.assignmentId and params.workerId
    Session.set("_hitId", params.hitId)
    Session.set("_assignmentId", params.assignmentId)
    Session.set("_workerId", params.workerId)

  # Recover either page params or stored session params as above
  hitId = Session.get("_hitId")
  assignmentId = Session.get("_assignmentId")
  workerId = Session.get("_workerId")

  mturkLogin(hitId, assignmentId, workerId) if hitId and assignmentId and workerId

# TODO check that this works properly
Deps.autorun ->
  userId = Meteor.userId()
  return unless userId
  turkserver = Meteor.users.findOne(
    _id: userId
    "turkserver.state": { $exists: true }
  , fields:
    "turkserver.state" : 1
  )?.turkserver
  return unless turkserver

  Session.set("turkserver.state", turkserver.state)

# Reactive variables for state
TurkServer.inLobby = ->
  Session.equals("turkserver.state", "lobby")

# Paths for lobby
Package['iron-router']?.Router.map ->
  @route "lobby",
    template: "tsLobby",
    layoutTemplate: "tsContainer"
