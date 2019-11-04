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
// Clean up old index
if (Meteor.isServer) {
  try {
    RoundTimers._dropIndex("_groupId_1_index_1");
    Meteor._debug("Dropped old non-unique index on RoundTimers");
  } catch (error) {}
}

TurkServer.partitionCollection(RoundTimers, {
  index: {index: 1},
  indexOptions: {
    unique: 1,
    dropDups: true,
    name: "_groupId_1_index_1_unique"
  }
});

this.Workers = new Mongo.Collection("ts.workers");
this.Assignments = new Mongo.Collection("ts.assignments");

this.WorkerEmails = new Mongo.Collection("ts.workeremails");
this.Qualifications = new Mongo.Collection("ts.qualifications");
this.HITTypes = new Mongo.Collection("ts.hittypes");
this.HITs = new Mongo.Collection("ts.hits");

const ErrMsg = {
  // authentication
  unexpectedBatch: "This HIT is not recognized.",
  batchInactive: "This task is currently not accepting new assignments.",
  batchLimit: "You've attempted or completed the maximum number of HITs allowed in this group. Please return this assignment.",
  simultaneousLimit: "You are already connected through another HIT, or you previously returned a HIT from this group. If you still have the HIT open, please complete that one first.",
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
    TurkServer.checkAdmin();
    if (Batches.findOne({ treatmentIds: { $in: [id] } })) {
      throw new Meteor.Error(403, "can't delete treatments that are used by existing batches");
    }

    return Treatments.remove(id);
  }
});

// Helpful functions

// Check if a particular user is an admin.
// If no user is specified, attempts to check the current user.
TurkServer.isAdmin = function(userId) {
  if (userId == null) { userId = Meteor.userId(); }
  if (!userId) { return false; }
  return __guard__(Meteor.users.findOne({
    _id: userId,
    "admin": { $exists: true }
  }
  , { fields: {
    "admin" : 1
  }
}
  ), x => x.admin) || false;
};

TurkServer.checkNotAdmin = function() {
  if (Meteor.isClient) {
    // Don't register reactive dependencies on userId for a client check
    if (Deps.nonreactive(() => TurkServer.isAdmin())) { throw new Meteor.Error(403, ErrMsg.adminErr); }
  } else {
    if (TurkServer.isAdmin()) { throw new Meteor.Error(403, ErrMsg.adminErr); }
  }
};

TurkServer.checkAdmin = function() {
  if (Meteor.isClient) {
    if (!Deps.nonreactive(() => TurkServer.isAdmin())) { throw new Meteor.Error(403, ErrMsg.notAdminErr); }
  } else {
    if (!TurkServer.isAdmin()) { throw new Meteor.Error(403, ErrMsg.notAdminErr); }
  }
};

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}