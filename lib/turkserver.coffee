# Server-side code

TurkServer.isAdminRule = (userId) -> Meteor.users.findOne(userId).admin is true

###
  Batches
  Treatments
  Experiments
###

Batches.allow
  insert: TurkServer.isAdminRule
  update: TurkServer.isAdminRule
  remove: TurkServer.isAdminRule

Treatments._ensureIndex {name: 1}, {unique: 1}

Treatments.allow
  insert: TurkServer.isAdminRule
  update: TurkServer.isAdminRule
  remove: TurkServer.isAdminRule

###
  Workers
  Assignments
###

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
  return null unless @userId

  return Meteor.users.find @userId,
    fields: { turkserver: 1 }

TurkServer.startup = (func) ->
  Meteor.startup ->
    TurkServer.directOperation(func)

