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
  user.group takes a moment to be propagated.
###
sessionReconnect = (doc) ->
  return unless getUserNonAdmin(doc.userId)?

  asst = TurkServer.Assignment.getCurrentUserAssignment(doc.userId)

  # TODO possible debug message, but probably caught below.
  return unless asst?

  # Save IP address and UA; multiple connections from different IPs/browsers
  # are recorded for diagnostic purposes.
  asst._update
    $addToSet: {
      ipAddr: doc.ipAddr
      userAgent: doc.userAgent
    }

userReconnect = (user) ->
  asst = TurkServer.Assignment.getCurrentUserAssignment(user._id)

  unless asst?
    Meteor._debug("#{user._id} reconnected but has no active assignment")
    # TODO maybe kick this user out and show an error
    return

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

  # If they are disconnecting after completing an assignment, there will be no
  # current assignment.
  return unless asst?

  # If user was in lobby, remove them
  asst._removeFromLobby()

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
    # TODO update API for writing panel data.
    # TODO don't overwrite panel data if we don't need to.
    if panel?
      asst.setWorkerData {
        contact: panel.contact
        available: {
          times: panel.times
          updated: new Date
        }
      }

    # Destroy the token for this connection, so that a resume login will not
    # be used for future HITs. Returning true should cause the HIT to submit on
    # the client side, but if that doesn't work, the user will be logged out.
    if (token = Accounts._getLoginToken(this.connection.id))
      # This $pulls tokens from services.resume.loginTokens, and should work
      # in the same way that Accounts._expireTokens effects cleanup.
       Meteor.setTimeout ->
        Accounts.destroyToken(userId, token)
      , 1000

    # return true to auto submit the HIT
    return true

