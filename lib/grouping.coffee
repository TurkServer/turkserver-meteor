###
  SERVER METHODS
  Hook in group id to all operations, including find

  Current limitations:
  - Collection must be restricted, or we assign a validator here

###

this.Grouping = new Meteor.Collection("_grouping")

# No allow/deny for find so we make our own checks
modifySelector = (userId, selector, options) ->
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

removeSelector = (userId, doc) ->
  # TODO this doesn't guard properly against mass remove due to unsupported:
  # https://github.com/matb33/meteor-collection-hooks/issues/23
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Grouping.findOne(userId: userId).groupId
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId

TurkServer.registerCollection = (collection) ->
  collection.before.find modifySelector
  collection.before.findOne modifySelector

  # These will hook the _validated methods as well
  collection.before.insert (userId, doc) ->
    throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
    groupId = Grouping.findOne(userId: userId).groupId
    throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
    doc._groupId = groupId
    return true

  # TODO change update and remove as they both use find in collection hooks
  collection.before.update modifySelector
  collection.before.remove removeSelector

  # Index the collections by groupId on the server for faster lookups...?
  # TODO figure out how compound indices work on Mongo and if we should do something smarter
  collection._ensureIndex
    _groupId: 1

TurkServer.addUserToGroup = (userId, groupId) ->
  Grouping.insert
    userId: userId
    groupId: groupId

  Meteor.users.update userId,
    $set: { "turkserver.group": groupId }



