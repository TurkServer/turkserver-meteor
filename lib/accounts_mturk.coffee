
TurkServer.authenticateWorker = (loginRequest) ->
  existing = Assignments.findOne
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId

  unless existing
    # not previously existing session
    _id = Assignments.insert
      hitId: loginRequest.hitId
      assignmentId: loginRequest.assignmentId

  else if loginRequest.workerId is existing?.workerId
    if TurkServer.sessionStatus(existing) is "completed"
      throw new Meteor.Error(403, "completed")

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

  # Check for limits if worker is not on same HIT
  # TODO account for setId
  if loginRequest.workerId isnt existing?.workerId

    if Assignments.find({
        workerId: loginRequest.workerId,
        inactiveTime: { $exists: false }
      }).count() >=
    TurkServer.settings.experiment.limit.simultaneous
      throw new Meteor.Error(403, "too many simultaneous logins")

    if Assignments.find({
        workerId: loginRequest.workerId
      }).count() >=
    TurkServer.settings.experiment.limit.set
      throw new Meteor.Error(403, "too many hits")

  # Set this worker as assigned to the HIT
  # TODO this repeats code from up there ^
  Assignments.update _id || existing._id,
    $set:
      workerId: loginRequest.workerId

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

  stampedToken = Accounts._generateStampedLoginToken();

  ###
    TODO We probably don't want to push this token - disable resume and force login each time
  ###

#  Meteor.users.update userId,
#    $push: {'services.resume.loginTokens': stampedToken}

  # Delete old resume tokens so they don't clog up the db
#  cutoff = +(new Date) - (24*60*60)*1000
#  Meteor.users.update userId, {
#    $pull:
#      'services.resume.loginTokens':
#        when: {$lt: cutoff}
#  },
#  {multi : true}

  TurkServer.handleConnection
    hitId: loginRequest.hitId
    assignmentId: loginRequest.assignmentId
    workerId: loginRequest.workerId
    userId: userId

  return {
    id: userId,
    token: stampedToken.token
  }
