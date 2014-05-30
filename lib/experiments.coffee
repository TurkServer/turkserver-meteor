init_queue = []

# TODO the collection called "Experiments" actually now refers to instances

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

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
    throw new Error("Instance already exists; use getInstance") if _instances[@groupId]

  # Run the initialize handlers for this instance
  setup: ->
    context =
      group: @groupId
      treatment: @treatment()

    Partitioner.bindGroup @groupId, ->
      (handler.call(context) for handler in init_queue)
      return

  addUser: (userId) ->
    if Experiments.findOne({_id: @groupId, endTime: $exists: true})?
      throw new Error("Cannot add a user to an instance that has ended.")
      return

    # Add a user to this instance
    Partitioner.setUserGroup(userId, @groupId)

    Experiments.update @groupId,
      { $addToSet: { users: userId } }
    Meteor.users.update userId,
      $set: { "turkserver.state": "experiment" }

    # Record instance Id in Assignment
    asst = TurkServer.Assignment.getCurrentUserAssignment(userId)
    asst._joinInstance(@groupId)
    return

  users: -> Experiments.findOne(@groupId).users || []

  batch: ->
    instance = Experiments.findOne(@groupId)
    return TurkServer.Batch.getBatch(instance.batchId) if instance?

  treatment: ->
    instance = Experiments.findOne(@groupId)
    return unless instance?
    return TurkServer._mergeTreatments Treatments.find({name: $in: instance.treatments})

  # Close this instance and return people to the lobby
  teardown: ->
    Experiments.update @groupId,
      $set:
        endTime: new Date()

    return unless (users = Experiments.findOne(@groupId).users)?
    batch = @batch()

    for userId in users
      Partitioner.clearUserGroup(userId)
      asst = TurkServer.Assignment.getCurrentUserAssignment(userId)
      asst._leaveInstance(@groupId)
      batch.lobby.addUser asst

    return


