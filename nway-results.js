// 2.6.5 vs 2.8.0-rc0 vs 2.8.0-rc1
// shows
// testname: {ab: delta: ac: delta }

//var comp = 
//[
//	"sanity-2.6.5-mmapv0-c1",
//	"sanity-2.8.0-rc0-mmapv1-c1",
//	"sanity-2.8.0-rc1-mmapv1-c1"
//]



for (var p=0; p < comp.length; p++) {
   var res = { base: comp[p], aginst: []};
   for (var q=0; q < comp.length; q++) {
      if ( p == q ) {
        continue;
      }
      res["aginst"].push(comp[q]);
      var label = comp[p] + " vs. " + comp[q];

      db.delta.find({label:label}).forEach( 
         function(thisDoc) {
            var lbl = (thisDoc.test).replace(/\./g,"/");
            if ( typeof res[lbl] === "undefined" ) {
               res[lbl] = {};
            }
            var a = res[lbl];
            if ( typeof a[thisDoc.threads] === "undefined" ) {
               a[thisDoc.threads] = [];
               a[thisDoc.threads].push(thisDoc.a_median);
            }
            a[thisDoc.threads].push(thisDoc.delta);
      });
   }
   db.diff.insert(res);
   printjson(res);  
}