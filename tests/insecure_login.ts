import * as _ from "underscore";

import { Meteor } from "meteor/meteor";
import { Accounts } from "meteor/accounts-base";

import { Batches } from "../lib/common";

export const InsecureLogin = {
  queue: [],
  ran: false,
  ready: function(callback: Function) {
    this.queue.push(callback);
    if (this.ran) this.unwind();
  },
  run: function() {
    this.ran = true;
    this.unwind();
  },
  unwind: function() {
    _.each(this.queue, function(callback) {
      callback();
    });
    this.queue = [];
  }
};

if (Meteor.isClient) {
  var hitId = "expClientHitId";
  var assignmentId = "expClientAssignmentId";
  var workerId = "expClientWorkerId";
  var batchId = "expClientBatch";

  Accounts.callLoginMethod({
    methodArguments: [
      {
        hitId: hitId,
        assignmentId: assignmentId,
        workerId: workerId,
        batchId: batchId,
        test: true
      }
    ],
    userCallback: function(err) {
      if (err) console.log(err);
      else {
        console.info("HIT login successful!");
        InsecureLogin.run();
      }
    }
  });
} else {
  InsecureLogin.run();
}

if (Meteor.isServer) {
  // Ensure batch exists
  Batches.upsert("expClientBatch", {
    $set: { active: true }
  });
}
