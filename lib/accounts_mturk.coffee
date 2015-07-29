###
  Add a hook to Meteor's login system:
  To account for for MTurk use, except for admin users
  for users who are not currently assigned to a HIT.
###
Accounts.validateLoginAttempt (info) ->
  return true if info.user?.admin # Always allow admin to login

  # If resuming, is the worker currently assigned to a HIT?
  # TODO add a test for this
  if info.methodArguments[0].resume?
    unless info.user?.workerId and Assignments.findOne(
      workerId: info.user.workerId
      status: "assigned"
    )
      throw new Meteor.Error(403, "Your HIT session has expired.")

  # TODO Does the worker have this open in another window? If so, reject the login.
  # This is a bit fail-prone due to leaking sessions across HCR, so take it out.
#  if info.user? and UserStatus.connections.findOne(userId: info.user._id)
#    throw new Meteor.Error(403, "You already have this open in another window. Complete it there.")

  return true

###
  Authenticate a worker taking an assignment.
  Returns an assignment object corresponding to the assignment.
###
authenticateWorker = (loginRequest) ->
  { batchId, hitId, assignmentId, workerId } = loginRequest

  # check if batchId is correct except for testing logins
  unless loginRequest.test
    hit = HITs.findOne
      HITId: hitId
    hitType = HITTypes.findOne
      HITTypeId: hit.HITTypeId
    throw new Meteor.Error(403, ErrMsg.unexpectedBatch) unless batchId is hitType.batchId

  # Has this worker already completed the HIT?
  if Assignments.findOne({
    hitId
    assignmentId
    workerId
    status: "completed"
  })
    # makes the client auto-submit with this error
    throw new Meteor.Error(403, ErrMsg.alreadyCompleted)

  # Is this already assigned to someone?
  existing = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    status: "assigned"

  if existing
    # Was a different account in progress?
    existingAsst = TurkServer.Assignment.getAssignment(existing._id)
    if workerId is existing.workerId
      # Worker has already logged in to this HIT, no need to create record below
      return existingAsst
    else
      # HIT has been taken by someone else. Record a new assignment for this worker.
      existingAsst.setReturned()

  ###
    Not a reconnection; we may create a new assignment
  ###
  batch = Batches.findOne(batchId)

  # Only active batches accept new HITs
  if batchId? and not batch?.active
    throw new Meteor.Error(403, ErrMsg.batchInactive)

  # Limits - simultaneously accepted HITs
  if Assignments.find({
    workerId: workerId,
    status: { $nin: [ "completed", "returned" ] }
  }).count() >= TurkServer.config.experiment.limit.simultaneous
    throw new Meteor.Error(403, ErrMsg.simultaneousLimit)

  # Limits for the given batch
  predicate =
    workerId: loginRequest.workerId
    batchId: batchId

  predicate.status = { $ne: "returned" } if batch.allowReturns

  if Assignments.find(predicate).count() >= TurkServer.config.experiment.limit.batch
    throw new Meteor.Error(403, ErrMsg.batchLimit)

  # Either no one has this assignment before or this worker replaced someone;
  # Create a new record for this worker on this assignment
  return TurkServer.Assignment.createAssignment
    batchId: batchId
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    acceptTime: new Date()
    status: "assigned"

Accounts.registerLoginHandler "mturk", (loginRequest) ->
  # Don't handle unless we have an mturk login
  return unless loginRequest.hitId and loginRequest.assignmentId and loginRequest.workerId

  # At some point this became processed as part of a method call
  # (DDP._CurrentInvocation.get() is defined), so we need the direct or this
  # would fail with a partitioner error.
  user = Meteor.users.direct.findOne
    workerId: loginRequest.workerId

  unless user
    # Use the provided method of creating users
    userId = Accounts.insertUserDoc {},
      workerId: loginRequest.workerId
  else
    userId = user._id;

  # should we let this worker in or not?
  asst = authenticateWorker(loginRequest)

  # This currently does nothing except print out some messages.
  Meteor.defer -> asst._loggedIn()

  # Because the login token `when` field is set by initialization date, not
  # expiration date, we can't artificially make this login expire sooner here.
  # So we'll need to aggressively prune logins when a HIT is submitted, instead.

  return {
    userId: userId,
  }

# Test exports
TestUtils.authenticateWorker = authenticateWorker
