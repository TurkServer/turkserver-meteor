@Assigners = {}

# Default top level class
class TurkServer.Assigner
  initialize: (batch) ->
    @batch = batch
    @lobby = batch.lobby

    @lobby.events.on "user-join", @userJoined
    @lobby.events.on "user-status", @userStatusChanged
    @lobby.events.on "user-leave", @userLeft

  assignToNewInstance: (userIds, treatments) ->
    @lobby.pluckUsers(userIds)

    instance = @batch.createInstance(treatments)
    instance.setup()
    instance.addUser(userId) for userId in userIds

  userJoined: ->
  userStatusChanged: ->
  userLeft: ->

# Puts everyone who joins into a single group.
class Assigners.TestAssigner extends TurkServer.Assigner

###
   Allows people to opt in after reaching a certain threshold.
###
class Assigners.ThresholdAssigner extends TurkServer.Assigner
  constructor: (@groupSize) ->

  userStatusChanged: =>
    readyUsers = @lobby.getUsers({status: true})
    return if readyUsers.length < @groupSize

    userIds = _.pluck(readyUsers, "_id")

    # Default behavior is to pick a random treatment
    # We could improve this in the future
    treatment = _.sample @batch.getTreatments()

    @assignToNewInstance(userIds, [treatment])

###
  Assigns users to groups in a randomized, round-robin fashion
  as soon as the join the lobby
###
class Assigners.RoundRobinAssigner extends TurkServer.Assigner
  constructor: (@instanceIds) ->
    # TODO: @instanceIds can be fetched from @batch

    @instances = []
    # Create instances if they don't exist
    for instanceId in @instanceIds
      try
        instance = TurkServer.Instance.getInstance(instanceId)
      catch
        # TODO pick treatments when creating instances
        # treatment = _.sample batch.treatments
        instance = @batch.createInstance()

      @instances.push instance

  userJoined: (asst) =>
    # By default, assign this to the instance with the least number of users
    minUserInstance = _.min @instances, (instance) -> instance.users().length

    @lobby.pluckUsers [asst.userId]
    minUserInstance.addUser(asst.userId)

###
  Assign users to fixed size experiments sequentially, as they arrive
###
class Assigners.SequentialAssigner extends TurkServer.Assigner
  constructor: (@groupSize, @instance) ->

  # Assignment for no lobby fixed group size
  userJoined: (asst) =>
    if @instance.users().length >= @groupSize
      # Create a new instance, replacing the one we are holding
      treatment = _.sample @batch.getTreatments()
      @instance = @batch.createInstance [treatment]
      @instance.setup()

    @lobby.pluckUsers [asst.userId]
    @instance.addUser(asst.userId)



