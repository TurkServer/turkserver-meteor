###
  Client selector modifiers
###

# No allow/deny for find so we make our own checks
modifySelector = (userId, selector, options) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Meteor.user()?.turkserver?.group
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId

  # if object (or empty) selector, just filter by group
  selector._groupId = groupId
  return true

removeSelector = (userId, doc) ->
  # TODO this could potentially allow deletes of arbitrary docs
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Meteor.user()?.turkserver?.group
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId

# Add in groupId for client so as not to cause unexpected sync changes
TurkServer.registerCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary (transform?)

  # These will hook the _validated methods as well
  collection.before.insert (userId, doc) ->
    throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
    groupId = Meteor.user()?.turkserver?.group
    throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId
    doc._groupId = groupId
    return true

  collection.before.update modifySelector
  collection.before.remove removeSelector
