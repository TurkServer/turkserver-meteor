userIdError = "No userId yet"
userNotInLobbyErr = "User not in lobby"

@TurkServer = @TurkServer || {}

this.Lobby = new Meteor.Collection("lobby")

TurkServer.addToLobby = (userId) ->
  Lobby.insert
    _id: userId
    status: false

  Meteor.users.update userId,
    $set:
      "turkserver.state": "lobby"

Meteor.methods
  "toggleStatus" : ->
    userId = Meteor.userId()
    existing = Lobby.findOne(userId) if userId

    if Meteor.isServer
      throw new Meteor.error(403, userIdError) unless userId
      throw new Meteor.error(403, userNotInLobbyErr) unless existing
    else
      return unless userId and existing

    Lobby.update userId,
      $set: { status: not existing.status }

if Meteor.isServer
  # Clear lobby status on startup
  Meteor.startup ->
    Lobby.remove {}

  # Remove disconnected users from lobby
  # TODO make this more robust
  UserStatus.on "sessionLogout", (userId, sessionId) ->
    Lobby.remove userId

  # TODO only publish the lobby to users who are actually in it
  Meteor.publish "lobby", -> Lobby.find()
