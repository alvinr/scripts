load('../nway.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-c8",
//	"sanity-2.8.0-rc0-mmapv1-c8",
//	"sanity-2.8.0-rc1-mmapv1-c8",
    "sanity-2.8.0-rc2-mmapv1-c8",
    "sanity-2.8.0-rc3-mmapv1-c8",
]

var criteria = {};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
//	"daily-2.8.0-rc0-mmapv1-c8",
//	"daily-2.8.0-rc1-mmapv1-c8",
//	"daily-2.8.0-rc2-mmapv1-c8",
	"daily-2.8.0-rc2-mmapv1-c8",
]

var criteria = {};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"sanity-2.6.5-mmapv0-c8",
//	"sanity-2.8.0-rc0-wiredtiger-c8",
//	"sanity-2.8.0-rc1-wiredTiger-c8",
//	"sanity-2.8.0-rc2-wiredTiger-c8",
	"sanity-2.8.0-rc3-wiredTiger-c8",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
//	"daily-2.8.0-rc0-wiredtiger-c8",
//	"daily-2.8.0-rc1-wiredTiger-c8",
	"daily-2.8.0-rc2-wiredTiger-c8",
	"daily-2.8.0-rc3-wiredTiger-c8",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
	"daily-2.8.0-rc2-wiredTiger-c8",
	"daily-2.8.0-rc2-mmapv1-c8",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();
