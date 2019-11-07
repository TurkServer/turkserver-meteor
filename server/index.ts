import { Assignment } from "./assignment";
import { Assigner } from "./assigners";
import { Batch, ensureBatchExists, ensureTreatmentExists } from "./batches";
import { Instance } from "./instance";

import { mturk } from "./mturk";
import { formatMillis, _mergeTreatments } from "../lib/util";

const TurkServer = {
  Assignment,
  Assigner,
  Batch,
  Instance,
  mturk,
  ensureBatchExists,
  ensureTreatmentExists,
  formatMillis,
  _mergeTreatments
};

export default TurkServer;
