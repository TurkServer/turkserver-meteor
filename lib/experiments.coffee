init_queue = []

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

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

class TurkServer.Experiment
  @setup: (groupId, treatment) ->
    context =
      group: groupId
      treatment: treatment

    TurkServer.bindGroup groupId, ->
      _.each init_queue, (handler) -> handler.call(context)



