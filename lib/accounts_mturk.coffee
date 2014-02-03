
TurkServer.authenticateWorker = (loginRequest) ->
  existing = Assignments.findOne
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId

  # Do we have a record of this assignment?
  unless existing
    # not previously existing session
    _id = Assignments.insert
      hitId: loginRequest.hitId
      assignmentId: loginRequest.assignmentId

  # Has this worker already completed this HIT?
  else if loginRequest.workerId is existing?.workerId
    # TODO make the client auto-submit if there was an error
    if TurkServer.sessionStatus(existing) is "completed"
      throw new Meteor.Error(403, ErrMsg.alreadyCompleted)

  # Was a different account in progress?
  else if loginRequest.workerId isnt existing?.workerId
    status = TurkServer.sessionStatus(existing)
    if status is "experiment" or status is "completed"
      # HIT has been taken by someone else. Reuse it
      # TODO: maybe we keep this copy and create a new one?
      Assignments.update existing._id,
        $set:
          workerId: loginRequest.workerId
        $unset:
          experimentId: null
          inactivePercent: null

      # TODO remove this hack
      existing.workerId = loginRequest.workerId # for next part check

  activeBatch = Batches.findOne(active: true)

  # Check for limits if worker is not on same HIT
  if loginRequest.workerId isnt existing?.workerId

    if Assignments.find({
        workerId: loginRequest.workerId,
        status: { $ne: "completed" }
      }).count() >=
    TurkServer.config.experiment.limit.simultaneous
      throw new Meteor.Error(403, ErrMsg.simultaneousLimit)

    predicate =
      workerId: loginRequest.workerId

    # TODO: allow for excluding other batches
    predicate.batchId = activeBatch._id if activeBatch

    if Assignments.find(predicate).count() >=
    TurkServer.config.experiment.limit.batch
      throw new Meteor.Error(403, ErrMsg.batchLimit)

  save =
    workerId: loginRequest.workerId
  save.batchId = activeBatch._id if activeBatch

  # Set this worker as assigned to the HIT
  # TODO this repeats code from up there ^
  Assignments.update (_id || existing._id), {$set: save}

  return

Accounts.registerLoginHandler (loginRequest) ->
  # Don't handle unless we have an mturk login
  return unless loginRequest.hitId and loginRequest.assignmentId and loginRequest.workerId

  user = Meteor.users.findOne
    workerId: loginRequest.workerId

  unless user
    userId = Meteor.users.insert
      workerId: loginRequest.workerId
  else
    userId = user._id;

  # should we let this worker in or not?
  TurkServer.authenticateWorker(loginRequest)

  ###
    TODO We probably don't want to push this token - disable resume and force login each time
  ###

#  Meteor.users.update userId,
#    $push: {'services.resume.loginTokens': stampedToken}

  TurkServer.handleConnection
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    userId: userId

  stampedToken = Accounts._generateStampedLoginToken();

  return {
    id: userId,
    token: stampedToken.token
  }
