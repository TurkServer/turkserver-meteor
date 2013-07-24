userIdErr = "Must be logged in to operate on TurkServer collection"
groupErr = "Must have group assigned to operate on TurkServer collection"

# Hook in group id on server and client side

modifySelector = (userId, selector) ->
  throw new Error(userIdErr) unless userId
  # for find(id) we should not touch this
  return true if typeof selector is "string"
  group = Meteor.users.findOne(userId)?.turkserver?.group
  throw new Error(groupErr) unless group
  # if object (or empty) selector, just filter by group
  selector._groupId = group
  return true

TurkServer.registerCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary
  collection.before "find", modifySelector
  collection.before "findOne", modifySelector

  collection.before "insert", (userId, doc) ->
    throw new Error(userIdErr) unless userId
    group = Meteor.users.findOne(userId)?.turkserver?.group
    throw new Error(groupErr) unless group
    doc._groupId = group
    return true

  collection.before "update", modifySelector
  collection.before "remove", modifySelector

  # Index the collections by groupId on the server for faster lookups...?
  if Meteor.isServer
    collection._ensureIndex
      _groupId: 1

###
  SERVER METHODS
###
if Meteor.isServer

  # Remove groups when users go offline
  Meteor.users.find({"profile.online": true}).observeChanges
    removed: (id) ->
      Meteor.users.update id,
        $unset: {"turkserver.group": null}


