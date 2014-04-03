	              __             __  
	   ____ ___  / /___  _______/ /__
	  / __ `__ \/ __/ / / / ___/ //_/
	 / / / / / / /_/ /_/ / /  / ,<   
	/_/ /_/ /_/\__/\__,_/_/  /_/|_|  

This module is for working with the [Mechanical Turk](https://www.mturk.com/mturk/) [API](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/Welcome.html). 

# Install

    npm install mturk

# Use
You must sign up for a Mechanical Turk account and then find [your Access Key and Secret Key](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMechanicalTurkRequester/MakingRequests_RequestAuthenticationArticle.html).

	var creds = {accessKey: "YOUR_ACCESS_KEY", secretKey: "YOUR_SECRET_KEY"};
    var mturk  = require("../index")({creds: creds, sandbox: true});

### Create a HIT Type

The HIT Type defines a bunch of things about the HIT such as approval time, reward, etc. and can be used for multiple HITs.  You must register at least one of these before creating a HIT.

	var RegisterHITTypeOptions = { 
		Title: "Your HIT Title"
		, Keywords: "keyword1, keyword2, keyword3" 
		, Description: "Your description"
		, Reward: {Amount: 1.0, CurrencyCode: "USD"}
		, AssignmentDurationInSeconds: 3600
		, AutoApprovalDelayInSeconds: 3600
		, QualificationRequirement: [mturk.QualificationRequirements.Adults]
	};

	mturk.RegisterHITType(RegisterHITTypeOptions, function(err, HITTypeId){
		if (err) throw err;
		console.log("Registered HIT type "+HITTypeId);
	});


### Create a HIT

Assumes you have `HITTypeId` (like the one created in the previous step) and some XML (`questionXML`) that is a [QuestionForm](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/ApiReference_QuestionFormDataStructureArticle.html) data structure, an [ExternalQuestion](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/ApiReference_ExternalQuestionArticle.html) data structure, an [HTMLQuestion](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/ApiReference_HTMLQuestionArticle.html) data structure, or a [HITLayoutId](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/ApiReference_HITLayoutArticle.html) with optional parameters.

	Use XML:

	var CreateHITOptions = {
		'HITTypeId': HITTypeId
		, 'Question': questionXML
		, 'LifetimeInSeconds': 60 * 20  // How long should the assignment last?
		, 'MaxAssignments': 10 			// How many responses do you want?
	};

	mturk.CreateHIT(CreateHITOptions, function(err, HITId){
		if (err) throw err;
		console.log("Created HIT "+HITId);
	});


	Or use a Layout:

	var LayoutOptions = {
	    'HITTypeId': HITTypeId
	    , 'HITLayoutId': layoutId
	    , 'HITLayoutParameters': {
	    	foo: 'bar'
	    }
	};


### Fetch Reviewalbe HITs
coming soon...

### Approve a HIT
coming soon...

# Test

To run tests, you first must make a file called test/aws_creds.js with the following:

	module.exports = {accessKey: "YOUR_ACCESS_KEY", secretKey: "YOUR_SECRET_KEY"};

Then you can run

	npm test



## To Do
- Tests for existing API methods that don't have them
- Systematic API method implementation
- Make some simple examples


## Other Reading

Before you use this module, it's very helpful to understand exactly how a a HIT, the fundamental unit of work on MTurk, works. This is a great guide: [Overview: Lifecycle of a HIT](http://mechanicalturk.typepad.com/blog/2011/04/overview-lifecycle-of-a-hit-.html)

This module is a pretty straightforward mirror of the MTurk API.  So after you read the previous article, check out the [API](http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMturkAPI/Welcome.html).