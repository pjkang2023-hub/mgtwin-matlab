function sc = scenarioByName(name)
%SCENARIOBYNAME Look up one battery scenario by name.
scs = mgtwin.battery();
for k = 1:numel(scs)
    if scs(k).name == string(name), sc = scs(k); return; end
end
error("mgtwin:KeyError", "no scenario named '%s'", string(name));
end
