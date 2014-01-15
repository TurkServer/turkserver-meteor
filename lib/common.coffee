# Create a global object for storing things
# This is exported so it doesn't need @
TurkServer = TurkServer || {}

@Batches = new Meteor.Collection("ts.batches")
@Treatments = new Meteor.Collection("ts.treatments")
@Experiments = new Meteor.Collection("ts.experiments")

@Workers = new Meteor.Collection("ts.workers")
@Assignments = new Meteor.Collection("ts.assignments")

@ErrMsg =
  userIdErr: "Must be logged in to operate on TurkServer collection"
  groupErr: "Must have group assigned to operate on TurkServer collection"
  userNotInLobbyErr: "User is not in lobby"

# TODO: only the admin is allowed to modify these from the client side
Meteor.methods
  "ts-delete-treatment": (id) ->
    if Batches.findOne({ treatmentIds: { $in: [id] } })
      throw new Meteor.Error(403, "can't delete treatments that are used by existing batches")

    Treatments.remove(id)
