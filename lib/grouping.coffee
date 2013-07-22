# Hook in group id on server and client side

modifySelector = (userId, selector) ->
  return if typeof selector is "string"
  group = Meteor.users.find(userId).turkserver?.group
  return false unless group
  selector._groupId = group
  return

TurkServer.registerCollection = (collection) ->
  # TODO delete the groupId on found records if/when it becomes necessary
  collection.before "find", modifySelector
  collection.before "findOne", modifySelector

  collection.before "insert", (userId, doc) ->
    group = Meteor.users.find(userId).turkserver?.group
    return false unless group
    doc._groupId = group

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


