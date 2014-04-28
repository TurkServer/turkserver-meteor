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

# Find current round, whether running or in break
# TODO this polls every second, which can be quite inefficient
currentRound = ->
  if (activeRound = RoundTimers.findOne(active: true))?
    # Is the active round started?
    if activeRound.startTime <= TimeSync.serverTime()
      return activeRound
    else
      # Return the round before this one, if any
      return RoundTimers.findOne(index: activeRound.index - 1)
  return

TurkServer.currentRound = UI.emboxValue(currentRound, EJSON.equals)

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
