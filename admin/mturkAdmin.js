// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const quals = () => Qualifications.find();
const hitTypes = () => HITTypes.find();

Template.tsAdminMTurk.helpers({
  selectedHITType() { return HITTypes.findOne(Session.get("_tsSelectedHITType")); }});

Template.tsAdminMTurk.events =
  {"click .-ts-new-hittype"() { return Session.set("_tsSelectedHITType", undefined); }};

Template.tsAdminHitTypes.events =
  {"click tr"() { return Session.set("_tsSelectedHITType", this._id); }};

Template.tsAdminHitTypes.helpers({
  hitTypes,
  selectedClass() {
    if (Session.equals("_tsSelectedHITType", this._id)) { return "info"; } else { return ""; }
  }
});

Template.tsAdminViewHitType.events = {
  "click .-ts-register-hittype"() {
    return Meteor.call("ts-admin-register-hittype", this._id, function(err, res) {
      if (err) { return bootbox.alert(err.reason); }
    });
  },
  "click .-ts-delete-hittype"() {
    return HITTypes.remove(this._id);
  }
};

Template.tsAdminViewHitType.helpers({
  batchName() { return __guard__(Batches.findOne(this.batchId), x => x.name) || "(none)"; },
  renderReward() { return this.Reward.toFixed(2); },
  qualName() { return __guard__(Qualifications.findOne(""+this), x => x.name); }
});

Template.tsAdminNewHitType.events = {
  "submit form"(e, tmpl) {
    e.preventDefault();

    const id = HITTypes.insert({
      batchId: tmpl.find("select[name=batch]").value,
      Title: tmpl.find("input[name=title]").value,
      Description: tmpl.find("textarea[name=desc]").value,
      Keywords: tmpl.find("input[name=keywords]").value,
      Reward: parseFloat(tmpl.find("input[name=reward]").value),
      QualificationRequirement: $(tmpl.find("select[name=quals]")).val(),
      AssignmentDurationInSeconds: parseInt(tmpl.find("input[name=duration]").value),
      AutoApprovalDelayInSeconds: parseInt(tmpl.find("input[name=delay]").value)
    });

    return Session.set("_tsSelectedHITType", id);
  }
};

Template.tsAdminNewHitType.helpers({
  quals,
  batches() { return Batches.find(); }
});

Template.tsAdminQuals.events = {
  "click .-ts-delete-qual"() {
    return Qualifications.remove(this._id);
  }
};

Template.tsAdminQuals.helpers({
  quals,
  value() {
    if (this.IntegerValue) {
      return this.IntegerValue + " (Integer)";
    } else if (this.LocaleValue) {
      return this.LocaleValue + " (Locale)";
    } else {
      return;
    }
  }
});

Template.tsAdminNewQual.events = {
  "click .-ts-create-qual"(e, tmpl) {
    const name = tmpl.find("input[name=name]").value;
    let type = tmpl.find("input[name=type]").value;
    const comp = tmpl.find("select[name=comp]").value;
    const {
      value
    } = tmpl.find("input[name=value]");
    const preview = tmpl.find("input[name=preview]").checked;

    if (!name || !type || !comp) { return; }

    const qual = {
      name,
      QualificationTypeId: type,
      Comparator: comp,
      RequiredToPreview: preview
    };

    try {
      switch (comp) {
        case "Exists": case "DoesNotExist":
          if (!!value) { throw new Error("No value should be specified for Exists or DoesNotExist"); }
          break;

        case "In": case "NotIn":
          // Parse value as a comma-separated array
          var vals = [];
          type = null;

          // Check that they are all the same type
          // TODO we don't check for the validity of the type here
          for (let v of Array.from(value.split(/[\s,]+/))) {
            var newType, numV;
            if (!v) { continue; }

            if (numV = parseInt(v)) {
              vals.push(numV);
              newType = "Integer";
            } else {
              vals.push(v);
              newType = "String";
            }

            if ((type != null) && (newType !== type)) { throw new Error("Must be all Integers or Locales"); }
            type = newType;
          }

          if (type == null) { throw new Error("Must specify at least one value for In or NotIn"); }

          if (type === "Integer") {
            qual.IntegerValue = vals;
          } else {
            qual.LocaleValue = vals;
          }
          break;

        default: // Things with values
          if (!!value) {
            if (parseInt(value)) {
              qual.IntegerValue = value;
            } else {
              qual.LocaleValue = value;
            }
          }
      }

      return Qualifications.insert(qual);
    } catch (error) {
      e = error;
      return bootbox.alert(e.toString());
    }
  }
};

