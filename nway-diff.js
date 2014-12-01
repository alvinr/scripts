function pre(label) {
  db.delta.remove({label:label});
  db.delta.ensureIndex({delta:1});

}

function diff(label, a, b, min_thread, max_thread) {
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

function generateResults(comp, min_thread, max_thread) {
    for (var p=0; p < comp.length; p++) {
       for (var q=0; q < comp.length; q++) {
          if ( p == q ) {
            continue;
          }
          var a = db.raw.findOne({label:comp[p]});
          var b = db.raw.findOne({label:comp[q]});
          var label = a.label + " vs. " + b.label;
          print(label);
          pre(label);
          diff(label, a, b, min_thread, max_thread);
       }
    }
}

