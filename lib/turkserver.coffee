# Collection modifiers, in case running on insecure

TurkServer.isAdminRule = (userId) -> Meteor.users.findOne(userId).admin is true

adminOnly =
  insert: TurkServer.isAdminRule
  update: TurkServer.isAdminRule
  remove: TurkServer.isAdminRule

always =
  insert: -> true
  update: -> true
  remove: -> true

###
  Batches
  Treatments
  Experiments
###

Batches.allow(adminOnly)
Treatments.allow(adminOnly)

Treatments._ensureIndex {name: 1}, {unique: 1}

# Only server should update these
Experiments.deny(always)
Logs.deny(always)
RoundTimers.deny(always)

###
  Workers
  Assignments

  Qualifications
  HITTypes
  HITs
###

Workers.deny(always)
Assignments.deny(always)

Qualifications.allow(adminOnly)
HITTypes.allow(adminOnly)
HITs.allow(adminOnly)

HITTypes._ensureIndex {HITTypeId: 1}, {unique: 1}
HITs._ensureIndex {HITId: 1}, {unique: 1}

# TODO more careful indices on these collections

# Index on unique assignment-worker pairs
Assignments._ensureIndex
  hitId: 1
  assignmentId: 1
  workerId: 1
, { unique: 1 }

# Allow fast lookup of a worker's HIT assignments by status
Assignments._ensureIndex
  workerId: 1
  status: 1

# Allow lookup of assignments by batch
Assignments._ensureIndex
  batchId: 1
  acceptTime: 1

###
  Data publications
###

# Publish turkserver user fields to a user
Meteor.publish null, ->
  return null unless @userId

  return Meteor.users.find @userId,
    fields: { turkserver: 1 }

# Publish current experiment for a user, if it exists
# This includes the data sent to the admin user
Meteor.publish "tsCurrentExperiment", (group) ->
  return unless @userId
  cursors = [
    Experiments.find(group),
    RoundTimers.find() # Partitioned by group
  ]

  # Current treatment data
  # XXX Treatments will not be updated reactively if added/removed to the experiment
  if (treatments = Experiments.findOne(group)?.treatments)?
    cursors.push Treatments.find(name: $in: treatments)

  # Current user assignment data, including idle and disconnection time
  # This won't be sent for the admin user
  # No reactive join needed here because workerId is immutable for users and re-sub will change group
  if (workerId = Meteor.users.findOne(@userId)?.workerId)?
    cursors.push Assignments.find({
      workerId: workerId
      "instances.id": group
    }, {
      fields: {
        instances: 1
      }
    })

  return cursors

# For test logins, need to publish the list of batches.
Meteor.publish null, -> Batches.find()

TurkServer.startup = (func) ->
  Meteor.startup ->
    Partitioner.directOperation(func)

# Backwards compatibility fixes
# XXX Remove these in the future
Meteor.startup ->
  prefix = "Schema update: "

  # Move "treatment" field in experiment instances to "treatments" array
  treatmentUpdates = 0
  Experiments.find({treatment: $exists: true}).forEach (instance, idx) ->
    treatmentUpdates = idx + 1
    Experiments.update instance._id,
      $addToSet: treatments: instance.treatment
      $unset: treatment: null

  console.log prefix + treatmentUpdates + " treatments updated" if treatmentUpdates > 0

  # Move "experimentId" fields in assignments to "instances" array
  experimentIdUpdates = 0
  Assignments.find({experimentId: $exists: true}).forEach (asst, idx) ->
    experimentIdUpdates = idx + 1
    Assignments.update asst._id,
      $push: instances: asst.experimentId
      $unset: experimentId: null

  console.log prefix + experimentIdUpdates + " experimentIds converted to instances" if experimentIdUpdates > 0

  # Update string values in instances array to objects
  instanceUpdates = 0
  Assignments.find({instances: $type: 2}).forEach (asst, idx) ->
    instanceUpdates = idx + 1
    instanceIds = asst.instances
    Assignments.update asst._id,
      $set: instances: _.map(instanceIds, (id) -> {id})

  console.log prefix + instanceUpdates + " instance ids updated to objects" if instanceUpdates > 0

  experimentBatchUpdates = 0
  Experiments.find({batchId: $exists: false}).forEach (exp, idx) ->
    experimentBatchUpdates = idx + 1
    someAsst = Assignments.findOne
      "instances.id": exp._id
    Experiments.update exp._id,
      $set: batchId: someAsst.batchId

  console.log prefix + experimentBatchUpdates + " batchIds added to experiment instances" if experimentBatchUpdates > 0

  # Convert batch treatmentIds to treatments (names)
  batchTreatmentUpdates = 0
  Batches.find(treatmentIds: $exists: true).forEach (batch, idx) ->
    batchTreatmentUpdates = idx + 1
    treatments = []
    for treatmentId in batch.treatmentIds
      treatmentName = Treatments.findOne(treatmentId)?.name
      treatments.push(treatmentName) if treatmentName?
    Batches.update batch._id,
      $set: { treatments }
      $unset: {treatmentIds: null}

  console.log prefix + batchTreatmentUpdates + " batch treatment ids updated to names" if instanceUpdates > 0
