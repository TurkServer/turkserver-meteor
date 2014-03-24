
var chai = require("chai")
var creds = require('./aws_creds')
var should = chai.should();
var fs = require('fs')
var libxmljs = require("libxmljs")
var util = require('util')
var path = require('path');

describe('mturk', function(){

	var mturk  = require("../index")({creds: creds, sandbox: true});
	var _datapath = path.resolve(path.join(__dirname, "../sampledata"));


	var _HITTypeId;			// For storing a HITTypeId made by any of the tests.
	var _HITId;				// For storing a HIT made by any of the tests
	var validateHIT = function(HIT) {
		HIT.should.have.ownProperty("HITId");
		HIT.should.have.ownProperty("HITTypeId");
		HIT.should.have.ownProperty("HITGroupId");
		HIT.should.have.ownProperty("CreationTime");
		HIT.should.have.ownProperty("Title");
		HIT.should.have.ownProperty("Description");
		HIT.should.have.ownProperty("HITStatus");
		HIT.should.have.ownProperty("MaxAssignments");
		HIT.should.have.ownProperty("Reward");
		HIT.should.have.ownProperty("AutoApprovalDelayInSeconds");
		HIT.should.have.ownProperty("Expiration");
		HIT.should.have.ownProperty("AssignmentDurationInSeconds");
		HIT.should.have.ownProperty("HITReviewStatus");
	}


	//beforeEach(function(){ });




	/**
	* mturk.libxmlToJSON()
	*/
	describe("#libxmlToJSON()", function(){
		it('should successfully convert a getHITResponse to a JSON structure', function(){
			fs.readFile(_datapath+"/GetHITResponse.xml", 'utf8', function(err, xml){
				if(err) throw err;

				var doc = libxmljs.parseXml(xml);
				if(doc.errors.length>0) {
					throw doc.errors[0];
				} else {
					var hit = doc.get("//HIT");
					var json = mturk.libxmlToJSON( hit );
					//console.log( util.inspect(json, {depth: 10}) );

					json.should.have.property("HITId");
				}
			});
		})
	});


	/**
	* Sanity check: mturk object properties
	*/
	describe("properties", function(){

		it("should have credentials set", function(){
			mturk.should.have.property("accessKey");
			mturk.accessKey.should.be.a("String");
			mturk.accessKey.should.have.length(20); //  TODO: confirm that it's always 40...
			mturk.should.have.property("secretKey");
			mturk.secretKey.should.be.a("String");
			mturk.secretKey.should.have.length(40); //  TODO: confirm that it's always 40...
		});

		it('should have some qualifications defined', function(){
			mturk.should.have.property("QualificationRequirements");
			mturk.QualificationRequirements.should.have.property("Adults");
			mturk.QualificationRequirements.Adults.should.be.a("Object");
		});
	});


	/**
	*	mturk.RegisterHITType()
	*/
	describe("#RegisterHITType()", function(){
		it('should create a HITType and return the new HITTypeId', function(done){
			var options = { 
				Title: "Mturk Nodejs module RegisterHITType test"
				, Keywords: "keyword1, keyword2, keyword3" 
				, Description: "Test description"
				, Reward: {Amount: 1.0, CurrencyCode: "USD"}
				, AssignmentDurationInSeconds: 3600
				, AutoApprovalDelayInSeconds: 3600
				, QualificationRequirement: [mturk.QualificationRequirements.Adults, mturk.QualificationRequirements.Masters]
			};

			mturk.RegisterHITType(options, function(err, HITTypeId){
				if (err) throw err;
				HITTypeId.should.be.a("String");
				HITTypeId.should.have.length(30);
				_HITTypeId = HITTypeId;
				done();
			});
		});
	})



	/**
	*	#GetAccountBalance()
	*/
	describe("#GetAccountBalance()", function(){
		it('should return a number greater than or equal to 0', function(done){
			mturk.GetAccountBalance({}, function(err, AccountBalance){
				if (err) throw err;
				AccountBalance.should.be.a('Number')
				AccountBalance.should.be.at.least(0);
				done();
			});
		})
	});



	/**
	*	#CreateHIT()
	*/
	describe("#CreateHIT()", function(){
		it('should create a HITTypeId/ExternalQuestion HIT and return the new HITId', function(done){
			fs.readFile(_datapath+"/ExternalQuestion.xml", 'utf8', function(err, questionXML) {
				if (err) throw err;
				var options = {
					'HITTypeId': _HITTypeId
					, 'Question': questionXML
					, 'LifetimeInSeconds': 60 * 20  // How long should the assignment last?
					, 'MaxAssignments': 1
				};

				mturk.CreateHIT(options, function(err, HITId){
					if (err) throw err;
					HITId.should.be.a("String");
					HITId.should.have.length(30);
					_HITId = HITId;
					done();
				});  // mturk.CreateHIT
			});
		});

	
		it('should create a HITTypeId/QuestionForm HIT and return the new HITId', function(done){
			fs.readFile(_datapath+"/QuestionForm.xml", 'utf8', function(err, questionXML) {
				if (err) throw err;
				var options = {
					'HITTypeId': _HITTypeId
					, 'Question': questionXML
					, 'LifetimeInSeconds': 60 * 20  // How long should the assignment last?
					, 'MaxAssignments': 1
				};

				mturk.CreateHIT(options, function(err, HITId){
					if (err) throw err;
					HITId.should.be.a("String");
					HITId.should.have.length(30);
					_HITId = HITId;
					done();
				});  // mturk.CreateHIT
			});
		});
	
		it('should create a HITTypeId/HTMLQuestion HIT and return the new HITId', function(done){
			fs.readFile(_datapath+"/HTMLQuestion.xml", 'utf8', function(err, questionXML) {
				if (err) throw err;
				var options = {
					'HITTypeId': _HITTypeId
					, 'Question': questionXML
					, 'LifetimeInSeconds': 60 * 20  // How long should the assignment last?
					, 'MaxAssignments': 1
				};
				mturk.CreateHIT(options, function(err, HITId){
					if (err) throw err;
					HITId.should.be.a("String");
					HITId.should.have.length(30);
					done();
				});  // mturk.CreateHIT
			});
		});


		// it('should create a common property HIT and return the ID of the new HITId', function(done){
		// 	done();
		// });
	});





	/**
	*
	*/
	describe("#GetHIT()", function(){
		it('should get a single hit with all of the associated information', function(done){
			mturk.GetHIT({HITId: _HITId}, function(err, HIT){
				validateHIT( HIT );
				done();
			});
		});
	});





	/**
	*
	*/
	// describe("#GetReviewableHITs()", function(){

	// });




	/**
	*
	*/
	describe("#SearchHITs()", function(){
		it('should get all of the hits that were created in the last few tests', function(done){
			mturk.SearchHITs({SortProperty: "Title"}, function(err, SearchHITsResult){
				
				if (err) throw err;

				SearchHITsResult.should.have.property("NumResults");
				SearchHITsResult.should.have.property("TotalNumResults");
				SearchHITsResult.should.have.property("PageNumber");
				SearchHITsResult.should.have.property("HIT");
				SearchHITsResult.HIT.should.be.a("Array");

				SearchHITsResult.HIT.length.should.be.above(2);
				SearchHITsResult.HIT.forEach(function(HIT){
					validateHIT( HIT );
				});
	
				done();
			});
		});
	});



	/**	
	describe("#disableHITs()", function(){
		this.timeout(15000);

		it('should disable all hits on the account', function(done){
			mturk.disableHITs(100, function(err){
				if (err) throw err;
		
				mturk.SearchHITs({}, function(err, SearchHITsResult){
					SearchHITsResult.TotalNumResults.should.equal("0");
					done();
				});
			});
		});
	});
	*/


	// after(function(done){
	// 	done();
	// });

});