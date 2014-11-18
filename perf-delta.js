var possible = ["singledb","multidb","multicoll"];
//var a_version = "2.6.5";
//var b_version = "2.8.0-rc0";
//var host = /sanity/

db.delta.drop();
db.delta.ensureIndex({delta:1});

var a = db.raw.findOne({label:"sanity-2.6.5-mmapv0-single"});
var b = db.raw.findOne({label:"sanity-bec3fc4b1374fb9eff9e4cc82ada7b8d5f43de45-2014-11-17-mmapv1-single"});


for (var k=0; k < possible.length; k++) {
   var resType = possible[k];
   if ( typeof a[resType] === "undefined" ) {
      continue;
   }
   if ( typeof b[resType] === "undefined" ) {
      continue;
   }

   var dbConfigA = a[resType]
   var dbConfigB = b[resType]

   for (var i=0; i < dbConfigA.length; i++) {

      var testA = dbConfigA[i];
      if ( typeof testA === "undefined" ) {
         continue;
      }     
      var testB;
      for (var l=0; l < dbConfigB.length; l++) {
         testB = dbConfigB[l];
         if ( testB.name == testA.name ) {
            break;
         }
      }

      if ( typeof testB === "undefined" ) {
         continue;
      }

      for (var j=0; j < 49; j++) {
         if ( typeof testA.results[j] === "undefined" ) {
            continue;
         }
         if ( typeof testB.results[j] === "undefined" ) {
            continue;
         }

         var diff = (testB.results[j].median)/(testA.results[j].median) * 100;
         res = { source: { a_label: a.label,
                           b_label: b.label,
                           a_version:  a.server_version + " / " + a.commit,
                           b_version: b.server_version + " / " + b.commit
                         },
                 test: testA.name,
                 threads: j,
                 a_median: testA.results[j].median,
                 b_median: testB.results[j].median,
                 delta: diff
               };
//          printjson(res);
          db.delta.insert(res);
      }
   }
}
print("******* WIN");
db.delta.find({},{_id:0, source:0}).sort({delta:-1}).limit(10).pretty();
print("******* LOSS");
db.delta.find({},{_id:0, source:0}).sort({delta:1}).limit(10).pretty();
