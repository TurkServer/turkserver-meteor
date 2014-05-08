EventEmitter = Npm.require('events').EventEmitter

# TODO add index on LobbyStatus if needed

class TurkServer.Lobby
  constructor: (@batchId) ->
    @events = new EventEmitter()

  addUser: (userId) ->
    # Insert or update status in lobby
    LobbyStatus.upsert userId,
      # Simply {status: false} caused https://github.com/meteor/meteor/issues/1552
      $set:
        batchId: @batchId
        status: false

    Meteor.users.update userId,
      $set:
        "turkserver.state": "lobby"

    Meteor.defer => @events.emit "user-join", userId

  getUsers: (selector) ->
    selector = _.extend selector || {},
      batchId: @batchId
    LobbyStatus.find(selector).fetch()

  toggleStatus: (userId) ->
    existing = LobbyStatus.findOne(userId)
    throw new Meteor.Error(403, ErrMsg.userNotInLobbyErr) unless existing
    newStatus = not existing.status
    LobbyStatus.update userId,
      $set: { status: newStatus }

    Meteor.defer => @events.emit "user-status", userId, newStatus

  # Takes a group of users from the lobby without triggering the user-leave event.
  pluckUsers: (userIds) ->
    LobbyStatus.remove {_id : $in: userIds }

  removeUser: (userId) ->
    if LobbyStatus.remove(userId) > 0
      Meteor.defer => @events.emit "user-leave", userId

# Publish lobby contents for a particular batch
Meteor.publish "lobby", (batchId) ->
  LobbyStatus.find( {batchId} )

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
