// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * DS208: Avoid top-level this
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Client-only pseudo collection that receives experiment metadata
this.TSConfig = new Mongo.Collection("ts.config");

TurkServer.batch = function() {
  let batchId;
  if ((batchId = __guard__(Session.get("_loginParams"), x => x.batchId)) != null) {
    return Batches.findOne(batchId);
  } else {
    return Batches.findOne();
  }
};

/*
  Reactive computations
*/

// TODO perhaps make a better version of this reactivity
Deps.autorun(function() {
  const userId = Meteor.userId();
  if (!userId) {
    return;
  }
  const turkserver = __guard__(
    Meteor.users.findOne(
      {
        _id: userId,
        "turkserver.state": { $exists: true }
      },
      {
        fields: {
          "turkserver.state": 1
        }
      }
    ),
    x => x.turkserver
  );
  if (!turkserver) {
    return;
  }

  return Session.set("turkserver.state", turkserver.state);
});

Deps.autorun(() => Meteor.subscribe("tsCurrentExperiment", Partitioner.group()));

// Reactive join on treatments for assignments and experiments
Deps.autorun(function() {
  const exp = Experiments.findOne({}, { fields: { treatments: 1 } });
  if (!exp || exp.treatments == null) {
    return;
  }
  return Meteor.subscribe("tsTreatments", exp.treatments);
});

Deps.autorun(function() {
  const asst = Assignments.findOne({}, { fields: { treatments: 1 } });
  if (!asst || asst.treatments == null) {
    return;
  }
  return Meteor.subscribe("tsTreatments", asst.treatments);
});

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null ? transform(value) : undefined;
}