Template.tsAdminHits.events = {
  "click tr"() { return Session.set("_tsSelectedHIT", this._id); },
  "click .-ts-new-hit"() { return Session.set("_tsSelectedHIT", undefined); }
};

Template.tsAdminHits.helpers({
  hits() { return HITs.find({}, {sort: {CreationTime: -1}}); },
  selectedHIT() { return HITs.findOne(Session.get("_tsSelectedHIT")); }
});

Template.tsAdminViewHit.events = {
  "click .-ts-refresh-hit"() {
    return TurkServer.callWithModal("ts-admin-refresh-hit", this.HITId);
  },

  "click .-ts-expire-hit"() {
    return TurkServer.callWithModal("ts-admin-expire-hit", this.HITId);
  },

  "submit .-ts-change-hittype"(e, tmpl) {
    e.preventDefault();
    const htId = tmpl.find("select[name=hittype]").value;
    const {
      HITTypeId
    } = HITTypes.findOne(htId);
    if (!HITTypeId) {
      bootbox.alert("Register that HIT Type first");
      return;
    }

    const params = {
      HITId: this.HITId,
      HITTypeId
    };
    return TurkServer.callWithModal("ts-admin-change-hittype", params);
  },

  "submit .-ts-extend-assignments"(e, tmpl) {
    e.preventDefault();
    const params = {
      HITId: this.HITId,
      MaxAssignmentsIncrement: parseInt(tmpl.find("input[name=assts]").value)
    };
    return TurkServer.callWithModal("ts-admin-extend-hit", params);
  },

  "submit .-ts-extend-expiration"(e, tmpl) {
    e.preventDefault();
    const params = {
      HITId: this.HITId,
      ExpirationIncrementInSeconds: parseInt(tmpl.find("input[name=secs]").value)
    };
    return TurkServer.callWithModal("ts-admin-extend-hit", params);
  }
};

Template.tsAdminViewHit.helpers({
  hitTypes});

Template.tsAdminNewHit.events = {
  "submit form"(e, tmpl) {
    e.preventDefault();

    const hitTypeId = tmpl.find("select[name=hittype]").value;

    if (!hitTypeId) {
      bootbox.alert("HIT Type isn't registered");
      return;
    }

    const params = {
      MaxAssignments:parseInt(tmpl.find("input[name=maxAssts]").value),
      LifetimeInSeconds:parseInt(tmpl.find("input[name=lifetime]").value)
    };

    return TurkServer.callWithModal("ts-admin-create-hit", hitTypeId, params);
  }
};

Template.tsAdminNewHit.helpers({
  hitTypes});

Template.tsAdminWorkers.helpers({
  settings: {
    position: "bottom",
    limit: 5,
    rules: [
      {
        collection: Meteor.users,
        field: "workerId",
        template: Template.tsAdminWorkerItem,
        // Match on workerId or username
        selector(match) {
          return {
            $or: [
              { workerId: { $regex: "^" + match.toUpperCase() } },
              { username: { $regex: match, $options: "i" } }
            ]
          };
        }
      }
    ]
  },

  workerData() { return Workers.findOne(this.workerId); },

  workerActiveAssts() {
    return Assignments.find({
      workerId: this.workerId,
      status: { $ne: "completed" }
    }, {
      sort: { acceptTime: -1
    }
    });
  },

  workerCompletedAssts() {
    return Assignments.find({
      workerId: this.workerId,
      status: "completed"
    }, {
      sort: { submitTime: -1
    }
    });
  },

  numCompletedAssts() {
    return Assignments.find({
      workerId: this.workerId,
      status: "completed"
    }).count();
  }
});


Template.tsAdminWorkers.events({
  "autocompleteselect input"(e, t, user) {
    if (user.workerId != null) { return Router.go("tsWorkers", {workerId: user.workerId}); }
  }
});

