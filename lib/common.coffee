# Create a global object for storing things
@TurkServer = @TurkServer || {}

@Batches = new Meteor.Collection("_batches")
@Treatments = new Meteor.Collection("_treatments")
@Experiments = new Meteor.Collection("_experiments")

@Workers = new Meteor.Collection("_workers")
@Assignments = new Meteor.Collection("_assignments")

# TODO: only the admin is allowed to modify these from the client side
Meteor.methods
  "ts-delete-treatment": (id) ->
    if Batches.findOne({ treatmentIds: { $in: [id] } })
      throw new Meteor.Error(403, "can't delete treatments that are used by existing batches")

    Treatments.remove(id)
