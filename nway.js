
function _median(values) { 
    values.sort( function(a,b) {return a - b;} ); 
    var half = Math.floor(values.length/2);
    if(values.length % 2)
        return values[half];
    else
        return (values[half-1] + values[half]) / 2.0;
}

function _preDiff(comp) {
   db.diff.remove({base: {$in: comp}})
}

function _genDiff(comp, criteria, threshold) {

    for (var p=0; p < comp.length; p++) {
       var res = { base: comp[p], against: [], 
                   median: { win: {}, loss: {}, win_loss_pct: {}, total_wins: {}, total_loss: {} }, 
                   abs: { win: {}, loss: {}, win_loss_pct: {}, total_wins: {}, total_loss: {} },                    
                 };
       for (var q=0; q < comp.length; q++) {
          if ( p == q ) {
            continue;
          }
          res["against"].push(comp[q]);
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
//                var verName = (thisDoc.source.b_version).replace(/\./g,"-") + "/" + thisDoc.source.b_platform + "/" + thisDoc.source.b_storage_engine;
                var verName = (thisDoc.source.b_label).replace(/\./g,"-");
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
                   res[testName]["min"][verName] = thisDoc.delta;
                }
                res[testName]["min"][verName] = Math.min(thisDoc.delta, res[testName]["min"][verName]);
                
                if ( typeof res[testName]["max"][verName] === "undefined" ) {
                   res[testName]["max"][verName] = thisDoc.delta;
                }
                res[testName]["max"][verName] = Math.max(thisDoc.delta, res[testName]["max"][verName]);

                if ( typeof res["median"]["win"][verName] === "undefined" ) {
                  res["median"]["win"][verName] = [];
                }
                if ( typeof res["median"]["loss"][verName] ==="undefined" ) {
                  res["median"]["loss"][verName] = [];
                }
                if ( typeof res["abs"]["win"][verName] === "undefined" ) {
                  res["abs"]["win"][verName] = [];
                }
                if ( typeof res["abs"]["loss"][verName] ==="undefined" ) {
                  res["abs"]["loss"][verName] = [];
                }

                if ( res[testName]["median"][verName] > threshold ) {
                   if ( res["median"]["win"][verName].lastIndexOf(testName) == -1 ) {
                      res["median"]["win"][verName].push(testName);
                      if ( res["median"]["loss"][verName].lastIndexOf(testName) != -1 ) {
                         res["median"]["loss"][verName].splice(res["median"]["loss"][verName].lastIndexOf(testName),1);
                      }
                   }
                }
                else {
                   if ( res["median"]["loss"][verName].lastIndexOf(testName) == -1 ) {
                      res["median"]["loss"][verName].push(testName);
                      if ( res["median"]["win"][verName].lastIndexOf(testName) != -1 ) {
                         res["median"]["win"][verName].splice(res["median"]["win"][verName].lastIndexOf(testName),1);
                      }
                   }
                }

                if ( res[testName]["min"][verName] > threshold && res[testName]["max"][verName] > threshold ) {
                   if ( res["abs"]["win"][verName].lastIndexOf(testName) == -1 ) {
                      res["abs"]["win"][verName].push(testName);
                      if ( res["abs"]["loss"][verName].lastIndexOf(testName) != -1 ) {
                         res["abs"]["loss"][verName].splice(res["abs"]["loss"][verName].lastIndexOf(testName),1);
                      }
                   }
                }
                else {
                   if ( res["abs"]["loss"][verName].lastIndexOf(testName) == -1 ) {
                      res["abs"]["loss"][verName].push(testName);
                      if ( res["abs"]["win"][verName].lastIndexOf(testName) != -1 ) {
                         res["abs"]["win"][verName].splice(res["abs"]["win"][verName].lastIndexOf(testName),1);
                      }
                   }
                }

                res["median"]["win_loss_pct"][verName] = Math.round((res["median"]["win"][verName].length / (res["median"]["loss"][verName].length + res["median"]["win"][verName].length))*100)
                res["median"]["total_wins"][verName] = res["median"]["win"][verName].length;
                res["median"]["total_loss"][verName] = res["median"]["loss"][verName].length;

                res["abs"]["win_loss_pct"][verName] = Math.round((res["abs"]["win"][verName].length / (res["abs"]["loss"][verName].length + res["abs"]["win"][verName].length))*100)
                res["abs"]["total_wins"][verName] = res["abs"]["win"][verName].length;
                res["abs"]["total_loss"][verName] = res["abs"]["loss"][verName].length;
          });
       }

       db.diff.insert(res);
    }
}

