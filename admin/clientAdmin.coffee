Router.map ->
  @route "turkserver/:page?",
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
      # If admin but in a group, make button to leave group
      else if TurkServer.group()
        @setLayout("tsContainer")
        @render("tsAdminLeaveGroup")
        @stop()
    action: ->
      switch @params?.page
        when "hits" then @render("tsAdminHits")
        when "users" then @render("tsAdminUsers")
        when "lobby" then @render("tsAdminLobby")
        when "experiments" then @render("tsAdminExperiments")
        when "manage" then @render("tsAdminManage")
        else @render("tsAdminOverview")
      return

Template.turkserverPulldown.events =
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

# Subscribe to admin data if we are an admin users
adminSubscription = null
Deps.autorun ->
  if Meteor.user()?.admin
    adminSubscription = Meteor.subscribe("tsAdmin")
  else
    adminSubscription?.stop()
    adminSubscription = null

Template.tsAdminLogin.events =
  "submit form": (e, tp) ->
    e.preventDefault()
    password = $(tp.find("input")).val()
    Meteor.loginWithPassword "admin", password, (err) ->
      bootbox.alert("Unable to login: " + err.reason) if err?

Template.tsAdminOverview.onlineUserCount = -> Meteor.users.find(
    admin: {$exists: false}
    "status.online": true
  ).count()

Template.tsAdminOverview.lobbyUserCount = -> LobbyStatus.find().count()
Template.tsAdminOverview.activeExperiments = -> Experiments.find().count()

# All non-admin users who are online
Template.tsAdminUsers.users = ->
  Meteor.users.find
    admin: {$exists: false}
    "status.online": true
