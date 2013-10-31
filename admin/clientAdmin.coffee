Package['iron-router']?.Router.map ->
  @route "turkserver/:page?",
    layoutTemplate: "tsAdminLayout"
    before: ->
      unless Meteor.user()
        @render("tsAdminLogin")
        @stop()
      else unless Meteor.user().admin
        @render("tsAdminDenied")
        @stop()
    action: ->
      switch @params?.page
        when "hits" then @render("tsAdminHits")
        when "users" then @render("tsAdminUsers")
        when "lobby" then @render("tsAdminLobby")
        when "experiments" then @render("tsAdminExperiments")
        else @render("tsAdminOverview")

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

# All non-admin users
Template.tsAdminUsers.users = -> Meteor.users.find({admin: {$exists: false}})
