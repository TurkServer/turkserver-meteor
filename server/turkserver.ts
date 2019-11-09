import { Meteor } from "meteor/meteor";
import { Mongo } from "meteor/mongo";

import { Partitioner } from "meteor/mizzao:partitioner";

import {
  Batches,
  Treatments,
  LobbyStatus,
  Experiments,
  RoundTimers,
  Logs,
  Workers,
  Assignments,
  WorkerEmails,
  Qualifications,
  HITTypes,
  HITs
} from "../lib/common";
import { check } from "meteor/check";

// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Collection modifiers, in case running on insecure

function isAdminRule(userId: string): boolean {
  if (userId == null) return false;
  const user = Meteor.users.findOne(userId);
  return (user && user.admin) || false;
}

const adminOnly = {
  insert: isAdminRule,
  update: isAdminRule,
  remove: isAdminRule
};

const always = {
  insert() {
    return true;
  },
  update() {
    return true;
  },
  remove() {
    return true;
  }
};

/*
  Batches
  Treatments
  Experiments
*/

Batches.allow(adminOnly);
Treatments.allow(adminOnly);

Treatments._ensureIndex({ name: 1 }, { unique: 1 });

// Allow admin to make emergency adjustments to the lobby collection just in case
LobbyStatus.allow(adminOnly);

// Only server should update these
Experiments.deny(always);
Logs.deny(always);
RoundTimers.deny(always);

// Create an index on experiments
Experiments._ensureIndex({
  batchId: 1,
  endTime: 1 // non-sparse ensures that running experiments are indexed
});

/*
  Workers
  Assignments

  WorkerEmails
  Qualifications
  HITTypes
  HITs
*/

Workers.allow(adminOnly);
Assignments.deny(always);

WorkerEmails.allow(adminOnly);
Qualifications.allow(adminOnly);
HITTypes.allow(adminOnly);
HITs.allow(adminOnly);

// XXX remove this check for release
try {
  HITTypes._dropIndex("HITTypeId_1");
  console.log("Dropped old index on HITTypeId");
} catch (error) {}

// Index HITTypes, but only for those that exist
HITTypes._ensureIndex(
  { HITTypeId: 1 },
  {
    name: "HITTypeId_1_sparse",
    unique: 1,
    sparse: 1
  }
);

HITs._ensureIndex({ HITId: 1 }, { unique: 1 });

// TODO more careful indices on these collections

// Index on unique assignment-worker pairs
Assignments._ensureIndex(
  {
    hitId: 1,
    assignmentId: 1,
    workerId: 1
  },
  { unique: 1 }
);

// Allow fast lookup of a worker's HIT assignments by status
Assignments._ensureIndex({
  workerId: 1,
  status: 1
});

// Allow lookup of assignments by batch and submitTime (completed vs incomplete)
Assignments._ensureIndex({
  batchId: 1,
  submitTime: 1
});

// TODO deprecated index
try {
  Assignments._dropIndex({
    batchId: 1,
    acceptTime: 1
  });
} catch (error1) {}

/*
  Data publications
*/

// Publish turkserver user fields to a user
Meteor.publish(null, function() {
  let workerId;
  if (!this.userId) {
    return null;
  }

  const cursors: Mongo.Cursor<any>[] = [
    Meteor.users.find(this.userId, { fields: { turkserver: 1 } })
  ];

  // Current user assignment data, including idle and disconnection time
  // This won't be sent for the admin user
  if ((workerId = __guard__(Meteor.users.findOne(this.userId), x => x.workerId)) != null) {
    cursors.push(
      Assignments.find(
        {
          workerId,
          status: "assigned"
        },
        {
          fields: {
            instances: 1,
            treatments: 1,
            bonusPayment: 1
          }
        }
      )
    );
  }

  return cursors;
});

Meteor.publish("tsTreatments", function(names) {
  if (names == null || names[0] == null) {
    return [];
  }
  check(names, [String]);
  return Treatments.find({ name: { $in: names } });
});

// Publish current experiment for a user, if it exists
// This includes the data sent to the admin user
Meteor.publish("tsCurrentExperiment", function(group) {
  if (!this.userId) {
    return;
  }
  return [
    Experiments.find(group),
    RoundTimers.find() // Partitioned by group
  ];
});

// For the preview page and test logins, need to publish the list of batches.
// TODO make this a bit more secure
Meteor.publish("tsLoginBatches", function(batchId) {
  // Never send the batch list to logged-in users.
  if (this.userId != null) {
    return [];
  }

  // If an erroneous batchId was sent, don't just send the whole list.
  if (arguments.length > 0 && batchId != null) {
    return Batches.find(batchId);
  } else {
    return Batches.find();
  }
});

Meteor.publish(null, function() {
  let workerId;
  if (this.userId == null) {
    return [];
  }
  // Publish specific batch if logged in
  // This should work for now because an assignment is made upon login
  if ((workerId = __guard__(Meteor.users.findOne(this.userId), x => x.workerId)) == null) {
    return [];
  }

  const sub = this;
  const handle = Assignments.find({
    workerId,
    status: "assigned"
  }).observeChanges({
    added(id, fields) {
      const { batchId } = Assignments.findOne(id);
      return sub.added("ts.batches", batchId, Batches.findOne(batchId));
    },
    removed(id) {
      const { batchId } = Assignments.findOne(id);
      return sub.removed("ts.batches", batchId);
    }
  });

  sub.ready();
  return sub.onStop(() => handle.stop());
});

export function startup(func) {
  Meteor.startup(() => Partitioner.directOperation(func));
}

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null ? transform(value) : undefined;
}
