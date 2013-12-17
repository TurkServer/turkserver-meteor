# Create a global object for storing things
@TurkServer = @TurkServer || {}

this.Batches = new Meteor.Collection("_batches")
this.Experiments = new Meteor.Collection("_experiments")

this.Workers = new Meteor.Collection("_workers")
this.Assignments = new Meteor.Collection("_assignments")

# TODO: only the admin is allowed to modify these from the client side
