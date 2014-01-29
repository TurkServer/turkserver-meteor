# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Meteor.Collection("ts.config")

# TODO perhaps make a better version of this reactivity
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
TurkServer.inQuiz = ->
  Session.equals("turkserver.state", "quiz")

TurkServer.inLobby = ->
  Session.equals("turkserver.state", "lobby")

TurkServer.inExperiment = ->
  Session.equals("turkserver.state", "experiment")

TurkServer.group = ->
  TSConfig.findOne("groupId")?.value

TurkServer.treatment = ->
  TSConfig.findOne("treatment")?.value


