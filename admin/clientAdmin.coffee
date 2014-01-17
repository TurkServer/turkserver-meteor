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
      # If admin but in a group, leave the group
      else if TurkServer.group()
        Meteor.call "ts-admin-leave-group", (err, res) ->
          bootbox.alert(err.reason) if err
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

# Subscribe to admin data if we are an admin user.
# On rerun, subscription is automatically stopped
Deps.autorun ->
  Meteor.subscribe("tsAdmin") if Meteor.user()?.admin

# Resubscribe when group changes
# Separate this one from the above to avoid re-runs for just a group change
Deps.autorun ->
  return unless Meteor.user()?.admin
  # must pass in different args to actually effect it
  Meteor.subscribe("tsAdminUsers", TurkServer.group())

Template.tsAdminLogin.events =
  "submit form": (e, tp) ->
    e.preventDefault()
    password = $(tp.find("input")).val()
    Meteor.loginWithPassword "admin", password, (err) ->
      bootbox.alert("Unable to login: " + err.reason) if err?

onlineUsers = -> Meteor.users.find(admin: {$exists: false}, "status.online": true)

Template.tsAdminOverview.onlineUserCount = -> onlineUsers().count()

Template.tsAdminOverview.lobbyUserCount = -> LobbyStatus.find().count()
Template.tsAdminOverview.activeExperiments = -> Experiments.find().count()

# All non-admin users who are online
Template.tsAdminUsers.users = onlineUsers
