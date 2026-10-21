function rep = gateModelHonesty(site)
%GATEMODELHONESTY Gate 4: refuse to let an assumed converter model support a
%   protection conclusion.
%
%   The public WECC generic GFM specification documents that steady-state
%   current limiting and advanced voltage ride-through are not represented.
%   If a converter's ride-through was assumed rather than identified from
%   measured response, every fault-current number downstream is a
%   placeholder, and the report must say so.
import mgtwin.Finding mgtwin.Severity
rep = mgtwin.GateReport();

for k = 1:numel(site.converters)
    c = site.converters(k);
    if ~c.params.ride_through_identified
        rep.add(Finding("honesty", Severity.WARN, ...
            "current-limit / ride-through behaviour was assumed, not identified from " + ...
            "measured response; fault-current results are provisional", c.id, ...
            "Identify from a measured step or fault response, or state the assumption " + ...
            "explicitly in the validity envelope."));
    end
    if isempty(c.params.i_limit_steady_pu)
        rep.add(Finding("honesty", Severity.WARN, ...
            "no steady-state current limit declared; sustained-fault behaviour is " + ...
            "unmodelled (a known gap in the public generics)", c.id));
    end
    if strlength(c.firmware) == 0
        rep.add(Finding("honesty", Severity.WARN, ...
            "no firmware version recorded; ride-through behaviour is firmware-bound " + ...
            "and a vendor update silently invalidates this model", c.id, ...
            "Record firmware at identification time and re-identify after any update."));
    end
end
end
