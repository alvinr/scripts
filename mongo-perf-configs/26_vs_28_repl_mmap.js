load('../nway.js');

// Single Node replica Set
var comp = 
[
	"sanity-2.6.5-mmapv0-single",
//	"sanity-2.8.0-rc0-mmapv1-single",
//	"sanity-2.8.0-rc1-mmapv1-single",
//	"sanity-2.8.0-rc2-mmapv1-single",
//	"sanity-2.8.0-rc3-mmapv1-single",
//	"sanity-2.8.0-rc4-mmapv1-single",
//	"sanity-2.8.0-rc5-mmapv1-single",
//	"sanity-3.0.0-rc6-mmapv1-single",
//	"sanity-3.0.0-rc7-mmapv1-single",
	"sanity-3.0.0-rc8-mmapv1-single",
]

var criteria = addBlacklistedMMAP({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-single",
//	"daily-2.8.0-rc2-mmapv1-single",
//	"daily-2.8.0-rc3-mmapv1-single",
//	"daily-2.8.0-rc4-mmapv1-single",
//	"daily-2.8.0-rc5-mmapv1-single",
//	"daily-3.0.0-rc6-mmapv1-single",
//	"daily-3.0.0-rc7-mmapv1-single",
	"daily-3.0.0-rc7-mmapv1-single",
]

var criteria = addBlacklistedMMAP({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

// 3 Node Replica Set
var comp = 
[
	"sanity-2.6.5-mmapv0-set",
//	"sanity-2.8.0-rc0-mmapv1-set",
//	"sanity-2.8.0-rc1-mmapv1-set",
//	"sanity-2.8.0-rc2-mmapv1-set",
//	"sanity-2.8.0-rc3-mmapv1-set",
//	"sanity-2.8.0-rc4-mmapv1-set",
//	"sanity-2.8.0-rc5-mmapv1-set",
//	"sanity-3.0.0-rc6-mmapv1-set"
//	"sanity-3.0.0-rc7-mmapv1-set"
	"sanity-3.0.0-rc8-mmapv1-set"
]

var criteria = addBlacklistedMMAP({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-set",
//	"daily-2.8.0-rc2-mmapv1-set",
//	"daily-2.8.0-rc3-mmapv1-set",
//	"daily-2.8.0-rc4-mmapv1-set",
//	"daily-2.8.0-rc5-mmapv1-set",
//	"daily-3.0.0-rc6-mmapv1-set",
//	"daily-3.0.0-rc7-mmapv1-set",
	"daily-3.0.0-rc8-mmapv1-set",
]

var criteria = addBlacklistedMMAP({});
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

// Overhead of repl
var comp = 
[
	"sanity-2.8.0-rc5-mmapv1-none",
	"sanity-2.8.0-rc5-mmapv1-single",
	"sanity-2.8.0-rc5-mmapv1-set",
]

var criteria = {};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

