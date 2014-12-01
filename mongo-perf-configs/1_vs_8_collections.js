load('../nway-diff.js');
load('../nway-results.js');
load('../nway-blacklist.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-c8",
	"sanity-2.8.0-rc0-mmapv1-c8",
	"sanity-2.8.0-rc1-mmapv1-c8",
]

var criteria = {};
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
	"daily-2.8.0-rc0-mmapv1-c8",
	"daily-2.8.0-rc1-mmapv1-c8",
]

var criteria = {};
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

var comp = 
[
	"sanity-2.6.5-mmapv0-c8",
	"sanity-2.8.0-rc0-wiredtiger-c8",
	"sanity-2.8.0-rc1-wiredTiger-c8",
]

var criteria = addBlacklisted({});
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
	"daily-2.8.0-rc0-wiredtiger-c8",
	"daily-2.8.0-rc1-wiredTiger-c8",
]

var criteria = addBlacklisted({});
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
	"daily-2.8.0-rc1-wiredtiger-c8",
	"daily-2.8.0-rc1-mmapv1-c8",
]

var criteria = addBlacklisted({});
generateResults(comp);
generateReport(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, win_loss_pct:1, total_wins:1, total_loss:1}).pretty();


