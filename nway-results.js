function _pre(comp) {
   db.diff.remove({base: {$in: comp}})
}

function _median(values) { 
    values.sort( function(a,b) {return a - b;} ); 
    var half = Math.floor(values.length/2);
    if(values.length % 2)
        return values[half];
    else
        return (values[half-1] + values[half]) / 2.0;
}

function _genReport(comp, criteria, threshold) {

    for (var p=0; p < comp.length; p++) {
       var res = { base: comp[p], aginst: [], win: {}, loss: {}, win_loss_pct: {}, total_wins: {}, total_loss: {} };
       for (var q=0; q < comp.length; q++) {
          if ( p == q ) {
            continue;
          }
          res["aginst"].push(comp[q]);
          var label = comp[p] + " vs. " + comp[q];
          var m = {};
          var predicate = {label:label};
          for (var attrname in criteria) { predicate[attrname] = criteria[attrname]; };
          
          db.delta.find(predicate).forEach( 
             function(thisDoc) {
                var testName = (thisDoc.test).replace(/\./g,"/");
                if ( typeof res[testName] === "undefined" ) {
                   res[testName] = { median:{}, max:{}, min:{} };
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
                m[testName][verName]["median"] = _median(m[testName][verName]["values"]);
                
                if ( typeof res[testName]["median"][verName] === "undefined" ) {
                   res[testName]["median"][verName] = {};
                }
                res[testName]["median"][verName] = m[testName][verName]["median"];
                
                if ( typeof res[testName]["min"][verName] === "undefined" ) {
                   res[testName]["min"][verName] = 0;
                }
                res[testName]["min"][verName] = Math.min(thisDoc.delta, res[testName]["min"][verName]);
                
                if ( typeof res[testName]["max"][verName] === "undefined" ) {
                   res[testName]["max"][verName] = 0;
                }
                res[testName]["max"][verName] = Math.max(thisDoc.delta, res[testName]["max"][verName]);

                if ( typeof res["win"][verName] === "undefined" ) {
                  res["win"][verName] = [];
                }
                if ( typeof res["loss"][verName] ==="undefined" ) {
                  res["loss"][verName] = [];
                }
                if ( res[testName]["median"][verName] > threshold ) {
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

                res["win_loss_pct"][verName] = Math.round((res["win"][verName].length / (res["loss"][verName].length + res["win"][verName].length))*100)
                res["total_wins"][verName] = res["win"][verName].length;
                res["total_loss"][verName] = res["loss"][verName].length;
          });
       }

       db.diff.insert(res);
    }
}

function generateReport(comp, criteria, threshold) {
  if ( typeof threshold === "undefined" ) {
     threshold = -10;
  }    
  _pre(comp);
  _genReport(comp, criteria, threshold);
}

