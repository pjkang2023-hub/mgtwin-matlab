%% mgtwin tutorial: authoring and screening a microgrid digital twin
% Run this script section by section (Ctrl+Enter) from the examples folder.
% Each section builds on the previous one and prints what it found.
%
% The workflow is the pipeline of the package:
%
%   1. COMPOSE   describe the microgrid as a canonical Site
%   2. VERIFY    run the gates; read the findings; remediate; re-run
%   3. QUANTIFY  put numbers on a grounding finding with an SLG fault study
%   4. IDENTIFY  fit converter parameters from a measured step response,
%                and let the identifier refuse when it should
%   5. TEST      run the IEEE 2030.8-shaped suite on one island
%   6. IMPORT    compose a site from MATPOWER / Simulink data (Banshee)
%
addpath(fullfile(fileparts(mfilename("fullpath")), ".."));   % folder holding +mgtwin
import mgtwin.*
RULE = string(repmat('=', 1, 78));

%% 1. Compose: describe the microgrid
% Everything starts with a per-unit base. Nothing in mgtwin carries an
% implicit base; every impedance says which base it refers to.
base = Base(s_base_mva=10, v_base_kv=11, f_base_hz=50);
fprintf("Z_base = %.3f ohm, I_base = %.1f A\n", base.z_base_ohm, base.i_base_a);

% Buses. The utility bus is the point of interconnection (POI).
buses = [ ...
    Bus(id="BUS_UTIL", v_nom_kv=33, is_poi=true)
    Bus(id="BUS_MV",   v_nom_kv=11)
    Bus(id="BUS_LOAD", v_nom_kv=11)];

% The interconnection transformer. Winding configuration is a first-class
% fact here because it decides where zero-sequence current can flow. A
% grounded-wye on the utility side and a DELTA on the microgrid side is
% the most common arrangement -- and it means the microgrid has no
% zero-sequence source of its own.
tx = Transformer(id="TX1", hv_bus="BUS_UTIL", lv_bus="BUS_MV", s_rated_mva=15, ...
    hv_kv=33, lv_kv=11, x_pu=0.08, r_pu=0.006, ...
    hv_config=WindingConfig.WYE_GROUNDED, lv_config=WindingConfig.DELTA);

% A feeder. The pu impedance declares its base explicitly.
feeder = Branch(id="FDR1", from_bus="BUS_MV", to_bus="BUS_LOAD", ...
    r_pu=0.012, x_pu=0.028, s_base_mva=10, v_base_kv=11, rating_mva=12);

% Switches: the PCC breaker (islanding point) and a feeder breaker.
switches = [ ...
    Switch(id="SW_PCC", from_bus="BUS_UTIL", to_bus="BUS_MV", is_pcc=true)
    Switch(id="SW_MV",  from_bus="BUS_MV",   to_bus="BUS_LOAD")];

% Sources. A grid-forming BESS (droop control), a grid-following PV
% inverter, and a diesel genset. Converter parameters follow the WECC
% generic model shape. Note ride_through_identified=false: we have NOT
% measured how this inverter behaves in a fault; we are assuming it.
bess = Converter(id="BESS_1", bus="BUS_MV", s_rated_mva=5, ...
    control=ConverterControl.GFM_DROOP, ...
    params=ConverterParams(p_f_droop_pu=0.05, h_sec=2.0, tp_sec=0.20, ...
        i_limit_transient_pu=1.2, ride_through_identified=false), ...
    energy_mwh=10);
pv = Converter(id="PV_1", bus="BUS_LOAD", s_rated_mva=3, ...
    control=ConverterControl.GFL, ...
    params=ConverterParams(tp_sec=0.05, i_limit_transient_pu=1.2));
diesel = SynchronousGen(id="DG_1", bus="BUS_MV", s_rated_mva=2, h_sec=1.2, ...
    xd_subtransient_pu=0.18, droop_pu=0.04);

% Loads.
loads = [ ...
    Load(id="LD_CRIT", bus="BUS_LOAD", p_mw=2.5, q_mvar=0.8, critical=true)
    Load(id="LD_GEN",  bus="BUS_LOAD", p_mw=3.5, q_mvar=1.1)];

