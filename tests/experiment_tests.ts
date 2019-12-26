// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS104: Avoid inline assignments
 * DS204: Change includes calls to have a more natural evaluation order
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */

import { Meteor } from "meteor/meteor";
import { Mongo } from "meteor/mongo";
import { Accounts } from "meteor/accounts-base";
import { Random } from "meteor/random";
import { Tinytest } from "meteor/tinytest";

import { Partitioner } from "meteor/mizzao:partitioner";

import TurkServer, { TestUtils } from "../server";
import { Batches, Assignments, Experiments, Logs } from "../lib/common";

const Doobie = new Mongo.Collection<any>("experiment_test");

Partitioner.partitionCollection(Doobie);

let setupContext = undefined;
let reconnectContext = undefined;
let disconnectContext = undefined;
let idleContext = undefined;
let activeContext = undefined;

TurkServer.initialize(function() {
  return (setupContext = this);
});

TurkServer.initialize(function() {
  Doobie.insert({
    foo: "bar"
  });

  // Test deferred insert
  return Meteor.defer(() =>
    Doobie.insert({
      bar: "baz"
    })
  );
});

TurkServer.onConnect(function() {
  return (reconnectContext = this);
});
TurkServer.onDisconnect(function() {
  return (disconnectContext = this);
});
TurkServer.onIdle(function() {
  return (idleContext = this);
});
TurkServer.onActive(function() {
  return (activeContext = this);
});

// Ensure batch exists
const batchId = "expBatch";
Batches.upsert({ _id: batchId }, { _id: batchId });

// Set up a treatment for testing
TurkServer.ensureTreatmentExists({
  name: "fooTreatment",
  fooProperty: "bar"
});

const batch = TurkServer.Batch.getBatch("expBatch");

const createAssignment = function() {
  const workerId = Random.id();
  const userId = Accounts.insertUserDoc(
    {},
    {
      workerId,
      turkserver: { state: "lobby" } // Created user goes in lobby
    }
  );
  return TurkServer.Assignment.createAssignment({
    batchId: "expBatch",
    hitId: Random.id(),
    assignmentId: Random.id(),
    workerId,
    acceptTime: new Date(),
    status: "assigned"
  });
};

const withCleanup = TestUtils.getCleanupWrapper({
  before() {
    // Clear any callback records
    setupContext = undefined;
    reconnectContext = undefined;
    disconnectContext = undefined;
    idleContext = undefined;
    return (activeContext = undefined);
  },

  after() {
    // Delete assignments
    Assignments.remove({ batchId: "expBatch" });
    // Delete generated log entries
    Experiments.find({ batchId: "expBatch" }).forEach(exp => Logs.remove({ _groupId: exp._id }));
    // Delete experiments
    Experiments.remove({ batchId: "expBatch" });

    // Clear contents of partitioned collection
    return Doobie.direct.remove({});
  }
});

const lastLog = groupId => Logs.findOne({ _groupId: groupId }, { sort: { _timestamp: -1 } });

Tinytest.add(
  "experiment - batch - creation and retrieval",
  withCleanup(function(test) {
    // First get should create, second get should return same object
    // TODO: this test will only run as intended on the first try
    const batch2 = TurkServer.Batch.getBatch("expBatch");

    return test.equal(batch2, batch);
  })
);

Tinytest.add(
  `experiment - assignment - currentAssignment in standalone \
server code returns null`,
  test => test.equal(TurkServer.Assignment.currentAssignment(), null)
);

Tinytest.add(
  "experiment - instance - throws error if doesn't exist",
  withCleanup(test => test.throws(() => TurkServer.Instance.getInstance("yabbadabbadoober")))
);

Tinytest.add(
  "experiment - instance - create",
  withCleanup(function(test) {
    const treatments = ["fooTreatment"];

    // Create a new id to test specified ID
    const serverInstanceId = Random.id();

    const instance = batch.createInstance(treatments, {
      _id: serverInstanceId
    });
    test.equal(instance.groupId, serverInstanceId);
    test.instanceOf(instance, TurkServer.Instance);

    // Batch and treatments recorded - no start time until someone joins
    const instanceData = Experiments.findOne(serverInstanceId);
    test.equal(instanceData.batchId, "expBatch");
    test.equal(instanceData.treatments, treatments);

    test.isFalse(instanceData.startTime);

    // Test that create meta event was recorded in log
    const logEntry = lastLog(serverInstanceId);
    test.isTrue(logEntry);
    test.equal(logEntry != null ? logEntry._meta : undefined, "created");

    // Getting the instance again should get the same one
    const inst2 = TurkServer.Instance.getInstance(serverInstanceId);
    return test.equal(inst2, instance);
  })
);

