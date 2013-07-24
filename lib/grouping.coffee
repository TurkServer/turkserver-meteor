userIdErr = "Must be logged in to operate on TurkServer collection"
groupErr = "Must have group assigned to operate on TurkServer collection"

###
  CLIENT METHODS
  Currently empty
  Not needed on client side since all operations go through server method hooks
###
if Meteor.isClient
  TurkServer.registerCollection = ->

###
  SERVER METHODS
  Hook in group id

  Current limitations:

  - Find cursors from a publish must have userId passed to them
  - Collection must be restricted, or we assign a validator here
###
if Meteor.isServer

  # No allow/deny for find so we make our own checks
  modifySelector = (userId, selector) ->
    throw new Meteor.Error(403, userIdErr) unless userId
    # for find(id) we should not touch this
    return true if typeof selector is "string"
    group = Meteor.users.findOne(userId)?.turkserver?.group
    throw new Meteor.Error(403, groupErr) unless group
    # if object (or empty) selector, just filter by group
    selector._groupId = group
    return true

  TurkServer.registerCollection = (collection) ->
    # TODO delete the groupId on found records if/when it becomes necessary
    collection.before "find", modifySelector
    collection.before "findOne", modifySelector

    # These will hook the _validated methods as well
    collection.before "insert", (userId, doc) ->

      throw new Meteor.Error(403, userIdErr) unless userId
      group = Meteor.users.findOne(userId)?.turkserver?.group
      throw new Meteor.Error(403, groupErr) unless group
      doc._groupId = group
      return true

    collection.before "update", modifySelector
    collection.before "remove", modifySelector

    if collection._isInsecure()
      Meteor._debug collection._name +
        """ appears to be insecure. TurkServer will add a simple allow validator to enable hooks.
            Otherwise, please define your own security beforehand."""

      collection.allow
        insert: -> true
        update: -> true
        remove: -> true

    # Index the collections by groupId on the server for faster lookups...?
    collection._ensureIndex
      _groupId: 1

  # Remove group ids when users go offline
  Meteor.users.find({"profile.online": true}).observeChanges
    removed: (id) ->
      Meteor.users.update id,
        $unset: {"turkserver.group": null}


