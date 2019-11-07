import { Assignment } from "./assignment";
import { Assigner } from "./assigners";
import { Batch, ensureBatchExists, ensureTreatmentExists } from "./batches";
import { Instance } from "./instance";

import { mturk } from "./mturk";

const TurkServer = {
  Assignment,
  Assigner,
  Batch,
  Instance,
  mturk,
  ensureBatchExists,
  ensureTreatmentExists
};

export default TurkServer;
