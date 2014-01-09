Meteor.publish "lobby", -> Lobby.find()

TurkServer.addToLobby = (userId) ->
  # Insert or update status in lobby
  Lobby.upsert userId,
    $set: {status: false} # Simply {status: false} caused https://github.com/meteor/meteor/issues/1552

  Meteor.users.update userId,
    $set:
      "turkserver.state": "lobby"

# Clear lobby status on startup
Meteor.startup ->
  Lobby.remove {}

# Remove disconnected users from lobby
# TODO make this more robust
UserStatus.on "sessionLogout", (doc) ->
  Lobby.remove doc.userId

# Add people in lobby to an experiment
Deps.autorun ->
  activeBatch = Batches.findOne(active: true)
  return unless activeBatch? and activeBatch.grouping is "groupSize"

  users = Lobby.find({ status: true }, fields: {_id: 1}).fetch()
  return if users.length < activeBatch.groupVal

  userIds = _.pluck(users, "_id")
  Lobby.remove {_id : $in: userIds }
  TurkServer.assignAllUsers userIds

# Reactive computation for enabling/disabling lobby
Deps.autorun ->
  return if Batches.findOne(active: true)?.lobby
  # TODO Lobby was disabled - kick people out
