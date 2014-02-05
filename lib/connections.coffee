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
    TurkServer.log
      _userId: doc.userId
      _meta: "connected"

    _.each connectCallbacks, (cb) ->
      try
        cb.call(userId: doc.userId)
      catch e
        Meteor._debug "Exception in experiment connect callback: " + e

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
    TurkServer.log
      _userId: doc.userId
      _meta: "disconnected"

    _.each disconnectCallbacks, (cb) ->
      try
        cb.call(userId: doc.userId)
      catch e
        Meteor._debug "Exception in experiment disconnect callback: " + e

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

  "ts-submit-exitdata": (doc, panel) ->
    userId = Meteor.userId()
    throw new Meteor.Error(403, ErrMsg.authErr) unless userId
    user = Meteor.users.findOne(userId)

    # check that the user is allowed to do this
    throw new Meteor.Error(403, ErrMsg.stateErr) unless user?.turkserver?.state is "exitsurvey"

    # TODO what if this doesn't exist?
    asst = Assignments.findOne
      workerId: user.workerId
      status: "assigned"

    # mark assignment as completed and save the data
    Assignments.update asst._id,
      $set: {
        status: "completed"
        submitTime: Date.now()
        exitdata: doc
      }

    # Update worker contact info
    # TODO generalize this
    if panel
      Workers.upsert user.workerId,
        $set:
          contact: panel.contact
          times: panel.times

    Meteor.users.update userId,
      $unset: {"turkserver.state": null}

    # return true to auto submit the HIT
    return true

TurkServer.handleConnection = (doc) ->

  # TODO Does the worker need to take quiz/tutorial?

  # Is worker in part of an active group (experiment)?
  # This is okay even if no active batch
  if TurkServer.Groups.getUserGroup(doc.userId)
    Meteor._debug doc.userId + " is reconnecting to an existing group"
    # other reconnection info recorded above
    return

  # Is the worker reconnecting to an exit survey?
  if Meteor.users.findOne(doc.userId)?.turkserver?.state is "exitsurvey"
    Meteor._debug doc.userId + " is reconnecting to the exit survey"
    # Wait for them to fill it out
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
  treatment = Treatments.findOne(treatmentId).name
  newId = TurkServer.Experiment.create(treatment)
  TurkServer.Experiment.setup(newId)

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
  treatment = Treatments.findOne(treatmentId).name
  newId = TurkServer.Experiment.create treatment,
    assignable: true
  TurkServer.Experiment.setup(newId)
  TurkServer.Experiment.addUser(newId, userId)



