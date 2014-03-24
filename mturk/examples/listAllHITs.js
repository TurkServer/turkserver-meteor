var creds = require("../test/aws_creds");
var mturk  = require("../index")({creds: creds, sandbox: true});
var fs = require("fs");
var util = require("util");


mturk.SearchHITs({SortProperty: "Title"}, function(err, SearchHITsResult){
				
	if (err) throw err;

	console.log("NumResults = "+ SearchHITsResult.NumResults);
	console.log("TotalNumResults = "+ SearchHITsResult.TotalNumResults);
	console.log("PageNumber = "+ SearchHITsResult.PageNumber);

	console.log(util.inspect(SearchHITsResult.HIT, {depth: 5}));
});