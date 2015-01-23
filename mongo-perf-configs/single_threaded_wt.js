load('../nway.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-c1",
//	"sanity-2.8.0-rc0-wiredtiger-c1",
//	"sanity-2.8.0-rc1-wiredTiger-c1",
//	"sanity-2.8.0-rc2-wiredTiger-c1",
//	"sanity-2.8.0-rc3-wiredTiger-c1",
//	"sanity-2.8.0-rc4-wiredTiger-c1",
	"sanity-2.8.0-rc5-wiredTiger-c1",
]

var criteria = addBlacklisted({threads:1});
var threshold = -30;
nway(comp, criteria, threshold);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c1",
//	"daily-2.8.0-rc0-wiredtiger-c1",
//	"daily-2.8.0-rc1-wiredTiger-c1",
//	"daily-2.8.0-rc2-wiredTiger-c1",
//	"daily-2.8.0-rc3-wiredTiger-c1",	
	"daily-2.8.0-rc4-wiredTiger-c1",	
]

var criteria = addBlacklisted({threads:1});
var threshold = -30;
nway(comp, criteria, threshold);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"sanity-2.6.5-mmapv0-single",
	"sanity-2.8.0-rc5-mmapv1-single",
	"sanity-2.8.0-rc5-wiredTiger-single",
]

var criteria = addBlacklisted({threads:1});
var threshold = -30;
nway(comp, criteria, threshold);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();