% Grounding is declared as an entity, not hidden in a transformer. This
% site's only ground reference is the utility substation neutral, which
% is upstream of the PCC: available_when_islanded=false.
grounding = GroundingSource(id="G_UTIL", bus="BUS_UTIL", kind=GroundingKind.SOLID, ...
    available_when_islanded=false, notes="Utility substation neutral, upstream of the PCC.");

% Protection: a phase overcurrent relay on the feeder breaker. Pickup is
% in primary amperes, exactly as set in the field. This one was set from
% the grid-connected fault study.
relay = OvercurrentRelay(id="R_MV", switch_id="SW_MV", ct_ratio=600, pickup_a=600, time_dial=0.3);

% Island configurations: every reachable operating state. Gates run per
% island, because a model that passes grid-connected and fails islanded
% is the finding you want before energization.
islands = [ ...
    IslandConfig(id="GRID",  description="Grid-connected", grid_connected=true, ...
        energized_source_ids=["BESS_1", "PV_1", "DG_1"])
    IslandConfig(id="ISL_1", description="Islanded, all sources", open_switches="SW_PCC", ...
        grid_connected=false, energized_source_ids=["BESS_1", "PV_1", "DG_1"])
    IslandConfig(id="ISL_2", description="Islanded, genset on outage", open_switches="SW_PCC", ...
        grid_connected=false, energized_source_ids=["BESS_1", "PV_1"])];

% Assemble. The Site constructor checks referential integrity: every bus,
% switch and source that is referenced must exist.
site = Site(id="TUTORIAL_MG", name="Tutorial microgrid", base=base, buses=buses, ...
    branches=feeder, transformers=tx, switches=switches, relays=relay, ...
    converters=[bess; pv], machines=diesel, loads=loads, grounding=grounding, islands=islands);
fprintf("composed %s: %d buses, %d sources, %d islands\n", site.id, numel(site.buses), ...
    numel(site.sourceIds()), numel(site.islands));

% Validation happens at construction. This is what a typo looks like:
try
    Converter(id="BAD", bus="BUS_MV", s_rated_mva=1, control=ConverterControl.GFM_DROOP, ...
        params=ConverterParams());          % grid-forming but no droop gain
catch err
    fprintf("rejected as expected: %s\n", err.message);
end

%% 2. Verify: run the gates
% A gate is a mechanical check that runs before anyone is allowed to
% believe the model. FAIL means a safety issue; WARN means an honesty or
% plausibility issue. Read the findings from the top down.
disp(RULE); disp("Gates on the site as first composed"); disp(RULE);
report = runAllGates(site);
disp(report.render());
fprintf("\nblocked: %d\n", report.failed());

% You can also run one gate, or filter findings.
g = gateGrounding(site);
fails = g.bySeverity(Severity.FAIL);
fprintf("\ngrounding gate alone: %d FAIL finding(s); first scope = %s\n", numel(fails), fails(1).scope);

%% 2b. Remediate and re-run
% Two findings above are structural, not cosmetic:
%   * every islanded 11 kV zone has no zero-sequence source (the DELTA
%     winding isolates the microgrid from the utility neutral);
%   * the 600 A relay pickup can never be reached by a 5 MVA converter
%     that is current-limited to 1.2 pu (~315 A).
% Fix both: add a zig-zag grounding transformer inside the microgrid and
% an islanded settings group for the relay. Site is a value class, so a
% copy is an independent scenario.
site2 = site;
site2.grounding(end+1) = GroundingSource(id="G_ZZ", bus="BUS_MV", kind=GroundingKind.LOW_RESISTANCE, ...
    z0_ohm=12, available_when_islanded=true, notes="12-ohm zig-zag added inside the microgrid");
site2.relays(1).pickup_a = 150;    % islanded settings group

disp(RULE); disp("Gates after remediation"); disp(RULE);
report2 = runAllGates(site2);
disp(report2.render());
fprintf("\nblocked: %d   warnings remain: %d\n", report2.failed(), report2.warned());
% The honesty warnings survive on purpose: no relay setting can be trusted
% until the converters' fault behaviour has been measured, not assumed.

%% 3. Quantify: what does an ungrounded island cost?
% The grounding gate says "no zero-sequence source". slgFault says what
% that means during a single-line-to-ground fault. Thevenin sequence
% impedances at the fault bus, on the site base: the diesel's Xd'' rebased
% from its own 2 MVA rating, plus the BESS treated as a stiff source.
z1 = 1i * 0.18 * (base.s_base_mva / diesel.s_rated_mva);
disp(RULE); disp("SLG fault on the islanded 11 kV bus"); disp(RULE);

