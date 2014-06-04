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
    return _assignments[asstId] = new Assignment(asstId, data)

  @getAssignment: (asstId) ->
    if (asst = _assignments[asstId])?
      return asst
    else
      data = Assignments.findOne(asstId)
      throw new Error("Assignment doesn't exist") unless data?
      return _assignments[asstId] = new Assignment(asstId, data)

  @getCurrentUserAssignment: (userId) ->
    user = Meteor.users.findOne(userId)
    return unless user.workerId?
    asstRecord = Assignments.findOne
      workerId: user.workerId
      status: "assigned"
    return @getAssignment(asstRecord._id) if asstRecord?

  @currentAssignment: ->
    userId = Meteor.userId()
    return unless userId?
    return TurkServer.Assignment.getCurrentUserAssignment(userId)

  constructor: (@asstId, properties) ->
    check(@asstId, String)
    throw new Error("Assignment already exists; use getAssignment") if _assignments[@asstId]?
    # The below properties are invariant for any assignment
    { @batchId, @hitId, @assignmentId, @workerId } = properties || Assignments.findOne(@asstId)
    check(@batchId, String)
    check(@hitId, String)
    check(@assignmentId, String)
    check(@workerId, String)
    # Grab the userId
    @userId = Meteor.users.findOne(workerId: @workerId)._id

  getBatch: -> TurkServer.Batch.getBatch(@batchId)

  getInstances: -> Assignments.findOne(@asstId).instances || []

  showExitSurvey: ->
    Meteor.users.update @userId,
      $set: { "turkserver.state": "exitsurvey" }

  setCompleted: (doc) ->
    user = Meteor.users.findOne(@userId)
    # check that the user is allowed to do this
    throw new Meteor.Error(403, ErrMsg.stateErr) unless user?.turkserver?.state is "exitsurvey"

    Assignments.update @asstId,
      $set: {
        status: "completed"
        submitTime: new Date()
        exitdata: doc
      }

    Meteor.users.update @userId,
      $unset: {"turkserver.state": null}

  # Gets the variable payment amount for this assignment (bonus)
  getPayment: ->
    Assignments.findOne(@asstId).bonusPayment

  # Sets the payment amount for this assignment, replacing any existing value
  setPayment: (amount) ->
    check(amount, Number)
    Assignments.update @asstId,
      $set: bonusPayment: amount

  # Adds (or subtracts) an amount to the payment for this assignment
  addPayment: (amount) ->
    check(amount, Number)
    Assignments.update @asstId,
      $inc: bonusPayment: amount

  # Gets an arbitrary data field on this assignment
  getData: (field) ->
    data = Assignments.findOne(@asstId)
    return if field then data[field] else data

  # Sets an arbitrary data field on this assignment
  setData: (doc) ->
    Assignments.update @asstId, $set: doc

  # Get data from the worker associated with this assignment
  getWorkerData: (field) ->
    data = Workers.findOne(@workerId)
    return if field then data[field] else data

  # Sets data on the worker associated with this assignment
  setWorkerData: (doc) ->
    Workers.upsert @workerId, { $set: doc }

  # Handle an initial connection by this user after accepting a HIT
  _loggedIn: ->
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
    @_enterLobby()

  _enterLobby: ->
    batch = @getBatch()
    throw new Meteor.Error(403, "No batch associated with assignment") unless batch?
    batch.lobby.addAssignment(@)

  _joinInstance: (instanceId) ->
    Assignments.update @asstId,
      $push:
        instances: {
          id: instanceId
          joinTime: new Date()
        }

  # Helper functions for constructing database updates
  addResetDisconnectedUpdateFields = (obj, discDurationMillis) ->
    obj.$inc ?= {}
    obj.$unset ?= {}
    obj.$inc["instances.$.disconnectedTime"] = discDurationMillis
    obj.$unset["instances.$.lastDisconnect"] = null
    return obj

  addResetIdleUpdateFields = (obj, idleDurationMillis) ->
    obj.$inc ?= {}
    obj.$unset ?= {}
    obj.$inc["instances.$.idleTime"] = idleDurationMillis
    obj.$unset["instances.$.lastIdle"] = null
    return obj

  _leaveInstance: (instanceId) ->
    now = new Date
    updateObj =
      $set:
        "instances.$.leaveTime": now

    # If in disconnected state, compute total disconnected time
    if (discTime = @_getLastDisconnect(instanceId))?
      addResetDisconnectedUpdateFields(updateObj, now.getTime() - discTime)
    # If in idle state, compute total idle time
    if (idleTime = @_getLastIdle(instanceId))?
      addResetIdleUpdateFields(updateObj, now.getTime() - idleTime)

    Assignments.update {
      _id: @asstId
      "instances.id": instanceId
    }, updateObj

  # Handle a disconnection by this user
  _disconnected: (instanceId) ->
    # Record a disconnect time if we are currently part of an instance
    now = new Date()
    updateObj =
      $set:
        "instances.$.lastDisconnect": now

    # If we are idle, add the total idle time to the running amount;
    # A new idle session will start when the user reconnects
    if (idleTime = @_getLastIdle(instanceId))?
      addResetIdleUpdateFields(updateObj, now.getTime() - idleTime)

    Assignments.update {
      _id: @asstId
      "instances.id": instanceId
    }, updateObj

    # Remove from lobby if present
    @getBatch().lobby.removeAssignment(@)

  # Handle a reconnection by a user, if they were assigned prior to the reconnection
  _reconnected: (instanceId) ->
    # XXX Safety hatch: never count an idle time tracked over a disconnection
    updateObj =
      $unset:
        "instances.$.lastIdle": null

    if (discTime = @_getLastDisconnect(instanceId))?
      addResetDisconnectedUpdateFields(updateObj, Date.now() - discTime)

    Assignments.update {
      _id: @asstId
      "instances.id": instanceId
    }, updateObj

  _isIdle: (instanceId, timestamp) ->
    # TODO: ignore if user is disconnected
    Assignments.update {
      _id: @asstId
      "instances.id": instanceId
    }, $set:
      "instances.$.lastIdle": timestamp

  _isActive: (instanceId, timestamp) ->
    idleTime = @_getLastIdle(instanceId)
    return unless idleTime
    Assignments.update {
      _id: @asstId
      "instances.id": instanceId
    }, addResetIdleUpdateFields({}, timestamp - idleTime)
    return

  # Helper functions
  # TODO test that these are grabbing the right numbers
  _getLastDisconnect: (instanceId) ->
    _.find(@getInstances(), (inst) -> inst.id is instanceId)?.lastDisconnect

  _getLastIdle: (instanceId) ->
    _.find(@getInstances(), (inst) -> inst.id is instanceId)?.lastIdle

