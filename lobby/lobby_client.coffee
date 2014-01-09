# TODO get this setting from somewhere
groupSize = 2

# Subscribe to lobby if we are in it (auto unsubscribe if we aren't)
Deps.autorun ->
  if TurkServer.inLobby()
    Meteor.subscribe("lobby")
    Package['iron-router']?.Router.go("/lobby")

Template.tsLobby.lobbyInfo = -> Lobby.find()

Template.tsLobby.readyEnabled = ->
  return Lobby.find().count() >= groupSize and @_id is Meteor.userId()

Template.tsLobby.events =
  "click a.changeStatus": (ev) ->
    ev.preventDefault()

    Meteor.call "toggleStatus", (err, res) ->
      bootbox.alert err.reason if err
