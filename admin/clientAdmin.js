/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
TurkServer.adminSettings = {
  // Thresholds for ghetto pagination
  defaultDaysThreshold: 7,
  defaultLimit: 200
};

// This controller handles the behavior of all admin templates
class TSAdminController extends RouteController {
  static initClass() {
  
    this.prototype.layoutTemplate = "tsAdminLayout";
  }
  onBeforeAction() {
    // If not logged in, render login
    if (!Meteor.user()) {
      this.layout("tsContainer");
      return this.render("tsAdminLogin");
      // If not admin, render access denied
    } else if (!Meteor.user().admin) {
      this.layout("tsContainer");
      return this.render("tsAdminDenied");
    } else {
      return this.next();
    }
  }

  // Using subscriptions here is safe as long as everything else below uses waitOn
  subscriptions() {
    if (!TurkServer.isAdmin()) { return []; }

    // Subscribe to admin data if we are an admin user, and in the admin interface
    // Re-subscribes should be a no-op; no arguments
    const subs = [ Meteor.subscribe("tsAdmin") ];

    // Subscribe to user data and resubscribe when group changes
    // Only subscribe if in admin interface, or assigned to a group
    // TODO this should grab the group in watch mode as well - or maybe not, it can be handled by implementer publications
    const group = Partitioner.group();

    // must pass in different args for group to actually effect changes
    subs.push(Meteor.subscribe("tsAdminUsers", group));

    return subs;
  }
}
TSAdminController.initClass();

const logSubErrors =
  {onError(e) { return console.log(e); }};

Router.map(function() {
  this.route("tsOverview", {
    path: "/turkserver",
    controller: TSAdminController,
    template: "tsAdminOverview"
  }
  );
  this.route("tsMturk", {
    path: "turkserver/mturk",
    controller: TSAdminController,
    template: "tsAdminMTurk"
  }
  );
  this.route("tsHits", {
    path: "turkserver/hits",
    controller: TSAdminController,
    template: "tsAdminHits"
  }
  );
  // No sub needed - done with autocomplete
  this.route("tsWorkers", {
    path: "turkserver/workers/:workerId?",
    controller: TSAdminController,
    template: "tsAdminWorkers",
    waitOn() {
      let workerId;
      if ((workerId = this.params.workerId) == null) { return; }
      return Meteor.subscribe("tsAdminWorkerData", workerId);
    },
    data() {
      return {workerId: this.params.workerId};
    }
  }
  );

  this.route("tsPanel", {
    path: "turkserver/panel",
    controller: TSAdminController,
    template: "tsAdminPanel",
    waitOn() { return Meteor.subscribe("tsAdminWorkers"); }
  }
  );

  this.route("tsActiveAssignments", {
    path: "turkserver/assignments/active",
    controller: TSAdminController,
    template: "tsAdminActiveAssignments",
    waitOn() {
      let batchId;
      if ((batchId = Session.get("_tsViewingBatchId")) == null) { return; }
      return Meteor.subscribe("tsAdminActiveAssignments", batchId);
    }
  }
  );

  this.route("tsCompletedAssignments", {
    path: "turkserver/assignments/completed/:days?/:limit?",
    controller: TSAdminController,
    template: "tsAdminCompletedAssignments",
    waitOn() {
      let batchId;
      if ((batchId = Session.get("_tsViewingBatchId")) == null) { return; }
      const days = parseInt(this.params.days) || TurkServer.adminSettings.defaultDaysThreshold;
      const limit = parseInt(this.params.limit) || TurkServer.adminSettings.defaultLimit;
      return Meteor.subscribe("tsAdminCompletedAssignments", batchId, days, limit);
    },
    data() {
      return {
        days: this.params.days || TurkServer.adminSettings.defaultDaysThreshold,
        limit: this.params.limit || TurkServer.adminSettings.defaultLimit
      };
    }
  }
  );

  this.route("tsConnections", {
    path: "turkserver/connections",
    controller: TSAdminController,
    template: "tsAdminConnections"
  }
  );
  this.route("tsLobby", {
    path: "turkserver/lobby",
    controller: TSAdminController,
    template: "tsAdminLobby",
    waitOn() {
      let batchId;
      if ((batchId = Session.get("_tsViewingBatchId")) == null) { return; }
      // Same sub as normal lobby clients
      return Meteor.subscribe("lobby", batchId);
    }
  }
  );

  this.route("tsExperiments", {
    path: "turkserver/experiments/:days?/:limit?",
    controller: TSAdminController,
    template: "tsAdminExperiments",
    waitOn() {
      let batchId;
      if ((batchId = Session.get("_tsViewingBatchId")) == null) { return; }
      const days = parseInt(this.params.days) || TurkServer.adminSettings.defaultDaysThreshold;
      const limit = parseInt(this.params.limit) || TurkServer.adminSettings.defaultLimit;
      return [
        Meteor.subscribe("tsAdminBatchRunningExperiments", batchId, logSubErrors),
        Meteor.subscribe("tsAdminBatchCompletedExperiments", batchId, days, limit, logSubErrors)
      ];
    },
    data() {
      return {
        days: this.params.days || TurkServer.adminSettings.defaultDaysThreshold,
        limit: this.params.limit || TurkServer.adminSettings.defaultLimit
      };
    }
  }
  );

  this.route("tsLogs", {
    path: "turkserver/logs/:groupId/:count",
    controller: TSAdminController,
    template: "tsAdminLogs",
    waitOn() { return Meteor.subscribe("tsGroupLogs", this.params.groupId, parseInt(this.params.count)); },
    data() {
      return {
        instance: this.params.groupId,
        count: this.params.count
      };
    }
  }
  );

  return this.route("tsManage", {
    path: "turkserver/manage",
    controller: TSAdminController,
    template: "tsAdminManage"
  }
  );
});

