load('../nway.js');

var comp = 
[
	"sanity-2.6.5-mmapv0-c1",
//	"sanity-2.8.0-rc0-mmapv1-c1",
//	"sanity-2.8.0-rc1-mmapv1-c1",
//	"sanity-2.8.0-rc2-mmapv1-c1",
//	"sanity-2.8.0-rc3-mmapv1-c1",
//	"sanity-2.8.0-rc4-mmapv1-c1",
//	"sanity-2.8.0-rc5-mmapv1-c1",
	"sanity-3.0.0-rc6-mmapv1-c1",
]

var criteria = {};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c1",
//	"daily-2.8.0-rc0-mmapv1-c1",
//	"daily-2.8.0-rc1-mmapv1-c1",
//	"daily-2.8.0-rc2-mmapv1-c1",
//	"daily-2.8.0-rc3-mmapv1-c1",
//	"daily-2.8.0-rc4-mmapv1-c1",
//	"daily-2.8.0-rc5-mmapv1-c1",
	"daily-3.0.0-rc6-mmapv1-c1",
]

var criteria = {};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

