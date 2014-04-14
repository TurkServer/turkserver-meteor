# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Meteor.Collection("ts.config")

# Reactive variables for state
TurkServer.inQuiz = ->
  Session.equals("turkserver.state", "quiz")

TurkServer.inLobby = ->
  Session.equals("turkserver.state", "lobby")

TurkServer.inExperiment = ->
  Session.equals("turkserver.state", "experiment")

TurkServer.inExitSurvey = ->
  Session.equals("turkserver.state", "exitsurvey")

TurkServer.isAdmin = ->
  userId = Meteor.userId()
  return false unless userId
  return Meteor.users.findOne(
    _id: userId
    "admin": { $exists: true }
  , fields:
    "admin" : 1
  )?.admin

TurkServer.treatment = ->
  Experiments.findOne({}, fields: {treatment: 1})?.treatment

TurkServer.currentRound = ->
  RoundTimers.findOne(active: true)

###
  Reactive computations
###

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

Deps.autorun ->
  Meteor.subscribe("tsCurrentExperiment", Partitioner.group())

# TODO start idle monitor automatically with an experiment
