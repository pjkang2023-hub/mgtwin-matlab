function report = runSuite(site, suite, island_id, opts)
%RUNSUITE Execute a TestSuite against a composed Site and one island
%   configuration, producing a RunReport whose honesty rules live in
%   TestResult / RunReport.
%
%   report = mgtwin.runSuite(site, suite, island_id, project_limits=d, f_nom=60)
%
%   project_limits : dictionary keyed "<case_id>/<metric>" -> limit. The
%                    caller supplies what the interconnection agreement /
%                    project spec defines. Anything not supplied stays
%                    UNEVALUATED. The runner never invents a limit.
%
%   Model tier -- this runner operates at the RMS tier with a single
%   aggregate grid-forming source (the GFM droop model in simulateGfm, which
%   also represents a droop-governed genset at this timescale):
%
%     STEADY_STATE, PLANNED_ISLANDING, UNPLANNED_ISLANDING -> executed
%     PROTECTION   -> executed as a SCREENING (sequence SLG + pickup ratios),
%                     then still marked for EMT confirmation because the
%                     case itself declares requires_emt
%     BLACK_START, POWER_QUALITY -> deferred (EMT tier)
%     DISPATCH, RECONNECTION     -> deferred (EMS / synchroniser models absent)
%
%   Prerequisite gating -- before executing anything, the site gates run
%   once. Findings scoped to the target island BLOCK the cases they
%   invalidate: an ungrounded zone blocks the protection case outright, and
%   blocks nothing else at RMS tier since positive-sequence dynamics do not
%   see grounding. Units-gate failures block everything.
arguments
    site (1,1) mgtwin.Site
    suite (1,1) mgtwin.TestSuite
    island_id (1,1) string
    opts.project_limits = dictionary(string.empty, double.empty)
    opts.f_nom double = []
end
import mgtwin.CoreFunction mgtwin.CaseStatus

limits = opts.project_limits;
if isempty(opts.f_nom), f_nom = site.base.f_base_hz; else, f_nom = opts.f_nom; end
isl = site.island(island_id);

RMS_EXECUTABLE = [CoreFunction.STEADY_STATE, CoreFunction.PLANNED_ISLANDING, ...
                  CoreFunction.UNPLANNED_ISLANDING, CoreFunction.PROTECTION];
DEFER_REASONS = dictionary( ...
    [CoreFunction.BLACK_START, CoreFunction.POWER_QUALITY, CoreFunction.DISPATCH, CoreFunction.RECONNECTION], ...
    ["transformer inrush against a current limit is an EMT question; RMS averaging removes the phenomenon being tested", ...
     "THD/unbalance/flicker are waveform quantities; EMT tier required", ...
     "no EMS model in this harness yet", ...
     "no synchroniser model in this harness yet"]);

gate_rep = mgtwin.runAllGates(site);
fails = gate_rep.bySeverity(mgtwin.Severity.FAIL);
unit_fails = mgtwin.Finding.empty(0,1);
island_grounding_fails = mgtwin.Finding.empty(0,1);
for k = 1:numel(fails)
    f = fails(k);
    if f.gate == "units"
        unit_fails(end+1, 1) = f; %#ok<AGROW>
    elseif f.gate == "grounding" && startsWith(f.scope, island_id + "/")
        island_grounding_fails(end+1, 1) = f; %#ok<AGROW>
    end
end

report = mgtwin.RunReport(suite.edition, site.id);
src = mgtwin.internal.aggregateSource(site, isl);

for k = 1:numel(suite.cases)
    tc = suite.cases(k);
    r = mgtwin.TestResult(tc, island_id, CaseStatus.EXECUTED);
    r.provenance = src.provenance;
    r.provenance_detail = src.detail;

    if ~isempty(unit_fails)
        r.status = CaseStatus.BLOCKED;
        r.blocking_findings = unit_fails;
        report.add(r);
        continue;
    end

    if ~ismember(tc.core_function, RMS_EXECUTABLE)
        r.status = CaseStatus.DEFERRED;
        r.defer_reason = DEFER_REASONS(tc.core_function);
        report.add(r);
        continue;
    end

    if tc.core_function == CoreFunction.PROTECTION && ~isempty(island_grounding_fails)
        r.status = CaseStatus.BLOCKED;
        r.blocking_findings = island_grounding_fails;
        r.notes(end+1) = "the gate already answers this case for an ungrounded zone: " + ...
            "SLG fault current ~0 (undetectable) and sqrt(3) overvoltage; " + ...
            "remediate grounding before a coordination study is meaningful";
        report.add(r);
        continue;
    end

    switch tc.core_function
        case CoreFunction.STEADY_STATE
            [m, c, n] = runSteadyState(site, isl, src, tc, limits, f_nom);
        case CoreFunction.PLANNED_ISLANDING
            [m, c, n] = runIslanding(site, isl, src, tc, limits, f_nom, true);
        case CoreFunction.UNPLANNED_ISLANDING
            [m, c, n] = runIslanding(site, isl, src, tc, limits, f_nom, false);
        otherwise  % PROTECTION, grounded path
            [m, c, n] = runProtectionScreening(site, isl, src, tc, limits);
            r.notes(end+1) = "EMT confirmation still required per the case definition";
    end

    r.metrics = m;
    r.criteria = c;
    r.notes = [r.notes, n];
    r.verdict = mgtwin.judge(c);
    report.add(r);
end
end

% =========================================================================
% Executors (RMS tier)
% =========================================================================

