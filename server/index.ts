import { Assignment } from "./assignment";
import { Assigner } from "./assigners";
import { Batch, ensureBatchExists, ensureTreatmentExists } from "./batches";
import { Instance, initialize } from "./instance";

import { mturk } from "./mturk";
import { formatMillis, _mergeTreatments } from "../lib/util";
import { startup } from "./turkserver";

const TurkServer = {
  Assignment,
  Assigner,
  Batch,
  Instance,
  mturk,
  ensureBatchExists,
  ensureTreatmentExists,
  formatMillis,
  initialize,
  startup,
  _mergeTreatments
};

export default TurkServer;
