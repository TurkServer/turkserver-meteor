/**
 * @summary The global object containing all TurkServer functions.
 * @namespace
 */
TurkServer = TurkServer || {};

TestUtils = TestUtils || {};

Batches = new Mongo.Collection("ts.batches");

/**
 * @summary The collection of treatments that are available to tag to instances/worlds or user assignments.
 *
 * Treatments are objects of the following form:
 * {
 *    name: "foo",
 *    key1: <value1>
 *    key2: <value2>
 * }
 *
 * This allows "foo" to be used to assign a treatment to worlds or users, and the values of key1 and key2 are available in TurkServer.treatment() on the client side.
 */
Treatments = new Mongo.Collection("ts.treatments");
Experiments = new Mongo.Collection("ts.experiments");

LobbyStatus = new Mongo.Collection("ts.lobby");
Logs = new Mongo.Collection("ts.logs");

RoundTimers = new Mongo.Collection("ts.rounds");

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
