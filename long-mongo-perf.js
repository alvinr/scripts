var possible = ["singledb","multidb","multicoll"];
db.long_exec.drop();

db.raw.find().forEach(
function(thisDoc) {

   for (var k=0; k < possible.length; k++) {
      var resType = possible[k];
      if ( typeof thisDoc[resType] === "undefined" ) {
//         print("skipping:" + thisDoc.label + " for:" + resType);
         continue;
      }
      var dbConfig = thisDoc[resType]
      for (var i=0; i < dbConfig.length; i++) {
         var test = dbConfig[i];
         for (var j=0; j < 48; j++) {
           if ( typeof test.results[j] === "undefined" ) {
//              print("skipping:" + thisDoc.label + " test:" + test.name + " it:" + j);
              continue;
           }
           var diff = (test.results[j].run_end_time - test.results[j].run_start_time)/1000;
           // Test to see if we exceed 105%
           if ( diff > (test.results[j].elapsed_secs*1.05) ) {
              res = { label: thisDoc.label,
                      test:  test.name,
                      threads: j,
                      requested: test.results[j].elapsed_secs,
                      actual: diff,
                      percentage: (diff/test.results[j].elapsed_secs)*100 };
//              printjson(res);
              db.long_exec.insert(res);
           }
         }
      }
   }
}
)
db.long_exec.find().sort({percentage:-1}).limit(20)