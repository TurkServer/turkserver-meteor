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
    if (exp = Experiments.findOne(batchId: @batch.batchId))?
      @instance = TurkServer.Instance.getInstance(exp._id)
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
      treatment = _.sample @batch.getTreatments() || []
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
      @assignToNewInstance([asst], @tutorialTreatments)
    else if instances.length is 2
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else if @autoAssign
      # Put me in, coach!
      @lobby.pluckUsers( [asst.userId] )
      @instance.addAssignment(asst)
    # Otherwise, wait for assignment event

ensureGroupTreatments = (sizeArray) ->
  for size in _.uniq(sizeArray)
    TurkServer.ensureTreatmentExists({name: "group_#{size}", groupSize: size})
  return

###
  Assigner that puts people into a tutorial and then random groups, with

  - Pre-allocation of groups for costly operations before users arrive
  - A waiting room that can hold the first arriving users
  - Completely random assignment into different groups
  - Restarting and resuming assignment from where it left off
  - A final "buffer" group to accommodate stragglers after randomization is done

  This was created for executing the crisis mapping experiment.
###
class TurkServer.Assigners.TutorialRandomizedGroupAssigner extends TurkServer.Assigner

  @generateConfig: (sizeArray, otherTreatments) ->
    ensureGroupTreatments(sizeArray)

    config = ({
      size: size,
      treatments: ["group_#{size}"].concat(otherTreatments)
    } for size in sizeArray)

    # Create a buffer group for everyone else
    config.push({
      treatments: otherTreatments
    })

    return config

  constructor: (@tutorialTreatments, @groupTreatments, @groupArray) ->

  initialize: ->
    super

    @configure()

    @lobby.events.on "setup-instances", @setup
    @lobby.events.on "configure", @configure
    @lobby.events.on "auto-assign", @assignAll

  # If pre-allocated instances don't exist, create and initialize them
  setup: (lookBackHours = 6) =>
    console.log "Creating new set of instances for randomized groups"

    existing = Experiments.find({
      batchId: @batch.batchId
      treatments: $nin: @tutorialTreatments
      $or: [
        { startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) } },
        { startTime: null }
      ]
    }).fetch()

    # Reuse buffer instance if it already exists
    if existing.length > 0 and _.any(existing, (exp) -> exp.startTime? )
      console.log "Not creating new instances as recently started ones already exist"
      return

    @groupConfig = TutorialRandomizedGroupAssigner.generateConfig(@groupArray, @groupTreatments)

    if existing.length is @groupConfig.length
      console.log "Not creating new instances as we already have the expected number"
      return

    # Some existing instances exist. Count how many are available to reuse
    reusable = {}
    for exp in existing
      if exp.treatments[0].indexOf("group_") >= 0
        key = parseInt(exp.treatments[0].substring(6))
      else
        key = "buffer"
      console.log "Will reuse one existing instance with #{exp.treatments}"

      if exp.endTime?
        Experiments.update exp._id,
          $unset: endTime: null
        console.log "Reset an unused terminated instance: #{exp._id}"

      reusable[key] ?= 0
      reusable[key]++

    # create and setup instances
    for config in @groupConfig
      # Skip creating reusable instances
      key = config.size || "buffer"
      if reusable[key]? and reusable[key] += 0
        console.log "Skipping creating one group of #{key}"
        reusable[key]--
        continue

      instance = @batch.createInstance(config.treatments)
      instance.setup()

    # Configure randomization with these groups
    @configure(undefined, lookBackHours)

  # TODO remove the restriction that groupArray has to be passed in sorted
  configure: (groupArray, lookBackHours = 6) =>
    if groupArray?
      @groupArray = groupArray
      console.log "Configuring randomized group assigner with", @groupArray
    else
      console.log "Initialization of randomized group assigner with", @groupArray

    @groupConfig = TutorialRandomizedGroupAssigner.generateConfig(@groupArray, @groupTreatments)

    # Check if existing created instances exist
    existing = Experiments.find({
      batchId: @batch.batchId
      treatments: $nin: @tutorialTreatments
      $or: [
        { startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) } },
        { startTime: null }
      ]
    }, {
      transform: (exp) ->
        exp.treatmentData = TurkServer.Instance.getInstance(exp._id).treatment()
        return exp
    }).fetch()

    if existing.length < @groupConfig.length
      console.log "Not setting up randomization: #{existing.length} existing groups"
      return

    # Sort existing experiments by smallest groups first for matching purposes.
    # The buffer group goes to the end.
    existing.sort (a, b) ->
      if not a.treatmentData.groupSize? # b comes first
        return 1
      else if not b.treatmentData.groupSize? # a comes first
        return -1
      else
        return a.treatmentData.groupSize - b.treatmentData.groupSize

    availableSlots = []


    # Compute remaining slots on existing groups
    existing.forEach (exp) =>
      filled = exp.users?.length || 0

      unless exp.treatmentData.groupSize?
        console.log "#{exp._id} (buffer) has #{filled} users"
        @bufferInstanceId = exp._id
        return

      target = exp.treatmentData.groupSize
      remaining = Math.max(0, target - filled) # In case some bug overfilled it

      console.log "#{exp._id} has #{remaining} slots left (#{filled}/#{target})"
      availableSlots.push(exp._id) for x in [0...remaining]

      @autoAssign = true if filled > 0

    if @autoAssign
      console.log "Enabled auto-assign as instances currently have users"

    # Shuffle the available slots
    @instanceSlots = _.shuffle(availableSlots)
    @instanceSlotIndex = 0

    console.log "#{@instanceSlots.length} randomization slots remaining"

  userJoined: (asst) ->
    instances = asst.getInstances()
    if instances.length is 0
      # This function automatically removes users from the lobby
      @assignToNewInstance([asst], @tutorialTreatments)
    else if instances.length is 2
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else if @autoAssign
      # Put me in, coach!
      @assignNext(asst)

    # Otherwise, wait for auto-assignment event
    return

  # Randomly assign all users in the lobby who have done the tutorial
  assignAll: =>
    unless @instanceSlots?
      console.log "Can't auto-assign as we haven't been set up yet"
      return

    currentAssignments = @lobby.getAssignments()

    # Auto assign future users that join after this point
    # We can't put this before getting current assignments,
    # or some people might get double assigned, with
    # "already in a group" errors.
    # TODO this should be theoretically right after grabbing LobbyStatus but
    # before populating assignments.
    @autoAssign = true

    assts = _.filter currentAssignments, (asst) ->
      asst.getInstances().length is 1

    @assignNext(asst) for asst in assts
    return

  assignNext: (asst) ->
    if @instanceSlotIndex >= @instanceSlots.length
      bufferInstance = TurkServer.Instance.getInstance(@bufferInstanceId)

      if bufferInstance.isEnded()
        console.log "Not assigning #{asst.asstId} as buffer has ended"
        return

      @lobby.pluckUsers( [asst.userId] )
      bufferInstance.addAssignment(asst)
      return

    nextInstId = @instanceSlots[@instanceSlotIndex]
    @instanceSlotIndex++

    instance = TurkServer.Instance.getInstance(nextInstId)

    if instance.isEnded()
      console.log "Skipping assignment to slot for ended instance #{instance.groupId}"
      # Recursively try to assign to the next slot
      @assignNext(asst)
      return

    @lobby.pluckUsers( [asst.userId] )
    instance.addAssignment(asst)
    return

