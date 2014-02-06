Router.map ->
  @route "turkserver",
    path: "turkserver/:page?"
    layoutTemplate: "tsAdminLayout"
    before: ->
      # If not logged in, render login
      unless Meteor.user()
        @setLayout("tsContainer")
        @render("tsAdminLogin")
        @stop()
      # If not admin, render access denied
      else unless Meteor.user().admin
        @setLayout("tsContainer")
        @render("tsAdminDenied")
        @stop()
      # If admin but in a group, leave the group
      else if TurkServer.group()
        @setLayout("tsContainer")
        @render("tsAdminWatching")
        @stop()
    action: ->
      switch @params?.page
        when "mturk" then @render("tsAdminMTurk")
        when "hits" then @render("tsAdminHits")
        when "workers" then @render("tsAdminWorkers")
        when "connections" then @render("tsAdminConnections")
        when "lobby" then @render("tsAdminLobby")
        when "experiments" then @render("tsAdminExperiments")
        when "manage" then @render("tsAdminManage")
        else @render("tsAdminOverview")
      return

# Subscribe to admin data if we are an admin user.
# On rerun, subscription is automatically stopped
Deps.autorun ->
  Meteor.subscribe("tsAdmin") if Meteor.user()?.admin

# Resubscribe when group changes
# Separate this one from the above to avoid re-runs for just a group change
Deps.autorun ->
  return unless Meteor.user()?.admin
  # must pass in different args to actually effect it
  Meteor.subscribe("tsAdminState", TurkServer.group())

# Extra admin user subscription for after experiment ended
Deps.autorun ->
  return unless Meteor.user()?.admin
  Meteor.subscribe "tsGroupUsers", TurkServer.group()

Template.turkserverPulldown.events =
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

Template.turkserverPulldown.admin = -> Meteor.user()?.admin

Template.tsAdminGroupInfo.group = -> TurkServer.group()
Template.tsAdminGroupInfo.treatment = -> TurkServer.treatment()
Template.tsAdminGroupInfo.users = -> Meteor.users.find()

Template.tsAdminLogin.events =
  "submit form": (e, tp) ->
    e.preventDefault()
    password = $(tp.find("input")).val()
    Meteor.loginWithPassword "admin", password, (err) ->
      bootbox.alert("Unable to login: " + err.reason) if err?

Template.tsAdminWatching.events =
  "click .-ts-watch-experiment": ->
    Router.go(Meteor.settings?.public?.turkserver?.watchRoute || "/")
  "click .-ts-leave-experiment": ->
    Meteor.call "ts-admin-leave-group", (err, res) ->
      bootbox.alert(err.reason) if err

onlineUsers = -> Meteor.users.find(admin: {$exists: false}, "status.online": true)

Template.tsAdminOverview.onlineUserCount = -> onlineUsers().count()

Template.tsAdminOverview.lobbyUserCount = -> LobbyStatus.find().count()
Template.tsAdminOverview.activeExperiments = -> Experiments.find().count()

# All non-admin users who are online
Template.tsAdminConnections.users = ->
  Meteor.users.find
    admin: {$exists: false}
    "turkserver.state": {$exists: true}
