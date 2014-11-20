var possible = ["singledb","multidb","multicoll"];
//var a_version = "2.6.5";
//var b_version = "2.8.0-rc0";
//var host = /sanity/
var min_thread=1;
var max_thread=48;


var a = db.raw.findOne({label:"sanity-2.8.0-rc0-mmapv1-c1"});
var b = db.raw.findOne({label:"sanity-def8f54bf6162317cc8b345e81c6e698d618ad96-2014-11-20-mmapv1-c1"});

var label = a + "/" + b;
db.delta.remove({_id:label});
db.delta.ensureIndex({delta:1});

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

      for (var j=min_thread; j <= max_thread; j++) {
         if ( typeof testA.results[j] === "undefined" ) {
            continue;
         }
         if ( typeof testB.results[j] === "undefined" ) {
            continue;
         }

         var diff = (testB.results[j].median)/(testA.results[j].median) * 100;
         res = { _id: label,
                 source: { a_label: a.label,
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
db.delta.find({_id:label},{_id:0, source:0}).sort({delta:-1}).limit(10).pretty();
print("******* LOSS");
db.delta.find({_id:label},{_id:0, source:0}).sort({delta:1}).limit(10).pretty();
