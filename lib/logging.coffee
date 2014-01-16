@Logs = new Meteor.Collection("ts.logs")

Logs._ensureIndex
  _groupId: 1
  _timestamp: 1

# Save group and timestamp for each log request
Logs.before.insert (userId, doc) ->
  throw new Meteor.Error(403, ErrMsg.userIdErr) unless userId
  groupId = Grouping.findOne(userId).groupId
  throw new Meteor.Error(403, ErrMsg.groupErr) unless groupId

  doc._groupId = groupId
  doc._timestamp = Date.now()
  return true

TurkServer.log = (doc, callback) ->
  Logs.insert(doc, callback)

Meteor.methods
  "ts-log": (doc) ->
    Meteor._debug("Warning; received log request for not logged in user") unless Meteor.userId()
    Logs.insert(doc)
