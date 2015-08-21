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

# Allow admin to make emergency adjustments to the lobby collection just in case
LobbyStatus.allow(adminOnly)

# Only server should update these
Experiments.deny(always)
Logs.deny(always)
RoundTimers.deny(always)

# Create an index on experiments
Experiments._ensureIndex({
  batchId: 1,
  endTime: 1 # non-sparse ensures that running experiments are indexed
})

###
  Workers
  Assignments

  WorkerEmails
  Qualifications
  HITTypes
  HITs
###

Workers.allow(adminOnly)
Assignments.deny(always)

WorkerEmails.allow(adminOnly)
Qualifications.allow(adminOnly)
HITTypes.allow(adminOnly)
HITs.allow(adminOnly)

# XXX remove this check for release
try
  HITTypes._dropIndex("HITTypeId_1")
  console.log "Dropped old index on HITTypeId"

# Index HITTypes, but only for those that exist
HITTypes._ensureIndex({HITTypeId: 1}, {
  name: "HITTypeId_1_sparse"
  unique: 1,
  sparse: 1
})

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

# Allow lookup of assignments by batch and submitTime (completed vs incomplete)
Assignments._ensureIndex
  batchId: 1
  submitTime: 1

# TODO deprecated index
try
  Assignments._dropIndex
    batchId: 1
    acceptTime: 1

###
  Data publications
###

# Publish turkserver user fields to a user
Meteor.publish null, ->
  return null unless @userId

  cursors = []

  cursors.push Meteor.users.find @userId,
    fields: { turkserver: 1 }

  # Current user assignment data, including idle and disconnection time
  # This won't be sent for the admin user
  if (workerId = Meteor.users.findOne(@userId)?.workerId)?
    cursors.push Assignments.find({
      workerId: workerId
      status: "assigned"
    }, {
      fields: {
        instances: 1,
        bonusPayment: 1,
      }
    })

  return cursors

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

  return cursors

# For the preview page and test logins, need to publish the list of batches.
# TODO make this a bit more secure
Meteor.publish "tsLoginBatches", (batchId) ->
  # Never send the batch list to logged-in users.
  return [] if @userId?

  # If an erroneous batchId was sent, don't just send the whole list.
  if arguments.length > 0 and batchId?
    return Batches.find(batchId)
  else
    return Batches.find()

Meteor.publish null, ->
  return [] unless @userId?
  # Publish specific batch if logged in
  # This should work for now because an assignment is made upon login
  return [] unless (workerId = Meteor.users.findOne(@userId)?.workerId)?

  sub = this
  handle = Assignments.find({workerId, status: "assigned"}).observeChanges
    added: (id, fields) ->
      batchId = Assignments.findOne(id).batchId
      sub.added "ts.batches", batchId, Batches.findOne(batchId)
    removed: (id) ->
      batchId = Assignments.findOne(id).batchId
      sub.removed "ts.batches", batchId

  sub.ready()
  sub.onStop -> handle.stop()

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

  console.log "#{prefix} #{treatmentUpdates} treatments updated" if treatmentUpdates > 0

  # Move "experimentId" fields in assignments to "instances" array
  experimentIdUpdates = 0
  Assignments.find({experimentId: $exists: true}).forEach (asst, idx) ->
    experimentIdUpdates = idx + 1
    Assignments.update asst._id,
      $push: instances: asst.experimentId
      $unset: experimentId: null

  console.log "#{prefix} #{experimentIdUpdates} experimentIds converted to instances" if experimentIdUpdates > 0

  # Update string values in instances array to objects
  instanceUpdates = 0
  Assignments.find({instances: $type: 2}).forEach (asst, idx) ->
    instanceUpdates = idx + 1
    instanceIds = asst.instances
    Assignments.update asst._id,
      $set: instances: _.map(instanceIds, (id) -> {id})

  console.log "#{prefix} #{instanceUpdates} instance ids updated to objects" if instanceUpdates > 0

  hitTypeBatchUpdates = 0
  HITTypes.find({batchId: $exists: false}).forEach (hitType, idx) ->
    # Find an assignment that was created in this HIT Type, if any, to patch up the batch Id
    return unless hitType.HITTypeId?
    hits = _.pluck(HITs.find(HITTypeId: hitType.HITTypeId).fetch(), "HITId")
    return unless hits.length > 0
    asst = Assignments.findOne
      batchId: $exists: true
      hitId: $in: hits
    return unless asst?
    HITTypes.update hitType._id,
      $set: batchId: asst.batchId
    hitTypeBatchUpdates += 1

  console.log "#{prefix} #{hitTypeBatchUpdates} HIT Types updated with batch Ids" if hitTypeBatchUpdates > 0

  experimentBatchUpdates = 0
  Experiments.find({batchId: {$exists: false}, startTime: {$exists: true}}).forEach (exp, idx) ->
    experimentBatchUpdates = idx + 1
    someAsst = Assignments.findOne
      "instances.id": exp._id
    Experiments.update exp._id,
      $set: batchId: someAsst.batchId

  console.log "#{prefix} #{experimentBatchUpdates} batchIds added to experiment instances" if experimentBatchUpdates > 0

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

  console.log "#{prefix} #{batchTreatmentUpdates} batch treatment ids updated to names" if instanceUpdates > 0

  # 7/11/14 - Update string or null IPs to be array
  # Because operators match into arrays, we need to make sure the field itself
  # isn't already an array.
  ipAddrUpdates = 0
  Assignments.find({
    ipAddr: {$type: 2},
    "ipAddr.0": {$exists: false}
  }).forEach (asst) ->
    ipAddrUpdates++
    if asst.ipAddr is "127.0.0.1" # Delete meaningless entries when proxy was set wrong
      Assignments.update asst._id,
        $unset: { ipAddr: null }
    else
      Assignments.update asst._id,
        $set: { ipAddr: [ asst.ipAddr ] }

  console.log "#{prefix} #{ipAddrUpdates} IP address fields updated" if ipAddrUpdates > 0

  ipAddrNulls = 0
  Assignments.find({ipAddr: $type: 10}).forEach (asst) ->
    ipAddrNulls++
    Assignments.update asst._id,
      $unset: { ipAddr: null }

  console.log "#{prefix} #{ipAddrNulls} IP address fields nulled out" if ipAddrNulls > 0

  # 7/16/14 - the HitTypeId field is mistaken and misleading of the actual HITTypeId field.
  hitTypeIdUpdates = 0
  HITs.find({HitTypeId: $exists: true}).forEach (hit) ->
    hitTypeIdUpdates++
    HITs.update(hit._id, $unset: HitTypeId: null)

  console.log "#{prefix} #{hitTypeIdUpdates} mistaken HitType fields nulled out" if hitTypeIdUpdates > 0

  # 8/4/14 - update worker schema
  workerPanelUpdates = 0
  Workers.find(times: $exists: true).forEach (worker) ->
    workerPanelUpdates++

    # Find first completed assignment for this worker.
    # TODO hack that works for crisis mapping, but maybe not other situations.
    earliestCompletedAsst = Assignments.findOne({
      workerId: worker._id,
      submitTime: $exists: true
    }, { sort: submitTime: 1 })

    Workers.update worker._id,
      $set:
        available:
          times: worker.times
          updated: new Date(earliestCompletedAsst.submitTime) # may be a timestamp
      $unset: times: null

  console.log "#{prefix} #{workerPanelUpdates} worker panel schemas updated" if workerPanelUpdates > 0
