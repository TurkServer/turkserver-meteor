import { Treatments } from "../lib/common";
import { _mergeTreatments } from "../lib/util";

import { Assignment } from "./assignment";
import { Instance } from "./instance";

export interface TreatmentData {
  [key: string]: any;
}

/**
 * @summary Access treatment data assigned to the current user (assignment)
 * or the user's current world (instance).
 * @locus Server
 * @returns {Object} treatment key/value pairs
 */
export function treatment(): TreatmentData {
  const instance = Instance.currentInstance();
  const asst = Assignment.currentAssignment();

  const instTreatments = (instance && instance.getTreatmentNames()) || [];
  const asstTreatments = (asst && asst.getTreatmentNames()) || [];

  return _mergeTreatments(
    Treatments.find({
      name: {
        $in: instTreatments.concat(asstTreatments)
      }
    })
  );
}
