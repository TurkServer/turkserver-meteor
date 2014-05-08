init_queue = []

# TODO the collection called "Experiments" actually now refers to instances

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

TurkServer.finishExperiment = ->
  TurkServer.Instance.currentInstance()?.teardown()

# Represents a group or slice on the server, containing some users
class TurkServer.Instance
  # map of groupId to instance objects
  _instances = {}

  @getInstance: (groupId) ->
    if (instance = _instances[groupId])?
      return instance
    else
      throw new Error("Instance does not exist: " + groupId) unless Experiments.findOne(groupId)?
      return _instances[groupId] = new TurkServer.Instance(groupId)

  @currentInstance: ->
    @getInstance Partitioner.group()

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
    return TurkServer.getBatch(instance.batchId) if instance?

  treatments: ->
    instance = Experiments.findOne(@groupId)
    return Treatments.find({name: $in: instance.treatments}).fetch() if instance?

  # Close this instance and return people to the lobby
  teardown: ->
    users = Experiments.findOne(@groupId).users

    Experiments.update @groupId,
      $set:
        endTime: Date.now()

    batch = @batch()
    _.each users, (userId) ->
      Partitioner.clearUserGroup(userId)
      batch.lobby.addUser(userId)

    Meteor.flush()

