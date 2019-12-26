// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Meteor } from "meteor/meteor";
import { Tinytest } from "meteor/tinytest";

import TurkServer, { TestUtils } from "../server";
import { Batches, HITTypes, HITs, Assignments, ErrMsg } from "../lib/common";
import { authenticateWorker } from "../server/accounts_mturk";

const hitType = "authHitType";

const hitId = "authHitId";
const hitId2 = "authHitId2";

const assignmentId = "authAssignmentId";
const assignmentId2 = "authAssignmentId2";

const workerId = "authWorkerId";
const workerId2 = "authWorkerId2";

const experimentId = "authExperimentId";

// Ensure that users with these workerIds exist
Meteor.users.upsert("authUser1", { $set: { workerId } });
Meteor.users.upsert("authUser2", { $set: { workerId: workerId2 } });

const authBatchId = "authBatch";
const otherBatchId = "someOtherBatch";

// Set up a dummy batch
if (Batches.findOne(authBatchId) == null) {
  Batches.insert({ _id: authBatchId });
}

// Set up a dummy HIT type and HITs
HITTypes.upsert(
  { HITTypeId: hitType },
  {
    $set: {
      batchId: authBatchId
    }
  }
);
HITs.upsert({ HITId: hitId }, { $set: { HITTypeId: hitType } });
HITs.upsert({ HITId: hitId2 }, { $set: { HITTypeId: hitType } });

// We can use the after wrapper here because the tests are synchronous
const withCleanup = TestUtils.getCleanupWrapper({
  before() {
    return Batches.update(authBatchId, {
      $set: { active: true },
      $unset: { allowReturns: null }
    });
  },
  after() {
    // Only remove assignments created here to avoid side effects on server-client tests
    return Assignments.remove({
      $or: [{ batchId: authBatchId }, { batchId: otherBatchId }]
    });
  }
});

Tinytest.add(
  "auth - with first time hit assignment",
  withCleanup(function(test) {
    const asst = authenticateWorker({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId
    });

    // Test in-memory stored values
    test.equal(asst.batchId, authBatchId);
    test.equal(asst.hitId, hitId);
    test.equal(asst.assignmentId, assignmentId);
    test.equal(asst.workerId, workerId);
    test.equal(asst.userId, "authUser1");

    // Test database storage
    const record = Assignments.findOne({
      hitId,
      assignmentId
    });

    test.isTrue(record);
    test.equal(record.workerId, workerId, "workerId not saved");
    return test.equal(record.batchId, authBatchId);
  })
);

Tinytest.add(
  "auth - reject incorrect batch",
  withCleanup(function(test) {
    const testFunc = () =>
      authenticateWorker({
        batchId: otherBatchId,
        hitId,
        assignmentId,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.unexpectedBatch);
  })
);

Tinytest.add(
  "auth - connection to inactive batch is rejected",
  withCleanup(function(test) {
    // Active is set to back to true on cleanup
    Batches.update(authBatchId, { $unset: { active: false } });

    const testFunc = () =>
      authenticateWorker({
        batchId: authBatchId,
        hitId,
        assignmentId,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.batchInactive);
  })
);

Tinytest.add(
  "auth - reconnect - with existing hit assignment",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "assigned"
    });

    // This needs to return an assignment
    const asst = authenticateWorker({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId
    });

    const record = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    test.equal(asst, TurkServer.Assignment.getAssignment(record._id));
    test.equal(asst.batchId, authBatchId);
    test.equal(asst.hitId, hitId);
    test.equal(asst.assignmentId, assignmentId);
    test.equal(asst.workerId, workerId);
    test.equal(asst.userId, "authUser1");

    return test.equal(record.status, "assigned");
  })
);

Tinytest.add(
  "auth - reconnect - with existing hit after batch is inactive",
  withCleanup(function(test) {
    // Active is set to back to true on cleanup
    Batches.update(authBatchId, { $unset: { active: false } });

    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "assigned"
    });

    TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId
    });

    const record = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    return test.equal(record.status, "assigned");
  })
);

Tinytest.add(
  "auth - with overlapping hit in experiment",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "assigned",
      experimentId
    });

    // Authenticate with different worker
    const asst = TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId: workerId2
    });

    const prevRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    const newRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId: workerId2
    });

    test.isTrue(asst);
    test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id));

    test.equal(prevRecord.status, "returned");

    return test.equal(newRecord.status, "assigned");
  })
);

