// Stand-ins for stuff that isn't typed yet

// Untyped Meteor stuff
declare var Facts: any;

// Override erroneous definition
declare module "meteor/tracker" {
  module Tracker {
    // TODO: pass this type through
    function nonreactive(func: Function): any;
  }
}

// Partitioner
declare var Partitioner: any;
