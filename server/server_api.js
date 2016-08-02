/**
 * @summary Access treatment data assigned to the current user (assignment)
 * or the user's current world (instance).
 * @locus Server
 * @returns {Object} treatment key/value pairs
 */
TurkServer.treatment = function() {
  const instance = TurkServer.Instance.currentInstance();
  const asst = TurkServer.Assignment.currentAssignment();

  const instTreatments = instance && instance.getTreatmentNames() || [];
  const asstTreatments = asst && asst.getTreatmentNames() || [];

  return TurkServer._mergeTreatments(Treatments.find({
      name: {
        $in: instTreatments.concat(asstTreatments)
      }
    }));
};
