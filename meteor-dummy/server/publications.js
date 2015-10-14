Meteor.publish("records", function () {
	return Records.find();
});

Meteor.publish("published-records", function () {
	return Records.find({published: true});
});
