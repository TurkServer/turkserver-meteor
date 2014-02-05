
# Publish the user's current treatment, if any
# TODO this observe is a bit inefficient
Meteor.publish null, ->
  return unless @userId
  sub = this
  subHandle = Experiments.find({
    users: { $in: [ @userId ] }
    treatment: { $exists: true }
  }, {
    fields: {treatment: 1}
  }).observeChanges
    added: (id, fields) ->
      sub.added "ts.config", "treatment", { value: Treatments.findOne(fields.treatment).name }
    changed: (id, fields) ->
      sub.changed "ts.config", "treatment", { value: Treatments.findOne(fields.treatment).name }
    removed: (id) ->
      sub.removed "ts.config", "treatment"
  sub.ready()
  sub.onStop -> subHandle.stop()

# Publish treatment for admin
# TODO this won't update properly if experiment treatment changes
Meteor.publish null, ->
  return unless Meteor.users.findOne(@userId)?.admin
  sub = this
  subHandle = Grouping.find(@userId).observeChanges
    added: (id, fields) ->
      treatmentId = Experiments.findOne(fields.groupId).treatment
      sub.added "ts.config", "treatment", { value: Treatments.findOne(treatmentId).name }
    changed: (id, fields) ->
      treatmentId = Experiments.findOne(fields.groupId).treatment
      sub.changed "ts.config", "treatment", { value: Treatments.findOne(treatmentId).name }
    removed: (id) ->
      sub.removed "ts.config", "treatment"
  sub.ready()
  sub.onStop -> subHandle.stop()

init_queue = []

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

TurkServer.treatment = -> TurkServer.Experiment.getTreatment TurkServer.group()

TurkServer.finishExperiment = ->
  group = TurkServer.group()
  return unless group
  TurkServer.Experiment.complete(group)

# TODO make this into a class like Meteor.collection ?
class TurkServer.Experiment
  @create: (treatmentId, fields) ->
    fields = _.extend fields || {},
      startTime: Date.now()
      treatment: treatmentId
    return Experiments.insert(fields)

  @getTreatment: (groupId) ->
    exp = Experiments.findOne(groupId)
    return Treatments.findOne(exp.treatment).name

  @setup: (groupId) ->
    context =
      group: groupId
      treatment: @getTreatment(groupId)

    TurkServer.bindGroup groupId, ->
      _.each init_queue, (handler) -> handler.call(context)

  # Add user to experiment
  @addUser: (groupId, userId) ->
    TurkServer.Groups.setUserGroup(userId, groupId)

    Experiments.update { _id: groupId },
      { $addToSet: { users: userId } }
    Meteor.users.update userId,
      $set: { "turkserver.state": "experiment" }

  # Take all users out of group and send to exit survey
  @complete: (groupId) ->
    users = Experiments.findOne(groupId).users

    Experiments.update groupId,
      $set:
        endTime: Date.now()

    _.each users, (userId) ->
      TurkServer.Groups.clearUserGroup(userId)
      Meteor.users.update userId,
        $set: { "turkserver.state": "exitsurvey" }

    Meteor.flush()





