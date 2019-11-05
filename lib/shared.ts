import { Mongo } from "meteor/mongo";

export const TestUtils = {};

export interface Batch {
  _id: string;
  active: boolean;
  treatments: string[];
}
export const Batches = new Mongo.Collection<Batch>("ts.batches");

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
export interface Treatment {
  _id: string;
  name: string;
  [key: string]: any;
}
export const Treatments = new Mongo.Collection<Treatment>("ts.treatments");

export interface Experiment {
  _id: string;
  batchId: string;
  users: string[];
  treatments: string[];
  startTime?: Date;
  endTime?: Date;
}
export const Experiments = new Mongo.Collection<Experiment>("ts.experiments");

export interface ILobbyStatus {
  _id: string;
}
export const LobbyStatus = new Mongo.Collection<ILobbyStatus>("ts.lobby");

export interface LogEntry {
  _id: string;
}
export const Logs = new Mongo.Collection<LogEntry>("ts.logs");

export interface RoundState {
  _id: string;
}
export const RoundTimers = new Mongo.Collection<RoundState>("ts.rounds");
