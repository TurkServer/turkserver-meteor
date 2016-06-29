# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Mongo.Collection("ts.config")

TurkServer.batch = ->
  if (batchId = Session.get('_loginParams')?.batchId)?
    return Batches.findOne(batchId)
  else
    return Batches.findOne()

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

TurkServer.disableIdleMonitor = () ->
  if idleComp?
    # If monitor is already started, stop it before trying new settings
    idleComp.stop()
    UserStatus.stopMonitor() if Deps.nonreactive -> UserStatus.isMonitoring()

TurkServer.enableIdleMonitor = (threshold, idleOnBlur) ->
  TurkServer.disableIdleMonitor()

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

# Reactive join on treatments for assignments and experiments
Deps.autorun ->
  exp = Experiments.findOne({}, {fields: {treatments: 1}})
  return unless exp && exp.treatments?
  Meteor.subscribe("tsTreatments", exp.treatments)

Deps.autorun ->
  asst = Assignments.findOne({}, {fields: {treatments: 1}})
  return unless asst && asst.treatments?
  Meteor.subscribe("tsTreatments", asst.treatments)

