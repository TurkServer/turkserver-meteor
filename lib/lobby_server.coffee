@LobbyStatus = new Meteor.Collection("ts.lobby")

class TurkServer.Lobby
  @addUser: (userId) ->
    # Insert or update status in lobby
    LobbyStatus.upsert userId,
      # Simply {status: false} caused https://github.com/meteor/meteor/issues/1552
      $set: {status: false}

    Meteor.users.update userId,
      $set:
        "turkserver.state": "lobby"

  @toggleStatus: (userId) ->
    existing = LobbyStatus.findOne(userId)
    throw new Meteor.Error(403, ErrMsg.userNotInLobbyErr) unless existing
    LobbyStatus.update userId,
      $set: { status: not existing.status }

  @removeUser: (userId) ->
    LobbyStatus.remove(userId)

  # Check for adding people in lobby to an experiment
  @checkState = ->
    activeBatch = Batches.findOne
      active: true
      grouping: "groupSize"
      lobby: true
      groupVal: {$exists: 1}
    return unless activeBatch?

    users = LobbyStatus.find({ status: true }, { limit: activeBatch.groupVal }).fetch()
    return if users.length < activeBatch.groupVal

    userIds = _.pluck(users, "_id")
    LobbyStatus.remove {_id : $in: userIds }
    TurkServer.assignAllUsers userIds

# Publish lobby contents
Meteor.publish "lobby", -> LobbyStatus.find()

# Publish lobby config information for active batches with lobby and grouping
# TODO publish this based on the batch of the active user
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

# Check for lobby state
Meteor.methods
  "toggleStatus" : ->
    userId = Meteor.userId()
    throw new Meteor.error(403, ErrMsg.userIdErr) unless userId

    TurkServer.Lobby.toggleStatus(userId)
    @unblock()

    TurkServer.Lobby.checkState()

# Clear lobby status on startup
Meteor.startup ->
  LobbyStatus.remove {}

  Meteor.users.update { "turkserver.state": "lobby" },
    $unset: {"turkserver.state": null}
  , {multi: true}
