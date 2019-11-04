/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let batch = null;

const withCleanup = TestUtils.getCleanupWrapper({
  before() {
    // Create a random batch and corresponding lobby for assigner tests
    const batchId = Batches.insert({});
    return batch = TurkServer.Batch.getBatch(batchId);
  },
  after() {
    Experiments.remove({ batchId: batch.batchId });
    return Assignments.remove({ batchId: batch.batchId });
  }});

const tutorialTreatments = [ "tutorial" ];
const groupTreatments = [ "group" ];

TurkServer.ensureTreatmentExists({
  name: "tutorial"});
TurkServer.ensureTreatmentExists({
  name: "group"});

const createAssignment = function() {
  const workerId = Random.id();
  const userId = Accounts.insertUserDoc({}, { workerId });
  return TurkServer.Assignment.createAssignment({
    batchId: batch.batchId,
    hitId: Random.id(),
    assignmentId: Random.id(),
    workerId,
    acceptTime: new Date(),
    status: "assigned"
  });
};

Tinytest.add("assigners - tutorialGroup - assigner picks up existing instance", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments);

  const instance = batch.createInstance(groupTreatments);
  instance.setup();

  batch.setAssigner(assigner);

  test.equal(assigner.instance, instance);
  return test.equal(assigner.autoAssign, true);
})
);

Tinytest.add("assigners - tutorialGroup - initial lobby gets tutorial", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments);
  batch.setAssigner(assigner);

  test.equal(assigner.autoAssign, false);

  const asst = createAssignment();
  TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});

  TestUtils.sleep(150); // YES!!

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  test.equal(user.turkserver.state, "experiment");
  test.length(instances, 1);

  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);
  const exp = Experiments.findOne(instances[0].id);
  return test.equal(exp.treatments, tutorialTreatments);
})
);

Tinytest.add("assigners - tutorialGroup - autoAssign event triggers properly", withCleanup(function(test) {

  const assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments);
  batch.setAssigner(assigner);

  const asst = createAssignment();
  // Pretend we already have a tutorial done
  const tutorialInstance = batch.createInstance(tutorialTreatments);
  tutorialInstance.setup();
  tutorialInstance.addAssignment(asst);
  tutorialInstance.teardown();

  TestUtils.sleep(100); // So the user joins the lobby properly

  let user = Meteor.users.findOne(asst.userId);
  let instances = asst.getInstances();

  test.equal(user.turkserver.state, "lobby");
  test.length(instances, 1);

  batch.lobby.events.emit("auto-assign");

  TestUtils.sleep(100);

  user = Meteor.users.findOne(asst.userId);
  instances = asst.getInstances();

  test.equal(user.turkserver.state, "experiment");
  test.length(instances, 2);

  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);
  const exp = Experiments.findOne(instances[1].id);
  return test.equal(exp.treatments, groupTreatments);
})
);

Tinytest.add("assigners - tutorialGroup - final send to exit survey", withCleanup(function(test) {

  const assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments);
  batch.setAssigner(assigner);

  const asst = createAssignment();
  // Pretend we already have a tutorial done
  const tutorialInstance = batch.createInstance(tutorialTreatments);
  tutorialInstance.setup();
  tutorialInstance.addAssignment(asst);
  tutorialInstance.teardown();

  TestUtils.sleep(100); // So the user joins the lobby properly

  const groupInstance = batch.createInstance(groupTreatments);
  groupInstance.setup();
  groupInstance.addAssignment(asst);
  groupInstance.teardown();

  TestUtils.sleep(100);

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  test.equal(user.turkserver.state, "exitsurvey");
  return test.length(instances, 2);
})
);

// Setup for multi tests below
TurkServer.ensureTreatmentExists({
  name: "tutorial"});

TurkServer.ensureTreatmentExists({
  name: "parallel_worlds"});

const multiGroupTreatments = [ "parallel_worlds" ];

