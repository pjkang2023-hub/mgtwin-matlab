function banshee_rung3()
%BANSHEE_RUNG3 Eval rung 3: run the controller test suite against
%   Banshee's diesel island (needs BANSHEE_DATA with BANSHEE.mdl).
%
%   Demonstrates the runner's full honesty taxonomy on one island:
%     EXECUTED / PASS           -- planned islanding, steady state
%     EXECUTED / FAIL           -- unplanned islanding at full import
%     EXECUTED / INDETERMINATE  -- protection screening after remediation
%     BLOCKED                   -- protection before remediation
%     DEFERRED                  -- dispatch, reconnection, black start, PQ
%
%   The project limits below are EXAMPLES, clearly labelled: they stand in
%   for the interconnection agreement. The runner never invents one.
addpath(fullfile(fileparts(mfilename("fullpath")), ".."));
RULE = string(repmat('=', 1, 78));
P = banshee_paths();
if ~P.available
    error("mgtwin:FileNotFound", "Banshee release not found at %s (set BANSHEE_DATA)", P.DATA);
end
if isfile(P.MDL), mdl = P.MDL; else, mdl = string.empty; end
site = mgtwin.composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=mdl);
suite = mgtwin.loadSuite("ieee2030_8_2018");
limits = banshee_example_limits();

disp(RULE);
disp("RUNG 3a  Suite vs ISL_F1 as released");
disp(RULE);
fprintf("(project limits are EXAMPLES standing in for the interconnection agreement)\n\n");
rep = mgtwin.runSuite(site, suite, "ISL_F1", project_limits=limits);
disp(rep.render());

fprintf("\n%s\n", RULE);
disp("RUNG 3b  Same island after grounding remediation (12-ohm zig-zag)");
disp(RULE);
site2 = site;   % value class: an independent copy
site2.grounding(end+1, 1) = mgtwin.GroundingSource(id="G_ZZ_F1", bus="B2", ...
    kind=mgtwin.GroundingKind.LOW_RESISTANCE, z0_ohm=12.0, available_when_islanded=true, ...
    notes="remediation from the rung-2 SLG study");
rep2 = mgtwin.runSuite(site2, suite, "ISL_F1", project_limits=limits);
disp(rep2.byCaseId("PROT-01").render());

fprintf("\n%s\n", RULE);
disp("READING THE RESULT");
disp(RULE);
disp("The report is the deliverable, and its shape is the point:" + newline + ...
    "  * The unplanned-islanding FAIL is real engineering output -- a" + newline + ...
    "    droop-only diesel cannot absorb a 0.86 pu step inside a 2 Hz" + newline + ...
    "    nadir. The fix is a load-shed scheme or storage, and the harness" + newline + ...
    "    will re-judge the same case when the model contains one." + newline + ...
    "  * PROT-01 is BLOCKED as released and becomes an INDETERMINATE" + newline + ...
    "    screening after the zig-zag is added -- with the 1.88 pu" + newline + ...
    "    overvoltage from rung 2 reappearing in the metrics, because the" + newline + ...
    "    machinery is the same. Note it never becomes PASS here: the" + newline + ...
    "    limits belong to the project, and the case demands EMT." + newline + ...
    "  * Every PASS on assumed parameters carries its condition. The" + newline + ...
    "    identification pipeline (rung 4) is what discharges it.");
end
