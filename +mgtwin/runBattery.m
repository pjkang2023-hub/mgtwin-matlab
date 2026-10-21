function rep = runBattery(opts)
%RUNBATTERY Run the whole scenario battery over a set of seeds.
%   rep = mgtwin.runBattery(seeds=0:9, protocol="single")
arguments
    opts.seeds (1,:) double = 0:9
    opts.protocol (1,1) string = "single"
end
rep = mgtwin.EvalReport();
scs = mgtwin.battery();
for k = 1:numel(scs)
    for seed = opts.seeds
        rep.add(mgtwin.runOne(scs(k), seed, opts.protocol));
    end
end
end
