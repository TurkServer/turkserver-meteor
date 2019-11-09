import { Assignment } from "./assignment";
import { Assigner } from "./assigners";

import { Batch, ensureBatchExists, ensureTreatmentExists } from "./batches";
import { Instance, initialize } from "./instance";
import { mturk } from "./mturk";
import { startup } from "./turkserver";
import { onConnect, onDisconnect, onIdle, onActive, connCallbacks } from "./connections";
import { scheduleOutstandingRounds, clearRoundHandlers } from "./timers_server";
import { authenticateWorker } from "./accounts_mturk";

import { formatMillis, _mergeTreatments } from "../lib/util";

// import * as TurkServer from "meteor/mizzao:turkserver";
export default {
  Assignment,
  Assigner,
  Batch,
  Instance,
  // connections
  onConnect,
  onDisconnect,
  onIdle,
  onActive,
  // etc
  mturk,
  ensureBatchExists,
  ensureTreatmentExists,
  formatMillis,
  initialize,
  startup,
  _mergeTreatments
};

export const TestUtils = {
  authenticateWorker,
  connCallbacks,
  scheduleOutstandingRounds,
  clearRoundHandlers
};
