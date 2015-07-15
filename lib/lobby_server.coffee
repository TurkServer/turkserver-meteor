EventEmitter = Npm.require('events').EventEmitter

# TODO add index on LobbyStatus if needed

class TurkServer.Lobby
  constructor: (@batchId) ->
    check(@batchId, String)
    @events = new EventEmitter()

  addAssignment: (asst) ->
    throw new Error("unexpected batchId") if asst.batchId isnt @batchId

    # Insert or update status in lobby
    LobbyStatus.upsert asst.userId,
      # Simply {status: false} caused https://github.com/meteor/meteor/issues/1552
      $set:
        batchId: @batchId
        asstId: asst.asstId

    Meteor.users.update asst.userId,
      $set:
        "turkserver.state": "lobby"

    Meteor.defer => @events.emit "user-join", asst

  getAssignments: (selector) ->
    selector = _.extend selector || {},
      batchId: @batchId
    TurkServer.Assignment.getAssignment(record.asstId) for record in LobbyStatus.find(selector).fetch()

  # TODO move status updates into specific assigners
  toggleStatus: (userId) ->
    existing = LobbyStatus.findOne(userId)
    throw new Meteor.Error(403, ErrMsg.userNotInLobbyErr) unless existing
    newStatus = not existing.status
    LobbyStatus.update userId,
      $set: { status: newStatus }

    asst = TurkServer.Assignment.getCurrentUserAssignment(userId)
    Meteor.defer => @events.emit "user-status", asst, newStatus

  # Takes a group of users from the lobby without triggering the user-leave event.
  pluckUsers: (userIds) ->
    LobbyStatus.remove {_id : $in: userIds }

  removeAssignment: (asst) ->
    # TODO check for batchId here
    if LobbyStatus.remove(asst.userId) > 0
      Meteor.defer => @events.emit "user-leave", asst

# Publish lobby contents for a particular batch, as well as users
# TODO can we simplify this by publishing users with turkserver.state = "lobby",
# if we use batch IDs in a smart way?
Meteor.publish "lobby", (batchId) ->
  sub = this

  handle = LobbyStatus.find({batchId}).observeChanges
    added: (id, fields) ->
      sub.added("ts.lobby", id, fields)
      sub.added("users", id, Meteor.users.findOne(id, fields: username: 1))
    changed: (id, fields) ->
      sub.changed("ts.lobby", id, fields)
    removed: (id) ->
      sub.removed("ts.lobby", id)
      sub.removed("users", id)

  sub.ready()
  sub.onStop -> handle.stop()

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

    TurkServer.Batch.currentBatch().lobby.toggleStatus(userId)
    @unblock()


# Clear lobby status on startup
# Just clear lobby users for assignment, but not lobby state
Meteor.startup ->
  LobbyStatus.remove {}

#  Meteor.users.update { "turkserver.state": "lobby" },
#    $unset: {"turkserver.state": null}
#  , {multi: true}
