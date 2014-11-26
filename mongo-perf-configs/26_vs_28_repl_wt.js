load('../nway-diff.js');
load('../nway-results.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-single",
	"sanity-2.8.0-rc0-wiredtiger-single",
	"sanity-2.8.0-rc1-wiredTiger-single",
]

var criteria = {};
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

var comp = 
[
	"sanity-2.6.5-mmapv0-set",
	"sanity-2.8.0-rc0-wiredtiger-set",
	"sanity-2.8.0-rc1-wiredTiger-set",
]

var criteria = {};
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

