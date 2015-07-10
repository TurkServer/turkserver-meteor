# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Mongo.Collection("ts.config")

TurkServer.batch = ->
  if (batchId = Session.get('_loginParams')?.batchId)?
    return Batches.findOne(batchId)
  else
    return Batches.findOne()

# Merge all treatments into one document
TurkServer.treatment = -> TurkServer._mergeTreatments Treatments.find({})

# Find current round, whether running or in break
# TODO this polls every second, which can be quite inefficient. Update this if
# we are going to stick with the current round system.
TurkServer.currentRound = ->
  if (activeRound = RoundTimers.findOne(active: true))?
    # Is the active round started?
    if activeRound.startTime <= TimeSync.serverTime()
      return activeRound
    else
      # Return the round before this one, if any
      return RoundTimers.findOne(index: activeRound.index - 1)
  return

# Called to start the monitor with given settings when in experiment
# Similar to usage in user-status demo
safeStartMonitor = (threshold, idleOnBlur) ->
  Deps.autorun (c) ->
    try
      settings = {threshold, idleOnBlur}
      UserStatus.startMonitor(settings)
      c.stop()
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


