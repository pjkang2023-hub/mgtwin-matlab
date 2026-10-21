function e = enumFromValue(className, value)
%ENUMFROMVALUE Look up an enumeration member by its string Value.
%   e = enumFromValue("mgtwin.CoreFunction", "dispatch")
members = enumeration(className);
for k = 1:numel(members)
    if members(k).Value == string(value)
        e = members(k);
        return;
    end
end
error("mgtwin:ValueError", "%s has no member with value '%s'", className, string(value));
end
