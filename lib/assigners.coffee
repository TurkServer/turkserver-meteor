TurkServer.Assigners = {}

# Default top level class
class TurkServer.Assigner
  initialize: (batch) ->
    @batch = batch
    @lobby = batch.lobby

    # Pre-bind callbacks below to avoid ugly fat arrows
    @lobby.events.on "user-join", @userJoined.bind(@)
    @lobby.events.on "user-status", @userStatusChanged.bind(@)
    @lobby.events.on "user-leave", @userLeft.bind(@)
    return

  assignToNewInstance: (userIds, treatments) ->
    @lobby.pluckUsers(userIds)

    instance = @batch.createInstance(treatments)
    instance.setup()
    instance.addUser(userId) for userId in userIds

  userJoined: ->
  userStatusChanged: ->
  userLeft: ->

###
  Very dumb assigner: puts everyone who joins into a single group.
  Once the instance ends, puts users in exit survey.
###
class TurkServer.Assigners.TestAssigner extends TurkServer.Assigner
  initialize: ->
    super
    # Take any experiment from this batch, creating it if it doesn't exist
    if (instanceId = Experiments.findOne(batchId: @batch.batchId))?
      @instance = TurkServer.Instance.getInstance(instanceId)
    else
      @instance = @batch.createInstance(@batch.getTreatments())
      @instance.setup()

  userJoined: (asst) ->
    if asst.getInstances().length > 0
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else
      try
        @instance.addUser( asst.userId )
      @lobby.pluckUsers( [asst.userId] )

###
  Assigns everyone who joins in a separate group.
  Anyone who is done with their instance goes into the exit survey
###
class TurkServer.Assigners.SimpleAssigner extends TurkServer.Assigner
  constructor: ->

  userJoined: (asst) ->
    if asst.getInstances().length > 0
      # Send user to exit survey
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else
      # Assign user to instance
      treatment = _.sample @batch.getTreatments()
      @assignToNewInstance( [asst.userId], [treatment] )

###
  Assigns users first to a tutorial treatment,
  then to a single group.
  An event on the lobby is used to trigger the group.
###
class TurkServer.Assigners.TutorialGroupAssigner extends TurkServer.Assigner
  constructor: (@tutorialTreatments, @groupTreatments) ->
    @autoAssign = false

  initialize: ->
    super
    @lobby.events.on "auto-assign", =>
      @autoAssign = true
      @assignAllUsers()

  # put all users who have done the tutorial in the group
  assignAllUsers: ->

  # Assign users to the tutorial, the group, and the exit survey
  userJoined: ->

###
   Allows people to opt in after reaching a certain threshold.
###
class TurkServer.Assigners.ThresholdAssigner extends TurkServer.Assigner
  constructor: (@groupSize) ->

  userStatusChanged: ->
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
class TurkServer.Assigners.RoundRobinAssigner extends TurkServer.Assigner
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

  userJoined: (asst) ->
    # By default, assign this to the instance with the least number of users
    minUserInstance = _.min @instances, (instance) -> instance.users().length

    @lobby.pluckUsers [asst.userId]
    minUserInstance.addUser(asst.userId)

###
  Assign users to fixed size experiments sequentially, as they arrive
###
class TurkServer.Assigners.SequentialAssigner extends TurkServer.Assigner
  constructor: (@groupSize, @instance) ->

  # Assignment for no lobby fixed group size
  userJoined: (asst) ->
    if @instance.users().length >= @groupSize
      # Create a new instance, replacing the one we are holding
      treatment = _.sample @batch.getTreatments()
      @instance = @batch.createInstance [treatment]
      @instance.setup()

    @lobby.pluckUsers [asst.userId]
    @instance.addUser(asst.userId)