Tinytest.add(
  "auth - with overlapping hit completed",
  withCleanup(function(test) {
    // This case should not happen often
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "completed"
    });

    // Authenticate with different worker
    const asst = TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId: workerId2
    });

    const prevRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    const newRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId: workerId2
    });

    test.isTrue(asst);
    test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id));

    test.equal(prevRecord.status, "completed");

    return test.equal(newRecord.status, "assigned");
  })
);

Tinytest.add(
  "auth - same worker completed hit",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "completed"
    });

    const testFunc = () =>
      TestUtils.authenticateWorker({
        batchId: authBatchId,
        hitId,
        assignmentId,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.alreadyCompleted);
  })
);

Tinytest.add(
  "auth - limit - concurrent across hits",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "assigned"
    });

    const testFunc = () =>
      TestUtils.authenticateWorker({
        batchId: authBatchId,
        hitId: hitId2,
        assignmentId: assignmentId2,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.simultaneousLimit);
  })
);

// Not sure this test needs to exist because only 1 assignment per worker for a HIT
Tinytest.add(
  "auth - limit - concurrent across assts",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "assigned"
    });

    const testFunc = () =>
      TestUtils.authenticateWorker({
        batchId: authBatchId,
        hitId,
        assignmentId: assignmentId2,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.simultaneousLimit);
  })
);

Tinytest.add(
  "auth - limit - too many total",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "completed"
    });
    // Should not trigger concurrent limit

    const testFunc = () =>
      TestUtils.authenticateWorker({
        batchId: authBatchId,
        hitId: hitId2,
        assignmentId: assignmentId2,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.batchLimit);
  })
);

Tinytest.add(
  "auth - limit - returns not allowed in batch",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "returned"
    });
    // Should not trigger concurrent limit

    const testFunc = () =>
      TestUtils.authenticateWorker({
        batchId: authBatchId,
        hitId: hitId2,
        assignmentId: assignmentId2,
        workerId
      });

    return test.throws(testFunc, e => e.error === 403 && e.reason === ErrMsg.batchLimit);
  })
);

Tinytest.add(
  "auth - limit - returns allowed in batch",
  withCleanup(function(test) {
    Batches.update(authBatchId, { $set: { allowReturns: true } });

    Assignments.insert({
      batchId: authBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "returned"
    });

    const asst = TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId: hitId2,
      assignmentId: assignmentId2,
      workerId
    });

    const prevRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    const newRecord = Assignments.findOne({
      hitId: hitId2,
      assignmentId: assignmentId2,
      workerId
    });

    test.isTrue(asst);
    test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id));

    test.equal(prevRecord.status, "returned");
    test.equal(prevRecord.batchId, authBatchId);

    test.equal(newRecord.status, "assigned");
    return test.equal(newRecord.batchId, authBatchId);
  })
);

Tinytest.add(
  "auth - limit - allowed after previous batch",
  withCleanup(function(test) {
    Assignments.insert({
      batchId: otherBatchId,
      hitId,
      assignmentId,
      workerId,
      status: "completed"
    });
    // Should not trigger concurrent limit

    const asst = TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId: hitId2,
      assignmentId: assignmentId2,
      workerId
    });

    const prevRecord = Assignments.findOne({
      hitId,
      assignmentId,
      workerId
    });

    const newRecord = Assignments.findOne({
      hitId: hitId2,
      assignmentId: assignmentId2,
      workerId
    });

    test.isTrue(asst);
    test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id));

    test.equal(prevRecord.status, "completed");
    test.equal(prevRecord.batchId, "someOtherBatch");

    test.equal(newRecord.status, "assigned");
    return test.equal(newRecord.batchId, authBatchId);
  })
);

// Worker is used for the test below
Meteor.users.upsert("testWorker", { $set: { workerId: "testingWorker" } });

Tinytest.add(
  "auth - testing HIT login doesn't require existing HIT",
  withCleanup(function(test) {
    const asst = TestUtils.authenticateWorker({
      batchId: authBatchId,
      hitId: "testingHIT",
      assignmentId: "testingAsst",
      workerId: "testingWorker",
      test: true
    });

    // Test database storage
    const record = Assignments.findOne({
      hitId: "testingHIT",
      assignmentId: "testingAsst"
    });

    test.isTrue(asst);
    test.equal(asst, TurkServer.Assignment.getAssignment(record._id));

    test.isTrue(record);
    test.equal(record.workerId, "testingWorker");
    return test.equal(record.batchId, authBatchId);
  })
);
