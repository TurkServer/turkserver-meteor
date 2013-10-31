mturk = Npm.require('mturk')

TurkServer.settings = {
  experiment : {
    limit: {
      simultaneous: 1
      set: 1
    }
  }
}

this.Assignments = new Meteor.Collection("assignments")
this.Experiments = new Meteor.Collection("experiments")
this.Workers = new Meteor.Collection("workers")

# TODO more careful indices on these collections

# Index on unique assignment-worker pairs
Assignments._ensureIndex
  hitId: 1
  assignmentId: 1
  workerId: 1
, { unique: 1 }

# Allow fast lookup of a worker's previous HITs
Assignments._ensureIndex
  workerId: 1

# Publish turkserver user fields
Meteor.publish null, ->
  return null unless @userId

  return Meteor.users.find @userId,
    fields: { turkserver: 1 }

TurkServer.sessionStatus = (record) ->
  # Use 'of' in order to avoid 0's being ignored
  if "inactivePercent" of record
    "completed"
  else if "experimentId" of record
    "experiment"
  else if "lobbyTime" of record
    "lobby"
  else if "connectTime" of record
    "assigned"
  else
    "unassigned"
