mturk = Npm.require('mturk')

this.Assignments = new Meteor.Collection("assignments")
this.Experiments = new Meteor.Collection("experiments")
this.Workers = new Meteor.Collection("workers")
# TODO create indices on these collections


