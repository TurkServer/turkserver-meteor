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

  assignToNewInstance: (assts, treatments) ->
    @lobby.pluckUsers( _.pluck(assts, "userId") )

    instance = @batch.createInstance(treatments)
    instance.setup()
    instance.addAssignment(asst) for asst in assts
    return instance

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
        @instance.addAssignment(asst)
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
      @assignToNewInstance( [asst], [treatment] )

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

    # if experiment was already created, and in progress store it
    if (exp = Experiments.findOne({
      batchId: @batch.batchId
      treatments: $all: @groupTreatments
      endTime: $exists: false
    }))?
      @instance = TurkServer.Instance.getInstance(exp._id)
      @autoAssign = true

    @lobby.events.on "auto-assign", =>
      @autoAssign = true
      @assignAllUsers()

  # put all users who have done the tutorial in the group
  assignAllUsers: ->
    unless @instance?
      @instance = @batch.createInstance(@groupTreatments)
      @instance.setup()

    assts = _.filter @lobby.getAssignments(), (asst) ->
      asst.getInstances().length is 1

    for asst in assts
      @lobby.pluckUsers( [asst.userId] )
      @instance.addAssignment(asst)
    return

  # Assign users to the tutorial, the group, and the exit survey
  userJoined: (asst) ->
    instances = asst.getInstances()
    if instances.length is 0
      @lobby.pluckUsers( [asst.userId] )
      @assignToNewInstance([asst], @tutorialTreatments)
    else if instances.length is 2
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else if @autoAssign
      # Put me in, coach!
      @lobby.pluckUsers( [asst.userId] )
      @instance.addAssignment(asst)
    # Otherwise, wait for assignment event

###
  Assign people to a tutorial treatment and then sequentially to different sized
  groups. Used for the crisis mapping experiment.

  groupConfig = [ { size: x, treatments: [ stuff ] }, ... ]
###
class TurkServer.Assigners.TutorialMultiGroupAssigner extends TurkServer.Assigner
  # bespoke algorithm for generating config.
  @generateConfig: (sizeArray, otherTreatments) ->
    for size in _.uniq(sizeArray)
      TurkServer.ensureTreatmentExists({name: "group_#{size}", groupSize: size})

    config = ({
      size: size,
      treatments: ["group_#{size}"].concat(otherTreatments)
    } for size in sizeArray)

    # Last absorbing group has no size param or treatment
    config.push({
      treatments: otherTreatments
    })

    return config

  constructor: (@tutorialTreatments, @groupConfig) ->

  initialize: ->
    super
    # If we resurrected in the middle of a server restart, pick up where we
    # left off.

    # TODO it's a bit of a hack to look for the last 12 hours, but it seems to
    # be the only way to find a threshold where new experiments (1 day later)
    # won't pick up from previous ones and yet we give experiments in progress
    # enough time to finish.
    @currentInstance = null
    @currentGroup = -1 # i.e. before the start of the array
    @currentFilled = 0

    existing = Experiments.find({
      batchId: @batch.batchId
      treatments: $nin: @tutorialTreatments
      startTime: { $gte: new Date(Date.now() - 12 * 3600 * 1000) }
    }, {
      sort: startTime: 1
    }).fetch()

    for exp, i in existing
      count = exp.users?.length || 0
      target = @groupConfig[i].size
      if count is target
        console.log "Group of size #{target} already filled in #{exp._id}"
        @currentGroup = i
        @currentFilled = count
        @currentInstance = TurkServer.Instance.getInstance(exp._id)
      else if count > target
        throw new Error("Unable to match with existing groups")
      else if i isnt existing.length - 1 # This better be the last one
        throw new Error("Unable to match with existing groups")
      else
        @currentGroup = i
        @currentFilled = count
        @currentInstance = TurkServer.Instance.getInstance(exp._id)
        break # We set the counter to the last assigned group.

    if @currentInstance?.isEnded()
      console.log "Most recent group is ended; resetting multi-group assigner "
      @currentInstance = null
      @currentGroup = -1
      @currentFilled = 0

    else if @currentGroup >= 0
      target = @groupConfig[@currentGroup].size
      console.log "Initializing multi-group assigner to group #{@currentGroup} (#{@currentFilled}/#{target})"

    # Provide a quick way to re-set the assignment for multi-groups
    @lobby.events.on "reset-multi-groups", =>
      console.log "Resetting multi-group assigner"
      @stopped = false
      @currentInstance = null
      @currentGroup = -1
      @currentFilled = 0

  userJoined: (asst) ->
    # TODO if users join way after we assigned, it is probably time to start a new set. For now we accomplish that by restarting the server or hitting the reset above.
    instances = asst.getInstances()
    if instances.length is 0
      @lobby.pluckUsers( [asst.userId] )
      @assignToNewInstance([asst], @tutorialTreatments)
    else if instances.length is 2
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else
      @assignNext( asst )

  ###
    TODO: not sure if all the race condition guards below are necessary.
    Taking them out seems to have no effect on the test.
  ###
  assignNext: (asst) ->
    # Check if the last group has already been stopped.
    if @currentGroup is @groupConfig.length - 1 and Experiments.findOne(@currentInstance.groupId)?.endTime
      @stopped = true
      console.log "Stopping automatic multi-group assignment"

    return if @stopped # Don't assign if experiments are done

    # It's imperative we do not do any yielding operations while updating counters
    if not @currentInstance? or @currentFilled is @groupConfig[@currentGroup].size
      # Move on and create new group
      newGroup = @currentGroup + 1

      treatments = @groupConfig[newGroup].treatments
      @currentInstance = @safeCreateInstance(treatments)

      # Update group counters only once, if we are the first fiber to arrive here
      if @currentGroup is newGroup
        # New group already created. Try again, recursively
        @assignNext(asst)
        return
      else
        # First to return from create instance. Put the user in this instance.
        @currentGroup = newGroup
        @currentFilled = 0

    @currentFilled++

    @lobby.pluckUsers( [asst.userId] )
    @currentInstance.addAssignment(asst)

  # Do not create multiple instances if multiple fibers arrive at a full
  # instance simultaneously
  safeCreateInstance: (treatments) ->
    if @creatingInstanceId?
      return TurkServer.Instance.getInstance(@creatingInstanceId)

    # For idempotency, pick an _id before we create the instance
    @creatingInstanceId = Random.id()
    instance = @batch.createInstance(treatments, { _id: @creatingInstanceId })
    instance.setup()
    @creatingInstanceId = null

    return instance

###
   Allows people to opt in after reaching a certain threshold.
###
class TurkServer.Assigners.ThresholdAssigner extends TurkServer.Assigner
  constructor: (@groupSize) ->

  userStatusChanged: ->
    readyAssts = @lobby.getAssignments({status: true})
    return if readyAssts.length < @groupSize

    # Default behavior is to pick a random treatment
    # We could improve this in the future
    treatment = _.sample @batch.getTreatments()

    @assignToNewInstance(readyAssts, [treatment])

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
    minUserInstance.addAssignment(asst)

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
    @instance.addAssignment(asst)