Tinytest.add(
  "experiment - instance - setup context",
  withCleanup(function(test) {
    const treatments = ["fooTreatment"];
    const instance = batch.createInstance(treatments);
    TestUtils.sleep(10); // Enforce different log timestamp
    instance.setup();

    test.isTrue(setupContext);
    const treatment = setupContext != null ? setupContext.instance.treatment() : undefined;

    test.equal(instance.batch(), TurkServer.Batch.getBatch("expBatch"));

    test.isTrue(treatment);
    test.isTrue(
      Array.from(treatment.treatments).includes("fooTreatment"),
      test.equal(treatment.fooProperty, "bar")
    );
    test.equal(setupContext != null ? setupContext.instance.groupId : undefined, instance.groupId);

    // Check that the init _meta event was logged with treatment info
    const logEntry = lastLog(instance.groupId);
    test.isTrue(logEntry);
    test.equal(logEntry != null ? logEntry._meta : undefined, "initialized");
    test.equal(logEntry != null ? logEntry.treatmentData : undefined, treatment);
    test.equal(logEntry != null ? logEntry.treatmentData.treatments : undefined, treatments);
    return test.equal(logEntry != null ? logEntry.treatmentData.fooProperty : undefined, "bar");
  })
);

Tinytest.add(
  "experiment - instance - teardown and log",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();
    TestUtils.sleep(10); // Enforce different log timestamp
    instance.teardown();

    const logEntry = lastLog(instance.groupId);
    test.isTrue(logEntry);
    test.equal(logEntry != null ? logEntry._meta : undefined, "teardown");

    const instanceData = Experiments.findOne(instance.groupId);
    return test.instanceOf(instanceData.endTime, Date);
  })
);

Tinytest.add(
  "experiment - instance - get treatment on server",
  withCleanup(function(test) {
    const instance = batch.createInstance(["fooTreatment"]);

    // Note this only tests world treatments. Assignment treatments have to be
    // tested with the janky client setup.

    // However, This also tests accessing server treatments outside of a client context.
    instance.bindOperation(function() {
      const treatment = TurkServer.treatment();
      test.equal(treatment.treatments[0], "fooTreatment");
      return test.equal(treatment.fooProperty, "bar");
    });

    // Undefined outside of an experiment instance
    const treatment = TurkServer.treatment();
    return test.equal(treatment.fooProperty, undefined);
  })
);

Tinytest.add(
  "experiment - instance - global group",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup(); // Inserts two items

    TestUtils.sleep(100); // Let deferred insert finish

    instance.bindOperation(() =>
      Doobie.insert({
        foo2: "bar"
      })
    );

    const stuff = Partitioner.directOperation(() => Doobie.find().fetch());

    test.length(stuff, 3);

    // Setup insert
    test.equal(stuff[0].foo, "bar");
    test.equal(stuff[0]._groupId, instance.groupId);
    // Deferred insert
    test.equal(stuff[1].bar, "baz");
    test.equal(stuff[1]._groupId, instance.groupId);
    // Bound insert
    test.equal(stuff[2].foo2, "bar");
    return test.equal(stuff[2]._groupId, instance.groupId);
  })
);

Tinytest.add(
  "experiment - assignment - reject adding user to ended instance",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    instance.teardown();

    const asst = createAssignment();

    test.throws(() => instance.addAssignment(asst));

    const user = Meteor.users.findOne(asst.userId);
    const asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));
    test.length(instance.users(), 0);
    test.equal(user.turkserver.state, "lobby");

    return test.isFalse(asstData.instances);
  })
);

Tinytest.add(
  "experiment - assignment - addAssignment records start time and instance id",
  withCleanup(function(test) {
    let needle;
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    const user = Meteor.users.findOne(asst.userId);
    const asstData = Assignments.findOne(asst.asstId);
    const instanceData = Experiments.findOne(instance.groupId);

    test.equal(Partitioner.getUserGroup(asst.userId), instance.groupId);

    test.isTrue(((needle = asst.userId), Array.from(instance.users()).includes(needle)));
    test.instanceOf(instanceData.startTime, Date);

    test.equal(user.turkserver.state, "experiment");
    test.instanceOf(asstData.instances, Array);

    test.isTrue(asstData.instances[0]);
    test.equal(asstData.instances[0].id, instance.groupId);
    return test.isTrue(asstData.instances[0].joinTime);
  })
);

Tinytest.add(
  "experiment - assignment - second addAssignment does not change date",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    let instanceData = Experiments.findOne(instance.groupId);
    test.instanceOf(instanceData.startTime, Date);

    const startedDate = instanceData.startTime;

    TestUtils.sleep(10);
    // Add a second user
    const asst2 = createAssignment();
    instance.addAssignment(asst2);

    instanceData = Experiments.findOne(instance.groupId);
    // Should be the same date as originally
    return test.equal(instanceData.startTime, startedDate);
  })
);

