###
  An assignment captures the lifecycle of a user assigned to a HIT.
  In the future, it can be generalized to represent the entire connection
  of a user from whatever source
###

class TurkServer.Assignment
  # Map of all assignments by id
  _assignments = {}

  @createAssignment: (data) ->
    asstId = Assignments.insert(data)
    return new TurkServer.Assignment(asstId, data)

  @getAssignment: (asstId) ->
    if (asst = _assignments[asstId])?
      return asst
    else
      data = Assignments.findOne(asstId)
      throw new Error("Assignment doesn't exist") unless data?
      return new TurkServer.Assignment(asstId, data)

  @getCurrentUserAssignment: (userId) ->
    user = Meteor.users.findOne(userId)
    return unless user.workerId?
    asst = Assignments.findOne
      workerId: user.workerId
      status: "assigned"
    return @getAssignment(asst._id) if asst?

  constructor: (@asstId, properties) ->
    check(@asstId, String)
    _assignments[@asstId] = this
    # The below properties are invariant for any assignment
    { @batchId, @hitId, @assignmentId, @workerId } = properties || Assignments.findOne(@asstId)
    check(@batchId, String)
    check(@hitId, String)
    check(@assignmentId, String)
    check(@workerId, String)
    # Grab the userId
    @userId = Meteor.users.findOne(workerId: @workerId)._id

  getBatch: -> TurkServer.Batch.getBatch(@batchId)

  addInstance: (instanceId) ->
    Assignments.update @asstId,
      $push: { instances: instanceId }

  setCompleted: (doc) ->
    Assignments.update @asstId,
      $set: {
        status: "completed"
        submitTime: Date.now()
        exitdata: doc
      }

  updateWorkerData: (panel) ->
    Workers.upsert @workerId, { $set: panel }

  # Handle a connection or reconnection by this user
  _connected: ->
    # Is worker in part of an active group (experiment)?
    # This is okay even if batch is not active
    if Partitioner.getUserGroup(@userId)
      Meteor._debug @userId + " is reconnecting to an existing group"
      return

    # Is the worker reconnecting to an exit survey?
    if Meteor.users.findOne(@userId)?.turkserver?.state is "exitsurvey"
      Meteor._debug @userId + " is reconnecting to the exit survey"
      # Wait for them to fill it out
      return

    # None of the above, throw them into the lobby/assignment mechanism
    batch = @getBatch()
    throw new Meteor.Error(403, "No batch associated with assignment") unless batch?
    batch.lobby.addUser(@userId)

    # Handle a disconnection by this user
  _disconnected: ->
    # Remove from lobby if present
    @getBatch().lobby.removeUser(@userId)

TurkServer.currentAssignment = ->
  userId = Meteor.userId()
  return unless userId?
  return TurkServer.Assignment.getCurrentUserAssignment(userId)

getUserGroup = (userId) ->
  return unless userId
  # No side effects from admin, please
  return if Meteor.users.findOne(userId)?.admin
  return Partitioner.getUserGroup(userId)

###
  Connect callbacks
###

UserStatus.events.on "connectionLogin", (doc) ->
  # Update ip address in assignments for this worker
  user = Meteor.users.findOne(doc.userId)
  return if user?.admin

  # TODO verify this is valid as we reject multiple connections on login
  Assignments.update {
    workerId: user.workerId
    status: "assigned"
  }, {
    $set: {ipAddr: doc.ipAddr}
  }

  return

connectCallbacks = []

UserStatus.events.on "connectionLogin", (doc) ->
  return unless (groupId = getUserGroup(doc.userId))?
  Partitioner.bindGroup groupId, ->
    TurkServer.log
      _userId: doc.userId
      _meta: "connected"

    _.each connectCallbacks, (cb) ->
      try
        cb.call
          userId: doc.userId
      catch e
        Meteor._debug "Exception in user connect callback: " + e

TurkServer.onConnect = (func) ->
  connectCallbacks.push func

###
  Disconnect callbacks
###

disconnectCallbacks = []

UserStatus.events.on "connectionLogout", (doc) ->
  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst?._disconnected()

  return unless (groupId = getUserGroup(doc.userId))?
  Partitioner.bindGroup groupId, ->
    TurkServer.log
      _userId: doc.userId
      _meta: "disconnected"

    _.each disconnectCallbacks, (cb) ->
      try
        cb.call
          userId: doc.userId
      catch e
        Meteor._debug "Exception in user disconnect callback: " + e

TurkServer.onDisconnect = (func) ->
  disconnectCallbacks.push func

###
  Idle and returning from idle
###

idleCallbacks = []
activeCallbacks = []

TurkServer.onIdle = (func) -> idleCallbacks.push(func)
TurkServer.onActive = (func) -> idleCallbacks.push(func)

# TODO: compute total amount of time a user has been idle in a group

UserStatus.events.on "connectionIdle", (doc) ->
  return unless (groupId = getUserGroup(doc.userId))?
  Partitioner.bindGroup groupId, ->
    TurkServer.log
      _userId: doc.userId
      _meta: "idle"
      _timestamp: doc.lastActivity # Overridden to a past value

    _.each idleCallbacks, (cb) ->
      try
        cb.call
          userId: doc.userId
      catch e
        Meteor._debug "Exception in user idle callback: " + e

UserStatus.events.on "connectionActive", (doc) ->
  return unless (groupId = getUserGroup(doc.userId))?
  Partitioner.bindGroup groupId, ->
    TurkServer.log
      _userId: doc.userId
      _meta: "active"
      _timestamp: doc.lastActivity # Also overridden

    _.each activeCallbacks, (cb) ->
      try
        cb.call
          userId: doc.userId
      catch e
        Meteor._debug "Exception in user active callback: " + e

###
  Methods
###

Meteor.methods
  "ts-set-username": (username) ->
    # TODO may need validation here due to bad browsers/bad people
    userId = Meteor.userId()
    return unless userId
    if Partitioner.directOperation(-> Meteor.users.findOne(username: username))
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
    asst = TurkServer.currentAssignment()

    # mark assignment as completed and save the data
    asst.setCompleted(doc)

    # TODO schedule this worker's resume token to be scavenged in the future

    # Update worker contact info
    asst.updateWorkerData(panel) if panel

    Meteor.users.update userId,
      $unset: {"turkserver.state": null}

    # return true to auto submit the HIT
    return true



