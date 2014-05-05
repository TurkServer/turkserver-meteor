init_queue = []

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

TurkServer.batch = -> TurkServer.Experiment.getBatch Partitioner.group()
TurkServer.treatment = -> TurkServer.Experiment.getTreatment Partitioner.group()

TurkServer.finishExperiment = ->
  group = Partitioner.group()
  return unless group
  TurkServer.Experiment.complete(group)

# TODO make this into a class like Meteor.collection ?
class TurkServer.Experiment
  @create: (batch, treatment, fields) ->
    fields = _.extend fields || {},
      startTime: Date.now()
      batchId: batch._id
      treatment: treatment.name
      treatmentId: treatment._id
    return Experiments.insert(fields)

  # TODO: what is this being used for?
  @getBatch: (groupId) ->
    experiment = Experiments.findOne(groupId)
    return Batches.findOne(experiment.batchId) if experiment?

  @getTreatment: (groupId) ->
    treatmentName = Experiments.findOne(groupId)?.treatment
    return Treatments.findOne(name: treatmentName)

  @setup: (groupId) ->
    context =
      group: groupId
      treatment: @getTreatment(groupId)

    Partitioner.bindGroup groupId, ->
      (handler.call(context) for handler in init_queue)
      return

  # Add user to experiment
  @addUser: (groupId, userId) ->
    Partitioner.setUserGroup(userId, groupId)

    Experiments.update { _id: groupId },
      { $addToSet: { users: userId } }
    Meteor.users.update userId,
      $set: { "turkserver.state": "experiment" }

    # Record experimentId in Assignment collection
    workerId = Meteor.users.findOne(userId).workerId
    Assignments.update {workerId: workerId, status: "assigned"},
      $set: {experimentId: groupId}

  # Take all users out of group and send to exit survey
  @complete: (groupId) ->
    users = Experiments.findOne(groupId).users

    Experiments.update groupId,
      $set:
        endTime: Date.now()
        assignable: false

    _.each users, (userId) ->
      Partitioner.clearUserGroup(userId)
      Meteor.users.update userId,
        $set: { "turkserver.state": "exitsurvey" }

    Meteor.flush()