Tinytest.add(
  "experiment - assignment - teardown with returned assignment",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    asst.setReturned();

    instance.teardown(); // This should not throw

    const user = Meteor.users.findOne(asst.userId);
    const asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));
    test.isFalse(user.turkserver != null ? user.turkserver.state : undefined);
    test.isTrue(asstData.instances[0]);
    return test.equal(asstData.status, "returned");
  })
);

Tinytest.add(
  "experiment - assignment - user disconnect and reconnect",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    TestUtils.connCallbacks.sessionDisconnect({
      userId: asst.userId
    });

    test.isTrue(disconnectContext);
    test.equal(disconnectContext != null ? disconnectContext.event : undefined, "disconnected");
    test.equal(disconnectContext != null ? disconnectContext.instance : undefined, instance);
    test.equal(disconnectContext != null ? disconnectContext.userId : undefined, asst.userId);

    let asstData = Assignments.findOne(asst.asstId);

    // TODO ensure the accounting here is done correctly
    let discTime = null;

    test.isTrue(asstData.instances[0]);
    test.isTrue(asstData.instances[0].joinTime);
    test.isTrue((discTime = asstData.instances[0].lastDisconnect));

    TestUtils.connCallbacks.sessionReconnect({
      userId: asst.userId
    });

    test.isTrue(reconnectContext);
    test.equal(reconnectContext != null ? reconnectContext.event : undefined, "connected");
    test.equal(reconnectContext != null ? reconnectContext.instance : undefined, instance);
    test.equal(reconnectContext != null ? reconnectContext.userId : undefined, asst.userId);

    asstData = Assignments.findOne(asst.asstId);
    test.isFalse(asstData.instances[0].lastDisconnect);
    // We don't know the exact length of disconnection, but make sure it's in the right ballpark
    test.isTrue(asstData.instances[0].disconnectedTime > 0);
    return test.isTrue(asstData.instances[0].disconnectedTime < Date.now() - discTime);
  })
);

Tinytest.add(
  "experiment - assignment - user idle and re-activate",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    const idleTime = new Date();

    TestUtils.connCallbacks.sessionIdle({
      userId: asst.userId,
      lastActivity: idleTime
    });

    test.isTrue(idleContext);
    test.equal(idleContext != null ? idleContext.event : undefined, "idle");
    test.equal(idleContext != null ? idleContext.instance : undefined, instance);
    test.equal(idleContext != null ? idleContext.userId : undefined, asst.userId);

    let asstData = Assignments.findOne(asst.asstId);
    test.isTrue(asstData.instances[0]);
    test.isTrue(asstData.instances[0].joinTime);
    test.equal(asstData.instances[0].lastIdle, idleTime);

    const offset = 1000;
    const activeTime = new Date(idleTime.getTime() + offset);

    TestUtils.connCallbacks.sessionActive({
      userId: asst.userId,
      lastActivity: activeTime
    });

    test.isTrue(activeContext);
    test.equal(activeContext != null ? activeContext.event : undefined, "active");
    test.equal(activeContext != null ? activeContext.instance : undefined, instance);
    test.equal(activeContext != null ? activeContext.userId : undefined, asst.userId);

    asstData = Assignments.findOne(asst.asstId);
    test.isFalse(asstData.instances[0].lastIdle);
    test.equal(asstData.instances[0].idleTime, offset);

    // Another bout of inactivity
    const secondIdleTime = new Date(activeTime.getTime() + 5000);
    const secondActiveTime = new Date(secondIdleTime.getTime() + offset);

    TestUtils.connCallbacks.sessionIdle({
      userId: asst.userId,
      lastActivity: secondIdleTime
    });

    TestUtils.connCallbacks.sessionActive({
      userId: asst.userId,
      lastActivity: secondActiveTime
    });

    asstData = Assignments.findOne(asst.asstId);
    test.isFalse(asstData.instances[0].lastIdle);
    return test.equal(asstData.instances[0].idleTime, offset + offset);
  })
);

Tinytest.add(
  "experiment - assignment - user disconnect while idle",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    const idleTime = new Date();

    TestUtils.connCallbacks.sessionIdle({
      userId: asst.userId,
      lastActivity: idleTime
    });

    TestUtils.connCallbacks.sessionDisconnect({
      userId: asst.userId
    });

    const asstData = Assignments.findOne(asst.asstId);
    test.isTrue(asstData.instances[0].joinTime);
    // Check that idle fields exist
    test.isFalse(asstData.instances[0].lastIdle);
    test.isTrue(asstData.instances[0].idleTime);
    // Check that disconnect fields exist
    return test.isTrue(asstData.instances[0].lastDisconnect);
  })
);

