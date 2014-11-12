
# Paths for lobby
Router.map ->
  @route "lobby",
    template: "tsBasicLobby",
    layoutTemplate: "tsContainer"
    onBeforeAction: ->
      # Don't show lobby to unauthenticated users
      unless Meteor.user()
        @layout("tsContainer")
        @render("tsUserAccessDenied")
      else
        @next()

# We need to defer this because of IR crap, as usual
Meteor.startup ->
  Meteor.defer ->
    # Subscribe to lobby if we are in it (auto unsubscribe if we aren't)
    Deps.autorun ->
      return if Package?.tinytest # Don't change routes when being tested
      if TurkServer.inLobby()
        # TODO this needs to subscribe by batch
        Meteor.subscribe("lobby", TurkServer.batch()?._id)
        Router.go("/lobby")

Meteor.methods
  "toggleStatus" : ->
    userId = Meteor.userId()
    existing = LobbyStatus.findOne(userId) if userId
    return unless userId and existing

    LobbyStatus.update userId,
      $set: { status: not existing.status }

Template.tsBasicLobby.helpers
  count: -> LobbyStatus.find().count()
  lobbyInfo: -> LobbyStatus.find()
  identifier: -> Meteor.users.findOne(@_id)?.username || "<i>unnamed user</i>"

Template.tsLobby.helpers
  lobbyInfo: -> LobbyStatus.find()
  identifier: -> Meteor.users.findOne(@_id)?.username || @_id
  readyEnabled: ->
    return LobbyStatus.find().count() >= TSConfig.findOne("lobbyThreshold").value and @_id is Meteor.userId()

Template.tsLobby.events =
  "click a.changeStatus": (ev) ->
    ev.preventDefault()

    Meteor.call "toggleStatus", (err, res) ->
      bootbox.alert err.reason if err
