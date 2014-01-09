userIdError = "No userId yet"
userNotInLobbyErr = "User not in lobby"

this.Lobby = new Meteor.Collection("lobby")

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
