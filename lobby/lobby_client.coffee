@Lobby = new Meteor.Collection("ts.lobby")

# Paths for lobby
Router.map ->
  @route "lobby",
    template: "tsLobby",
    layoutTemplate: "tsContainer"
    before: ->
      # Don't show lobby to unauthenticated users
      unless Meteor.user()
        console.log @setLayout
        @setLayout("tsContainer")
        @render("tsUserAccessDenied")
        @stop()

# Subscribe to lobby if we are in it (auto unsubscribe if we aren't)
Deps.autorun ->
  if TurkServer.inLobby()
    Meteor.subscribe("lobby")
    Router.go("/lobby")

Meteor.methods
  "toggleStatus" : ->
    userId = Meteor.userId()
    existing = Lobby.findOne(userId) if userId
    return unless userId and existing

    Lobby.update userId,
      $set: { status: not existing.status }

Template.tsLobby.lobbyInfo = -> Lobby.find()

Template.tsLobby.readyEnabled = ->
  return Lobby.find().count() >= TSConfig.findOne("lobbyThreshold").value and @_id is Meteor.userId()

Template.tsLobby.events =
  "click a.changeStatus": (ev) ->
    ev.preventDefault()

    Meteor.call "toggleStatus", (err, res) ->
      bootbox.alert err.reason if err
