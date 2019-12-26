// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Meteor } from "meteor/meteor";
import { Mongo } from "meteor/mongo";
import { Tracker } from "meteor/tracker";

import { Partitioner } from "meteor/mizzao:partitioner";

export interface Batch {
  _id: string;
  active: boolean;
  treatments: string[];
  // If a worker has returned an assignment, let them take another one
  allowReturns: true;
}
export const Batches = new Mongo.Collection<Batch>("ts.batches");

/**
 * @summary The collection of treatments that are available to tag to instances/worlds or user assignments.
 *
 * Treatments are objects of the following form:
 * {
 *    name: "foo",
 *    key1: <value1>
 *    key2: <value2>
 * }
 *
 * This allows "foo" to be used to assign a treatment to worlds or users, and the values of key1 and key2 are available in TurkServer.treatment() on the client side.
 */
export interface Treatment {
  _id: string;
  name: string;
  [key: string]: any;
}
export const Treatments = new Mongo.Collection<Treatment>("ts.treatments");

export interface Experiment {
  _id: string;
  batchId: string;
  users: string[];
  treatments: string[];
  startTime?: Date;
  endTime?: Date;
}
export const Experiments = new Mongo.Collection<Experiment>("ts.experiments");

export interface ILobbyStatus {
  _id: string;
  asstId: string;
  status: boolean; // Whether the user has clicked "ready"
}
export const LobbyStatus = new Mongo.Collection<ILobbyStatus>("ts.lobby");

export interface LogEntry {
  _id: string;
}
export const Logs = new Mongo.Collection<LogEntry>("ts.logs");

export interface RoundState {
  _id: string;
}
export const RoundTimers = new Mongo.Collection<RoundState>("ts.rounds");

export interface Worker {
  _id: string;
}
export const Workers = new Mongo.Collection<Worker>("ts.workers");

export type MTurkStatus = "Submitted" | "Approved" | "Rejected";

export type InstanceData = {
  id: string;
  joinTime: Date;
  lastDisconnect?: Date;
  disconnectedTime?: number;
  lastIdle?: Date;
  idleTime?: number;
};

export interface IAssignment {
  _id: string;
  batchId: string;
  experimentId?: string;
  hitId: string;
  workerId: string;
  assignmentId: string;
  acceptTime?: Date;
  instances?: InstanceData[];
  treatments?: string[];
  mturkStatus?: MTurkStatus;
  status?: "assigned" | "completed" | "returned";
  bonusPaid?: Date;
  bonusPayment?: number;
}
export const Assignments = new Mongo.Collection<IAssignment>("ts.assignments");

export interface WorkerMemo {
  subject: string;
  message: string;
  recipients: string[];
  sentTime?: Date;
}
export const WorkerEmails = new Mongo.Collection<WorkerMemo>("ts.workeremails");

// TODO: check if we just get these from the AWS SDK.
export interface Qualification {
  _id: string;
  name: string;
  LocaleValue?: any;
}
export const Qualifications = new Mongo.Collection<Qualification>("ts.qualifications");

export interface HITType {
  _id: string;
  batchId: string;
  // MTurk fields
  HITTypeId: string;
  // TODO shim until we replace with aws-sdk
  Reward: any;
  QualificationRequirement: any[];
}
export const HITTypes = new Mongo.Collection<HITType>("ts.hittypes");

export interface HIT {
  HITId: string;
  HITTypeId: string;
}
export const HITs = new Mongo.Collection<HIT>("ts.hits");

// Need a global here for export to test code, after updating to Meteor 1.4.
export const ErrMsg = {
  // authentication
  unexpectedBatch: "This HIT is not recognized.",
  batchInactive: "This task is currently not accepting new assignments.",
  batchLimit:
    "You've attempted or completed the maximum number of HITs allowed in this group. Please return this assignment.",
  simultaneousLimit:
    "You are already connected through another HIT, or you previously returned a HIT from this group. If you still have the HIT open, please complete that one first.",
  alreadyCompleted: "You have already completed this HIT.",
  // operations
  authErr: "You are not logged in",
  stateErr: "You can't perform that operation right now",
  notAdminErr: "Not logged in as admin",
  adminErr: "Operation not permitted by admin",
  // Stuff
  usernameTaken: "Sorry, that username is taken.",
  userNotInLobbyErr: "User is not in lobby"
};

// TODO move this to a more appropriate location
Meteor.methods({
  "ts-delete-treatment"(id) {
    checkAdmin();
    if (Batches.findOne({ treatmentIds: { $in: [id] } })) {
      throw new Meteor.Error(403, "can't delete treatments that are used by existing batches");
    }

    return Treatments.remove(id);
  }
});

// Helpful functions

// Check if a particular user is an admin.
// If no user is specified, attempts to check the current user.
export function isAdmin(userId = Meteor.userId()): boolean {
  if (userId == null) return false;

  const user = Meteor.users.findOne(
    { _id: userId, admin: { $exists: true } },
    { fields: { admin: 1 } }
  );
  return (user && user.admin) || false;
}

export function checkNotAdmin() {
  if (Meteor.isClient) {
    // Don't register reactive dependencies on userId for a client check
    if (Tracker.nonreactive(() => isAdmin())) {
      throw new Meteor.Error(403, ErrMsg.adminErr);
    }
  } else {
    if (isAdmin()) {
      throw new Meteor.Error(403, ErrMsg.adminErr);
    }
  }
}

export function checkAdmin() {
  if (Meteor.isClient) {
    if (!Tracker.nonreactive(() => isAdmin())) {
      throw new Meteor.Error(403, ErrMsg.notAdminErr);
    }
  } else {
    if (!isAdmin()) {
      throw new Meteor.Error(403, ErrMsg.notAdminErr);
    }
  }
}

/**
 * @summary The global object containing all TurkServer functions.
 * @namespace
 */
export const TurkServer = {
  group: Partitioner.group,
  partitionCollection: Partitioner.partitionCollection
};

/**
 * @summary Get the current group (partition) of the environment.
 * @locus Anywhere
 * @function
 * @returns {String} The group id.
 */
TurkServer.group = Partitioner.group;

/**
 * @summary Partition a collection for use across instances.
 * @locus Server
 * @param {Meteor.Collection} collection The collection to partition.
 * @function
 */
TurkServer.partitionCollection = Partitioner.partitionCollection;

TurkServer.partitionCollection(RoundTimers, {
  index: { index: 1 },
  indexOptions: {
    unique: 1,
    dropDups: true,
    name: "_groupId_1_index_1_unique"
  }
});
