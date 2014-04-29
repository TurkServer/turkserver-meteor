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

TurkServer.authenticateWorker = (loginRequest) ->
  # Has this worker already completed the HIT?
  if Assignments.findOne({
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    status: "completed"
  })
    # makes the client auto-submit with this error
    throw new Meteor.Error(403, ErrMsg.alreadyCompleted)

  # Is this already assigned to someone?
  existing = Assignments.findOne
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    status: "assigned"

  if existing
    # Was a different account in progress?
    if loginRequest.workerId is existing.workerId
      # Worker has already logged in to this HIT, no need to create record below
      return
    else
      # HIT has been taken by someone else. Record a new assignment for this worker.
      Assignments.update existing._id,
        $set: { status: "returned" }

  # Check for limits before creating a new assignment
  if Assignments.find({
    workerId: loginRequest.workerId,
    status: { $ne: "completed" }
  }).count() >=
  TurkServer.config.experiment.limit.simultaneous
    throw new Meteor.Error(403, ErrMsg.simultaneousLimit)

  # TODO check for the hitId in the current batch, in case the HIT is out of date
  activeBatch = Batches.findOne(active: true)

  predicate =
    workerId: loginRequest.workerId

  # TODO: allow for excluding other batches
  predicate.batchId = activeBatch._id if activeBatch

  if Assignments.find(predicate).count() >=
  TurkServer.config.experiment.limit.batch
    throw new Meteor.Error(403, ErrMsg.batchLimit)

  # Either no one has this assignment before or this worker replaced someone;
  # Create a new record for this worker on this assignment
  save =
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    acceptTime: Date.now()
    status: "assigned"

  save.batchId = activeBatch._id if activeBatch

  Assignments.insert(save)
  return

Accounts.registerLoginHandler (loginRequest) ->
  # Don't handle unless we have an mturk login
  return unless loginRequest.hitId and loginRequest.assignmentId and loginRequest.workerId

  # TODO: Do we need Partitioner.directOperation here?
  # Probably only if user is already logged in, which would be an error.
  user = Meteor.users.findOne
    workerId: loginRequest.workerId

  unless user
    userId = Meteor.users.insert
      workerId: loginRequest.workerId
  else
    userId = user._id;

  # should we let this worker in or not?
  TurkServer.authenticateWorker(loginRequest)

  TurkServer.handleConnection
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    userId: userId

  # TODO: set the login token ourselves so that the expiration interval is shorter.

  return {
    userId: userId,
  }
