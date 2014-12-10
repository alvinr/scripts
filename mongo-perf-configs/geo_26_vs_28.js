load('../nway.js');

var comp = 
[
	"daily-2.6.5-mmapv0-c1",
	"daily-2.8.0-rc2-mmapv1-c1",
	"daily-2.8.0-rc2-wiredTiger-c1",
]

var criteria = {test:/^Geo/};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

var comp = 
[
	"daily-2.6.5-mmapv0-c8",
	"daily-2.8.0-rc2-mmapv1-c8",
	"daily-2.8.0-rc2-wiredTiger-c8",
]

var criteria = {test:/^Geo/};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

load('../nway.js');
var comp = 
[
	"daily-2.8.0-rc1-wiredTiger-c1",
	"daily-2.8.0-rc1-wiredTiger-c8",
]

var criteria = {test:/^Geo/};
nway(comp, criteria);

db.diff.find({base:comp[0]},{base:1, against:1, median:1, abs:1}).pretty();

