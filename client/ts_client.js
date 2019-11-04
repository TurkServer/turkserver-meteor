# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Mongo.Collection("ts.config")

TurkServer.batch = ->
  if (batchId = Session.get('_loginParams')?.batchId)?
    return Batches.findOne(batchId)
  else
    return Batches.findOne()

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

