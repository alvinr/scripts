// 2.6.5 vs 2.8.0-rc0 vs 2.8.0-rc1
// shows
// testname: {ab: delta: ac: delta }

var comp = 
[
	"sanity-2.6.5-mmapv0-c1",
//    "sanity-2.8.0-rc0-mmapv1-single",
//	"sanity-2.8.0-rc1-mmapv1-c1",
//	"sanity-2.8.0-rc0-wiredtiger-single",
	"sanity-2.8.0-rc1-mmapv1-c1",
]

db.diff.remove({base: {$in: comp}})

function median(values) { 
    values.sort( function(a,b) {return a - b;} ); 
    var half = Math.floor(values.length/2);
    if(values.length % 2)
        return values[half];
    else
        return (values[half-1] + values[half]) / 2.0;
}

for (var p=0; p < comp.length; p++) {
   var res = { base: comp[p], aginst: [], win: {}, loss: {}, win_loss_pct: {}, total_wins: {}, totaL_loss: {} };
   for (var q=0; q < comp.length; q++) {
      if ( p == q ) {
        continue;
      }
      res["aginst"].push(comp[q]);
      var label = comp[p] + " vs. " + comp[q];
      var m = {};

      db.delta.find({label:label}).forEach( 
         function(thisDoc) {
            var testName = (thisDoc.test).replace(/\./g,"/");
            if ( typeof res[testName] === "undefined" ) {
               res[testName] = { median:{} };
            }
            if ( typeof res[testName][thisDoc.threads] === "undefined" ) {
               var verName = (thisDoc.source.a_version).replace(/\./g,"-") + "/" + thisDoc.source.a_platform + "/" + thisDoc.source.a_storage_engine;
               res[testName][thisDoc.threads] = {};
               res[testName][thisDoc.threads][verName] = thisDoc.a_median;
            }
            var verName = (thisDoc.source.b_version).replace(/\./g,"-") + "/" + thisDoc.source.b_platform + "/" + thisDoc.source.b_storage_engine;
            res[testName][thisDoc.threads][verName] = thisDoc.delta;
            
            if ( typeof m[testName] === "undefined" ) {
               m[testName] = {};
               m[testName][verName] = {};
               m[testName][verName]["values"] = [];
            }
            m[testName][verName]["values"].push(thisDoc.delta);
            m[testName][verName]["median"] = median(m[testName][verName]["values"]);
            
            if ( typeof res[testName]["median"][verName] === "undefined" ) {
               res[testName]["median"][verName] = {};
            }
            res[testName]["median"][verName] = m[testName][verName]["median"];
            if ( typeof res["win"][verName] === "undefined" ) {
              res["win"][verName] = [];
            }
            if ( typeof res["loss"][verName] ==="undefined" ) {
              res["loss"][verName] = [];
            }
            if ( res[testName]["median"][verName] > -10 ) {
               if ( res["win"][verName].lastIndexOf(testName) == -1 ) {
                  res["win"][verName].push(testName);
                  if ( res["loss"][verName].lastIndexOf(testName) != -1 ) {
                     res["loss"][verName].splice(res["loss"][verName].lastIndexOf(testName),1);
                  }
               }
            }
            else {
               if ( res["loss"][verName].lastIndexOf(testName) == -1 ) {
                  res["loss"][verName].push(testName);
                  if ( res["win"][verName].lastIndexOf(testName) != -1 ) {
                     res["win"][verName].splice(res["win"][verName].lastIndexOf(testName),1);
                  }
               }
            }
      res["win_loss_pct"][verName] = (res["win"][verName].length / (res["loss"][verName].length + res["win"][verName].length))*100
      res["total_wins"][verName] = res["win"][verName].length;
      res["totaL_loss"][verName] = res["loss"][verName].length;
      });
   }

   db.diff.insert(res);
}

//db.diff.find({base:comp[0]},{total_wins:1, totaL_loss:1, win_loss:1, win:1, loss:1}).pretty();
db.diff.find({base:comp[0]}).pretty();