Tinytest.add(
  "experiment - assignment - idleness is cleared on reconnection",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    const idleTime = new Date();

    TestUtils.connCallbacks.sessionDisconnect({
      userId: asst.userId
    });

    TestUtils.connCallbacks.sessionIdle({
      userId: asst.userId,
      lastActivity: idleTime
    });

    TestUtils.sleep(100);

    TestUtils.connCallbacks.sessionReconnect({
      userId: asst.userId
    });

    const asstData = Assignments.findOne(asst.asstId);

    test.isTrue(asstData.instances[0].joinTime);
    // Check that idleness was not counted
    test.isFalse(asstData.instances[0].lastIdle);
    test.isFalse(asstData.instances[0].idleTime);
    // Check that disconnect fields exist
    test.isFalse(asstData.instances[0].lastDisconnect);
    return test.isTrue(asstData.instances[0].disconnectedTime);
  })
);

Tinytest.add(
  "experiment - assignment - teardown while disconnected",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    TestUtils.connCallbacks.sessionDisconnect({
      userId: asst.userId
    });

    let discTime = null;
    let asstData = Assignments.findOne(asst.asstId);
    test.isTrue((discTime = asstData.instances[0].lastDisconnect));

    instance.teardown();

    asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));

    test.isTrue(asstData.instances[0].leaveTime);
    test.isFalse(asstData.instances[0].lastDisconnect);
    // We don't know the exact length of disconnection, but make sure it's in the right ballpark
    test.isTrue(asstData.instances[0].disconnectedTime > 0);
    return test.isTrue(asstData.instances[0].disconnectedTime < Date.now() - discTime);
  })
);

Tinytest.add(
  "experiment - assignment - teardown while idle",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    const idleTime = new Date();

    TestUtils.connCallbacks.sessionIdle({
      userId: asst.userId,
      lastActivity: idleTime
    });

    instance.teardown();

    const asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));

    test.isTrue(asstData.instances[0].leaveTime);
    test.isFalse(asstData.instances[0].lastIdle);
    return test.isTrue(asstData.instances[0].idleTime);
  })
);

Tinytest.add(
  "experiment - assignment - leave instance after teardown",
  withCleanup(function(test) {
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    // Immediately disconnect
    TestUtils.connCallbacks.sessionDisconnect({
      userId: asst.userId
    });

    instance.teardown(false);

    // Wait a bit to ensure we have the right value; the above should have
    // completed within this interval
    TestUtils.sleep(200);

    // Could do either of the below
    instance.sendUserToLobby(asst.userId);

    const asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));

    test.isTrue(asstData.instances[0].leaveTime);
    test.isFalse(asstData.instances[0].lastDisconnect);
    // We don't know the exact length of disconnection, but make sure it's in the right ballpark
    test.isTrue(asstData.instances[0].disconnectedTime > 0);
    return test.isTrue(asstData.instances[0].disconnectedTime < 200);
  })
);

Tinytest.add(
  "experiment - assignment - teardown and join second instance",
  withCleanup(function(test) {
    let needle, needle1;
    const instance = batch.createInstance([]);
    instance.setup();

    const asst = createAssignment();

    instance.addAssignment(asst);

    instance.teardown();

    let user = Meteor.users.findOne(asst.userId);
    let asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));

    test.isTrue(((needle = asst.userId), Array.from(instance.users()).includes(needle))); // Shouldn't have been removed
    test.equal(user.turkserver.state, "lobby");
    test.instanceOf(asstData.instances, Array);

    test.isTrue(asstData.instances[0]);
    test.equal(asstData.instances[0].id, instance.groupId);
    test.isTrue(asstData.instances[0].joinTime);
    test.isTrue(asstData.instances[0].leaveTime);

    const instance2 = batch.createInstance([]);
    instance2.setup();

    instance2.addAssignment(asst);

    user = Meteor.users.findOne(asst.userId);

    test.equal(Partitioner.getUserGroup(asst.userId), instance2.groupId);
    test.equal(user.turkserver.state, "experiment");

    instance2.teardown();

    user = Meteor.users.findOne(asst.userId);
    asstData = Assignments.findOne(asst.asstId);

    test.isFalse(Partitioner.getUserGroup(asst.userId));

    test.isTrue(((needle1 = asst.userId), Array.from(instance2.users()).includes(needle1))); // Shouldn't have been removed
    test.equal(user.turkserver.state, "lobby");
    test.instanceOf(asstData.instances, Array);

    // Make sure array-based updates worked
    test.isTrue(asstData.instances[1]);
    test.equal(asstData.instances[1].id, instance2.groupId);
    test.notEqual(asstData.instances[0].joinTime, asstData.instances[1].joinTime);
    return test.notEqual(asstData.instances[0].leaveTime, asstData.instances[1].leaveTime);
  })
);
