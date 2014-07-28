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
      # Return this if another Fiber created it while we yielded
      return _assignments[asstId] ?= new Assignment(asstId, data)

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
    # Grab the userId - when the assignment is constructed as part of a method
    # call, we need to reach around it to avoid adding a group key, which will
    # cause the find to fail.
    @userId = Partitioner.directOperation =>
      Meteor.users.findOne(workerId: @workerId)._id

  getBatch: -> TurkServer.Batch.getBatch(@batchId)

  getInstances: -> Assignments.findOne(@asstId).instances || []

  showExitSurvey: ->
    Meteor.users.update @userId,
      $set: { "turkserver.state": "exitsurvey" }

  isCompleted: -> Assignments.findOne(@asstId).status is "completed"

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

  # Mark this assignment as returned and not completable
  setReturned: ->
    Assignments.update @asstId,
      $set: { status: "returned" }
    # Unset the user's state
    Meteor.users.update @userId,
      $unset: {"turkserver.state": null}

  # Gets the variable payment amount for this assignment (bonus)
  getPayment: ->
    Assignments.findOne(@asstId).bonusPayment

  # Sets the payment amount for this assignment, replacing any existing value
  setPayment: (amount) ->
    check(amount, Number)
    Assignments.update @asstId,
      $set:
        bonusPayment: amount

  # Adds (or subtracts) an amount to the payment for this assignment
  addPayment: (amount) ->
    check(amount, Number)
    Assignments.update @asstId,
      $inc: bonusPayment: amount

  # Get the current MTurk status for this assignment
  refreshStatus: ->
    # Since MTurk AssignmentIds may be re-used, it's important we only query
    # for completed assignments.
    unless @isCompleted()
      throw new Error("Assignment not completed")

    try
      asstData = TurkServer.mturk "GetAssignment", { AssignmentId: @assignmentId }
    catch e
      throw new Meteor.Error(500, e.toString())

    # Just check that it's actually the same worker here.
    unless @workerId is asstData.WorkerId
      throw new Error("Worker ID doesn't match")

    Assignments.update @asstId,
      $set:
        mturkStatus: asstData.AssignmentStatus

  _checkSubmittedStatus: ->
    unless @isCompleted()
      throw new Error("Assignment not completed")

    mturkStatus = @_data().mturkStatus
    if mturkStatus is "Approved" or mturkStatus is "Rejected"
      throw new Error("Already approved or rejected")

  approve: (message) ->
    check(message, String)
    @_checkSubmittedStatus()

    TurkServer.mturk "ApproveAssignment",
      AssignmentId: @assignmentId
      RequesterFeedback: message

    # TODO: if assignment is already approved, then update status as well

    # If approved, update mturk status to reflect
    Assignments.update @asstId,
      $set:
        mturkStatus: "Approved"

  reject: (message) ->
    check(message, String)
    @_checkSubmittedStatus()

    TurkServer.mturk "RejectAssignment",
      AssignmentId: @assignmentId
      RequesterFeedback: message

    Assignments.update @asstId,
      $set:
        mturkStatus: "Rejected"

  # Pays the worker their bonus, if set, using the mturk API
  payBonus: (message) ->
    check(message, String)

    data = Assignments.findOne(@asstId)
    throw new Error("Bonus value not set") unless data.bonusPayment?
    throw new Error("Bonus already paid") if data.bonusPaid?

    TurkServer.mturk "GrantBonus",
      WorkerId: data.workerId
      AssignmentId: data.assignmentId
      BonusAmount:
        Amount: data.bonusPayment
        CurrencyCode: "USD"
      Reason: message

    # Successfully paid!
    Assignments.update @asstId,
      $set:
        bonusPaid: new Date()
        bonusMessage: message

  # Get data from the worker associated with this assignment
  getWorkerData: (field) ->
    data = Workers.findOne(@workerId)
    return if field then data[field] else data

  # Sets data on the worker associated with this assignment
  setWorkerData: (doc) ->
    Workers.upsert @workerId, { $set: doc }

  _data: -> Assignments.findOne(@asstId)

  _update: (modifier) ->
    Assignments.update(@asstId, modifier)

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

    # Nothing else needs to be done; a fresh login OR a reconnect will check for lobby state properly.

  _enterLobby: ->
    batch = @getBatch()
    throw new Meteor.Error(403, "No batch associated with assignment") unless batch?
    batch.lobby.addAssignment(@)

  _removeFromLobby: ->
    # Remove from lobby if present
    @getBatch().lobby.removeAssignment(@)

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
    check(instanceId, String)

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

attemptCallbacks = (callbacks, context, errMsg) ->
  for cb in callbacks
    try
      cb.call(context)
    catch e
      Meteor._debug errMsg, e

connectCallbacks = []
disconnectCallbacks = []
idleCallbacks = []
activeCallbacks = []

TurkServer.onConnect = (func) -> connectCallbacks.push(func)
TurkServer.onDisconnect = (func) -> disconnectCallbacks.push(func)
TurkServer.onIdle = (func) -> idleCallbacks.push(func)
TurkServer.onActive = (func) -> activeCallbacks.push(func)

# When getting user records in a session callback, we have to check if admin
getUserNonAdmin = (userId) ->
  user = Meteor.users.findOne(userId)
  return if not user? or user?.admin
  return user

