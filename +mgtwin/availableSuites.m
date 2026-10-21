function names = availableSuites()
%AVAILABLESUITES Names of the test suites shipped in +mgtwin/specs.
d = dir(fullfile(mgtwin.internal.specDir(), "*.json"));
names = sort(string(erase({d.name}, ".json")));
end
