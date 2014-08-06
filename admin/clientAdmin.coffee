TurkServer.adminSettings =
  # Thresholds for ghetto pagination
  defaultDaysThreshold: 7
  defaultLimit: 200

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
  # No sub needed - done with autocomplete
  @route "workers",
    path: "turkserver/workers/:workerId?",
    controller: TSAdminController
    template: "tsAdminWorkers"
    waitOn: ->
      return unless (workerId = this.params.workerId)?
      Meteor.subscribe("tsAdminWorkerData", workerId)
    data: ->
      workerId: this.params.workerId

  @route "panel",
    path: "turkserver/panel",
    controller: TSAdminController
    template: "tsAdminPanel"
    waitOn: -> Meteor.subscribe("tsAdminWorkers")

  @route "activeAssignments",
    path: "turkserver/assignments/active",
    controller: TSAdminController
    template: "tsAdminActiveAssignments"
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      return Meteor.subscribe("tsAdminActiveAssignments", batchId)

  @route "completedAssignments",
    path: "turkserver/assignments/completed/:days?/:limit?",
    controller: TSAdminController
    template: "tsAdminCompletedAssignments"
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      days = parseInt(@params.days) || TurkServer.adminSettings.defaultDaysThreshold
      limit = parseInt(@params.limit) || TurkServer.adminSettings.defaultLimit
      return Meteor.subscribe("tsAdminCompletedAssignments", batchId, days, limit)
    data: ->
      days: @params.days || TurkServer.adminSettings.defaultDaysThreshold
      limit: @params.limit || TurkServer.adminSettings.defaultLimit

  @route "connections",
    path: "turkserver/connections",
    controller: TSAdminController
    template: "tsAdminConnections"
  @route "lobby",
    path: "turkserver/lobby",
    controller: TSAdminController
    template: "tsAdminLobby"
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      # Same sub as normal lobby clients
      return Meteor.subscribe("lobby", batchId)

  @route "experiments",
    path: "turkserver/experiments/:days?/:limit?",
    controller: TSAdminController
    template: "tsAdminExperiments",
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      days = parseInt(@params.days) || TurkServer.adminSettings.defaultDaysThreshold
      limit = parseInt(@params.limit) || TurkServer.adminSettings.defaultLimit
      return [
        Meteor.subscribe("tsAdminBatchRunningExperiments", batchId, logSubErrors)
        Meteor.subscribe "tsAdminBatchCompletedExperiments", batchId, days, limit, logSubErrors
      ]
    data: ->
      days: @params.days || TurkServer.adminSettings.defaultDaysThreshold
      limit: @params.limit || TurkServer.adminSettings.defaultLimit

  @route "logs",
    path: "turkserver/logs/:groupId/:count",
    controller: TSAdminController
    template: "tsAdminLogs"
    waitOn: -> Meteor.subscribe("tsGroupLogs", @params.groupId, parseInt(@params.count))
    data: ->
      instance: @params.groupId
      count: @params.count

  @route "manage",
    path: "turkserver/manage",
    controller: TSAdminController
    template: "tsAdminManage"

###
   Subscribe to admin data if we are an admin user, and in the admin interface
###
Deps.autorun ->
  path = Router.current()?.path
  return unless path?.indexOf("/turkserver") >= 0 and TurkServer.isAdmin()
  # Re-subscribes should be a no-op; no arguments
  Meteor.subscribe("tsAdmin")

###
  Subscribe to user data and resubscribe when group changes
  Separated from the above to avoid re-runs for just a group change
###
Deps.autorun ->
  return unless TurkServer.isAdmin()
  path = Router.current()?.path
  # Only subscribe if in admin interface, or assigned to a group
  return unless path?.indexOf("/turkserver") >= 0 or (group = Partitioner.group())?
  # must pass in different args for group to actually effect changes
  Meteor.subscribe("tsAdminUsers", group)

# Extra admin user subscription for after experiment ended
Deps.autorun ->
  return unless TurkServer.isAdmin()
  return unless (group = Partitioner.group())?
  Meteor.subscribe "tsGroupUsers", group

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