###
  Connect/disconnect callbacks

  In the methods below, we use Partitioner.getUserGroup(userId) because
  user.turkserver.group takes a moment to be propagated.
###
sessionReconnect = (doc) ->
  return unless getUserNonAdmin(doc.userId)?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)

  # Save IP address and UA; multiple connections from different IPs/browsers
  # are recorded for diagnostic purposes.
  asst._update
    $addToSet: {
      ipAddr: doc.ipAddr
      userAgent: doc.userAgent
    }

userReconnect = (user) ->
  asst = TurkServer.Assignment.getCurrentUserAssignment(user._id)

  # Ensure user is in a valid state; add to lobby if not
  state = user.turkserver?.state
  if state is "lobby" or not state?
    asst._enterLobby()
    return

  # We only call the group operations below if the user was in a group at the
  # time of connection
  return unless (groupId = Partitioner.getUserGroup(user._id))?
  asst._reconnected(groupId)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: user._id
      _meta: "connected"

    attemptCallbacks(connectCallbacks, this, "Exception in user connect callback")
    return
  , {
      userId: user._id
      event: "connected"
    }

userDisconnect = (user) ->
  asst = TurkServer.Assignment.getCurrentUserAssignment(user._id)

  # If user was in lobby, remove them
  # If they are disconnecting after completing an assignment, there will be no current assignment.
  asst?._removeFromLobby()

  return unless (groupId = Partitioner.getUserGroup(user._id))?
  asst._disconnected(groupId)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: user._id
      _meta: "disconnected"

    attemptCallbacks(disconnectCallbacks, this, "Exception in user disconnect callback")
    return
  , {
      userId: user._id
      event: "disconnected"
    }

###
  Idle and returning from idle
###

userIdle = (user) ->
  return unless (groupId = Partitioner.getUserGroup(user._id))?

  asst = TurkServer.Assignment.getCurrentUserAssignment(user._id)
  asst._isIdle(groupId, user.status.lastActivity)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: user._id
      _meta: "idle"
      _timestamp: user.status.lastActivity # Overridden to a past value

    attemptCallbacks(idleCallbacks, this, "Exception in user idle callback")
    return
  , {
      userId: user._id
      event: "idle"
    }

# Because activity on any session will make a user active, we use this in
# order to properly record the last activity time on the client
sessionActive = (doc) ->
  return unless getUserNonAdmin(doc.userId)?

  return unless (groupId = Partitioner.getUserGroup(doc.userId))?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)
  asst._isActive(groupId, doc.lastActivity)

  TurkServer.Instance.getInstance(groupId).bindOperation ->
    TurkServer.log
      _userId: doc.userId
      _meta: "active"
      _timestamp: doc.lastActivity # Also overridden

    attemptCallbacks(activeCallbacks, this, "Exception in user active callback")
    return
  , {
      userId: doc.userId
      event: "active"
    }

###
  Hook up callbacks to events and observers
###

UserStatus.events.on "connectionLogin", sessionReconnect
# Logout / Idle are done at user level
UserStatus.events.on "connectionActive", sessionActive

# This is triggered from individual connection changes via multiplexing in
# user-status. Note that `observe` is used instead of `observeChanges` because
# we're interested in the contents of the entire user document when someone goes
# online/offline or idle/active.
Meteor.startup ->

  Meteor.users.find({
    "admin": {$exists: false} # Excluding admin
    "status.online": true # User is online
  }).observe({
      added: userReconnect
      removed: userDisconnect
    })

  Meteor.users.find({
    "admin": {$exists: false} # Excluding admin
    "status.idle": true # User is idle
  }).observe({
    added: userIdle
  })

###
  Test handlers - assuming user-status is working correctly, we create these
  convenience functions for testing users coming online and offline

  TODO: we might want to make these tests end-to-end so that they ensure all of
  the user-status functionality is working as well.
###
TestUtils.connCallbacks = {
  sessionReconnect: (doc) ->
    sessionReconnect(doc)
    userReconnect( Meteor.users.findOne(doc.userId) )

  sessionDisconnect: (doc) ->
    userDisconnect( Meteor.users.findOne(doc.userId) )

  sessionIdle: (doc) ->
    # We need to set the status.lastActivity field here, as in user-status,
    # because the callback expects to read its value
    Meteor.users.update doc.userId,
      $set: {"status.lastActivity": doc.lastActivity }

    userIdle( Meteor.users.findOne(doc.userId) )

  sessionActive: sessionActive
}

###
  Methods
###

Meteor.methods
  "ts-set-username": (username) ->
    # TODO may need validation here due to bad browsers/bad people
    userId = Meteor.userId()
    return unless userId

    # No directOperation needed here since partitioner recognizes username as
    # a unique index
    if Meteor.users.findOne(username: username)?
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

    # Update worker contact info
    # TODO don't overwrite panel data if we don't need to.
    asst.setWorkerData(panel) if panel?

    # Destroy the token for this connection, so that a resume login will not
    # be used for future HITs. Returning true should cause the HIT to submit on
    # the client side, but if that doesn't work, the user will be logged out.
    if (token = Accounts._getLoginToken(this.connection.id))
      # This $pulls tokens from services.resume.loginTokens, and should work
      # in the same way that Accounts._expireTokens effects cleanup.
      Accounts.destroyToken(userId, token)

    # return true to auto submit the HIT
    return true