/*
  Randomized multi-group assigner
*/

Tinytest.add("assigners - tutorialRandomizedGroup - initial lobby gets tutorial", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, [8, 16, 32]);

  batch.setAssigner(assigner);

  const asst = createAssignment();
  TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});

  TestUtils.sleep(150);

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  // should be in experiment
  test.equal(user.turkserver.state, "experiment");
  test.length(instances, 1);
  // should not be in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);
  // should be in a tutorial
  const exp = Experiments.findOne(instances[0].id);
  return test.equal(exp.treatments, tutorialTreatments);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - send to exit survey", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, [8, 16, 32]);

  batch.setAssigner(assigner);

  const asst = createAssignment();
  // Pretend we already have two instances done
  Assignments.update(asst.asstId, {
    $push: {
      instances: {
        $each: [
          { id: Random.id() },
          { id: Random.id() }
        ]
      }
    }
  });

  TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});

  TestUtils.sleep(100);

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  test.equal(user.turkserver.state, "exitsurvey");
  return test.length(instances, 2);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - set up instances", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, [8, 16, 32]);

  batch.setAssigner(assigner);

  assigner.setup();

  // Verify that four instances were created with the right treatments
  const created = Experiments.find({ batchId: batch.batchId }).fetch();

  test.length(created, 4);

  // Sort by group size and test
  created.sort(function(a, b) {
    if (a.treatments[0] === "parallel_worlds") { return 1;
    } else if (b.treatments[0] === "parallel_worlds") { return -1;
    // grab the part after "group_"
    } else { return parseInt(a.treatments[0].substring(6)) - parseInt(b.treatments[0].substring(6)); }
  });

  test.equal(created[0].treatments, [ "group_8", "parallel_worlds" ]);
  test.equal(created[1].treatments, [ "group_16", "parallel_worlds" ]);
  test.equal(created[2].treatments, [ "group_32", "parallel_worlds" ]);
  // Buffer group
  test.equal(created[3].treatments, [ "parallel_worlds" ]);

  // Test that there are 56 randomization slots now with the right allocation
  test.isFalse(assigner.autoAssign);
  test.isTrue(assigner.bufferInstanceId);

  test.length(assigner.instanceSlots, 56);
  test.equal(assigner.instanceSlotIndex, 0);

  const allocation = _.countBy(assigner.instanceSlots, Object);
  test.equal(allocation[created[0]._id], 8);
  test.equal(allocation[created[1]._id], 16);
  test.equal(allocation[created[2]._id], 32);

  // Calling setup again should not do anything
  assigner.setup();

  return test.length(Experiments.find({ batchId: batch.batchId }).fetch(), 4);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - set up reusing existing instances", withCleanup(function(test) {
  const groupArr = [
    1, 1, 1, 1, 1, 1, 1, 1,
    2, 2, 2, 2,
    4, 4,
    8, 16, 32
  ];

  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Create one existing treatment of group size 1
  const instance = batch.createInstance( ["group_1"].concat(multiGroupTreatments) );
  instance.setup();

  batch.setAssigner(assigner);

  assigner.setup();

  // Verify that 18 instances were created with the right treatments
  const created = Experiments.find({ batchId: batch.batchId }).fetch();

  test.length(created, 18);

  // Test that there are 56 randomization slots now with the right allocation
  test.isFalse(assigner.autoAssign);
  test.isTrue(assigner.bufferInstanceId);

  test.length(assigner.instanceSlots, 80);
  return test.equal(assigner.instanceSlotIndex, 0);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - pick up existing instances", withCleanup(function(test) {
  const groupArr = [8, 16, 32];
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Generate the config that the group assigner would have
  const groupConfig = TurkServer.Assigners.TutorialRandomizedGroupAssigner
    .generateConfig(groupArr, multiGroupTreatments);

  const created = [];

  for (let i = 0; i < groupConfig.length; i++) {
    const conf = groupConfig[i];
    const instance = batch.createInstance(conf.treatments);
    instance.setup();

    created.push(instance.groupId);
  }

  batch.setAssigner(assigner);

  // Test that there are 56 randomization slots now with the right allocation
  test.isFalse(assigner.autoAssign);
  test.isTrue(assigner.bufferInstanceId);

  test.length(assigner.instanceSlots, 56);
  test.equal(assigner.instanceSlotIndex, 0);

  const allocation = _.countBy(assigner.instanceSlots, Object);
  test.equal(allocation[created[0]], 8);
  test.equal(allocation[created[1]], 16);
  return test.equal(allocation[created[2]], 32);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - resume with partial allocation", withCleanup(function(test) {
  const groupArr = [8, 16, 32];
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Generate the config that the group assigner would have
  const groupConfig = TurkServer.Assigners.TutorialRandomizedGroupAssigner
    .generateConfig(groupArr, multiGroupTreatments);

  const created = [];

  for (let i = 0; i < groupConfig.length; i++) {
    const conf = groupConfig[i];
    const instance = batch.createInstance(conf.treatments);
    instance.setup();

    // Fill each group half full
    for (let j = 1, end = conf.size/2, asc = 1 <= end; asc ? j <= end : j >= end; asc ? j++ : j--) {
      const asst = createAssignment();

      // Pretend like this instance did the tutorial
      const tutorialInstance = batch.createInstance(tutorialTreatments);
      tutorialInstance.setup();
      tutorialInstance.addAssignment(asst);
      tutorialInstance.teardown();

      instance.addAssignment(asst);
    }

    created.push(instance.groupId);
  }

  // Run it
  batch.setAssigner(assigner);

  // Test that there are 28 randomization slots now with the right allocation
  // auto-assign should be enabled because there are people in it
  test.isTrue(assigner.autoAssign);
  test.isTrue(assigner.bufferInstanceId);

  test.length(assigner.instanceSlots, 28);
  test.equal(assigner.instanceSlotIndex, 0);

  const allocation = _.countBy(assigner.instanceSlots, Object);
  test.equal(allocation[created[0]], 8/2);
  test.equal(allocation[created[1]], 16/2);
  return test.equal(allocation[created[2]], 32/2);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - resume with fully allocated groups", withCleanup(function(test) {
  const groupArr = [8, 16, 32];
  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Generate the config that the group assigner would have
  const groupConfig = TurkServer.Assigners.TutorialRandomizedGroupAssigner
    .generateConfig(groupArr, multiGroupTreatments);

  const created = [];

  for (let i = 0; i < groupConfig.length; i++) {
    const conf = groupConfig[i];
    const instance = batch.createInstance(conf.treatments);
    instance.setup();

    // Fill each group half full
    for (let j = 1, end = conf.size, asc = 1 <= end; asc ? j <= end : j >= end; asc ? j++ : j--) {
      const asst = createAssignment();

      // Pretend like this instance did the tutorial
      const tutorialInstance = batch.createInstance(tutorialTreatments);
      tutorialInstance.setup();
      tutorialInstance.addAssignment(asst);
      tutorialInstance.teardown();

      instance.addAssignment(asst);
    }

    created.push(instance.groupId);
  }

  // Run it
  batch.setAssigner(assigner);

  // auto-assign should be enabled because there are people in it
  test.isTrue(assigner.autoAssign);
  test.isTrue(assigner.bufferInstanceId);

  test.length(assigner.instanceSlots, 0);
  return test.equal(assigner.instanceSlotIndex, 0);
})
);

