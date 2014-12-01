load('../nway-diff.js');
load('../nway-results.js');

var comp = 
[
	"daily-2.6.5-mmapv0-c1",
	"daily-2.8.0-rc1-mmapv1-c1",
	"daily-2.8.0-rc1-wiredTiger-c1",
]

var criteria = {test:/^Geo/};
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();
