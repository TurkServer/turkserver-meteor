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

###
  Workers
  Assignments
###

Workers.deny(always)
Assignments.deny(always)

HITTypes.allow(adminOnly)
Qualifications.allow(adminOnly)

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

# Publish turkserver user fields to a user
Meteor.publish null, ->
  return unless @userId

  return Meteor.users.find @userId,
    fields: { turkserver: 1 }

# Publish current experiment for a user, if it exists
Meteor.publish "tsCurrentExperiment", (group) ->
  return unless @userId
  return Experiments.find(group)

TurkServer.startup = (func) ->
  Meteor.startup ->
    TurkServer.directOperation(func)

