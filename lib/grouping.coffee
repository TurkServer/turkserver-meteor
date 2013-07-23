# Hook in group id on server and client side

modifySelector = (userId, selector) ->
  return false unless userId
  # for find(id) we should not touch this
  return true if typeof selector is "string"
  group = Meteor.users.findOne(userId)?.turkserver?.group
  return false unless group
  # if object (or empty) selector, just filter by group
  selector._groupId = group
  return true

TurkServer.registerCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary
  collection.before "find", modifySelector
  collection.before "findOne", modifySelector

  collection.before "insert", (userId, doc) ->
    return false unless userId
    group = Meteor.users.findOne(userId)?.turkserver?.group
    return false unless group
    doc._groupId = group
    return true

  collection.before "update", modifySelector
  collection.before "remove", modifySelector

###
  SERVER METHODS
###
if Meteor.isServer

  # Remove groups when users go offline
  Meteor.users.find({"profile.online": true}).observeChanges
    removed: (id) ->
      Meteor.users.update id,
        $unset: {"turkserver.group": null}


