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

# TODO only publish the lobby to users who are actually in it
Meteor.publish "lobby", -> Lobby.find()

# Reactive computation for enabling/disabling lobby
Deps.autorun ->
  return if Batches.findOne(active: true)?.lobby
  # TODO Lobby was disabled - kick people out
