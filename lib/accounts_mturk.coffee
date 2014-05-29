###
  Add a hook to Meteor's login system:
  To account for for MTurk use, except for admin users
  for users who are not currently assigned to a HIT.
###
Accounts.validateLoginAttempt (info) ->
  if info.methodArguments[0].resume? and not info.user?.admin
    # Is the worker currently assigned to a HIT?
    unless info.user?.workerId and Assignments.findOne(
      workerId: info.user.workerId
      status: "assigned"
    )
      throw new Meteor.Error(403, "Your HIT session has expired.")
  return true

###
  After a successful login, save the worker's IP address and
  trigger initial assignment
###
Accounts.onLogin (info) ->
  # User object should always exist here, since account was already created
  return if info.user.admin

  # However, user data (workerId) may not be up to date, so use our own
  # method to grab the assignment for this user
  # This is especially pertinent in testing
  # TODO verify this is valid as we reject multiple connections on login
  asst = TurkServer.Assignment.getCurrentUserAssignment(info.user._id)

  unless asst?
    Meteor._debug "Nonexistent assignment for user " + info.user._id
    return

  asst.setData { ipAddr: info.connection.clientAddress }

  # console.log "saved IP address for connection ", info.connection.clientAddress
  return

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
    throw new Meteor.Error(403, "Unexpected batchId") unless batchId is hitType.batchId

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
    if workerId is existing.workerId
      # Worker has already logged in to this HIT, no need to create record below
      return TurkServer.Assignment.getAssignment(existing._id)
    else
      # HIT has been taken by someone else. Record a new assignment for this worker.
      Assignments.update existing._id,
        $set: { status: "returned" }

  ###
    Not a reconnection; creating a new assignment
  ###
  # Only active batches accept new HITs
  if batchId? and not Batches.findOne(batchId)?.active
    throw new Meteor.Error(403, "Batch is no longer active")

  # Check for limits
  if Assignments.find({
    workerId: workerId,
    status: { $ne: "completed" }
  }).count() >= TurkServer.config.experiment.limit.simultaneous
    throw new Meteor.Error(403, ErrMsg.simultaneousLimit)

  predicate =
    workerId: loginRequest.workerId
    batchId: batchId

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

Accounts.registerLoginHandler (loginRequest) ->
  # Don't handle unless we have an mturk login
  return unless loginRequest.hitId and loginRequest.assignmentId and loginRequest.workerId

  # Probably only if user is already logged in, which would be an error.
  user = Meteor.users.findOne
    workerId: loginRequest.workerId

  unless user
    # Use the provided method of creating users
    userId = Accounts.insertUserDoc {},
      workerId: loginRequest.workerId
  else
    userId = user._id;

  # should we let this worker in or not?
  asst = authenticateWorker(loginRequest)

  # This does the work of triggering what happens next.
  Meteor.defer -> asst._loggedIn()

  # TODO: set the login token ourselves so that the expiration interval is shorter.

  return {
    userId: userId,
  }

# Test exports
TestUtils.authenticateWorker = authenticateWorker