r_ung = slgFault(z1, z0_pu=[]);                         % [] = no zero-sequence path
disp("as composed (ungrounded):"); disp(r_ung.render(i_base_a=base.i_base_a));

z0_zz = 3 * zigzagZ0Pu(12, 11, base.s_base_mva) + 1i * 0.10;
r_zz = slgFault(z1, z0_pu=z0_zz);
disp("with the 12-ohm zig-zag:"); disp(r_zz.render(i_base_a=base.i_base_a));
% Lesson: low-resistance grounding makes the fault DETECTABLE (hundreds of
% amperes for a 51G element) but does not relieve the overvoltage; a
% resistive Z0 against a reactive Z1 can push the unfaulted phase past
% sqrt(3). Insulation coordination is a separate decision.

%% 4. Identify: fit converter parameters from a measured step response
% The library model is a grid-forming converter feeding an islanded load:
%     omega, Pm = simulateGfm(t, p_load, rp_pu, tp_sec, h_sec)
% In practice you would load a PMU record of a load-step test. Here we
% manufacture one from a known "truth" so the answer can be checked.
RP_TRUE = 0.05; TP_TRUE = 0.20; H_TRUE = 2.0;
[t, p] = loadStep(t_end=8, dt=0.002, t_step=1, p_before=0.20, p_after=0.50);
truth = simulateGfm(t, p, RP_TRUE, TP_TRUE, H_TRUE);

idx = (1:10:numel(t))';                                % PMU at 50 samples/s
rs = RandStream("mt19937ar", "Seed", 7);
y_meas = truth(idx, 1) + 2e-4 * randn(rs, numel(idx), 1);   % omega_pu with noise

% A predictor maps a parameter struct to a prediction the size of y_meas.
predict = @(theta) tutorialPredict(t, p, idx, theta.rp_pu, theta.tp_sec, H_TRUE);

theta0 = struct("rp_pu", 0.03, "tp_sec", 0.40);          % starting guess
bounds = struct("rp_pu", [0.005 0.20], "tp_sec", [0.01 2.0]);

disp(RULE); disp("Identification, correct model form, PMU-rate data"); disp(RULE);
res = identify(predict, y_meas, theta0, bounds);
disp(res.render());
fprintf("truth: rp_pu=%g tp_sec=%g\n", RP_TRUE, TP_TRUE);

% The result carries the estimate AND the verdict. Only IDENTIFIED means
% the numbers can be used for a protection setting.
if res.verdict == Verdict.IDENTIFIED
    est = res.thetaStruct();
    fprintf("use rp_pu = %.4f, tp_sec = %.4f\n", est.rp_pu, est.tp_sec);
end

%% 4b. When the identifier must refuse
% Same fit, but the real plant has a ramp limiter the model does not.
% The intervals come back tight -- and wrong. Residual whiteness is
% tested first and overrides them.
truth_ramp = simulateGfm(t, p, RP_TRUE, TP_TRUE, H_TRUE, ramp_limit_pu_s=0.30);
rs = RandStream("mt19937ar", "Seed", 11);
y_ramp = truth_ramp(idx, 1) + 2e-4 * randn(rs, numel(idx), 1);

disp(RULE); disp("Identification, plant has an unmodelled ramp limit"); disp(RULE);
res_ramp = identify(predict, y_ramp, theta0, bounds);
disp(res_ramp.render());
fprintf("tp_sec estimate is %+.0f%% off, with a %.1f%% interval -- and the verdict says so\n", ...
    100 * (res_ramp.theta(2) - TP_TRUE) / TP_TRUE, 100 * res_ramp.rel_se(2));

%% 4c. The two-amplitude protocol
% Some mismatches (governor deadband, output clamps, piecewise droop) are
% invisible on a single trajectory: they look like a different parameter
% value with white residuals. The cure is a second experiment at a
% different amplitude and a consistency demand. identifyMulti does that.
sc = scenarioByName("deadband");            % a truth plant with a +/-0.2 Hz deadband
exps = {evalExperiment(sc, 0, [0.20 0.60]), evalExperiment(sc, 1000, [0.20 0.35])};

