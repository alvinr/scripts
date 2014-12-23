load('../nway.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-single",
//	"sanity-2.8.0-rc1-wiredTiger-single",
//	"sanity-2.8.0-rc2-wiredTiger-single",
	"sanity-2.8.0-rc3-wiredTiger-single",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"sanity-2.6.5-mmapv0-set",
//	"sanity-2.8.0-rc1-wiredTiger-set",
	"sanity-2.8.0-rc2-wiredTiger-set",
	"sanity-2.8.0-rc3-wiredTiger-set",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