###
  Assign people to a tutorial treatment and then sequentially to different sized
  groups. Used for the crisis mapping experiment.

  groupArray = e.g. [ 16, 16 ]
  groupConfig = [ { size: x, treatments: [ stuff ] }, ... ]

  After the last group is filled, there is no more assignment.
###
class TurkServer.Assigners.TutorialMultiGroupAssigner extends TurkServer.Assigner

  # bespoke algorithm for generating config.
  # TODO unit test this
  @generateConfig: (sizeArray, otherTreatments) ->
    ensureGroupTreatments(sizeArray)

    config = ({
      size: size,
      treatments: ["group_#{size}"].concat(otherTreatments)
    } for size in sizeArray)

    return config

  constructor: (@tutorialTreatments, @groupTreatments, @groupArray) ->

  initialize: ->
    super

    @configure()

    # Provide a quick way to re-set the assignment for multi-groups
    @lobby.events.on "reset-multi-groups", =>
      console.log "Resetting multi-group assigner with ", @groupArray
      @stopped = false
      @currentInstance = null
      @currentGroup = -1
      @currentFilled = 0

    @lobby.events.on "reconfigure-multi-groups", @configure

  configure: (groupArray, lookBackHours = 6) =>

    if groupArray
      @groupArray = groupArray
      @stopped = false
      console.log "Reconfiguring multi-group assigner with", @groupArray
    else
      console.log "Initial setup of multi-group assigner with", @groupArray

    @groupConfig = TutorialMultiGroupAssigner.generateConfig(@groupArray, @groupTreatments)
    # If we resurrected in the middle of a server restart, pick up where we
    # left off.

    # TODO it's a bit of a hack to look for the last 6 hours, but it seems to
    # be the only way to find a threshold where new experiments (1 day later)
    # won't pick up from previous ones and yet we give experiments in progress
    # enough time to finish if there are any problems.
    # TODO we need to make this support running multiple batches in a day.
    @currentInstance = null
    @currentGroup = -1 # i.e. before the start of the array
    @currentFilled = 0

    existing = Experiments.find({
      batchId: @batch.batchId
      treatments: $nin: @tutorialTreatments
      startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) }
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
      else if count > target or
      i isnt existing.length - 1 or
      !_.isEqual(exp.treatments, @groupConfig[i].treatments)
        # Group sizes either don't match or this isn't the last one
        console.log("Unable to match with existing groups, starting over")
        @currentInstance = null
        @currentGroup = -1 # i.e. before the start of the array
        @currentFilled = 0
        break
      else
        @currentGroup = i
        @currentFilled = count
        @currentInstance = TurkServer.Instance.getInstance(exp._id)
        console.log "Initializing multi-group assigner to group #{@currentGroup} (#{@currentFilled}/#{target})"
        break # We set the counter to the last assigned group.

    # TODO after reconfiguring, we may want to re-assign any users in the lobby.

  currentGroupFilled: ->
    @currentFilled is @groupConfig[@currentGroup].size

  userJoined: (asst) ->
    # TODO if users join way after we assigned, it is probably time to start a new set. For now we accomplish that by restarting the server or hitting the reset above.
    instances = asst.getInstances()
    if instances.length is 0
      @assignToNewInstance([asst], @tutorialTreatments)
    else if instances.length is 2
      @lobby.pluckUsers( [asst.userId] )
      asst.showExitSurvey()
    else
      @assignNext( asst )

  assignNext: (asst) ->
    return if @stopped # Don't assign if experiments are done

    # Check if the last group has already been stopped.
    if @currentGroup is @groupConfig.length - 1 and @currentInstance?.isEnded()
      @stopped = true
      console.log "Final group has finished, stopping automatic multi-group assignment"
      return

    if @currentGroup is @groupConfig.length - 1 and @currentGroupFilled()
      @stopped = true
      console.log "Final group has filled, stopping automatic multi-group assignment"
      return

    # It's imperative we do not do any yielding operations while updating counters
    if not @currentInstance? or @currentGroupFilled()
      # Move on and create new group
      newGroup = @currentGroup + 1

      treatments = @groupConfig[newGroup].treatments
      @currentInstance = @safeCreateInstance(treatments)

      # Update group counters only once, if we are the first fiber to arrive here
      if @currentGroup is newGroup
        # New group already created. Try again on the next tick
        Meteor.defer => @assignNext(asst)
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
  #
  # Yes, this is necessary! During the experiment where we basically DDoSed
  # ourselves, we saw that the getInstance function was called before
  # createInstance returned, resulting in an error when we tried to create a new
  # TurkServer.Instance at the very end of it - a rare but hard to see bug that
  # is now fixed.
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



