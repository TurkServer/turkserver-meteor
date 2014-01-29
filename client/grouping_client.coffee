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

findHook = (userId, selector, options) ->
  # Allow these operations to proceed for the sake of reactivity
  # but may be useful for diagnostic purposes
  unless userId
    # Meteor._debug "Find hook called but " + ErrMsg.userIdErr
    return true
  groupId = TurkServer.group()
  unless groupId
    # Meteor._debug "Find hook called but " + ErrMsg.groupErr
    return true

  # TODO delete the groupId on found records if/when it becomes necessary (transform?)

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
TurkServer.partitionCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary (transform?)
  collection.before.find findHook
  collection.before.findOne findHook

  # These will hook the _validated methods as well
  collection.before.insert insertHook

