@Lobby = new Meteor.Collection("ts.lobby")

# Publish lobby contents
Meteor.publish "lobby", -> Lobby.find()

# Publish lobby groupsize information for active batches with lobby and grouping
Meteor.publish null, ->
  sub = this
  subHandle = Batches.find({
    active: true
    lobby: true
    grouping: "groupSize"
    groupVal: { $exists: true }
  },
    fields: { groupVal: 1 }
  ).observeChanges
    added: (id, fields) ->
      sub.added "ts.config", "lobbyThreshold", { value: fields.groupVal }
    changed: (id, fields) ->
      sub.changed "ts.config", "lobbyThreshold", { value: fields.groupVal }
    removed: (id) ->
      sub.removed "ts.config", "lobbyThreshold"

  sub.ready()
  sub.onStop -> subHandle.stop()

TurkServer.addToLobby = (userId) ->
  # Insert or update status in lobby
  Lobby.upsert userId,
    $set: {status: false} # Simply {status: false} caused https://github.com/meteor/meteor/issues/1552

  Meteor.users.update userId,
    $set:
      "turkserver.state": "lobby"

# Check for lobby state
Meteor.methods
  "toggleStatus" : ->
    userId = Meteor.userId()
    existing = Lobby.findOne(userId) if userId

    throw new Meteor.error(403, ErrMsg.userIdErr) unless userId
    throw new Meteor.error(403, ErrMsg.userNotInLobbyErr) unless existing

    Lobby.update userId,
      $set: { status: not existing.status }

    @unblock()
    checkLobbyState()

# Clear lobby status on startup
Meteor.startup ->
  Lobby.remove {}

# Remove disconnected users from lobby
# TODO make this more robust
UserStatus.on "sessionLogout", (doc) ->
  Lobby.remove doc.userId

# Check for adding people in lobby to an experiment
checkLobbyState = ->
  # Depend on active batch having lobby
  activeBatch = Batches.findOne
    active: true
    grouping: "groupSize"
    lobby: true
    groupVal: {$exists: 1}
  return unless activeBatch?

  # Depend on lobby contents
  users = Lobby.find({ status: true }).fetch()
  return if users.length < activeBatch.groupVal

  userIds = _.pluck(users, "_id")
  Lobby.remove {_id : $in: userIds }
  TurkServer.assignAllUsers userIds

# TODO Reactively enabling/disabling lobby - if Lobby was disabled, kick people out
