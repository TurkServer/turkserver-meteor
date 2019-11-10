// Stand-ins for stuff that isn't typed yet

// Untyped Meteor stuff
declare var Facts: any;

declare module "meteor/mongo" {
  module Mongo {
    interface Collection<T> {
      // For collection hooks
      direct: any;
      before: any;
    }
  }
}

// Override erroneous definition
declare module "meteor/tracker" {
  module Tracker {
    // TODO: pass this type through
    function nonreactive(func: Function): any;
  }
}

// Partitioner
declare module "meteor/mizzao:partitioner";
declare module "meteor/mizzao:user-status";

declare module "meteor/momentjs:moment";

// Old MTurk stuff
declare module "mturk-api";
declare module "jspath";
declare module "deepmerge";
