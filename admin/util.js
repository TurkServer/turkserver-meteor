// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS201: Simplify complex destructure assignments
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
if (TurkServer.Util == null) {
  TurkServer.Util = {};
}

TurkServer.Util.duration = function(millis) {
  const diff = moment.utc(millis);
  const time = diff.format("H:mm:ss");
  const days = +diff.format("DDD") - 1;
  return (days !== 0 ? days + "d " : "") + time;
};

TurkServer.Util.timeSince = timestamp =>
  TurkServer.Util.duration(TimeSync.serverTime() - timestamp);
TurkServer.Util.timeUntil = timestamp =>
  TurkServer.Util.duration(timestamp - TimeSync.serverTime());

TurkServer.callWithModal = function(...args1) {
  let adjustedLength = Math.max(args1.length, 1),
    args = args1.slice(0, adjustedLength - 1),
    callback = args1[adjustedLength - 1];
  const dialog = bootbox.dialog({
    closeButton: false,
    message: "<h3>Working...</h3>"
  });

  // If callback is not specified, assume it is just an argument.
  if (!_.isFunction(callback)) {
    args.push(callback);
    callback = null;
  }

  // Add our own callback that alerts for errors
  args.push(function(err, res) {
    dialog.modal("hide");
    if (err != null) {
      bootbox.alert(err);
      return;
    }

    // If callback is given, calls it with data, otherwise just alert
    if (res != null && callback != null) {
      return callback(res);
    } else if (res != null) {
      return bootbox.alert(res);
    }
  });

  return Meteor.call.apply(null, args);
};

UI.registerHelper("_tsViewingBatch", () => Batches.findOne(Session.get("_tsViewingBatchId")));

UI.registerHelper("_tsLookupTreatment", function() {
  return Treatments.findOne({ name: "" + this });
});

UI.registerHelper("_tsRenderTime", timestamp => new Date(timestamp).toLocaleString());
UI.registerHelper("_tsRenderTimeMillis", function(timestamp) {
  const m = moment(timestamp);
  return m.format("L h:mm:ss.SSS A");
});

UI.registerHelper("_tsRenderTimeSince", TurkServer.Util.timeSince);
UI.registerHelper("_tsRenderTimeUntil", TurkServer.Util.timeUntil);

UI.registerHelper("_tsRenderISOTime", function(isoString) {
  const m = moment(isoString);
  return m.format("L LT") + " (" + m.fromNow() + ")";
});

// https://github.com/kvz/phpjs/blob/master/functions/strings/nl2br.js
const nl2br = str => (str + "").replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, "$1<br>$2");

UI.registerHelper("_tsnl2br", nl2br);

Template.tsBatchSelector.events = {
  "change select"(e) {
    if (!Session.equals("_tsViewingBatchId", e.target.value)) {
      return Session.set("_tsViewingBatchId", e.target.value);
    }
  }
};

Template.tsBatchSelector.helpers({
  batches() {
    return Batches.find({}, { sort: { name: 1 } });
  },
  noBatchSelection() {
    return !Session.get("_tsViewingBatchId");
  },
  selected() {
    return Session.equals("_tsViewingBatchId", this._id);
  },
  viewingBatchId() {
    return Session.get("_tsViewingBatchId");
  }
});

Template.tsAdminInstance.rendered = function() {
  // Subscribe to instance with whatever we rendered with
  return this.autorun(() => Meteor.subscribe("tsAdminInstance", Blaze.getData()));
};

Template.tsAdminInstance.helpers({
  instance() {
    return Experiments.findOne(this + "");
  }
});

Template.tsAdminPayBonus.events({
  "submit form"(e, t) {
    e.preventDefault();
    const amount = parseFloat(t.find("input[name=amount]").value);
    const reason = t.find("textarea[name=reason]").value;

    $(t.firstNode)
      .closest(".bootbox.modal")
      .modal("hide");

    return TurkServer.callWithModal("ts-admin-pay-bonus", this._id, amount, reason);
  }
});

Template.tsAdminEmailWorker.events({
  "submit form"(e, t) {
    e.preventDefault();
    const subject = t.find("input[name=subject]").value;
    const message = t.find("textarea[name=message]").value;
    const recipients = [this.workerId];

    const emailId = WorkerEmails.insert({ subject, message, recipients });

    $(t.firstNode)
      .closest(".bootbox.modal")
      .modal("hide");

    return TurkServer.callWithModal("ts-admin-send-message", emailId);
  }
});

const userLabelClass = function() {
  switch (false) {
    case !(this.status != null ? this.status.idle : undefined):
      return "label-warning";
    case !(this.status != null ? this.status.online : undefined):
      return "label-success";
    default:
      return "label-default";
  }
};

const userIdentifier = function() {
  if (this.username) {
    return this.username;
  } else if (this.workerId) {
    return "(" + this.workerId + ")";
  } else {
    return "(" + this._id + ")";
  }
};

Template.tsAdminWorkerItem.helpers({
  labelClass: userLabelClass,
  identifier: userIdentifier
});

Template.tsUserPill.helpers({
  user() {
    switch (false) {
      case !this.userId:
        return Meteor.users.findOne(this.userId);
      case !this.workerId:
        return Meteor.users.findOne({ workerId: this.workerId });
      default:
        return this;
    }
  }, // Object was already passed in
  labelClass: userLabelClass,
  identifier: userIdentifier
});

Template.tsUserPill.events({
  "click .ts-admin-email-worker"() {
    return TurkServer._displayModal(Template.tsAdminEmailWorker, this);
  }
});

Template.tsDescList.helpers({
  properties() {
    const result = [];
    for (let key in this) {
      const value = this[key];
      result.push({ key, value });
    }
    return result;
  },
  // Special rules for rendering description lists
  value() {
    switch (false) {
      case this.value !== false:
        return "false";
      case !_.isObject(this.value):
        return JSON.stringify(this.value);
      default:
        return nl2br(this.value);
    }
  }
});
