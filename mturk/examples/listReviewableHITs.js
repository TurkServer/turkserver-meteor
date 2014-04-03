var creds = require("../test/aws_creds");
var mturk  = require("../index")({creds: creds, sandbox: true});
var util = require("util");

// Get all HITs that have submitted assignemnts
mturk.GetReviewableHITs({}, function(err, result){

	var hits = (result.HIT instanceof Array) ? result.HIT : [result.HIT];

	hits.forEach(function(HIT){

		// For each reviewable HIT, get the assignments that have been submitted
		mturk.GetAssignmentsForHIT({ "HITId": HIT.HITId }, function(err, result){

			var assignments = (result.Assignment instanceof Array) ? result.Assignment : [result.Assignment];

			assignments.forEach(function(assignment){
				console.log( util.inspect(assignment) );

				// Here you could do
				// mturk.ApproveAssignment({"AssignmentId": assignment.AssignmentId, "RequesterFeedback": "Great work!"}, function(err, id){ 
					// Now assignment "id" is approved!
				// });

			});
		})
	});
});