disp(RULE); disp("Single step vs two amplitudes on a plant with a deadband"); disp(RULE);
single = identify(exps{1}{1}, exps{1}{2}, theta0, bounds);
fprintf("single experiment : %s  (rp_pu = %.4f, truth 0.05)\n", single.verdict.Value, single.theta(1));
multi = identifyMulti(exps, theta0, bounds);
disp(multi.render());
% Product rule that follows: a commissioning test needs load steps at two
% amplitudes minimum. One clean load-rejection trace is not evidence.

%% 5. Test: run the controller test suite on an island
% Test definitions are versioned data (IEEE 2030.8-2018 shape). The runner
% executes what the RMS tier can answer, BLOCKS cases whose prerequisites
% failed a gate, and DEFERS cases that need EMT or missing models.
suite = loadSuite("ieee2030_8_2018");
fprintf("suite edition %s: %d cases\n", suite.edition, numel(suite.cases));

% Limits are never invented. Supply the ones your interconnection
% agreement or project spec defines, keyed "<case_id>/<metric>".
limits = dictionary( ...
    ["ISL-P-01/frequency_nadir_deviation", "ISL-U-01/frequency_nadir_deviation", ...
     "ISL-U-01/rocof_peak", "SS-01/steady_state_frequency_band"], ...
    [0.5, 2.0, 3.0, 2.5]);

disp(RULE); disp("Test run on ISL_1, site as composed"); disp(RULE);
run1 = runSuite(site, suite, "ISL_1", project_limits=limits);
disp(run1.render());
% PROT-01 is BLOCKED: the grounding gate already answered it.

disp(RULE); disp("PROT-01 on the remediated site"); disp(RULE);
run2 = runSuite(site2, suite, "ISL_1", project_limits=limits);
disp(run2.byCaseId("PROT-01").render());
% It executes as a screening but stays INDETERMINATE: no project limit was
% supplied for those criteria, and the case itself demands EMT.

c = run1.counts();
fprintf("\nsummary: %d executed, %d blocked, %d deferred\n", c.executed, c.blocked, c.deferred);

%% 6. Import: composing a site from benchmark data
% For a real network you compose from machine-readable sources instead of
% typing entities. composeBanshee reads a MATPOWER case (buses, branches,
% loads), relay-setting spreadsheets, and winding configurations out of a
% Simulink .mdl -- and records what those sources CANNOT provide.
P = banshee_paths();
if P.available
    if isfile(P.MDL), mdl = P.MDL; else, mdl = string.empty; end
    banshee = composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=mdl);
    fprintf("Banshee: %d buses, %d branches, %d transformers, %d relays, %d islands\n", ...
        numel(banshee.buses), numel(banshee.branches), numel(banshee.transformers), ...
        numel(banshee.relays), numel(banshee.islands));
    rep = runAllGates(banshee);
    gf = rep.bySeverity(Severity.FAIL);
    fprintf("gate FAILs: %d (%s)\n", numel(gf), strjoin(unique(string({gf.gate})), ", "));
    for k = 1:numel(gf)
        if gf(k).gate == "grounding", fprintf("  %s\n", gf(k).scope); end
    end
    % Then: mgtwin.runSuite(banshee, suite, "ISL_F1", project_limits=...) as in section 5,
    % or examples/banshee_rung1 / banshee_rung3 for the full walkthroughs.
else
    disp("Banshee data pack not found; see examples/banshee_paths.m for where to put it.");
end

%% Where to go next
%   examples/demo.m                        gates + four identification verdicts
%   examples/ieee4_rung2.m                 unbalanced solver verified vs IEEE 4-node
%   examples/banshee_slg.m                 the grounding design triangle
%   examples/rung4_identifiability_evals.m the adversarial identification battery
%   tests/MgtwinTest.m                     every behaviour above, pinned as a test
disp("tutorial complete");

%% ------------------------------------------------------------------------
function yhat = tutorialPredict(t, p, idx, rp_pu, tp_sec, h_sec)
% Library-form predictor: simulate, then sample where the PMU sampled.
out = mgtwin.simulateGfm(t, p, rp_pu, tp_sec, h_sec);
yhat = out(idx, 1);
end
