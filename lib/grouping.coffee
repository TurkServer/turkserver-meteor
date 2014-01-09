###
  SERVER METHODS
  Hook in group id to all operations, including find

  Current limitations:
  - Collection must be restricted, or we assign a validator here

###

@Grouping = new Meteor.Collection("ts.grouping")

Grouping._ensureIndex {userId: 1}, { unique: 1 }

TurkServer.groupingHooks = {}

# No allow/deny for find so we make our own checks
findHook = (userId, selector, options) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  # for find(id) we should not touch this
  return true if typeof selector is "string"

  groupId = Grouping.findOne(userId: userId).groupId
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId

  # if object (or empty) selector, just filter by group
  unless @args[0]
    @args[0] = { _groupId : groupId }
  else unless _.isString @args[0] # TODO may allow arbitrary finds
    selector._groupId = groupId
  return true

insertHook = (userId, doc) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Grouping.findOne(userId: userId).groupId
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
  doc._groupId = groupId
  return true

TurkServer.groupingHooks.findHook = findHook
TurkServer.groupingHooks.insertHook = insertHook

TurkServer.registerCollection = (collection) ->
  collection.before.find findHook
  collection.before.findOne findHook

  # These will hook the _validated methods as well
  collection.before.insert insertHook

  ###
    No update/remove hook necessary, see
    https://github.com/matb33/meteor-collection-hooks/issues/23
  ###

  # Index the collections by groupId on the server for faster lookups...?
  # TODO figure out how compound indices work on Mongo and if we should do something smarter
  collection._ensureIndex
    _groupId: 1

TurkServer.addUserToGroup = (userId, groupId) ->
  # TODO check for existing group

  Grouping.upsert {userId: userId},
    $set: groupId: groupId

  Meteor.users.update userId,
    $set: { "turkserver.group": groupId }



