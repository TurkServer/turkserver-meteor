Template.tsAdminLobby.lobbyUsers = -> LobbyStatus.find()

Template.tsAdminLobbyHeader.count = -> LobbyStatus.find().count()
