TurkServer.adminSettings =
  # Thresholds for ghetto pagination
  defaultDaysThreshold: 7
  defaultLimit: 200

# This controller handles the behavior of all admin templates
class TSAdminController extends RouteController
  onBeforeAction: ->
    # If not logged in, render login
    unless Meteor.user()
      @layout("tsContainer")
      @render("tsAdminLogin")
      # If not admin, render access denied
    else unless Meteor.user().admin
      @layout("tsContainer")
      @render("tsAdminDenied")
    else
      @next()

  # Using subscriptions here is safe as long as everything else below uses waitOn
  subscriptions: ->
    return [] unless TurkServer.isAdmin()

    # Subscribe to admin data if we are an admin user, and in the admin interface
    # Re-subscribes should be a no-op; no arguments
    subs = [ Meteor.subscribe("tsAdmin") ]

    # Subscribe to user data and resubscribe when group changes
    # Only subscribe if in admin interface, or assigned to a group
    # TODO this should grab the group in watch mode as well - or maybe not, it can be handled by implementer publications
    group = Partitioner.group()

    # must pass in different args for group to actually effect changes
    subs.push Meteor.subscribe("tsAdminUsers", group)

    return subs

  layoutTemplate: "tsAdminLayout"

logSubErrors =
  onError: (e) -> console.log(e)

Router.map ->
  @route "tsOverview",
    path: "/turkserver",
    controller: TSAdminController
    template: "tsAdminOverview"
  @route "tsMturk",
    path: "turkserver/mturk",
    controller: TSAdminController
    template: "tsAdminMTurk"
  @route "tsHits",
    path: "turkserver/hits",
    controller: TSAdminController
    template: "tsAdminHits"
  # No sub needed - done with autocomplete
  @route "tsWorkers",
    path: "turkserver/workers/:workerId?",
    controller: TSAdminController
    template: "tsAdminWorkers"
    waitOn: ->
      return unless (workerId = this.params.workerId)?
      Meteor.subscribe("tsAdminWorkerData", workerId)
    data: ->
      workerId: this.params.workerId

  @route "tsPanel",
    path: "turkserver/panel",
    controller: TSAdminController
    template: "tsAdminPanel"
    waitOn: -> Meteor.subscribe("tsAdminWorkers")

  @route "tsActiveAssignments",
    path: "turkserver/assignments/active",
    controller: TSAdminController
    template: "tsAdminActiveAssignments"
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      return Meteor.subscribe("tsAdminActiveAssignments", batchId)

  @route "tsCompletedAssignments",
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

  @route "tsConnections",
    path: "turkserver/connections",
    controller: TSAdminController
    template: "tsAdminConnections"
  @route "tsLobby",
    path: "turkserver/lobby",
    controller: TSAdminController
    template: "tsAdminLobby"
    waitOn: ->
      return unless (batchId = Session.get("_tsViewingBatchId"))?
      # Same sub as normal lobby clients
      return Meteor.subscribe("lobby", batchId)

  @route "tsExperiments",
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

  @route "tsLogs",
    path: "turkserver/logs/:groupId/:count",
    controller: TSAdminController
    template: "tsAdminLogs"
    waitOn: -> Meteor.subscribe("tsGroupLogs", @params.groupId, parseInt(@params.count))
    data: ->
      instance: @params.groupId
      count: @params.count

  @route "tsManage",
    path: "turkserver/manage",
    controller: TSAdminController
    template: "tsAdminManage"

# Extra admin user subscription for after experiment ended
Deps.autorun ->
  return unless TurkServer.isAdmin()
  return unless (group = Partitioner.group())?
  Meteor.subscribe "tsGroupUsers", group

TurkServer.showInstanceModal = (id) ->
  TurkServer._displayModal Template.tsAdminInstance, id

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
      content: Blaze.toHTMLWithData Template.tsAdminAssignmentInstanceInfo, Blaze.getData(e.target)
    }).popover("show")

    container.one("mouseleave", -> container.popover("destroy") )

  # Show instance info in modal
  "click .ts-instance-pill-container": (e) ->
    TurkServer.showInstanceModal Blaze.getData(e.target).id

  "mouseenter .ts-user-pill-container": (e) ->
    container = $(e.target)

    container.popover({
      html: true
      placement: "auto right"
      trigger: "manual"
      container: container
    # TODO: ditto
      content: Blaze.toHTMLWithData Template.tsUserPillPopover, Blaze.getData(e.target)
    }).popover("show")

    container.one("mouseleave", -> container.popover("destroy") )

Template.turkserverPulldown.events
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

# Add the pill events as well
Template.turkserverPulldown.events(pillPopoverEvents)

Template.turkserverPulldown.helpers
  admin: TurkServer.isAdmin
  currentExperiment: -> Experiments.findOne()

Template.tsAdminLogin.events =
  "submit form": (e, tp) ->
    e.preventDefault()
    password = $(tp.find("input")).val()
    Meteor.loginWithPassword "admin", password, (err) ->
      bootbox.alert("Unable to login: " + err.reason) if err?

Template.tsAdminLayout.events(pillPopoverEvents)

onlineUsers = -> Meteor.users.find({
  admin: {$exists: false},
  "status.online": true
})

Template.tsAdminOverview.events =
  "click .-ts-account-balance": ->
    Meteor.call "ts-admin-account-balance", (err, res) ->
      if err then bootbox.alert(err.reason) else bootbox.alert("<h3>$#{res}</h3>")

Template.tsAdminOverview.helpers
  onlineUserCount: -> onlineUsers().count()

# All non-admin users who are online, sorted by most recent login
Template.tsAdminConnections.helpers
  users: ->
    Meteor.users.find({
      admin: {$exists: false}
      "turkserver.state": {$exists: true}
    }, {
      sort: { "status.lastLogin.date" : -1 }
    })

Template.tsAdminConnectionMaintenance.events
  "click .-ts-cleanup-user-state": ->
    TurkServer.callWithModal("ts-admin-cleanup-user-state")
