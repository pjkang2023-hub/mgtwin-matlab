function rep = runAllGates(site)
%RUNALLGATES Run every verification gate on SITE and merge the findings.
%   Gates are mechanical checks that run before anyone is allowed to believe
%   a model: forming, units, grounding, protection, model honesty,
%   energisation and loading (Python's ALL_GATES order).
rep = mgtwin.GateReport();
gates = {@mgtwin.gateForming, @mgtwin.gateUnits, @mgtwin.gateGrounding, @mgtwin.gateProtection, ...
    @mgtwin.gateModelHonesty, @mgtwin.gateEnergisation, @mgtwin.gateLoading};
for k = 1:numel(gates)
    rep.extend(gates{k}(site));
end
end