Template.tsAdminPanel.rendered = function() {
  const svg = d3.select(this.find("svg"));
  const $svg = this.$("svg");

  const margin = {
    left: 90,
    bottom: 30
  };

  const x = d3.scale.linear()
    .range([0, $svg.width() - margin.left]);

  const y = d3.scale.ordinal()
    // Data was originally stored in GMT -5 so just display that
    .domain(Array.from(TurkServer.Util._defaultTimeSlots()).map((m) => m.zone(300).format("HH ZZ")))
    .rangeBands([0, $svg.height() - margin.bottom], 0.2);

  const xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

  const yAxis = d3.svg.axis()
    .scale(y)
    .orient("left");

  // Draw axes
  const chart = svg.append("g")
    .attr("transform", "translate(" + margin.left + ",0)");

  chart.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + ($svg.height() - margin.bottom) + ")")
    .call(xAxis);

  chart.append("g")
    .attr("class", "y axis")
    .call(yAxis)
  .append("text")
    .attr("transform", "rotate(-90)")
    .attr("y", -80)
    .attr("dy", ".71em")
    .style("text-anchor", "end")
    .text("Timezone");

  const data = {};

  let newData = false;
  const redraw = function() {
    if (!newData) { return; }
    newData = false;

    const entries = d3.entries(data);

    // Update domain with max value
    x.domain([0, d3.max(entries, d => d.value)]);
    chart.select("g.x.axis").call(xAxis);

    const bars = chart.selectAll(".bar")
      .data(entries, d => d.key);

    // Add any new bars in the enter selection
    bars.enter()
      .append("rect")
      .attr("class", "bar")
      .attr("y", d => y(d.key))
      .attr("height", y.rangeBand());

    // Update widths in the update selection, including entered nodes
    return bars.attr("data-value", d => d.value)
      .transition()
      .attr("width", d => x(d.value));
  };

  // Aggregate the worker times into the current timezone
  return this.handle = Workers.find().observeChanges({
    added(id, fields) {
      // Only use data from workers who agreed to be contacted
      if (!fields.contact || (fields.available == null)) { return; }
      for (let time of Array.from(fields.available.times)) {
        // normalize into buckets
        if (!time) { continue; } // Ignore invalid (empty) entries
        if (data[time] == null) { data[time] = 0; }
        data[time] += 1;
      }

      newData = true;
      return Meteor.defer(redraw);
    }
  });
};

Template.tsAdminPanel.destroyed = function() {
  return this.handle.stop();
};

Template.tsAdminPanel.helpers({
  workerContact() { return Workers.find({contact: true}).count(); },
  workerTotal() { return Workers.find().count(); }
});

const recipientsHelper = function(recipients) {
    if (recipients.length === 1) {
      return recipients;
    } else {
      return recipients.length;
    }
  };

Template.tsAdminEmail.helpers({
  messages() { return WorkerEmails.find({}, {sort: {sentTime: -1}}); },
  recipientsHelper
});

Template.tsAdminEmail.events({
  "click tr"() { return Session.set("_tsSelectedEmailId", this._id); }});

Template.tsAdminEmailMessage.helpers({
  selectedMessage() {
    const emailId = Session.get("_tsSelectedEmailId");
    if (emailId != null) { return WorkerEmails.findOne(emailId); }
  },
  recipientsHelper
});

Template.tsAdminEmailMessage.events({
  "click .ts-admin-send-message"() {
    return TurkServer.callWithModal("ts-admin-send-message", this._id);
  },

  "click .ts-admin-resend-message"() {
    return TurkServer.callWithModal("ts-admin-resend-message", this._id);
  },

  "click .ts-admin-copy-message"() {
    return TurkServer.callWithModal("ts-admin-copy-message", this._id);
  },

  "click .ts-admin-delete-message"() {
    return TurkServer.callWithModal("ts-admin-delete-message", this._id);
  }
});

Template.tsAdminNewEmail.helpers({
  messages() {
    return WorkerEmails.find({}, {
      fields: {subject: 1},
      sort: {sentTime: -1}
    });
  }
});

Template.tsAdminNewEmail.events({
  "submit form"(e, t) {
    let copyFromId;
    e.preventDefault();
    const $sub = t.$("input[name=subject]");
    const $msg = t.$("textarea[name=message]");

    const subject = $sub.val();
    const message = $msg.val();

    if (t.$("input[name=recipients]:checked").val() === "copy") {
      copyFromId = t.$("select[name=copyFrom]").val();
      if (copyFromId == null) {
        bootbox.alert("Select an e-mail to copy recipients from");
        return;
      }
    }

    return TurkServer.callWithModal("ts-admin-create-message", subject, message, copyFromId, res => // Display the new message
    Session.set("_tsSelectedEmailId", res));
  }
});

