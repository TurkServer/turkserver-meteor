# TODO get this setting from somewhere
groupSize = 2

Meteor.subscribe("lobby")

Template.waitingLobby.lobbyInfo = -> Lobby.find()

Template.waitingLobby.readyEnabled = ->
  return Lobby.find().count() >= groupSize and @_id is Meteor.userId()

Template.waitingLobby.events =
  "click a.changeStatus": (ev) ->
    ev.preventDefault()

    Meteor.call "toggleStatus", (err, res) ->
      bootbox.alert err.reason if err
