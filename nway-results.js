// 2.6.5 vs 2.8.0-rc0 vs 2.8.0-rc1
// shows
// testname: {ab: delta: ac: delta }

var comp = 
[
	"sanity-7bdca162807d6436d469a352a129226252cb451d-2014-11-13-mmapv1-c1",
	"sanity-def8f54bf6162317cc8b345e81c6e698d618ad96-2014-11-20-mmapv1-c1",
	"sanity-534263f1d83cdeb142c27f0ea5a1ecffc5b7526a-2014-11-21-mmapv1-c1"
]



for (var p=0; p < comp.length; p++) {
   var res = { base: comp[p], aginst: []};
   for (var q=0; q < comp.length; q++) {
      if ( p == q ) {
        continue;
      }
      res["aginst"].push(comp[q]);
      var label = comp[p] + " vs. " + comp[q];
//      var myCursor = db.delta.find({label:label});

//      while (myCursor.hasNext()) {
//         var obj = myCursor.next();
//         diff.push(this.delta);
//         print(tojson(myCursor.next()));
//      }
      db.delta.find({label:label}).forEach( 
         function(thisDoc) {
            if ( typeof res[thisDoc.test] === "undefined" ) {
               res[thisDoc.test] = {};
            }
            var a = res[thisDoc.test];
            if ( typeof a[thisDoc.threads] === "undefined" ) {
               a[thisDoc.threads] = [];
               a[thisDoc.threads].push(thisDoc.a_median);
            }
            a[thisDoc.threads].push(thisDoc.delta);
      });
   }
   printjson(res);  
}