Template.tsAdminAssignmentMaintenance.events({
  "click .-ts-cancel-assignments"() {
    const message = "This will cancel all assignments of users are disconnected. You should only do this if these users will definitely not return to their work. Continue? ";
    return bootbox.confirm(message, function(res) {
      if (!res) { return; }
      return TurkServer.callWithModal("ts-admin-cancel-assignments", Session.get("_tsViewingBatchId"));
    });
  }
});

const numAssignments = () => Assignments.find().count();

Template.tsAdminActiveAssignments.helpers({
  numAssignments,
  activeAssts() {
    return Assignments.find({}, { sort: {acceptTime: -1} });
  }});

const checkBatch = function(batchId) {
  if (batchId == null) {
    bootbox.alert("Select a batch first!");
    return false;
  }
  return true;
};

Template.tsAdminCompletedMaintenance.events({
  "click .-ts-refresh-assignments"() {
    const batchId = Session.get("_tsViewingBatchId");
    if (!checkBatch(batchId)) { return; }
    return TurkServer.callWithModal("ts-admin-refresh-assignments", batchId);
  },

  "click .-ts-approve-all"() {
    const batchId = Session.get("_tsViewingBatchId");
    if (!checkBatch(batchId)) { return; }

    return TurkServer.callWithModal("ts-admin-count-submitted", batchId, function(count) {
      if (count === 0) {
        bootbox.alert("No assignments to approve!");
        return;
      }

      return bootbox.prompt(`${count} assignments will be approved. Enter a (possibly blank) message to send to each worker.`, function(res) {
        if (res == null) { return; }
        return TurkServer.callWithModal("ts-admin-approve-all", batchId, res);
      });
    });
  },

  "click .-ts-pay-bonuses"() {
    const batchId = Session.get("_tsViewingBatchId");
    if (!checkBatch(batchId)) { return; }

    return TurkServer.callWithModal("ts-admin-count-unpaid-bonuses", batchId, function(data) {
      if (data.numPaid === 0) {
        bootbox.alert("No bonuses to pay!");
        return;
      }

      return bootbox.prompt(`${data.numPaid} workers will be paid, for a total of $${data.amt}. Enter a message to send to each worker.`, function(res) {
        if (!res) { return; }
        return TurkServer.callWithModal("ts-admin-pay-bonuses", batchId, res);
      });
    });
  }
});

Template.tsAdminCompletedAssignments.events({
  "submit form.ts-admin-assignment-filter"(e, t) {
    e.preventDefault();

    return Router.go("tsCompletedAssignments", {
      days: parseInt(t.find("input[name=filter_days]").value) ||
        TurkServer.adminSettings.defaultDaysThreshold,
      limit: parseInt(t.find("input[name=filter_limit]").value) ||
        TurkServer.adminSettings.defaultLimit
    }
    );
  }
});

Template.tsAdminCompletedAssignments.helpers({
  numAssignments,
  completedAssts() {
    return Assignments.find({}, { sort: {submitTime: -1} });
  }});

Template.tsAdminCompletedAssignmentsTable.events({
  "click .ts-admin-refresh-assignment"() {
    return TurkServer.callWithModal("ts-admin-refresh-assignment", this._id);
  },

  "click .ts-admin-approve-assignment"() {
    const _asstId = this._id;
    return bootbox.prompt("Approve assignment: enter an optional message to send to the worker.", res => TurkServer.callWithModal("ts-admin-approve-assignment", _asstId, res));
  },

  "click .ts-admin-reject-assignment"() {
    const _asstId = this._id;
    return bootbox.prompt("1 worker's assignment will be rejected. Enter a message to send to the worker.", function(res) {
      if (!res) { return; }
      return TurkServer.callWithModal("ts-admin-reject-assignment", _asstId, res);
    });
  },

  "click .ts-admin-unset-bonus"() {
    return Meteor.call("ts-admin-unset-bonus", this._id);
  },

  "click .ts-admin-pay-bonus"() {
    return TurkServer._displayModal(Template.tsAdminPayBonus, this);
  }
});

Template.tsAdminCompletedAssignmentRow.helpers({
  labelStatus() {
    switch (this.mturkStatus) {
      case "Submitted": return "label-warning";
      case "Approved": return "label-primary";
      case "Rejected": return "label-danger";
      default: return "label-default";
    }
  },
  submitted() {
    return this.mturkStatus === "Submitted";
  }
});

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}