/**
 * @summary The global object containing all TurkServer functions.
 * @namespace
 */
TurkServer = TurkServer || {};

TestUtils = TestUtils || {};

/**
 * @summary Get the current group (partition) of the environment.
 * @locus Anywhere
 * @function
 * @returns {String} The group id.
 */
TurkServer.group = Partitioner.group;

/**
 * @summary Partition a collection for use across instances.
 * @locus Server
 * @param {Meteor.Collection} collection The collection to partition.
 * @function
 */
TurkServer.partitionCollection = Partitioner.partitionCollection;
