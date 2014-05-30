batch = null

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    # Create a random batch and corresponding lobby for assigner tests
    batchId = Batches.insert({})
    batch = TurkServer.Batch.getBatch(batchId)
  after: ->
    Assignments.remove { batchId: batch.batchId }

tutorialTreatments = [ "tutorial" ]
groupTreatments = [ "group" ]

TurkServer.ensureTreatmentExists
  name: "tutorial"
TurkServer.ensureTreatmentExists
  name: "group"

createAssignment = ->
  workerId = Random.id()
  userId = Accounts.insertUserDoc {}, { workerId }
  return TurkServer.Assignment.createAssignment
    batchId: batch.batchId
    hitId: Random.id()
    assignmentId: Random.id()
    workerId: workerId
    acceptTime: new Date()
    status: "assigned"

Tinytest.add "assigners - tutorialGroup - assigner picks up existing instance", withCleanup (test) ->
  assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments)

  instance = batch.createInstance(groupTreatments)
  instance.setup()

  batch.setAssigner(assigner)

  test.equal assigner.instance, instance
  test.equal assigner.autoAssign, true

Tinytest.add "assigners - tutorialGroup - initial lobby gets tutorial", withCleanup (test) ->
  assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments)
  batch.setAssigner(assigner)

  test.equal assigner.autoAssign, false

  asst = createAssignment()
  asst._loggedIn()

  sleep(100) # YES!!

  user = Meteor.users.findOne(asst.userId)
  instances = asst.getInstances()

  test.equal user.turkserver.state, "experiment"
  test.length instances, 1

  test.equal LobbyStatus.find(batchId: batch.batchId).count(), 0
  exp = Experiments.findOne(instances[0].id)
  test.equal exp.treatments, tutorialTreatments

Tinytest.add "assigners - tutorialGroup - autoAssign event triggers properly", withCleanup (test) ->

  assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments)
  batch.setAssigner(assigner)

  asst = createAssignment()
  # Pretend we already have a tutorial done
  tutorialInstance = batch.createInstance(tutorialTreatments)
  tutorialInstance.setup()
  tutorialInstance.addAssignment(asst)
  tutorialInstance.teardown()

  sleep(100) # So the user joins the lobby properly

  user = Meteor.users.findOne(asst.userId)
  instances = asst.getInstances()

  test.equal user.turkserver.state, "lobby"
  test.length instances, 1

  batch.lobby.events.emit("auto-assign")

  sleep(100)

  user = Meteor.users.findOne(asst.userId)
  instances = asst.getInstances()

  test.equal user.turkserver.state, "experiment"
  test.length instances, 2

  test.equal LobbyStatus.find(batchId: batch.batchId).count(), 0
  exp = Experiments.findOne(instances[1].id)
  test.equal exp.treatments, groupTreatments

Tinytest.add "assigners - tutorialGroup - final send to exit survey", withCleanup (test) ->

  assigner = new TurkServer.Assigners.TutorialGroupAssigner(tutorialTreatments, groupTreatments)
  batch.setAssigner(assigner)

  asst = createAssignment()
  # Pretend we already have a tutorial done
  tutorialInstance = batch.createInstance(tutorialTreatments)
  tutorialInstance.setup()
  tutorialInstance.addAssignment(asst)
  tutorialInstance.teardown()

  sleep(100) # So the user joins the lobby properly

  groupInstance = batch.createInstance(groupTreatments)
  groupInstance.setup()
  groupInstance.addAssignment(asst)
  groupInstance.teardown()

  sleep(100)

  user = Meteor.users.findOne(asst.userId)
  instances = asst.getInstances()

  test.equal user.turkserver.state, "exitsurvey"
  test.length instances, 2





