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
  @create: (treatment, fields) ->
    fields = _.extend fields || {},
      startTime: Date.now()
      treatment: treatment
    return Experiments.insert(fields)

  @getTreatment: (groupId) -> Experiments.findOne(groupId).treatment

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

    _.each users, (userId) ->
      TurkServer.Groups.clearUserGroup(userId)
      Meteor.users.update userId,
        $set: { "turkserver.state": "exitsurvey" }

    Meteor.flush()