getActiveGroup = (userId) ->
  return unless userId
  # No side effects from admin, please
  return if Meteor.users.findOne(userId)?.admin
  return Partitioner.getUserGroup(userId)

###
  TODO: If/when simultaneous connections are supported, fix logic below
  or just replace connections with users due to muxing implemented in user-status
###

attemptCallbacks = (callbacks, context, errMsg) ->
  for cb in callbacks
    try
      cb.call(context)
    catch e
      Meteor._debug errMsg, e

###
  Connect callbacks
###

connectCallbacks = []

userReconnect = (doc) ->
  # Ensure user is in a valid state; add to lobby if not
  user = Meteor.users.findOne(doc.userId)
  return if not user? or user?.admin

  unless user?.turkserver?.state
    TurkServer.Assignment.getCurrentUserAssignment(doc.userId)._enterLobby()
    return

  return unless (groupId = getActiveGroup(doc.userId))?
  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst._reconnected(groupId)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: doc.userId
      _meta: "connected"

    attemptCallbacks(connectCallbacks, this, "Exception in user connect callback")
    return
  , { userId: doc.userId }

TurkServer.onConnect = (func) ->
  connectCallbacks.push func

###
  Disconnect callbacks
###

disconnectCallbacks = []

userDisconnect = (doc) ->
  return unless (groupId = getActiveGroup(doc.userId))?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst?._disconnected(groupId) # Needed during tests, as assignments are being removed from db

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: doc.userId
      _meta: "disconnected"

    attemptCallbacks(disconnectCallbacks, this, "Exception in user disconnect callback")
    return
  , { userId: doc.userId }

TurkServer.onDisconnect = (func) ->
  disconnectCallbacks.push func

###
  Idle and returning from idle
###

idleCallbacks = []
activeCallbacks = []

TurkServer.onIdle = (func) -> idleCallbacks.push(func)
TurkServer.onActive = (func) -> idleCallbacks.push(func)

userIdle = (doc) ->
  return unless (groupId = getActiveGroup(doc.userId))?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst._isIdle(groupId, doc.lastActivity)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: doc.userId
      _meta: "idle"
      _timestamp: doc.lastActivity # Overridden to a past value

    attemptCallbacks(idleCallbacks, this, "Exception in user idle callback")
    return
  , { userId: doc.userId }

userActive = (doc) ->
  return unless (groupId = getActiveGroup(doc.userId))?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst._isActive(groupId, doc.lastActivity)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: doc.userId
      _meta: "active"
      _timestamp: doc.lastActivity # Also overridden

    attemptCallbacks(activeCallbacks, this, "Exception in user active callback")
    return
  , { userId: doc.userId }

UserStatus.events.on "connectionLogin", userReconnect
UserStatus.events.on "connectionLogout", userDisconnect
UserStatus.events.on "connectionIdle", userIdle
UserStatus.events.on "connectionActive", userActive

TestUtils.connCallbacks = {
  userReconnect
  userDisconnect
  userIdle
  userActive
}

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

  "ts-submit-exitdata": (doc, panel) ->
    userId = Meteor.userId()
    throw new Meteor.Error(403, ErrMsg.authErr) unless userId

    # TODO what if this doesn't exist?
    asst = TurkServer.Assignment.currentAssignment()
    # mark assignment as completed and save the data
    asst.setCompleted(doc)

    # TODO schedule this worker's resume token to be scavenged in the future

    # Update worker contact info
    asst.setWorkerData(panel) if panel

    # return true to auto submit the HIT
    return true