// Extra admin user subscription for after experiment ended
Deps.autorun(function() {
  let group;
  if (!TurkServer.isAdmin()) { return; }
  if ((group = Partitioner.group()) == null) { return; }
  return Meteor.subscribe("tsGroupUsers", group);
});

TurkServer.showInstanceModal = id => TurkServer._displayModal(Template.tsAdminInstance, id);

const pillPopoverEvents = {
  // Show assignment instance info
  "mouseenter .ts-instance-pill-container"(e) {
    const container = $(e.target);

    container.popover({
      html: true,
      placement: "auto right",
      trigger: "manual",
      container,
      // TODO: Dynamic popover content would be very helpful here.
      // https://github.com/meteor/meteor/issues/2010#issuecomment-40532280
      content: Blaze.toHTMLWithData(Template.tsAdminAssignmentInstanceInfo, Blaze.getData(e.target))
    }).popover("show");

    return container.one("mouseleave", () => container.popover("destroy"));
  },

  // Show instance info in modal
  "click .ts-instance-pill-container"(e) {
    return TurkServer.showInstanceModal(Blaze.getData(e.target).id);
  },

  "mouseenter .ts-user-pill-container"(e) {
    const container = $(e.target);

    container.popover({
      html: true,
      placement: "auto right",
      trigger: "manual",
      container,
    // TODO: ditto
      content: Blaze.toHTMLWithData(Template.tsUserPillPopover, Blaze.getData(e.target))
    }).popover("show");

    return container.one("mouseleave", () => container.popover("destroy"));
  }
};

Template.turkserverPulldown.events({
  "click .ts-adminToggle"(e) {
    e.preventDefault();
    return $("#ts-content").slideToggle();
  }
});

// Add the pill events as well
Template.turkserverPulldown.events(pillPopoverEvents);

Template.turkserverPulldown.helpers({
  admin: TurkServer.isAdmin,
  currentExperiment() { return Experiments.findOne(); }
});

Template.tsAdminLogin.events = {
  "submit form"(e, tp) {
    e.preventDefault();
    const password = $(tp.find("input")).val();
    return Meteor.loginWithPassword("admin", password, function(err) {
      if (err != null) { return bootbox.alert("Unable to login: " + err.reason); }
    });
  }
};

Template.tsAdminLayout.events(pillPopoverEvents);

const onlineUsers = () => Meteor.users.find({
  admin: {$exists: false},
  "status.online": true
});

Template.tsAdminOverview.events = {
  "click .-ts-account-balance"() {
    return Meteor.call("ts-admin-account-balance", function(err, res) {
      if (err) { return bootbox.alert(err.reason); } else { return bootbox.alert(`<h3>$${res}</h3>`); }
    });
  }
};

Template.tsAdminOverview.helpers({
  onlineUserCount() { return onlineUsers().count(); }});

// All non-admin users who are online, sorted by most recent login
Template.tsAdminConnections.helpers({
  users() {
    return Meteor.users.find({
      admin: {$exists: false},
      "turkserver.state": {$exists: true}
    }, {
      sort: { "status.lastLogin.date" : -1 }
    });
  }
});

Template.tsAdminConnectionMaintenance.events({
  "click .-ts-cleanup-user-state"() {
    return TurkServer.callWithModal("ts-admin-cleanup-user-state");
  }
});
