import { Meteor } from "meteor/meteor";
import { ErrMsg, Logs } from "../lib/common";

// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
Logs._ensureIndex({
  _groupId: 1,
  _timestamp: 1
});

// Save group and timestamp for each log request
Logs.before.insert(function(userId, doc) {
  // Never log admin actions
  // TODO this means admin-initiated teardown events aren't recorded
  if (__guard__(Meteor.users.findOne(userId), x => x.admin)) {
    return false;
  }
  let groupId = Partitioner._currentGroup.get();

  if (!groupId) {
    if (!userId) {
      throw new Meteor.Error(403, ErrMsg.userIdErr);
    }
    groupId = Partitioner.getUserGroup(userId);
    if (!groupId) {
      throw new Meteor.Error(403, ErrMsg.groupErr);
    }
  }

  if (userId) {
    doc._userId = userId;
  }
  doc._groupId = groupId;
  if (doc._timestamp == null) {
    doc._timestamp = new Date();
  } // Allow specification of custom timestamps
  return true;
});

export function log(doc, callback = null) {
  Logs.insert(doc, callback);
}

Meteor.methods({
  "ts-log"(doc) {
    if (!Meteor.userId()) {
      Meteor._debug("Warning; received log request for anonymous user: ", doc);
    }
    Logs.insert(doc);
  }
});

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null ? transform(value) : undefined;
}
