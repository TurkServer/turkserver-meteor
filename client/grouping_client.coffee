###
  Client selector modifiers
###

TurkServer.groupingHooks = {}

userFindHook = (userId, selector, options) ->
  # Do the usual find for no user or single selector
  return true if !userId or _.isString(selector) or (selector? and "_id" of selector)

  # No hooking needed for regular users, taken care of on server
  return true unless Meteor.user()?.admin

  # Don't have admin see itself for global finds
  unless @args[0]
    @args[0] =
      admin: {$exists: false}
  else
    selector.admin = {$exists: false}
  return true

TurkServer.groupingHooks.userFindHook = userFindHook

Meteor.users.before.find userFindHook
Meteor.users.before.findOne userFindHook

# No allow/deny for find so we make our own checks
findHook = (userId, selector, options) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = TurkServer.group()
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
  # No need to add selectors if server side filtering works properly
  return true

insertHook = (userId, doc) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = TurkServer.group()
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
  doc._groupId = groupId
  return true

TurkServer.groupingHooks.findHook = {}
TurkServer.groupingHooks.insertHook = {}

# Add in groupId for client so as not to cause unexpected sync changes
TurkServer.registerCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary (transform?)
  collection.before.find findHook
  collection.before.findOne findHook

  # These will hook the _validated methods as well
  collection.before.insert insertHook

