# This controller handles the behavior of all admin templates
class TSAdminController extends RouteController
  onBeforeAction: (pause) ->
    # If not logged in, render login
    unless Meteor.user()
      @setLayout("tsContainer")
      @render("tsAdminLogin")
      pause()
      # If not admin, render access denied
    else unless Meteor.user().admin
      @setLayout("tsContainer")
      @render("tsAdminDenied")
      pause()
      # If admin but in a group, leave the group
    else if Partitioner.group()
      @setLayout("tsContainer")
      @render("tsAdminWatching")
      pause()
  layoutTemplate: "tsAdminLayout"

logSubErrors =
  onError: (e) -> console.log(e)

Router.map ->
  @route "overview",
    path: "/turkserver",
    controller: TSAdminController
    template: "tsAdminOverview"
  @route "mturk",
    path: "turkserver/mturk",
    controller: TSAdminController
    template: "tsAdminMTurk"
  @route "hits",
    path: "turkserver/hits",
    controller: TSAdminController
    template: "tsAdminHits"
  @route "workers",
    path: "turkserver/workers",
    controller: TSAdminController
    template: "tsAdminWorkers"
  @route "activeAssignments",
    path: "turkserver/assignments/active",
    controller: TSAdminController
    template: "tsAdminActiveAssignments"

  @route "completedAssignments",
    path: "turkserver/assignments/completed",
    controller: TSAdminController
    template: "tsAdminCompletedAssignments"

  @route "connections",
    path: "turkserver/connections",
    controller: TSAdminController
    template: "tsAdminConnections"
  @route "lobby",
    path: "turkserver/lobby",
    controller: TSAdminController
    template: "tsAdminLobby"

  @route "experiments",
    path: "turkserver/experiments/:days?/:limit?",
    controller: TSAdminController
    template: "tsAdminExperiments",
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      days = parseInt(@params.days) || 7
      limit = parseInt(@params.limit) || 200
      return [
        Meteor.subscribe("tsAdminBatchRunningExperiments", batchId, logSubErrors)
        Meteor.subscribe "tsAdminBatchCompletedExperiments", batchId, days, limit, logSubErrors
      ]
    data: ->
      days: @params.days || 7
      limit: @params.limit || 200

  @route "turkserver/logs/:groupId/:count",
    controller: TSAdminController
    template: "tsAdminLogs"
    waitOn: -> Meteor.subscribe("tsGroupLogs", @params.groupId, parseInt(@params.count))
    data: -> Experiments.findOne(@params.groupId)
  @route "manage",
    path: "turkserver/manage",
    controller: TSAdminController
    template: "tsAdminManage"

# Subscribe to admin data if we are an admin user.
# On rerun, subscription is automatically stopped
Deps.autorun ->
  Meteor.subscribe("tsAdmin") if TurkServer.isAdmin()

# Resubscribe when group changes
# Separate this one from the above to avoid re-runs for just a group change
Deps.autorun ->
  return unless TurkServer.isAdmin()
  # must pass in different args to actually effect it
  Meteor.subscribe("tsAdminState", Session.get("_tsViewingBatchId"), Partitioner.group())

# Extra admin user subscription for after experiment ended
Deps.autorun ->
  return unless TurkServer.isAdmin()
  Meteor.subscribe "tsGroupUsers", Partitioner.group()

pillPopoverEvents =
  # Show assignment instance info
  "mouseenter .ts-instance-pill-container": (e) ->
    container = $(e.target)

    container.popover({
      html: true
      placement: "auto right"
      trigger: "manual"
      container: container
      # TODO: Dynamic popover content would be very helpful here.
      # https://github.com/meteor/meteor/issues/2010#issuecomment-40532280
      content: Blaze.toHTML Blaze.With(UI.getElementData(e.target), -> Template.tsAdminAssignmentInstanceInfo)
    }).popover("show")

    container.one("mouseleave", -> container.popover("destroy") )

  # Show instance info in modal
  "click .ts-instance-pill-container": (e) ->
    TurkServer._displayModal UI.renderWithData(Template.tsAdminInstance, UI.getElementData(e.target).id)

  "mouseenter .ts-user-pill-container": (e) ->
    container = $(e.target)

    container.popover({
      html: true
      placement: "auto right"
      trigger: "manual"
      container: container
    # TODO: ditto
      content: Blaze.toHTML Blaze.With UI.getElementData(e.target), -> Template.tsUserPillPopover
    }).popover("show")

    container.one("mouseleave", -> container.popover("destroy") )

Template.turkserverPulldown.events
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

# Add the pill events as well
Template.turkserverPulldown.events(pillPopoverEvents)

Template.turkserverPulldown.admin = TurkServer.isAdmin
Template.turkserverPulldown.currentExperiment = -> Experiments.findOne()

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

Template.tsAdminLayout.events(pillPopoverEvents)

onlineUsers = -> Meteor.users.find({
  admin: {$exists: false},
  "status.online": true
})

Template.tsAdminOverview.events =
  "click .-ts-account-balance": ->
    Meteor.call "ts-admin-account-balance", (err, res) ->
      if err then bootbox.alert(err.reason) else bootbox.alert("<h3>$#{res.toFixed(2)}</h3>")

Template.tsAdminOverview.onlineUserCount = -> onlineUsers().count()

Template.tsAdminOverview.lobbyUserCount = -> LobbyStatus.find().count()
Template.tsAdminOverview.activeExperiments = -> Experiments.find().count()

# All non-admin users who are online, sorted by most recent login
Template.tsAdminConnections.users = ->
  Meteor.users.find({
    admin: {$exists: false}
    "turkserver.state": {$exists: true}
  }, {
    sort: { "status.lastLogin.date" : -1 }
  })

Template.tsAdminConnectionMaintenance.events
  "click .-ts-cleanup-user-state": ->
    Meteor.call "ts-admin-cleanup-user-state", (err, res) ->
      bootbox.alert(err.reason) if err?
