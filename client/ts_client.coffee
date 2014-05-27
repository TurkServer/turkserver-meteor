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

TurkServer.batch = ->
  batchId = Session.get('_loginParams')?.batchId
  Batches.findOne(batchId) if batchId?

# Merge all treatments into one document
TurkServer.treatment = ->
  fields =
    treatments: []
  Treatments.find({}).forEach (treatment) ->
    fields.treatments.push treatment.name
    _.extend(fields, _.omit(treatment, "_id", "name"))
  return fields

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

safeStartMonitor = (threshold, idleOnBlur) ->
  Deps.autorun ->
    # Don't try to start the monitor in case the state changed
    @stop() unless TurkServer.inExperiment()
    try
      settings = {threshold, idleOnBlur}
      UserStatus.startMonitor(settings)
      @stop()
      console.log "Idle monitor started with ", settings

idleComp = null

TurkServer.enableIdleMonitor = (threshold, idleOnBlur) ->
  if idleComp?
    # If monitor is already started, stop it before trying new settings
    idleComp.stop()
    UserStatus.stopMonitor() if Deps.nonreactive -> UserStatus.isMonitoring()

  idleComp = Deps.autorun ->
    if TurkServer.inExperiment()
      safeStartMonitor(threshold, idleOnBlur)
    else
      UserStatus.stopMonitor() if Deps.nonreactive -> UserStatus.isMonitoring()

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

