UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->
  # Update ip address in assignments for this worker
  user = Meteor.users.findOne(userId)

  # TODO verify this is valid as we reject multiple connections on login
  Assignments.update {
    workerId: user.workerId
    status: "ASSIGNED"
  }, {
    $set: {ipAddr: ipAddr}
  }

UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  # TODO record disconnection

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
  if Grouping.findOne(userId: doc.userId)
    # TODO record reconnection
    return

  # None of the above, throw them into the assignment mechanism
  activeBatch = Batches.findOne(active: true)
  throw new Meteor.Error(403, "No active batch configured on server") unless activeBatch?

  if activeBatch.lobby
    TurkServer.addToLobby(doc.userId)
  else
    TurkServer.assignUser(doc.userId)

TurkServer.assignUser = (userId) ->



