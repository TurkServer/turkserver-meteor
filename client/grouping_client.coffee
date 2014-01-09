###
  Client selector modifiers
###

TurkServer.groupingHooks = {}

# No allow/deny for find so we make our own checks
findHook = (userId, selector, options) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Meteor.user()?.turkserver?.group
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
  # No need to add selectors if server side filtering works properly

insertHook = (userId, doc) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Meteor.user()?.turkserver?.group
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