function _preDelta(label) {
  db.delta.remove({label:label});
  db.delta.ensureIndex({delta:1});
  db.delta.ensureIndex({test:1});
}

function _calcDelta(label, a, b, min_thread, max_thread) {
    if ( typeof min_thread === "undefined" ) {
       min_thread=1;
    }
    if ( typeof max_thread === "undefined" ) {
       max_thread=20;
    }

    var possible = ["singledb","multidb","multicoll"];

    if ( typeof a === "undefined" ) {
       print("a is not an object");
       return;
    }

    if ( typeof b === "undefined" ) {
       print("b is not an object");
       return;
    }

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

          if ( testB.name != testA.name ) {
             continue;
          }

          for (var j=min_thread; j <= max_thread; j++) {
             if ( typeof testA.results[j] === "undefined" ) {
                continue;
             }
             if ( typeof testB.results[j] === "undefined" ) {
                print("skipping threadB:" + j);
                continue;
             }

//             var diff = Math.round(((testB.results[j].median)/(testA.results[j].median)-1) * 100);
             var diff = Math.round((testB.results[j].median - testA.results[j].median)/(testA.results[j].median) * 100);
             res = { label: label,
                     comp_date: new Date(),
                     source: { a_label: a.label,
                               b_label: b.label,
                               a_version:  a.server_version,
                               b_version: b.server_version,
                               a_commit: a.commit,
                               b_commit: b.commit,
                               a_storage_engine: a.server_storage_engine,
                               b_storage_engine: b.server_storage_engine,
                               a_platform: a.platform,
                               b_platform: b.platform
                             },
                     test: testA.name,
                     threads: j,
                     a_median: testA.results[j].median,
                     b_median: testB.results[j].median,
                     delta: diff
                   };
              db.delta.insert(res);
          }
       }
    }
}

// 3.0.0 MMAP blacklisted tests - for single collection
function addBlacklistedMMAP(predicate) {
    var blacklisted = {test: {$nin: 
        ["Update.FieldAtOffset",
        ]}};
    for (var attrname in predicate) { blacklisted[attrname] = predicate[attrname]; };

    return blacklisted;
}

// 3.0.0 WiredTiger blacklisted tests
function addBlacklisted(predicate) {
    var blacklisted = {test: {$nin: 
        ["Commands.v1.DistinctWithoutIndex",
         "Commands.v1.DistinctWithoutIndexAndQuery",
         "Commands.isMaster",
         "Update.MmsIncShallow1",
         "Update.MmsIncShallow2",
         "Update.MmsIncDeep1",
         "Update.MmsIncDeepSharedPath2",
         "Update.MmsIncDeepSharedPath3",
         "Update.MmsIncDeepDistinctPath2",
         "Update.MmsIncDeepDistinctPath3",
         "Update.FieldAtOffset",
         "Geo.within.2dsphere.polygon.findOne",
         "Geo.within.2dsphere.polygon.findOne.offcenter",
         "Geo.geoJSON.within.2dsphere.polygon.findOne",
         "Geo.geoJSON.within.2dsphere.polygon.findOne.offcenter",
         ]}};
    for (var attrname in predicate) { blacklisted[attrname] = predicate[attrname]; };

    return blacklisted;
}

function generateDelta(comp, min_thread, max_thread) {
    for (var p=0; p < comp.length; p++) {
       for (var q=0; q < comp.length; q++) {
          if ( p == q ) {
            continue;
          }
          var a = db.raw.findOne({label:comp[p]});
          var b = db.raw.findOne({label:comp[q]});
          if ( a == null ) {
              print("skipping label - not found: " + comp[p]);
              continue;
          }
          if ( b == null ) {
              print("skipping label - not found: " + comp[q]);
              continue;
          }
          var label = a.label + " vs. " + b.label;
          print(label);
          _preDelta(label);
          _calcDelta(label, a, b, min_thread, max_thread);
       }
    }
}

function generateDiff(comp, criteria, threshold) {
  if ( typeof threshold === "undefined" ) {
     threshold = -10;
  }    
  _preDiff(comp);
  _genDiff(comp, criteria, threshold);
}

function nway(comp, criteria, threshold, min_thread, max_thread) {
  generateDelta(comp, min_thread, max_thread);
  generateDiff(comp, criteria, threshold); 
}


