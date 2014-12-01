function addBlacklisted(predicate) {
    var blacklisted = {test: {$nin: ["Commands.v1.DistinctWithoutIndex","Commands.v1.DistinctWithoutIndexAndQuery","Commands.isMaster"]}};
    for (var attrname in predicate) { blacklisted[attrname] = predicate[attrname]; };

    return blacklisted;
}