Tinytest.add("assigners - tutorialRandomizedGroup - assign with waiting room and sequential", withCleanup(function(test) {
  let exp, groupSize, instance, users;
  let i;
  const groupArr = [8, 16, 32];

  const assigner = new TurkServer.Assigners.TutorialRandomizedGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  batch.setAssigner(assigner);

  assigner.setup(); // Create instances

  test.isFalse(assigner.autoAssign);
  test.length(assigner.instanceSlots, 56);
  test.equal(assigner.instanceSlotIndex, 0);

  // Get the config that the group assigner would have
  const groupConfigMulti = assigner.groupConfig;

  const assts = ((() => {
    const result = [];
    for (i = 1; i <= 64; i++) {
      result.push(createAssignment());
    }
    return result;
  })());

  // Pretend they have all done the tutorial
  for (let asst of Array.from(assts)) {
    Assignments.update(asst.asstId,
      {$push: { instances: { id: Random.id() } }});
  }

  // Make the first half join
  for (i = 0; i <= 27; i++) {
    TestUtils.connCallbacks.sessionReconnect({userId: assts[i].userId});
  }

  TestUtils.sleep(500); // Give enough time for lobby functions to process

  // should have 32 users in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 28);

  // Run auto-assign
  assigner.assignAll();

  test.isTrue(assigner.autoAssign);
  test.length(assigner.instanceSlots, 56);
  test.equal(assigner.instanceSlotIndex, 28);

  TestUtils.sleep(500); // Give enough time for lobby functions to process
  // should have 0 users in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);

  const exps = Experiments.find({ batchId: batch.batchId }).fetch();

  // Check that the groups have the right size and treatments
  let totalAdded = 0;
  for (exp of Array.from(exps)) {
    instance = TurkServer.Instance.getInstance(exp._id);
    ({
      groupSize
    } = instance.treatment());

    if (groupSize != null) {
      users = instance.users();
      test.isTrue(users.length < groupSize);
      totalAdded += users.length;
    } else { // Buffer group should be empty
      test.length(instance.users(), 0);
    }
  }

  test.equal(totalAdded, 28);

  // Fill in remaining users
  for (i = 28; i <= 63; i++) {
    TestUtils.connCallbacks.sessionReconnect({userId: assts[i].userId});
  }

  test.isTrue(assigner.autoAssign);
  test.length(assigner.instanceSlots, 56);
  test.equal(assigner.instanceSlotIndex, 56);

  TestUtils.sleep(800);

  // Should have no one in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);

  // All groups should be filled with 8 in buffer
  totalAdded = 0;
  for (exp of Array.from(exps)) {
    instance = TurkServer.Instance.getInstance(exp._id);
    ({
      groupSize
    } = instance.treatment());

    users = instance.users();

    if (groupSize != null) {
      test.length(users, groupSize);
      totalAdded += users.length;
    } else { // Buffer group should have 8 users
      test.length(users, 8);
      totalAdded += users.length;
    }
  }

  test.equal(totalAdded, 64);

  // Test auto-stopping
  const lastInstance = TurkServer.Instance.getInstance(assigner.bufferInstanceId);
  lastInstance.teardown();

  const slackerAsst = createAssignment();

  Assignments.update(slackerAsst.asstId,
    {$push: { instances: { id: Random.id() } }});

  TestUtils.connCallbacks.sessionReconnect({userId: slackerAsst.userId});

  TestUtils.sleep(150);

  // ensure that user is still in lobby
  const user = Meteor.users.findOne(slackerAsst.userId);
  const instances = slackerAsst.getInstances();

  // should still be in lobby
  test.equal(user.turkserver.state, "lobby");
  test.length(instances, 1);
  return test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 1);
})
);

