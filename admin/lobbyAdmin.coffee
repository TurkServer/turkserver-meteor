Template.tsAdminLobby.lobbyUsers = -> LobbyStatus.find()

Template.tsAdminLobbyStatus.noBatchActive = -> not Batches.findOne(active: true)

Template.tsAdminLobbyStatus.lobbyDisabled = ->
  Batches.findOne(active: true)?.lobby is false

Template.tsAdminLobbyHeader.count = -> LobbyStatus.find().count()
