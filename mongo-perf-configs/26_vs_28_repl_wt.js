load('../nway.js');

// Single Node Replioca Set
var comp = 
[
	"sanity-2.6.5-mmapv0-single",
//	"sanity-2.8.0-rc1-wiredTiger-single",
//	"sanity-2.8.0-rc2-wiredTiger-single",
//	"sanity-2.8.0-rc3-wiredTiger-single",
//	"sanity-2.8.0-rc4-wiredTiger-single",
//	"sanity-2.8.0-rc5-wiredTiger-single",
//	"sanity-3.0.0-rc6-wiredTiger-single",
//	"sanity-3.0.0-rc7-wiredTiger-single",
//	"sanity-3.0.0-rc8-wiredTiger-single",
//	"sanity-3.0.0-rc9-wiredTiger-single",
//	"sanity-3.0.0-rc10-wiredTiger-single",
	"sanity-3.0.0-rc11-wiredTiger-single",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-single",
//	"daily-2.8.0-rc2-wiredTiger-single",
//	"daily-2.8.0-rc3-wiredTiger-single",
//	"daily-2.8.0-rc4-wiredTiger-single",
//	"daily-2.8.0-rc5-wiredTiger-single",
//	"daily-3.0.0-rc6-wiredTiger-single",
//	"daily-3.0.0-rc7-wiredTiger-single",
	"daily-3.0.0-rc8-wiredTiger-single",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

// 3 Node Replioca Set
var comp = 
[
	"sanity-2.6.5-mmapv0-set",
//	"sanity-2.8.0-rc1-wiredTiger-set",
//	"sanity-2.8.0-rc2-wiredTiger-set",
//	"sanity-2.8.0-rc3-wiredTiger-set",
//	"sanity-2.8.0-rc4-wiredTiger-set",
//	"sanity-2.8.0-rc5-wiredTiger-set",
//	"sanity-3.0.0-rc6-wiredTiger-set",
//	"sanity-3.0.0-rc7-wiredTiger-set",
//	"sanity-3.0.0-rc8-wiredTiger-set",
	"sanity-3.0.0-rc9-wiredTiger-set",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-set",
//	"daily-2.8.0-rc2-wiredTiger-set",
//	"daily-2.8.0-rc3-wiredTiger-set",
//	"daily-2.8.0-rc4-wiredTiger-set",
//	"daily-2.8.0-rc5-wiredTiger-set",
//	"daily-3.0.0-rc6-wiredTiger-set",
//	"daily-3.0.0-rc7-wiredTiger-set",
	"daily-3.0.0-rc8-wiredTiger-set",
]

var criteria = addBlacklisted({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();
