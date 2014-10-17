Template.tsAdminLobby.helpers
  lobbyUsers: -> LobbyStatus.find()

Template.tsAdminLobbyHeader.events =
  "submit form": (e, t) ->
    e.preventDefault()
    event = t.$("input[name=lobby-event]").val()
    Meteor.call "ts-admin-lobby-event", Session.get("_tsViewingBatchId"), event, (err, res) ->
      bootbox.alert(err) if err

Template.tsAdminLobbyHeader.helpers
  count: -> LobbyStatus.find().count()
