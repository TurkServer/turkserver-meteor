###
  Connect callbacks
###

UserStatus.on "sessionLogin", (doc) ->
  # Update ip address in assignments for this worker
  user = Meteor.users.findOne(doc.userId)

  # TODO verify this is valid as we reject multiple connections on login
  Assignments.update {
    workerId: user.workerId
    status: "assigned"
  }, {
    $set: {ipAddr: doc.ipAddr}
  }

connectCallbacks = []

UserStatus.on "sessionLogin", (doc) ->
  return unless doc.userId
  groupId = Grouping.findOne(doc.userId)?.groupId
  return unless groupId
  TurkServer.bindGroup groupId, ->
    _.each connectCallbacks, (cb) ->
      cb.call(userId: doc.userId)

TurkServer.onConnect = (func) ->
  connectCallbacks.push func

###
  Disconnect callbacks
###

UserStatus.on "sessionLogout", (doc) ->
  # Remove disconnected users from lobby, if they are there
  TurkServer.Lobby.removeUser(doc.userId)

disconnectCallbacks = []

UserStatus.on "sessionLogout", (doc) ->
  return unless doc.userId
  groupId = Grouping.findOne(doc.userId)?.groupId
  return unless groupId
  TurkServer.bindGroup groupId, ->
    _.each disconnectCallbacks, (cb) ->
      cb.call(userId: doc.userId)

TurkServer.onDisconnect = (func) ->
  disconnectCallbacks.push func

###
  Methods
###

Meteor.methods
  "ts-set-username": (username) ->
    # TODO may need validation here due to bad browsers/bad people
    userId = Meteor.userId()
    return unless userId
    if TurkServer.directOperation(-> Meteor.users.findOne(username: username))
      throw new Meteor.Error(409, ErrMsg.usernameTaken)
    Meteor.users.update userId,
      $set: {username: username}

  "ts-record-inactive": (data) ->
    # TODO implement tracking inactivity
    # We don't trust client timestamps, but only as identifier and use difference
    console.log data.start, data.time

  "ts-submit-exitdata": (doc) ->
    userId = Meteor.userId()

    # TODO check that the user is allowed to do this
    # TODO save the data
    # TODO return true to auto submit the HIT
    return true

TurkServer.handleConnection = (doc) ->
  # Make sure any previous assignments are recorded as returned
  # TODO this is currently not used
  Assignments.update {
    hitId: doc.hitId
    assignmentId: doc.assignmentId
    workerId: {$ne: doc.workerId}
  }, {
    $set: { status: "returned" }
  }, { multi: true }

  # Track this worker as assigned
  Assignments.upsert {
    hitId: doc.hitId
    assignmentId: doc.assignmentId
    workerId: doc.workerId
  }, {
    $set: { status: "assigned" }
  }

  # TODO Does the worker need to take quiz/tutorial?

  # Is worker in part of an active group (experiment)?
  # This is okay even if no active batch
  if TurkServer.Groups.getUserGroup(doc.userId)
    Meteor._debug doc.userId + " is reconnecting to an existing group"
    # other reconnection info recorded above
    return

  # None of the above, throw them into the assignment mechanism
  activeBatch = Batches.findOne(active: true)
  throw new Meteor.Error(403, "No active batch configured on server") unless activeBatch?

  if activeBatch.grouping is "groupSize" and activeBatch.lobby
    TurkServer.Lobby.addUser(doc.userId)
  else if activeBatch.grouping is "groupCount"
    TurkServer.assignUserRoundRobin(doc.userId)
  else
    TurkServer.assignUserSequential(doc.userId)

# TODO fix up the stuff below to assign treatments properly

# Assignment from lobby
TurkServer.assignAllUsers = (userIds) ->
  # TODO don't just assign a random treatment
  treatmentId = _.sample Batches.findOne(active: true).treatmentIds
  newId = TurkServer.Experiment.create(treatmentId)
  TurkServer.Experiment.setup(newId, Treatments.findOne(treatmentId).name)

  _.each userIds, (userId) ->
    TurkServer.Experiment.addUser(newId, userId)

# Assignment for fixed group count
TurkServer.assignUserRoundRobin = (userId) ->
  experimentIds = Batches.findOne(active: true).experimentIds
  exp = _.min Experiments.find(_id: $in: experimentIds).fetch(), (ex) ->
    Grouping.find(groupId: ex._id).count()

  TurkServer.Experiment.addUser(exp._id, userId)

# Assignment for no lobby fixed group size
TurkServer.assignUserSequential = (userId) ->
  activeBatch = Batches.findOne(active: true)

  assignedToExisting = false
  Experiments.find(assignable: true).forEach (exp) ->
    return if assignedToExisting # Break loop if already assigned
    if Grouping.find(groupId: exp._id).count() < activeBatch.groupVal
      TurkServer.experiment.addUser(exp._id, userId)
      assignedToExisting = true

  return if assignedToExisting

  # Create a new experiment
  # TODO find a treatment
  treatmentId = undefined
  newId = TurkServer.Experiment.create treatmentId,
    assignable: true
  TurkServer.Experiment.setup(newId, Treatments.findOne(treatmentId).name)
  TurkServer.Experiment.addUser(newId, userId)



