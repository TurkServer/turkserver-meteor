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

# Publish turkserver user fields to a user
Meteor.publish null, ->
  return null unless @userId

  return Meteor.users.find @userId,
    fields: { turkserver: 1 }

# Publish current experiment for a user, if it exists
Meteor.publish "tsCurrentExperiment", (group) ->
  return unless @userId
  cursors = [
    Experiments.find(group),
    RoundTimers.find() # Partitioned by group
  ]

  # Current treatment data
  if (treatments = Experiments.findOne(group)?.treatments)?
    cursors.push Treatments.find(name: $in: treatments)

  return cursors

# For test logins, need to publish the list of batches.
Meteor.publish null, -> Batches.find()

TurkServer.startup = (func) ->
  Meteor.startup ->
    Partitioner.directOperation(func)

