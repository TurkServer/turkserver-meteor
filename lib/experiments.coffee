init_queue = []

# TODO the collection called "Experiments" actually now refers to instances

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

TurkServer.finishExperiment = ->
  TurkServer.Experiment.currentInstance()?.teardown()

# Represents a group or slice on the server, containing some users
class TurkServer.Instance
  constructor: (@groupId) ->

  # Run the initialize handlers for this instance
  setup: ->
    context =
      group: @groupId
      treatment: @treatments()

    Partitioner.bindGroup @groupId, ->
      (handler.call(context) for handler in init_queue)
      return

  addUser: (userId) ->
    # Add a user to this instance
    Partitioner.setUserGroup(userId, @groupId)

    Experiments.update @groupId,
      { $addToSet: { users: userId } }
    Meteor.users.update userId,
      $set: { "turkserver.state": "experiment" }

    # Record experimentId in Assignment collection
    workerId = Meteor.users.findOne(userId).workerId
    Assignments.update { workerId: workerId, status: "assigned" },
      $push: { instances: @groupId }

  users: -> Experiments.findOne(@groupId).users

  batch: ->
    instance = Experiments.findOne(@groupId)
    return Batches.findOne(instance.batchId) if instance?

  treatments: ->
    instance = Experiments.findOne(@groupId)
    return Treatments.find({name: $in: instance.treatments}).fetch() if instance?

  # Close this instance and return people to the lobby
  teardown: ->
    users = Experiments.findOne(@groupId).users

    Experiments.update @groupId,
      $set:
        endTime: Date.now()

    _.each users, (userId) ->
      Partitioner.clearUserGroup(userId)
      Meteor.users.update userId,
        $set: { "turkserver.state": "lobby" }

    Meteor.flush()

# Global class controlling instances across experiments
class TurkServer.Experiment
  # map of groupId to instance objects
  @instances = {}

  @createInstance: (batch, treatmentNames, fields) ->
    fields = _.extend fields || {},
      startTime: Date.now()
      batchId: batch._id
      treatments: treatmentNames

    groupId = Experiments.insert(fields)
    return new TurkServer.Instance(groupId)

  @getInstance: (groupId) ->
    if (instance = @instances[groupId])?
      return instance
    else
      throw new Error("Instance does not exist") unless Experiments.findOne(groupId)?
      return @instances[groupId] = new TurkServer.Instance(groupId)

  @currentInstance: ->
    @getInstance Partitioner.group()
