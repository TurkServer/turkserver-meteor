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

  # TODO: should we let this worker in or not?

  stampedToken = Accounts._generateStampedLoginToken();
  Meteor.users.update userId,
    $push: {'services.resume.loginTokens': stampedToken}

  # Delete old resume tokens so they don't clog up the db
  cutoff = +(new Date) - (24*60*60)*1000
  Meteor.users.update userId, {
    $pull:
      'services.resume.loginTokens':
        when: {$lt: cutoff}
  },
  {multi : true}

  return {
    id: userId,
    token: stampedToken.token
  }