/*
  Multi-group assigner
*/

Tinytest.add("assigners - tutorialMultiGroup - initial lobby gets tutorial", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialMultiGroupAssigner(
    tutorialTreatments, multiGroupTreatments, [16, 16]);
  batch.setAssigner(assigner);

  const asst = createAssignment();
  TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});

  TestUtils.sleep(150); // YES!!

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  // should be in experiment
  test.equal(user.turkserver.state, "experiment");
  test.length(instances, 1);
  // should not be in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 0);
  // should be in a tutorial
  const exp = Experiments.findOne(instances[0].id);
  return test.equal(exp.treatments, tutorialTreatments);
})
);

Tinytest.add("assigners - tutorialMultiGroup - resumes from partial", withCleanup(function(test) {
  let conf, instance, j;
  let asc1, end1;
  const groupArr = [ 1, 1, 1, 1, 2, 2, 4, 4, 8, 16, 32, 16, 8, 4, 4, 2, 2, 1, 1, 1, 1 ];

  const assigner = new TurkServer.Assigners.TutorialMultiGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Generate the config that the group assigner would have
  const groupConfigMulti = TurkServer.Assigners.TutorialMultiGroupAssigner
    .generateConfig(groupArr, multiGroupTreatments);

  const borkedGroup = 10;
  const filledAmount = 16;

  // Say we are in the middle of the group of 32: index 10
  for (let i = 0; i < groupConfigMulti.length; i++) {
    var asc, end;
    conf = groupConfigMulti[i];
    if (i === borkedGroup) { break; }

    instance = batch.createInstance(conf.treatments);
    instance.setup();

    for (j = 1, end = conf.size, asc = 1 <= end; asc ? j <= end : j >= end; asc ? j++ : j--) {
      const asst = createAssignment();

      // Pretend like this instance did the tutorial
      const tutorialInstance = batch.createInstance(tutorialTreatments);
      tutorialInstance.setup();
      tutorialInstance.addAssignment(asst);
      tutorialInstance.teardown();

      instance.addAssignment(asst);
    }
  }

  conf = groupConfigMulti[borkedGroup];
  instance = batch.createInstance(conf.treatments);
  instance.setup();
   for (j = 1, end1 = filledAmount, asc1 = 1 <= end1; asc1 ? j <= end1 : j >= end1; asc1 ? j++ : j--) { instance.addAssignment(createAssignment()); } 

  batch.setAssigner(assigner);

  test.equal(assigner.currentGroup, borkedGroup);
  test.equal(assigner.currentInstance, instance);
  return test.equal(assigner.currentFilled, filledAmount);
})
);

