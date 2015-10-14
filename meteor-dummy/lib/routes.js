Router.route('/records', { where: 'server' })
	.get(function () {
		var res = this.response;
		res.end(JSON.stringify(Records.find().fetch()));
	})
	.post(function () {
		Records.insert(JSON.parse(this.params.record));
		res.end(JSON.stringify({ success: true }));
	})
	.put(function () {
		Records.update(this.params.id, { $set: JSON.parse(this.params.record) });
		res.end(JSON.stringify({ success: true }));
	})
	.delete(function () {
		Records.remove(this.params.id);
		res.end(JSON.stringify({ success: true }));
	});

Router.route('/records/clear', { where: 'server' })
	.post(function () {
		Records.remove({});
	});