function [nadir_dev, rocof] = freqMetrics(t, f_hz, f_nom)
nadir_dev = max(abs(f_hz - f_nom));
% ROCOF over a 100 ms sliding window
dt = t(2) - t(1);
w = max(1, round(0.1 / dt));
df = (f_hz(w+1:end) - f_hz(1:end-w)) / (w * dt);
rocof = max(abs(df));
end

function [t, f] = runStep(src, p0, p1, f_nom)
t = (0:0.002:12 - 0.002)';
p = p1 * ones(size(t));
p(t < 1.0) = p0;
y = mgtwin.simulateGfm(t, p, src.rp_pu, src.tp_sec, src.h_sec, p_ref=p0);
f = y(:, 1) * f_nom;
end

function crits = judgeCriteria(tc, measured, limits)
crits = mgtwin.CriterionResult.empty(1,0);
for j = 1:numel(tc.criteria)
    c = tc.criteria(j);
    key = tc.id + "/" + c.metric;
    if isKey(limits, key)
        c.limit = limits(key);
    end
    if isfield(measured, c.metric)
        val = measured.(c.metric);
    else
        val = [];
    end
    crits(end+1) = mgtwin.evaluateCriterion(c, val); %#ok<AGROW>
end
end

function [metrics, crits, notes] = runSteadyState(site, isl, src, tc, limits, f_nom)
p_max = mgtwin.internal.islandLoadMw(site, isl) / src.s_mva;
p_min = 0.2 * p_max;
% Droop-only means ONE fixed reference across the load range; moving the
% reference with the operating point is secondary control by accident and
% reports a zero band. The band is the droop characteristic itself:
% f(p_min) - f(p_max) = rp * (p_max - p_min) * f_nom.
t = (0:0.002:12 - 0.002)';
f_lo = mgtwin.simulateGfm(t, p_min * ones(size(t)), src.rp_pu, src.tp_sec, src.h_sec, p_ref=p_min);
f_hi = mgtwin.simulateGfm(t, p_max * ones(size(t)), src.rp_pu, src.tp_sec, src.h_sec, p_ref=p_min);
band = abs(f_lo(end, 1) * f_nom - f_hi(end, 1) * f_nom);
metrics = [ ...
    mgtwin.MetricValue("island_peak_load", p_max * src.s_mva, "MW"), ...
    mgtwin.MetricValue("source_loading_at_peak", 100 * p_max, "%", "of aggregate GFM rating"), ...
    mgtwin.MetricValue("steady_state_frequency_band", band, "hz", ...
        sprintf("droop-only, load %.2f..%.2f pu", p_min, p_max))];
measured = struct("steady_state_frequency_band", band);
crits = judgeCriteria(tc, measured, limits);
notes = "reactive sharing not assessed: single aggregate source at this tier";
end

function [metrics, crits, notes] = runIslanding(site, isl, src, tc, limits, f_nom, planned)
p_island = mgtwin.internal.islandLoadMw(site, isl) / src.s_mva;
if planned, p0 = 0.9 * p_island; else, p0 = 0.10; end
[t, f] = runStep(src, p0, p_island, f_nom);
[nadir, rocof] = freqMetrics(t, f, f_nom);
metrics = [ ...
    mgtwin.MetricValue("pre_island_source_output", p0, "pu", "of GFM rating"), ...
    mgtwin.MetricValue("post_island_load", p_island, "pu"), ...
    mgtwin.MetricValue("frequency_nadir_deviation", nadir, "hz"), ...
    mgtwin.MetricValue("rocof_peak", rocof, "hz_s", "100 ms window")];
measured = struct( ...
    "frequency_nadir_deviation", nadir, ...
    "rocof_peak", rocof, ...
    "critical_load_interrupted", 0.0, ...   % no shed scheme modelled
    "voltage_excursion", []);               % not observable in this frequency model
crits = judgeCriteria(tc, measured, limits);
notes = string.empty(1,0);
if ~planned
    notes(end+1) = "no load-shed scheme modelled: the full island load lands on the " + ...
        "GFM source instantly, which is the declared worst case";
    if p_island > 1.0
        notes(end+1) = sprintf("island load exceeds aggregate GFM rating (%.2f pu): " + ...
            "steady state is not sustainable regardless of the transient", p_island);
    end
end
end

function [metrics, crits, notes] = runProtectionScreening(site, ~, src, tc, limits)
% Sequence-SLG screening. Only reached when the island's zones are grounded
% (otherwise the case is BLOCKED with the gate finding).
z1 = 1i * 0.15 * (site.base.s_base_mva / src.s_mva);   % subtransient, assumed
g = site.grounding([site.grounding.available_when_islanded]);
z0 = [];
if ~isempty(g)
    z0 = 3.0 * g(1).z0_ohm / site.base.z_base_ohm + 1i * 0.10;
end
res = mgtwin.slgFault(z1, z0_pu=z0);
i_a = abs(res.i_fault_pu) * site.base.i_base_a;
metrics = [ ...
    mgtwin.MetricValue("slg_fault_current", i_a, "A"), ...
    mgtwin.MetricValue("unfaulted_phase_overvoltage", res.v_max_unfaulted_pu, "pu")];
measured = struct( ...
    "unfaulted_phase_overvoltage", res.v_max_unfaulted_pu, ...
    "primary_clearing_time", []);   % needs coordination study
crits = judgeCriteria(tc, measured, limits);
notes = "SCREENING TIER ONLY: sequence-network SLG with assumed subtransient " + ...
    "reactance; the case itself declares requires_emt, so this result is " + ...
    "a screen, not a coordination study";
end
