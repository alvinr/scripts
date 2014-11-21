var comp = [
              "sanity-7bdca162807d6436d469a352a129226252cb451d-2014-11-13-mmapv1-c1",
              "sanity-def8f54bf6162317cc8b345e81c6e698d618ad96-2014-11-20-mmapv1-c1",
              "sanity-534263f1d83cdeb142c27f0ea5a1ecffc5b7526a-2014-11-21-mmapv1-c1"
           ];

function pre(label) {
  db.delta.remove({label:label});
  db.delta.ensureIndex({delta:1});

}

function diff(label, a, b) {
    var possible = ["singledb","multidb","multicoll"];
    var min_thread=1;
    var max_thread=20;

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

             var diff = (testB.results[j].median)/(testA.results[j].median) * 100;
             res = { label: label,
                     comp_date: new Date(),
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
              db.delta.insert(res);
          }
       }
    }
}

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
      diff(label, a, b);
      print("******* WINS");
      db.delta.find({label:label},{_id:0, source:0}).sort({delta:-1}).limit(7).forEach( function(myDoc) { printjson( myDoc); } );
      print("******* LOSSES");
      db.delta.find({label:label},{_id:0, source:0}).sort({delta:1}).limit(7).forEach( function(myDoc) { printjson( myDoc); } );
   }
}
