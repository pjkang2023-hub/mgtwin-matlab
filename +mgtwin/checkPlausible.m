function msg = checkPlausible(name, value)
%CHECKPLAUSIBLE Return a message if VALUE falls outside its plausible band,
%   else an empty string "".
r = mgtwin.plausibleRanges();
msg = "";
if ~isfield(r, name)
    return;
end
band = r.(name);
lo = band(1); hi = band(2);
if ~(lo <= value && value <= hi)
    msg = sprintf("%s=%g is outside the plausible range [%g, %g]. " + ...
        "This usually indicates a unit error rather than an unusual design.", ...
        name, value, lo, hi);
end
end