Tinytest.add("assigners - tutorialMultiGroup - resumes on group boundary", withCleanup(function(test) {
  let instance;
  const groupArr = [ 1, 1, 1, 1, 2, 2, 4, 4, 8, 16, 32, 16, 8, 4, 4, 2, 2, 1, 1, 1, 1 ];

  const assigner = new TurkServer.Assigners.TutorialMultiGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  // Generate the config that the group assigner would have
  const groupConfigMulti = TurkServer.Assigners.TutorialMultiGroupAssigner
    .generateConfig(groupArr, multiGroupTreatments);

  const borkedGroup = 2;

  // Say we are in the middle of the group of 32: index 10
  for (let i = 0; i < groupConfigMulti.length; i++) {
    const conf = groupConfigMulti[i];
    if (i === borkedGroup) { break; }

    instance = batch.createInstance(conf.treatments);
    instance.setup();

    for (let j = 1, end = conf.size, asc = 1 <= end; asc ? j <= end : j >= end; asc ? j++ : j--) {
      const asst = createAssignment();

      // Pretend like this instance did the tutorial
      const tutorialInstance = batch.createInstance(tutorialTreatments);
      tutorialInstance.setup();
      tutorialInstance.addAssignment(asst);
      tutorialInstance.teardown();

      instance.addAssignment(asst);
    }
  }

  batch.setAssigner(assigner);

  test.equal(assigner.currentGroup, borkedGroup - 1);
  test.equal(assigner.currentInstance, instance);
  test.equal(assigner.currentFilled, groupConfigMulti[borkedGroup - 1].size);

  // Test reconfiguration into new groups
  const newArray = [16, 16];
  assigner.configure(newArray);

  test.equal(assigner.groupArray, newArray);
  test.equal(assigner.currentGroup, -1);
  test.equal(assigner.currentInstance, null);
  return test.equal(assigner.currentFilled, 0);
})
);

