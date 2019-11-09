// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { EventEmitter } from "events";
import * as _ from "underscore";

import { Meteor } from "meteor/meteor";
import { check } from "meteor/check";

import { ErrMsg, LobbyStatus, Batches } from "../lib/common";
import { Assignment } from "./assignment";
import { Batch } from "./batches";

// TODO add index on LobbyStatus if needed

export class Lobby {
  batchId: string;
  events: EventEmitter;

  constructor(batchId) {
    this.batchId = batchId;
    check(this.batchId, String);
    this.events = new EventEmitter();
  }

  addAssignment(asst) {
    if (asst.batchId !== this.batchId) {
      throw new Error("unexpected batchId");
    }

    // Insert or update status in lobby
    LobbyStatus.upsert(asst.userId, {
      // Simply {status: false} caused https://github.com/meteor/meteor/issues/1552
      $set: {
        batchId: this.batchId,
        asstId: asst.asstId
      }
    });

    Meteor.users.update(asst.userId, {
      $set: {
        "turkserver.state": "lobby"
      }
    });

    return Meteor.defer(() => this.events.emit("user-join", asst));
  }

  getAssignments(selector = {}) {
    selector = _.extend(selector, { batchId: this.batchId });
    return Array.from(LobbyStatus.find(selector).fetch()).map(record =>
      Assignment.getAssignment(record.asstId)
    );
  }

  // TODO move status updates into specific assigners
  toggleStatus(userId) {
    const existing = LobbyStatus.findOne(userId);
    if (!existing) {
      throw new Meteor.Error(403, ErrMsg.userNotInLobbyErr);
    }
    const newStatus = !existing.status;
    LobbyStatus.update(userId, { $set: { status: newStatus } });

    const asst = Assignment.getCurrentUserAssignment(userId);
    return Meteor.defer(() => this.events.emit("user-status", asst, newStatus));
  }

  // Takes a group of users from the lobby without triggering the user-leave event.
  pluckUsers(userIds) {
    return LobbyStatus.remove({ _id: { $in: userIds } });
  }

  removeAssignment(asst) {
    // TODO check for batchId here
    if (LobbyStatus.remove(asst.userId) > 0) {
      return Meteor.defer(() => this.events.emit("user-leave", asst));
    }
  }
}

// Publish lobby contents for a particular batch, as well as users
// TODO can we simplify this by publishing users with turkserver.state = "lobby",
// if we use batch IDs in a smart way?
Meteor.publish("lobby", function(batchId) {
  if (batchId == null) {
    return [];
  }
  const sub = this;

  const handle = LobbyStatus.find({ batchId }).observeChanges({
    added(id, fields) {
      sub.added("ts.lobby", id, fields);
      return sub.added("users", id, Meteor.users.findOne(id, { fields: { username: 1 } }));
    },
    changed(id, fields) {
      return sub.changed("ts.lobby", id, fields);
    },
    removed(id) {
      sub.removed("ts.lobby", id);
      return sub.removed("users", id);
    }
  });

  sub.ready();
  return sub.onStop(() => handle.stop());
});

// Publish lobby config information for active batches with lobby and grouping
// TODO publish this based on the batch of the active user
Meteor.publish(null, function() {
  const sub = this;
  const subHandle = Batches.find(
    {
      active: true,
      lobby: true,
      grouping: "groupSize",
      groupVal: { $exists: true }
    },
    { fields: { groupVal: 1 } }
  ).observeChanges({
    added(id, fields) {
      return sub.added("ts.config", "lobbyThreshold", {
        value: fields.groupVal
      });
    },
    changed(id, fields) {
      return sub.changed("ts.config", "lobbyThreshold", {
        value: fields.groupVal
      });
    },
    removed(id) {
      return sub.removed("ts.config", "lobbyThreshold");
    }
  });

  sub.ready();
  return sub.onStop(() => subHandle.stop());
});

// Check for lobby state
Meteor.methods({
  toggleStatus() {
    const userId = Meteor.userId();
    if (!userId) {
      throw new Meteor.Error(403, ErrMsg.userIdErr);
    }

    Batch.currentBatch().lobby.toggleStatus(userId);
    return this.unblock();
  }
});

// Clear lobby status on startup
// Just clear lobby users for assignment, but not lobby state
Meteor.startup(() => LobbyStatus.remove({}));

//  Meteor.users.update { "turkserver.state": "lobby" },
//    $unset: {"turkserver.state": null}
//  , {multi: true}
