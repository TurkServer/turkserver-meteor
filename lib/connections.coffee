UserStatus.on "sessionLogin", (doc) ->
  # Update ip address in assignments for this worker
  user = Meteor.users.findOne(doc.userId)

  # TODO verify this is valid as we reject multiple connections on login
  Assignments.update {
    workerId: user.workerId
    status: "ASSIGNED"
  }, {
    $set: {ipAddr: doc.ipAddr}
  }

UserStatus.on "sessionLogout", (doc) ->
  # Remove disconnected users from lobby, if they are there
  TurkServer.Lobby.removeUser(doc.userId)

  # TODO record disconnection

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

Meteor.methods
  "inactive": (data) ->
    # TODO implement tracking inactivity
    # We don't trust client timestamps, but only as identifier and use difference
    console.log data.start, data.time

TurkServer.handleConnection = (doc) ->
  # Make sure any previous assignments are recorded as returned
  Assignments.update {
    hitId: doc.hitId
    assignmentId: doc.assignmentId
    workerId: {$ne: doc.workerId}
  }, {
    $set: { status: "RETURNED" }
  }, { multi: true }

  # Track this worker as assigned
  Assignments.upsert {
    hitId: doc.hitId
    assignmentId: doc.assignmentId
    workerId: doc.workerId
  }, {
    $set: { status: "ASSIGNED" }
  }

  # TODO Does the worker need to take quiz/tutorial?

  # Is worker in part of an active group (experiment)?
  if TurkServer.Groups.getUserGroup(doc.userId)
    # TODO record reconnection
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
  newId = Experiments.insert
    startTime: Date.now()
    treatment: treatmentId
  TurkServer.Experiment.setup(newId, Treatments.findOne(treatmentId).name)

  _.each userIds, (userId) ->
    TurkServer.Groups.setUserGroup(userId, newId)
    Meteor.users.update userId,
      $set: { "turkserver.state": "experiment" }

# Assignment for fixed group count
TurkServer.assignUserRoundRobin = (userId) ->
  exp = _.min Experiments.find(assignable: true).fetch(), (ex) ->
    Grouping.find(groupId: ex._id).count()

  TurkServer.Groups.setUserGroup(userId, exp._id)

  Meteor.users.update userId,
    $set: { "turkserver.state": "experiment" }

# Assignment for no lobby fixed group size
TurkServer.assignUserSequential = (userId) ->
  activeBatch = Batches.findOne(active: true)

  assignedToExisting = false
  Experiments.find(assignable: true).forEach (exp) ->
    return if assignedToExisting # Break loop if already assigned
    if Grouping.find(groupId: exp._id).count() < activeBatch.groupVal
      TurkServer.Groups.setUserGroup(userId, exp._id)
      assignedToExisting = true

  unless assignedToExisting # Create a new experiment
    newId = Experiments.insert
      startTime: Date.now()
      assignable: true
    TurkServer.Experiment.setup(newId, undefined)

    TurkServer.Groups.setUserGroup(userId, newId)

  Meteor.users.update userId,
    $set: { "turkserver.state": "experiment" }