Tinytest.add("assigners - tutorialMultiGroup - send to exit survey", withCleanup(function(test) {
  const assigner = new TurkServer.Assigners.TutorialMultiGroupAssigner(
    tutorialTreatments, multiGroupTreatments, [16, 16]);

  batch.setAssigner(assigner);

  const asst = createAssignment();
  // Pretend we already have two instances done
  Assignments.update(asst.asstId, {
    $push: {
      instances: {
        $each: [
          { id: Random.id() },
          { id: Random.id() }
        ]
      }
    }
  });

  TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});

  TestUtils.sleep(100);

  const user = Meteor.users.findOne(asst.userId);
  const instances = asst.getInstances();

  test.equal(user.turkserver.state, "exitsurvey");
  return test.length(instances, 2);
})
);

Tinytest.add("assigners - tutorialMultiGroup - simultaneous multiple assignment", withCleanup(function(test) {
  let asst;
  let i;
  const groupArr = [ 1, 1, 1, 1, 2, 2, 4, 4, 8, 16, 32 ];

  const assigner = new TurkServer.Assigners.TutorialMultiGroupAssigner(
    tutorialTreatments, multiGroupTreatments, groupArr);

  batch.setAssigner(assigner);

  // Get the config that the group assigner would have
  const groupConfigMulti = assigner.groupConfig;

  const assts = ((() => {
    const result = [];
    for (i = 1; i <= 80; i++) {
      result.push(createAssignment());
    }
    return result;
  })());

  // Pretend they have all done the tutorial
  for (asst of Array.from(assts)) {
    Assignments.update(asst.asstId,
      {$push: { instances: { id: Random.id() } }});
  }

  // Make them all join simultaneously - lobby join is deferred
  for (asst of Array.from(assts)) {
    // TODO some sort of weirdness (write fence?) prevents us from deferring these
    TestUtils.connCallbacks.sessionReconnect({userId: asst.userId});
  }

  TestUtils.sleep(500); // Give enough time for lobby functions to process

  const exps = Experiments.find({batchId: batch.batchId}, {sort: {startTime: 1}}).fetch();

  // Check that the groups have the right size and treatments
  i = 0;
  while (i < groupConfigMulti.length) {
    const group = groupConfigMulti[i];
    const exp = exps[i];

    test.equal(exp.treatments[0], group.treatments[0]);
    test.equal(exp.treatments[1], group.treatments[1]);

    test.equal(exp.users.length, group.size);

    i++;
  }

  test.length(exps, groupConfigMulti.length);

  // Should have people in lobby
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 8);

  // Test auto-stopping
  const lastInstance = TurkServer.Instance.getInstance(exps[exps.length - 1]._id);
  lastInstance.teardown();

  const slackerAsst = createAssignment();

  Assignments.update(slackerAsst.asstId,
    {$push: { instances: { id: Random.id() } }});

  TestUtils.connCallbacks.sessionReconnect({userId: slackerAsst.userId});

  TestUtils.sleep(150);

  // assigner should have stopped
  test.equal(assigner.stopped, true);

  // ensure that user is still in lobby
  const user = Meteor.users.findOne(slackerAsst.userId);
  const instances = slackerAsst.getInstances();

  // should still be in lobby
  test.equal(user.turkserver.state, "lobby");
  test.length(instances, 1);
  test.equal(LobbyStatus.find({batchId: batch.batchId}).count(), 9);

  // Test resetting, if we launch new set a different day
  batch.lobby.events.emit("reset-multi-groups");

  test.equal(assigner.stopped, false);
  test.equal(assigner.groupArray, groupArr); // Still same config
  test.equal(assigner.currentGroup, -1);
  test.equal(assigner.currentInstance, null);
  return test.equal(assigner.currentFilled, 0);
})
);
