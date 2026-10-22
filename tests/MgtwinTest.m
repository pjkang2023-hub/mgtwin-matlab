classdef MgtwinTest < matlab.unittest.TestCase
    %MGTWINTEST Regression tests for the mgtwin MATLAB package.
    %
    %   The tests that matter here are the ones asserting that a gate FAILS.
    %   A harness whose gates quietly stop firing is worse than no harness,
    %   because the report still looks clean. So the negative cases are
    %   tested at least as carefully as the positive ones.
    %
    %   Run with:  runtests("tests/MgtwinTest.m")
    %   Banshee-dependent tests are skipped unless BANSHEE_DATA points at the
    %   extracted EPHCC release.

    properties (Constant)
        RP = 0.05
        TP = 0.20
        H = 2.0
    end

    methods (TestClassSetup)
        function setupPath(tc)
            root = fileparts(fileparts(mfilename("fullpath")));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, "examples")));
        end
    end

    % ---------------------------------------------------------------------
    % Helpers
    % ---------------------------------------------------------------------
    methods (Static)
        function s = revcExample()
            % CAMPAIGN-003 Rev C, as Python's mgtwin writes it (examples/).
            root = fileparts(fileparts(mfilename("fullpath")));
            s = mgtwin.siteFromJson(fullfile(root, "examples", "c003_revC_site.json"));
        end

        function fs = scoped(rep, prefix)
            % findings whose scope starts with PREFIX
            if isempty(rep.findings), fs = rep.findings; return; end
            fs = rep.findings(startsWith(string({rep.findings.scope}), prefix));
        end

        function w = worstByIsland(rep)
            % island id -> worst severity among its findings
            w = dictionary(string.empty, string.empty);
            rank = dictionary(["pass", "warn", "fail"], [0, 1, 2]);
            for k = 1:numel(rep.findings)
                f = rep.findings(k);
                isl = extractBefore(f.scope + "/", "/");
                if ~isKey(w, isl) || rank(f.severity.Value) >= rank(w(isl))
                    w(isl) = f.severity.Value;
                end
            end
        end

        function s = revcRebased()
            % Rev C with every transformer reactance on its own rating (the units gate clears).
            s = MgtwinTest.revcExample();
            for k = 1:numel(s.transformers), s.transformers(k).x_pu = 0.06; end
        end

        function s = twoBessSite(functions, pickup_a, state_group, opts)
            % Two 5 MVA grid-forming BESS on B1 and B2, tied by breaker SW; its relay carries FUNCTIONS.
            % GENSET puts a 1 MVA machine (x'' 0.15: 6.7x its rated current into a fault) on B2 beside
            % BESS2; EARTHED a low-resistance earthing source on each bus.
            arguments
                functions (1,:) mgtwin.ProtectionFunction = mgtwin.ProtectionFunction.empty(1,0)
                pickup_a double = []
                state_group (1,1) string = "A"
                opts.genset (1,1) logical = false
                opts.earthed (1,1) logical = false
            end
            bess = @(i, b) mgtwin.Converter(id=i, bus=b, s_rated_mva=5.0, control=mgtwin.ConverterControl.GFM_DROOP, ...
                params=mgtwin.ConverterParams(p_f_droop_pu=0.05, i_limit_transient_pu=1.2));
            args = {"id", "T", "base", mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0), ...
                "buses", [mgtwin.Bus(id="B1", v_nom_kv=11.0); mgtwin.Bus(id="B2", v_nom_kv=11.0)], ...
                "converters", [bess("BESS1", "B1"); bess("BESS2", "B2")], ...
                "switches", mgtwin.Switch(id="SW", from_bus="B1", to_bus="B2"), ...
                "relays", mgtwin.OvercurrentRelay(id="R", switch_id="SW", ct_ratio=600.0, pickup_a=pickup_a, functions=functions)};
            energized = ["BESS1", "BESS2"];
            if opts.genset
                args = [args, {"machines", mgtwin.SynchronousGen(id="GEN", bus="B2", s_rated_mva=1.0, h_sec=1.0, xd_subtransient_pu=0.15)}];
                energized(end+1) = "GEN";
            end
            if opts.earthed
                args = [args, {"grounding", [ ...
                    mgtwin.GroundingSource(id="GB1", bus="B1", kind=mgtwin.GroundingKind.LOW_RESISTANCE, z0_ohm=20.0, available_when_islanded=true); ...
                    mgtwin.GroundingSource(id="GB2", bus="B2", kind=mgtwin.GroundingKind.LOW_RESISTANCE, z0_ohm=20.0, available_when_islanded=true)]}];
            end
            args = [args, {"islands", mgtwin.IslandConfig(id="I1", grid_connected=false, settings_group=state_group, ...
                energized_source_ids=energized)}];
            s = mgtwin.Site(args{:});
        end

        function rules = revcRules()
            rules = [ ...
                mgtwin.TagRule(pattern="^(?P<id>PCS\d+)\.(?P<meas>\w+)$", kind="converter", ...
                    meas_map=dictionary(["P_MW", "Q_MVAR", "F", "SOC"], ["P", "Q", "F", "SOC"])), ...
                mgtwin.TagRule(pattern="^(?P<id>SOFC\d\d)_(?P<meas>KW|KVAR|HZ)$", kind="converter", ...
                    meas_map=dictionary(["KW", "KVAR", "HZ"], ["P", "Q", "F"])), ...
                mgtwin.TagRule(pattern="^(?P<id>CB_\w+)\.POS$", kind="switch", measurement="POS"), ...
                mgtwin.TagRule(pattern="^GEN\.(?P<meas>\w+)$", kind="machine", ...
                    meas_map=dictionary(["P", "F"], ["P", "F"]), id_template="GEN_BS"), ...
                mgtwin.TagRule(pattern="^(?P<id>PCS1)\.P_MW$", kind="converter", measurement="Q")];   % deliberately conflicting
        end

        function st = statusOf(rep, tag)
            % statuses of every result for TAG, in order
            rs = rep.results(arrayfun(@(r) r.tag.tag == tag, rep.results));
            st = [rs.status];
        end

        function verifyThrows(tc, f, needle)
            try
                f();
                tc.verifyFail("expected an error containing: " + needle);
            catch err
                tc.verifySubstring(err.message, needle);
            end
        end

        function s = minimalSite(varargin)
            s = mgtwin.Site("id", "T", "base", mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0), ...
                "buses", mgtwin.Bus(id="B1", v_nom_kv=11.0), varargin{:});
        end

        function s = converterOnlySite(pickup_a)
            s = MgtwinTest.minimalSite( ...
                "converters", mgtwin.Converter(id="BESS", bus="B1", s_rated_mva=5.0, ...
                    control=mgtwin.ConverterControl.GFM_DROOP, ...
                    params=mgtwin.ConverterParams(p_f_droop_pu=0.05, i_limit_transient_pu=1.2)), ...
                "switches", mgtwin.Switch(id="SW", from_bus="B1", to_bus="B1"), ...
                "relays", mgtwin.OvercurrentRelay(id="R", switch_id="SW", ct_ratio=600.0, pickup_a=pickup_a, time_dial=0.3), ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false, energized_source_ids="BESS"));
        end

        function res = fit(dt_meas, sigma, t_end, ramp_limit, theta0, bounds, fixed, seed)
            if nargin < 8, seed = 7; end
            [t, p] = mgtwin.loadStep(t_end=t_end, dt=0.002);
            truth = mgtwin.simulateGfm(t, p, MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H, ramp_limit_pu_s=ramp_limit);
            idx = (1:round(dt_meas / 0.002):numel(t))';
            rs = RandStream("mt19937ar", "Seed", seed);
            y = truth(idx, 1) + sigma * randn(rs, numel(idx), 1);
            predict = @(theta) MgtwinTest.predictGfm(t, p, idx, theta, fixed);
            res = mgtwin.identify(predict, y, theta0, bounds);
        end

        function yhat = predictGfm(t, p, idx, theta, fixed)
            get = @(nm) MgtwinTest.getParam(theta, fixed, nm);
            out = mgtwin.simulateGfm(t, p, get("rp_pu"), get("tp_sec"), get("h_sec"));
            yhat = out(idx, 1);
        end

        function v = getParam(theta, fixed, nm)
            if isfield(theta, nm), v = theta.(nm); else, v = fixed.(nm); end
        end

        function tf = anyMessageContains(findings, needle)
            tf = false;
            for k = 1:numel(findings)
                if contains(findings(k).message, needle), tf = true; return; end
            end
        end

        function [site, suite, limits] = rung3Fixture()
            P = banshee_paths();
            site = mgtwin.composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=P.MDL);
            suite = mgtwin.loadSuite("ieee2030_8_2018");
            limits = banshee_example_limits();
        end
    end

    methods
        function assumeBanshee(tc)
            P = banshee_paths();
            tc.assumeTrue(P.available, "Banshee EPHCC release not present (set BANSHEE_DATA)");
        end
    end

    methods (Test)
        % -----------------------------------------------------------------
        % Units
        % -----------------------------------------------------------------
        function test_per_unit_base_arithmetic(tc)
            b = mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0, f_base_hz=50.0);
            tc.verifyEqual(b.z_base_ohm, 121.0 / 10.0, "RelTol", 1e-12);
            tc.verifyEqual(b.i_base_a, 10e6 / (sqrt(3) * 11e3), "RelTol", 1e-9);
            tc.verifyEqual(b.puCurrent(b.amps(1.37)), 1.37, "RelTol", 1e-12);
            tc.verifyEqual(b.puImpedance(b.ohms(0.08)), 0.08, "RelTol", 1e-12);
        end

        function test_rebase_impedance(tc)
            old = mgtwin.Base(s_base_mva=100.0, v_base_kv=11.0);
            new = mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0);
            tc.verifyEqual(new.rebaseImpedance(0.50, old), 0.05, "RelTol", 1e-12);
        end

        function test_invalid_base_rejected(tc)
            tc.verifyError(@() mgtwin.Base(s_base_mva=-1.0, v_base_kv=11.0), "mgtwin:ValueError");
            tc.verifyError(@() mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0, f_base_hz=45.0), "mgtwin:ValueError");
        end

        % -----------------------------------------------------------------
        % Ontology integrity
        % -----------------------------------------------------------------
        function test_dangling_bus_reference_rejected(tc)
            f = @() MgtwinTest.minimalSite("converters", mgtwin.Converter(id="C1", bus="NOPE", ...
                s_rated_mva=1.0, control=mgtwin.ConverterControl.GFL, params=mgtwin.ConverterParams()));
            tc.verifyError(f, "mgtwin:ValidationError");
            try, f(); catch e, tc.verifySubstring(e.message, "unknown bus"); end
        end

        function test_gfm_without_droop_rejected(tc)
            f = @() mgtwin.Converter(id="C1", bus="B1", s_rated_mva=1.0, ...
                control=mgtwin.ConverterControl.GFM_DROOP, params=mgtwin.ConverterParams());
            tc.verifyError(f, "mgtwin:ValidationError");
            try, f(); catch e, tc.verifySubstring(e.message, "no P-f droop"); end
        end

        function test_vsm_without_inertia_rejected(tc)
            f = @() mgtwin.Converter(id="C1", bus="B1", s_rated_mva=1.0, ...
                control=mgtwin.ConverterControl.GFM_VSM, params=mgtwin.ConverterParams(p_f_droop_pu=0.05));
            tc.verifyError(f, "mgtwin:ValidationError");
            try, f(); catch e, tc.verifySubstring(e.message, "no inertia"); end
        end

        function test_solid_grounding_with_large_impedance_rejected(tc)
            f = @() mgtwin.GroundingSource(id="G", bus="B1", kind=mgtwin.GroundingKind.SOLID, ...
                z0_ohm=25.0, available_when_islanded=true);
            tc.verifyError(f, "mgtwin:ValidationError");
            try, f(); catch e, tc.verifySubstring(e.message, "solid grounding"); end
        end

        function test_steady_limit_above_transient_rejected(tc)
            f = @() mgtwin.ConverterParams(i_limit_transient_pu=1.2, i_limit_steady_pu=1.5);
            tc.verifyError(f, "mgtwin:ValidationError");
            try, f(); catch e, tc.verifySubstring(e.message, "steady-state current limit"); end
        end

        function test_missing_required_argument_rejected(tc)
            tc.verifyError(@() mgtwin.Bus(id="B1"), "mgtwin:ValidationError");
        end

        % -----------------------------------------------------------------
        % Gates
        % -----------------------------------------------------------------
        function test_units_gate_catches_ohms_in_a_pu_field(tc)
            % A 12.1 ohm feeder entered as 12.1 pu must not pass.
            site = MgtwinTest.minimalSite( ...
                "buses", [mgtwin.Bus(id="B1", v_nom_kv=11.0); mgtwin.Bus(id="B2", v_nom_kv=11.0)], ...
                "branches", mgtwin.Branch(id="F1", from_bus="B1", to_bus="B2", r_pu=0.01, x_pu=12.1, ...
                    s_base_mva=10.0, v_base_kv=11.0, rating_mva=10.0));
            rep = mgtwin.gateUnits(site);
            tc.verifyTrue(rep.failed());
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.FAIL), "plausible range"));
        end

        function test_units_gate_catches_transformer_ratio_mismatch(tc)
            site = MgtwinTest.minimalSite( ...
                "buses", [mgtwin.Bus(id="HV", v_nom_kv=33.0); mgtwin.Bus(id="LV", v_nom_kv=11.0)], ...
                "transformers", mgtwin.Transformer(id="TX", hv_bus="HV", lv_bus="LV", s_rated_mva=15.0, ...
                    hv_kv=33.0, lv_kv=6.6, x_pu=0.08, ...   % wrong: bus is 11 kV
                    hv_config=mgtwin.WindingConfig.WYE_GROUNDED, lv_config=mgtwin.WindingConfig.DELTA));
            tc.verifyTrue(mgtwin.gateUnits(site).failed());
        end

        function test_grounding_fails_when_reference_is_outside_the_microgrid(tc)
            site = MgtwinTest.minimalSite( ...
                "converters", mgtwin.Converter(id="C1", bus="B1", s_rated_mva=1.0, ...
                    control=mgtwin.ConverterControl.GFM_DROOP, params=mgtwin.ConverterParams(p_f_droop_pu=0.05)), ...
                "grounding", mgtwin.GroundingSource(id="G", bus="B1", kind=mgtwin.GroundingKind.SOLID, ...
                    available_when_islanded=false), ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false, energized_source_ids="C1"));
            rep = mgtwin.gateGrounding(site);
            tc.verifyTrue(rep.failed());
            fail = rep.bySeverity(mgtwin.Severity.FAIL);
            tc.verifySubstring(fail(1).message, "zero-sequence");
            tc.verifyTrue(startsWith(fail(1).scope, "I1/zone"));
        end

        function test_grounding_zones_split_by_delta_winding(tc)
            % The Banshee lesson as a unit test: a DYg transformer grounds its
            % LV zone and nothing else. The MV zone with the source must FAIL
            % even though the LV zone passes.
            site = MgtwinTest.minimalSite( ...
                "buses", [mgtwin.Bus(id="MV", v_nom_kv=13.8); mgtwin.Bus(id="LV", v_nom_kv=0.48)], ...
                "transformers", mgtwin.Transformer(id="TX", hv_bus="MV", lv_bus="LV", s_rated_mva=2.0, ...
                    hv_kv=13.8, lv_kv=0.48, x_pu=0.0575, ...
                    hv_config=mgtwin.WindingConfig.DELTA, lv_config=mgtwin.WindingConfig.WYE_GROUNDED), ...
                "converters", mgtwin.Converter(id="GFM", bus="MV", s_rated_mva=2.0, ...
                    control=mgtwin.ConverterControl.GFM_DROOP, params=mgtwin.ConverterParams(p_f_droop_pu=0.05)), ...
                "loads", mgtwin.Load(id="L", bus="LV", p_mw=0.5), ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false, energized_source_ids="GFM"));
            rep = mgtwin.gateGrounding(site);
            lvSev = mgtwin.Severity.empty(0,1); mvSev = mgtwin.Severity.empty(0,1);
            for f = rep.findings'
                if contains(f.scope, "0.48"), lvSev(end+1) = f.severity; end %#ok<AGROW>
                if contains(f.scope, "13.8"), mvSev(end+1) = f.severity; end %#ok<AGROW>
            end
            tc.verifyNotEmpty(lvSev); tc.verifyEqual(lvSev(1), mgtwin.Severity.PASS);
            tc.verifyNotEmpty(mvSev); tc.verifyEqual(mvSev(1), mgtwin.Severity.FAIL);
        end

        function test_grounding_gate_passes_when_reference_survives_islanding(tc)
            site = MgtwinTest.minimalSite( ...
                "grounding", mgtwin.GroundingSource(id="G", bus="B1", kind=mgtwin.GroundingKind.LOW_RESISTANCE, ...
                    z0_ohm=12.0, available_when_islanded=true), ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false));
            tc.verifyFalse(mgtwin.gateGrounding(site).failed());
        end

        function test_grounding_gate_fails_when_nothing_declared(tc)
            % Silence is not a pass. An undeclared grounding scheme is a finding.
            site = MgtwinTest.minimalSite("islands", mgtwin.IslandConfig(id="I1", grid_connected=false));
            tc.verifyTrue(mgtwin.gateGrounding(site).failed());
        end

        function test_protection_gate_fails_below_pickup(tc)
            % 5 MVA at 11 kV -> 262 A rated, x1.2 limit -> 315 A available.
            rep = mgtwin.gateProtection(MgtwinTest.converterOnlySite(600.0));
            tc.verifyTrue(rep.failed());
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.FAIL), "never operate"));
        end

        function test_protection_gate_fails_inside_dependability_margin(tc)
            % Above pickup but below margin is still a FAIL, not a warning.
            rep = mgtwin.gateProtection(MgtwinTest.converterOnlySite(250.0));  % ratio ~1.26
            tc.verifyTrue(rep.failed());
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.FAIL), "dependability margin"));
        end

        function test_protection_gate_passes_with_adequate_margin(tc)
            rep = mgtwin.gateProtection(MgtwinTest.converterOnlySite(150.0));  % ratio ~2.1
            tc.verifyFalse(rep.failed());
        end

        function test_protection_warns_on_converter_dominance_even_when_passing(tc)
            rep = mgtwin.gateProtection(MgtwinTest.converterOnlySite(150.0));
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.WARN), "current-limited converters"));
        end

        function test_converter_fault_contribution_is_current_limited(tc)
            % 5 MVA at 11 kV is 262 A rated; contribution should be ~315 A, not thousands.
            base = mgtwin.Base(s_base_mva=10.0, v_base_kv=11.0);
            c = mgtwin.Converter(id="C", bus="B1", s_rated_mva=5.0, control=mgtwin.ConverterControl.GFM_DROOP, ...
                params=mgtwin.ConverterParams(p_f_droop_pu=0.05, i_limit_transient_pu=1.2));
            tc.verifyEqual(c.faultContributionA(base), 315.0, "RelTol", 0.01);
        end

        function test_demo_site_gates_block_then_pass(tc)
            rep = mgtwin.runAllGates(build_demo_site(false));
            tc.verifyTrue(rep.failed());
            gates = unique(string({rep.bySeverity(mgtwin.Severity.FAIL).gate}));
            tc.verifyTrue(all(ismember(["grounding", "protection"], gates)));
            rep2 = mgtwin.runAllGates(build_demo_site(true));
            tc.verifyFalse(rep2.failed());
            tc.verifyTrue(rep2.warned());   % converter-dominance warning survives remediation
        end

        % -----------------------------------------------------------------
        % Residual diagnostics
        % -----------------------------------------------------------------
        function test_whiteness_accepts_white_noise(tc)
            rs = RandStream("mt19937ar", "Seed", 0);
            tc.verifyTrue(mgtwin.assessWhiteness(randn(rs, 500, 1), 2).white);
        end

        function test_whiteness_rejects_a_deterministic_trend(tc)
            t = linspace(0, 1, 500)';
            rs = RandStream("mt19937ar", "Seed", 0);
            resid = 0.5 * sin(2 * pi * 2 * t) + 0.05 * randn(rs, numel(t), 1);
            tc.verifyFalse(mgtwin.assessWhiteness(resid, 2).white);
        end

        % -----------------------------------------------------------------
        % Identification: the honesty properties
        % -----------------------------------------------------------------
        function test_well_posed_case_recovers_truth(tc)
            res = MgtwinTest.fit(0.02, 2e-4, 8.0, [], ...
                struct("rp_pu", 0.03, "tp_sec", 0.40), ...
                struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]), ...
                struct("h_sec", MgtwinTest.H));
            tc.verifyEqual(res.verdict, mgtwin.Verdict.IDENTIFIED);
            tc.verifyEqual(res.theta(1), MgtwinTest.RP, "RelTol", 0.02);
            tc.verifyEqual(res.theta(2), MgtwinTest.TP, "RelTol", 0.05);
            tc.verifyTrue(res.whiteness.white);
        end

        function test_historian_grade_data_is_reported_not_identifiable(tc)
            % When the experiment cannot support the parameter set, the gate
            % must refuse rather than return the optimiser's answer.
            res = MgtwinTest.fit(1.0, 1e-3, 20.0, [], ...
                struct("rp_pu", 0.03, "tp_sec", 0.40, "h_sec", 1.0), ...
                struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0], "h_sec", [0.05, 20.0]), ...
                struct());
            tc.verifyEqual(res.verdict, mgtwin.Verdict.NOT_IDENTIFIABLE);
            tc.verifyGreaterThan(res.cond_number, 1e3);
            % And the point of the refusal: the returned estimate is badly wrong.
            tc.verifyGreaterThan(abs(res.theta(2) - MgtwinTest.TP) / MgtwinTest.TP, 0.5);
        end

        function test_model_form_mismatch_overrides_tight_intervals(tc)
            % The single most important behaviour in the package.
            res = MgtwinTest.fit(0.02, 2e-4, 8.0, 0.30, ...
                struct("rp_pu", 0.03, "tp_sec", 0.40), ...
                struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]), ...
                struct("h_sec", MgtwinTest.H), 11);
            tc.verifyEqual(res.verdict, mgtwin.Verdict.STRUCTURAL_MISMATCH);
            tc.verifyFalse(res.whiteness.white);
            tc.verifyLessThan(res.rel_se(2), 0.05);   % intervals look reassuring...
            tc.verifyGreaterThan(abs(res.theta(2) - MgtwinTest.TP) / MgtwinTest.TP, 0.5);  % ...while biased
            tc.verifyTrue(any(contains(res.notes, "optimistically biased")));
        end

        % -----------------------------------------------------------------
        % Model numerics
        % -----------------------------------------------------------------
        function test_droop_steady_state_matches_analytic_value(tc)
            [t, p] = mgtwin.loadStep(t_end=30.0, dt=0.002, p_before=0.30, p_after=0.30);
            y = mgtwin.simulateGfm(t, p, MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H);
            tc.verifyEqual(y(end, 1), 1.0 - MgtwinTest.RP * 0.30, "AbsTol", 1e-6);
            tc.verifyEqual(y(end, 2), 0.30, "AbsTol", 1e-6);
        end

        function test_load_increase_lowers_frequency(tc)
            [t, p] = mgtwin.loadStep();
            y = mgtwin.simulateGfm(t, p, MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H);
            tc.verifyLessThan(y(end, 1), y(1, 1));
        end

        function test_ramp_limit_slows_the_response(tc)
            [t, p] = mgtwin.loadStep();
            fast = mgtwin.simulateGfm(t, p, MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H);
            slow = mgtwin.simulateGfm(t, p, MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H, ramp_limit_pu_s=0.30);
            tc.verifyEqual(slow(end, 1), fast(end, 1), "AbsTol", 1e-4);
            i = find(t >= 1.3, 1);
            tc.verifyLessThan(slow(i, 2), fast(i, 2));
        end

        function test_simulator_rejects_non_monotonic_time(tc)
            tc.verifyError(@() mgtwin.simulateGfm([0.0, 0.1, 0.05], zeros(1, 3), ...
                MgtwinTest.RP, MgtwinTest.TP, MgtwinTest.H), "mgtwin:ValueError");
        end

        % -----------------------------------------------------------------
        % Test spec
        % -----------------------------------------------------------------
        function test_suite_loads_and_carries_no_invented_limits(tc)
            suite = mgtwin.loadSuite("ieee2030_8_2018");
            tc.verifyNotEmpty(suite.cases);
            % Every clause reference must be blank: none is reproduced from the standard.
            tc.verifyTrue(all(strlength([suite.cases.clause]) == 0));
            % Any limit that IS set must not claim the standard as its source
            % unless it is a structural zero.
            for c = suite.cases
                for cr = c.criteria
                    if ~isempty(cr.limit)
                        tc.verifyTrue(cr.limit_source ~= "standard" || cr.limit == 0.0);
                    end
                end
            end
        end

        function test_emt_cases_are_flagged(tc)
            suite = mgtwin.loadSuite("ieee2030_8_2018");
            ids = string({suite.emtCases().id});
            tc.verifyTrue(all(ismember(["BLK-01", "PROT-01"], ids)));
        end

        % -----------------------------------------------------------------
        % Rung 2: unbalanced solver vs IEEE 4-node, and SLG fault module
        % -----------------------------------------------------------------
        function test_ieee4_both_connections_match_published_solutions(tc)
            D = ieee4_data();
            for conn = ["GrY-GrY", "D-GrY"]
                [v_nodes, ~] = ieee4_build(conn).solve();
                got = struct("v3", mgtwin.polar(v_nodes{3}), "v4", mgtwin.polar(v_nodes{4}));
                ref = D.REFS.(matlab.lang.makeValidName(conn));
                for node = ["v3", "v4"]
                    tc.verifyLessThan(abs(got.(node)(:, 1) - ref.(node)(:, 1)), 2.0, conn + " " + node);
                    tc.verifyLessThan(abs(got.(node)(:, 2) - ref.(node)(:, 2)), 0.15, conn + " " + node);
                end
            end
        end

        function test_dgy_thirty_degree_shift_and_zero_sequence_blocking(tc)
            % Exactly 30 degrees holds at NO load (pure connection rotation).
            f_yy = ieee4_build("GrY-GrY"); f_dy = ieee4_build("D-GrY");
            f_yy.load_kw = [0 0 0]; f_dy.load_kw = [0 0 0];
            [v_yy, ~] = f_yy.solve(); [v_dy, ~] = f_dy.solve();
            a_yy = mgtwin.polar(v_yy{4}); a_dy = mgtwin.polar(v_dy{4});
            for ph = 1:3
                shift = mod(a_yy(ph, 2) - a_dy(ph, 2), 360.0);
                tc.verifyEqual(shift, 30.0, "AbsTol", 1e-9);
            end
            % Zero-sequence current on the delta (source) side must vanish
            % (checked on the LOADED case, where I0 on the wye side is large).
            feeder = ieee4_build("D-GrY");
            [~, i_load] = feeder.solve();
            tx = feeder.elements{2};
            i_hi = tx.d * i_load;
            i0_hi = abs(sum(i_hi)) / 3.0;
            i0_lo = abs(sum(i_load)) / 3.0;
            tc.verifyGreaterThan(i0_lo, 50.0);
            tc.verifyLessThan(i0_hi, 1e-6 * i0_lo);
        end

        function test_ladder_refuses_to_return_unconverged(tc)
            D = ieee4_data();
            f = mgtwin.RadialFeeder(v_source_ln=mgtwin.balancedSourceLn(12.47), ...
                elements={mgtwin.LineSegment(D.Z_Y, 2000.0)}, load_kw=D.LOAD_KW, load_pf=D.LOAD_PF);
            tc.verifyError(@() f.solve(max_iter=1), "mgtwin:ConvergenceError");
        end

        function test_slg_ungrounded_is_exactly_sqrt3(tc)
            res = mgtwin.slgFault(0.01 + 0.8i, z0_pu=[]);
            tc.verifyFalse(res.grounded);
            tc.verifyEqual(res.i_fault_pu, 0.0);
            tc.verifyEqual(res.v_max_unfaulted_pu, sqrt(3.0), "RelTol", 1e-12);
        end

        function test_slg_resistive_grounding_exceeds_sqrt3(tc)
            % Low-resistance grounding buys detection, not relief.
            res = mgtwin.slgFault(0.013 + 0.77i, z0_pu=3.8 + 0.1i);
            tc.verifyTrue(res.grounded);
            tc.verifyGreaterThan(abs(res.i_fault_pu), 0.5);
            tc.verifyGreaterThan(res.v_max_unfaulted_pu, sqrt(3.0));
        end

        function test_slg_effective_grounding_relieves_overvoltage(tc)
            res = mgtwin.slgFault(0.013 + 0.77i, z0_pu=0.05 + 1.6i);
            tc.verifyLessThan(res.v_max_unfaulted_pu, 1.4);
            tc.verifyGreaterThan(abs(res.i_fault_pu), 0.8);
        end

        function test_slg_faulted_phase_is_zero_for_bolted_fault(tc)
            res = mgtwin.slgFault(0.02 + 0.5i, z0_pu=0.05 + 1.0i, zf_pu=0.0);
            tc.verifyLessThan(abs(res.v_abc_pu(1)), 1e-12);
        end

        % -----------------------------------------------------------------
        % Rung 3: the test runner's honesty taxonomy
        % -----------------------------------------------------------------
        function test_runner_rejects_island_without_gfm(tc)
            site = MgtwinTest.minimalSite( ...
                "converters", mgtwin.Converter(id="PV", bus="B1", s_rated_mva=1.0, ...
                    control=mgtwin.ConverterControl.GFL, params=mgtwin.ConverterParams()), ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false, energized_source_ids="PV"));
            f = @() mgtwin.internal.aggregateSource(site, site.islands(1));
            tc.verifyError(f, "mgtwin:ValueError");
            try, f(); catch e, tc.verifySubstring(e.message, "no grid-forming source"); end
        end

        function test_runner_taxonomy_on_demo_island(tc)
            % Synthetic stand-in for the Banshee rung-3 fixture: the demo
            % site's ISL_1 is ungrounded as handed over, so PROT-01 must be
            % BLOCKED with the grounding finding attached; RMS cases execute;
            % the rest defer with the tier named.
            site = build_demo_site(false);
            suite = mgtwin.loadSuite("ieee2030_8_2018");
            rep = mgtwin.runSuite(site, suite, "ISL_1");
            prot = rep.byCaseId("PROT-01");
            tc.verifyEqual(prot.status, mgtwin.CaseStatus.BLOCKED);
            tc.verifyTrue(any(string({prot.blocking_findings.gate}) == "grounding"));
            deferred = string.empty(1,0);
            for r = rep.results
                if r.status == mgtwin.CaseStatus.DEFERRED, deferred(end+1) = r.test_case.id; end %#ok<AGROW>
            end
            tc.verifyEqual(sort(deferred), sort(["DISP-01", "DISP-02", "REC-01", "BLK-01", "PQ-01"]));
            c = rep.counts();
            tc.verifyEqual([c.executed, c.blocked, c.deferred], [3, 1, 5]);
            % Without project limits, nothing with a null spec limit is evaluated.
            for r = rep.results
                if r.status ~= mgtwin.CaseStatus.EXECUTED, continue; end
                for cr = r.criteria
                    if isempty(cr.criterion.limit), tc.verifyFalse(cr.evaluated); end
                end
                tc.verifyTrue(ismember(r.verdict, [mgtwin.CaseVerdict.INDETERMINATE, mgtwin.CaseVerdict.PASS]));
            end
            % Remediated site: PROT-01 unblocks into an INDETERMINATE screening
            % and the LRG overvoltage exceeds sqrt(3).
            rep2 = mgtwin.runSuite(build_demo_site(true), suite, "ISL_1");
            prot2 = rep2.byCaseId("PROT-01");
            tc.verifyEqual(prot2.status, mgtwin.CaseStatus.EXECUTED);
            tc.verifyEqual(prot2.verdict, mgtwin.CaseVerdict.INDETERMINATE);
            tc.verifyGreaterThan(prot2.metric("unfaulted_phase_overvoltage").value, 1.73);
            % Assumed-parameter PASS carries its condition.
            limits = dictionary("ISL-P-01/frequency_nadir_deviation", 5.0);
            rep3 = mgtwin.runSuite(site, suite, "ISL_1", project_limits=limits);
            isl_p = rep3.byCaseId("ISL-P-01");
            tc.verifyEqual(isl_p.verdict, mgtwin.CaseVerdict.PASS);
            tc.verifyEqual(isl_p.provenance, mgtwin.ParamProvenance.ASSUMED);
            tc.verifySubstring(isl_p.render(), "conditional");
        end

        % -----------------------------------------------------------------
        % Rung 4: adversarial identification evals
        % -----------------------------------------------------------------
        function test_single_experiment_is_blind_to_amplitude_class_mismatch(tc)
            % The rung-4 finding, pinned as a fact about the method.
            r = mgtwin.runOne(mgtwin.scenarioByName("deadband"), 0, "single");
            tc.verifyEqual(r.cell, "false_confidence");
        end

        function test_multi_amplitude_catches_deadband_and_saturation(tc)
            for name = ["deadband", "saturation", "knee_droop"]
                for seed = [0, 1]
                    r = mgtwin.runOne(mgtwin.scenarioByName(name), seed, "multi");
                    tc.verifyTrue(r.verdict.isRefusal(), sprintf("%s seed %d: %s", name, seed, r.verdict.Value));
                    tc.verifyEqual(r.cell, "true_refusal", sprintf("%s seed %d", name, seed));
                end
            end
        end

        function test_multi_amplitude_keeps_nominal_and_minor_probes_identified(tc)
            for name = ["nominal", "quantized", "fast_unmodeled"]
                r = mgtwin.runOne(mgtwin.scenarioByName(name), 0, "multi");
                tc.verifyEqual(r.verdict, mgtwin.Verdict.IDENTIFIED, name);
                tc.verifyEqual(r.cell, "true_confidence", name);
            end
        end

        function test_shape_class_mismatch_caught_by_both_protocols(tc)
            for protocol = ["single", "multi"]
                r = mgtwin.runOne(mgtwin.scenarioByName("ramp_limit"), 0, protocol);
                tc.verifyTrue(r.verdict.isRefusal(), protocol);
            end
        end

        function test_identify_multi_pools_consistent_experiments(tc)
            C = mgtwin.evalConstants();
            sc = mgtwin.scenarioByName("nominal");
            exps = {mgtwin.evalExperiment(sc, 0, sc.step), mgtwin.evalExperiment(sc, 1000, C.SMALL_STEP)};
            res = mgtwin.identifyMulti(exps, struct("rp_pu", 0.03, "tp_sec", 0.40), ...
                struct("rp_pu", [0.005, 0.20], "tp_sec", [0.01, 2.0]));
            tc.verifyEqual(res.verdict, mgtwin.Verdict.IDENTIFIED);
            tc.verifyNotEmpty(res.theta_pooled);
            tc.verifyEqual(res.theta_pooled(1), 0.05, "RelTol", 0.02);
            tc.verifyEqual(res.theta_pooled(2), 0.20, "RelTol", 0.05);
            tc.verifyLessThan(max(struct2array(res.spread_rel)), 0.03);
        end

        % -----------------------------------------------------------------
        % Rung 1 / 3: Banshee (skipped if data absent)
        % -----------------------------------------------------------------
        function test_banshee_case_translates_with_expected_shape(tc)
            tc.assumeBanshee();
            P = banshee_paths();
            expected = {"case_banshee_feeder_all_v5.m", 12.825; "case_banshee_feeder_all_v4.m", 0.0};
            for k = 1:2
                mpc = mgtwin.loadMatpowerCase(fullfile(P.DATA, "Matpower", expected{k, 1}));
                tc.verifyEqual(mpc.baseMVA, 20.0);
                tc.verifyEqual(size(mpc.bus), [40, 13]);
                tc.verifyEqual(size(mpc.branch, 1), 39);
                tc.verifyEqual(sum(mpc.bus(:, 3)), expected{k, 2}, "AbsTol", 1e-6);
                tc.verifyEqual(unique(mpc.bus(:, 10))', [0.208, 0.48, 4.16, 13.8], "RelTol", 1e-9);
            end
        end

        function test_banshee_v4_reproduces_published_matpower_currents(tc)
            tc.assumeBanshee();
            tc.assumeTrue(exist("runpf", "file") > 0, "MATPOWER (runpf) not on path");
            P = banshee_paths();
            [~, cands] = banshee_solve_and_currents(P.CASE_V4);
            placeholder = ["8-9:from", "8-9:to", "2-6:from", "6-7:from"];
            T = readtable(P.CSV_PATH, "TextType", "string");
            checked = 0;
            for r = 1:height(T)
                m_a = T.MATPOWER_A(r);
                if m_a < 400.0, continue; end
                fdr = str2double(extractBetween(T.METER(r), 3, 3));
                pool = cands([cands.feeder] == fdr);
                [~, j] = min(abs([pool.i_a] - m_a));
                if ismember(pool(j).name, placeholder), continue; end
                tc.verifyLessThan(abs(pool(j).i_a - m_a) / m_a, 5e-4, T.METER(r));
                checked = checked + 1;
            end
            tc.verifyGreaterThanOrEqual(checked, 4);
        end

        function test_banshee_composition_is_blocked_for_the_right_reasons(tc)
            tc.assumeBanshee();
            P = banshee_paths();
            if isfile(P.MDL), mdl = P.MDL; else, mdl = string.empty; end
            site = mgtwin.composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=mdl);
            tc.verifyEqual(numel(site.buses), 40);
            tc.verifyEqual(numel(site.loads), 18);
            tc.verifyEqual(numel(site.relays), 3);
            rep = mgtwin.runAllGates(site);
            tc.verifyTrue(rep.failed());
            fails = rep.bySeverity(mgtwin.Severity.FAIL);
            gates = unique(string({fails.gate}));
            tc.verifyTrue(ismember("grounding", gates));
            tc.verifyTrue(ismember("protection", gates));
            if isfile(P.MDL)
                tc.verifyEqual(numel(site.transformers), 22);
                g_fails = fails(string({fails.gate}) == "grounding");
                tc.verifyEqual(numel(g_fails), 4);
                scopes = string({g_fails.scope});
                tc.verifyTrue(all(contains(scopes, "13.8kV")));
                tc.verifyEqual(sort(unique(extractBefore(scopes, "/"))), ["ISL_ALL", "ISL_F1", "ISL_F2", "ISL_F3"]);
            end
        end

        function test_banshee_transformers_paired_by_impedance(tc)
            % The .m's transformer branches pair with the .mdl's instances by
            % impedance, not by order: XTX_3_4 (x 1.96 on 20 MVA) is a 500 kVA
            % unit. Rebased to its unit's rating every reactance is a
            % transformer's (the units gate passes); the three branches no
            % instance matches are named.
            tc.assumeBanshee();
            P = banshee_paths();
            T = mgtwin.transformerPairing(P.CASE_V5, P.MDL);
            row = T(T.branch == "TX_3_4", :);
            tc.verifyEqual(row.kva, 500); tc.verifyEqual(row.mismatch, 0);
            tc.verifyEqual(sort(T.branch(T.mismatch > 0.05))', ["TX_30_40", "TX_50_60", "TX_80_110"]);
            site = mgtwin.composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=P.MDL);
            tx = site.transformers(string({site.transformers.id}) == "XTX_3_4");
            tc.verifyEqual(tx.s_rated_mva, 0.5); tc.verifyEqual(tx.x_pu, 0.049, AbsTol=1e-3);
            fails = mgtwin.gateUnits(site).bySeverity(mgtwin.Severity.FAIL);
            tc.verifyFalse(any(contains(string({fails.message}), "reactance")));
        end

        function test_runner_taxonomy_on_banshee_isl_f1(tc)
            tc.assumeBanshee();
            [site, suite, limits] = MgtwinTest.rung3Fixture();
            rep = mgtwin.runSuite(site, suite, "ISL_F1", project_limits=limits);
            tc.verifyEqual(rep.byCaseId("ISL-P-01").verdict, mgtwin.CaseVerdict.PASS);
            tc.verifyEqual(rep.byCaseId("ISL-U-01").verdict, mgtwin.CaseVerdict.FAIL);
            tc.verifyEqual(rep.byCaseId("SS-01").verdict, mgtwin.CaseVerdict.PASS);
            tc.verifyEqual(rep.byCaseId("PROT-01").status, mgtwin.CaseStatus.BLOCKED);
            c = rep.counts();
            tc.verifyEqual([c.executed, c.blocked, c.deferred], [3, 1, 5]);
        end

        function test_prot_unblocks_into_screening_after_remediation(tc)
            tc.assumeBanshee();
            [site, suite, ~] = MgtwinTest.rung3Fixture();
            site2 = site;
            site2.grounding(end+1, 1) = mgtwin.GroundingSource(id="G_ZZ_F1", bus="B2", ...
                kind=mgtwin.GroundingKind.LOW_RESISTANCE, z0_ohm=12.0, available_when_islanded=true);
            rep = mgtwin.runSuite(site2, suite, "ISL_F1");
            prot = rep.byCaseId("PROT-01");
            tc.verifyEqual(prot.status, mgtwin.CaseStatus.EXECUTED);
            tc.verifyEqual(prot.verdict, mgtwin.CaseVerdict.INDETERMINATE);
            tc.verifyGreaterThan(prot.metric("unfaulted_phase_overvoltage").value, 1.73);
        end
        % -----------------------------------------------------------------
        % v0.6.1-v0.6.5: declared IT, forming, energisation, loading, switch states
        % -----------------------------------------------------------------
        function test_declared_it_zone_warns_with_detector_requirement_not_fail(tc)
            % v0.6.1: an ungrounded zone the design DECLARES as an IT system
            % is a WARN carrying the detector requirement, not a PASS or FAIL.
            site = MgtwinTest.minimalSite( ...
                "buses", [mgtwin.Bus(id="MV", v_nom_kv=33.0); mgtwin.Bus(id="LV", v_nom_kv=0.69)], ...
                "transformers", mgtwin.Transformer(id="TX", hv_bus="MV", lv_bus="LV", s_rated_mva=5.5, ...
                    hv_kv=33.0, lv_kv=0.69, x_pu=0.06, hv_config=mgtwin.WindingConfig.DELTA, ...
                    lv_config=mgtwin.WindingConfig.WYE_UNGROUNDED), ...
                "converters", mgtwin.Converter(id="PCS", bus="LV", s_rated_mva=5.5, ...
                    control=mgtwin.ConverterControl.GFM_DROOP, params=mgtwin.ConverterParams(p_f_droop_pu=0.04)), ...
                "grounding", [mgtwin.GroundingSource(id="GT", bus="MV", kind=mgtwin.GroundingKind.LOW_RESISTANCE, ...
                        z0_ohm=38.0, available_when_islanded=true); ...
                    mgtwin.GroundingSource(id="IT_LV", bus="LV", kind=mgtwin.GroundingKind.UNGROUNDED, ...
                        available_when_islanded=true, notes="declared IT, IMD fitted")], ...
                "islands", mgtwin.IslandConfig(id="I1", grid_connected=false, energized_source_ids="PCS"));
            rep = mgtwin.gateGrounding(site);
            zones = rep.findings(contains(string({rep.findings.scope}), "zone"));
            mv = zones(contains(string({zones.scope}), "33kV"));
            lv = zones(contains(string({zones.scope}), "0.69kV"));
            tc.verifyEqual(mv(1).severity, mgtwin.Severity.PASS);
            tc.verifyEqual(lv(1).severity, mgtwin.Severity.WARN);
            tc.verifySubstring(lv(1).message, "DECLARED");
            tc.verifySubstring(lv(1).message, "detector");
            tc.verifyFalse(rep.failed());
        end

        function test_forming_gate_fails_section_of_grid_following_only(tc)
            % v0.6.2: a sectionalised bus whose only sources are
            % grid-following has no reference and must FAIL.
            site = MgtwinTest.minimalSite( ...
                "buses", [mgtwin.Bus(id="A", v_nom_kv=33.0); mgtwin.Bus(id="B", v_nom_kv=33.0)], ...
                "switches", mgtwin.Switch(id="TIE", from_bus="A", to_bus="B"), ...
                "converters", [mgtwin.Converter(id="GFM", bus="A", s_rated_mva=5.5, ...
                        control=mgtwin.ConverterControl.GFM_DROOP, params=mgtwin.ConverterParams(p_f_droop_pu=0.04)); ...
                    mgtwin.Converter(id="GFL", bus="B", s_rated_mva=2.2, ...
                        control=mgtwin.ConverterControl.GFL, params=mgtwin.ConverterParams())], ...
                "islands", [mgtwin.IslandConfig(id="COUPLED", grid_connected=false, energized_source_ids=["GFM", "GFL"]); ...
                    mgtwin.IslandConfig(id="SPLIT", grid_connected=false, energized_source_ids=["GFM", "GFL"], open_switches="TIE")]);
            rep = mgtwin.gateForming(site);
            coupled = MgtwinTest.scoped(rep, "COUPLED");
            split = MgtwinTest.scoped(rep, "SPLIT");
            tc.verifyEqual([coupled.severity], mgtwin.Severity.PASS);
            tc.verifyEqual(sort(arrayfun(@(f) f.severity.Value, split))', ["fail", "pass"]);
        end

        function test_energisation_fails_whole_section_passes_one_at_a_time(tc)
            % Five 3 MVA transformers closed together exceed six 5.5 MVA PCS
            % headroom; one at a time fits.
            w = MgtwinTest.worstByIsland(mgtwin.gateEnergisation(MgtwinTest.revcExample()));
            tc.verifyEqual(w("FAST_TRANSFER_WHOLE_SECTION"), "fail");
            tc.verifyTrue(ismember(w("SLOW_TRANSFER_ONE_GROUP"), ["pass", "warn"]));
        end

        function test_loading_gate_fails_a_black_start_carrying_the_halls(tc)
            % Rev C's BLACKSTART_GEN leaves the cord-A hall feeders closed on
            % the 3 MVA genset: the loading gate FAILs it; its later
            % black-start states, load breakers open, pass.
            rep = mgtwin.gateLoading(MgtwinTest.revcExample());
            w = MgtwinTest.worstByIsland(rep);
            tc.verifyEqual(w("BLACKSTART_GEN"), "fail");
            tc.verifyEqual(w("NORMAL"), "pass");
            tc.verifyEqual(w("BLACKSTART_GEN_FIRST_PCS_TR"), "pass");
            bs = MgtwinTest.scoped(rep, "BLACKSTART_GEN/");
            tc.verifyTrue(any(contains(string({bs.message}), "exceeds the rating of every source")));
        end

        function test_loading_gate_warns_when_storage_carries_the_load(tc)
            % PCS 1-2 forming BESS-1 with Aux A closed and no SOFC running:
            % carried, but on the batteries.
            fs = MgtwinTest.scoped(mgtwin.gateLoading(MgtwinTest.revcExample()), "BLACKSTART_BESS1_SOFC_PAIR/");
            tc.verifyEqual([fs.severity], mgtwin.Severity.WARN);
        end

        function test_loading_fails_transformer_feeding_more_than_its_rating(tc)
            % A 3.5 MVA transformer feeding a 12.5 MW hall cord with no source
            % behind it: FAIL, in every state that closes the cord's feeder.
            site = MgtwinTest.revcExample();
            h = find([site.loads.p_mw] > 5, 1);
            site.buses(end+1, 1) = mgtwin.Bus(id="HALL_LV", v_nom_kv=0.4);
            site.transformers(end+1, 1) = mgtwin.Transformer(id="TR_HALL", hv_bus=site.loads(h).bus, ...
                lv_bus="HALL_LV", s_rated_mva=3.5, hv_kv=33.0, lv_kv=0.4, x_pu=0.08, r_pu=0.006, ...
                hv_config=mgtwin.WindingConfig.DELTA, lv_config=mgtwin.WindingConfig.WYE_GROUNDED);
            site.loads(h).bus = "HALL_LV";
            rep = mgtwin.gateLoading(site);
            tr = rep.findings(endsWith(string({rep.findings.scope}), "/TR_HALL"));
            tc.verifyNotEmpty(tr);
            tc.verifyEqual(unique(arrayfun(@(f) f.severity.Value, tr)), "fail");
            tc.verifyTrue(any(startsWith(string({tr.scope}), "NORMAL/")));
        end

        function test_units_gate_fails_transformer_reactance_on_the_system_base(tc)
            % Transformer.x_pu is on the transformer's own rating; a Site that
            % gives it on the 50 MVA system base (x 1.0 for 6 % on 3 MVA) is
            % caught, and one entered on its own rating is not.
            site = MgtwinTest.revcExample();
            fs = mgtwin.gateUnits(site).bySeverity(mgtwin.Severity.FAIL);
            fs = fs(contains(string({fs.message}), "transformer reactance"));
            tc.verifyNotEmpty(fs);
            tc.verifySubstring(fs(1).message, "TR_SOFC01 1");
            for k = 1:numel(site.transformers)
                site.transformers(k).x_pu = 0.06;
            end
            rep = mgtwin.gateUnits(site);
            tc.verifyFalse(any(contains(string({rep.findings.message}), "transformer reactance")));
        end

        function test_loading_gate_keeps_normally_open_switches_open(tc)
            % A normally open tie or alternate leg is open unless the state
            % closes it, so it does not join the boards it ties; marked
            % normally closed, it does.
            site = MgtwinTest.revcExample();
            ids = site.busIds();
            found = false;
            for i = 1:numel(site.islands)
                root = mgtwin.internal.sections(site, site.islands(i));
                for k = 1:numel(site.switches)
                    sw = site.switches(k);
                    if ~sw.normally_closed && root(ids == sw.from_bus) ~= root(ids == sw.to_bus)
                        found = true; break;
                    end
                end
                if found, break; end
            end
            tc.assertTrue(found);
            site.switches(k).normally_closed = true;
            root = mgtwin.internal.sections(site, site.islands(i));
            tc.verifyEqual(root(ids == sw.from_bus), root(ids == sw.to_bus));
        end

        function test_a_state_closes_a_normally_open_leg(tc)
            % Rev C's transfers re-close groups 1-5 onto SOFC-2A through their
            % normally open second legs: listed in closed_switches, the legs
            % conduct and the energisation gate weighs the step's inrush. Left
            % out, the gate says the step energises nothing.
            site = MgtwinTest.revcExample();
            i = find(string({site.islands.id}) == "FAST_TRANSFER_WHOLE_SECTION");
            tc.verifyTrue(ismember("CB_SOFC01_2", site.islands(i).closed_switches));
            tc.verifyFalse(ismember("CB_SOFC01_2", site.openSwitchIds(site.islands(i))));
            fast = MgtwinTest.scoped(mgtwin.gateEnergisation(site), "FAST_TRANSFER_WHOLE_SECTION/");
            tc.verifyNumElements(fast, 1);
            tc.verifySubstring(fast.message, "5 transformer(s)");
            tc.verifyEqual(fast.severity, mgtwin.Severity.FAIL);
            site.islands(i).closed_switches = string.empty(1,0);
            fast = MgtwinTest.scoped(mgtwin.gateEnergisation(site), "FAST_TRANSFER_WHOLE_SECTION/");
            tc.verifyNumElements(fast, 5);
            tc.verifyTrue(all(contains(string({fast.message}), "no energised source reaches")));
        end

        function test_a_state_cannot_open_and_close_one_switch(tc)
            root = fileparts(fileparts(mfilename("fullpath")));
            raw = jsondecode(fileread(fullfile(root, "examples", "c003_revC_site.json")));
            i = find(cellfun(@(x) string(x.id) == "FAST_TRANSFER_WHOLE_SECTION", raw.islands));
            raw.islands{i}.open_switches{end+1} = 'CB_SOFC01_2';
            tc.verifyError(@() mgtwin.siteFromStruct(raw), "mgtwin:ValidationError");
            try
                mgtwin.siteFromStruct(raw);
            catch err
                tc.verifySubstring(err.message, "both opens and closes");
            end
            raw.islands{i}.open_switches(end) = [];
            raw.islands{i}.closed_switches{end+1} = 'CB_NOPE';
            try
                mgtwin.siteFromStruct(raw);
                tc.verifyFail("an unknown switch in closed_switches was accepted");
            catch err
                tc.verifySubstring(err.message, "unknown switch");
            end
        end

        function test_a_state_moves_load(tc)
            % When a board is lost the dual-corded halls move to the other cord: the state says so with a
            % load factor, and the loading gate sums the moved load - and a factor for an unknown load, or
            % a negative one, is refused.
            site = MgtwinTest.revcRebased();
            i = find(string({site.islands.id}) == "MVA_BUS_FAULT");
            ids = string({site.loads.id});
            cb = find(contains(ids, "cordB"), 1);
            msgs = @(s) string({MgtwinTest.scoped(mgtwin.gateLoading(s), "MVA_BUS_FAULT/loading").message});
            before = msgs(site);
            site.islands(i).load_factors = dictionary(ids(cb), 2.0);
            after = msgs(site);
            [p, q] = site.stateLoads(site.islands(i));
            tc.verifyEqual(p(cb), 2 * site.loads(cb).p_mw);
            tc.verifyEqual(q(cb), 2 * site.loads(cb).q_mvar);
            tc.verifyNotEqual(before, after);
            root = fileparts(fileparts(mfilename("fullpath")));
            raw = jsondecode(fileread(fullfile(root, "examples", "c003_revC_site.json")));
            j = find(cellfun(@(x) string(x.id) == "MVA_BUS_FAULT", raw.islands));
            raw.islands{j}.load_factors = struct("NOPE", 2.0);
            try
                mgtwin.siteFromStruct(raw);
                tc.verifyFail("a factor for an unknown load was accepted");
            catch err
                tc.verifySubstring(err.message, "scales unknown load");
            end
            raw.islands{j}.load_factors = struct(char(ids(cb)), -1.0);
            try
                mgtwin.siteFromStruct(raw);
                tc.verifyFail("a negative factor was accepted");
            catch err
                tc.verifySubstring(err.message, "negative factor");
            end
        end

        function test_revc_example_matches_python_gate_counts(tc)
            % The Rev C example through all seven gates gives Python v0.6.5's
            % run_all, gate by gate and severity by severity.
            rep = mgtwin.runAllGates(MgtwinTest.revcExample());
            key = string({rep.findings.gate})' + "/" + arrayfun(@(f) f.severity.Value, rep.findings);
            [u, ~, j] = unique(key);
            got = dictionary(u, accumarray(j, 1));
            expected = dictionary( ...
                ["energisation/fail", "energisation/warn", "forming/pass", "grounding/pass", "honesty/warn", ...
                 "loading/fail", "loading/pass", "loading/warn", "protection/warn", "units/fail"], ...
                [3, 1, 15, 279, 78, 2, 10, 4, 1, 1]);
            tc.verifyEqual(sort(keys(got)), sort(keys(expected)));
            tc.verifyEqual(got(keys(expected)), values(expected));
        end

        % -----------------------------------------------------------------
        % Stage 6: the validity envelope (Python v0.6.6)
        % -----------------------------------------------------------------
        function test_envelope_a_site_wide_fail_puts_everything_outside(tc)
            env = mgtwin.buildEnvelope(MgtwinTest.revcExample());
            tc.verifyNotEmpty(env.site_wide_fails);
            tc.verifySubstring(env.site_wide_fails(1), "transformer reactance");
            [v, why] = env.check("NORMAL", "loading", load_mva=30.0);
            tc.verifyEqual(v, mgtwin.Inside.OUTSIDE);
            tc.verifySubstring(why(1), "site-wide");
        end

        function test_envelope_states_gates_and_tier(tc)
            % The gates bound the envelope state by state; phenomena beyond the
            % tier and states the Site does not enumerate are outside;
            % storage-carried load is provisional; assumed parameters make
            % frequency provisional.
            env = mgtwin.buildEnvelope(MgtwinTest.revcRebased());
            tc.verifyEmpty(env.site_wide_fails);
            tc.verifyEqual(env.check("NORMAL", "loading", load_mva=37.0), mgtwin.Inside.INSIDE);
            tc.verifyEqual(env.check("NORMAL", "loading", load_mva=60.0), mgtwin.Inside.PROVISIONAL);   % above 44 MVA sustained
            tc.verifyEqual(env.check("NORMAL", "loading", load_mva=80.0), mgtwin.Inside.OUTSIDE);       % above 77 MVA in all
            [v, why] = env.check("BLACKSTART_GEN", "loading");
            tc.verifyEqual(v, mgtwin.Inside.OUTSIDE); tc.verifySubstring(why(1), "loading");
            tc.verifyEqual(env.check("FAST_TRANSFER_WHOLE_SECTION", "energisation"), mgtwin.Inside.OUTSIDE);
            tc.verifyEqual(env.check("SLOW_TRANSFER_ONE_GROUP", "energisation"), mgtwin.Inside.PROVISIONAL);   % assumed inrush
            tc.verifyEqual(env.check("NORMAL", "emt"), mgtwin.Inside.OUTSIDE);
            tc.verifyEqual(env.check("NORMAL", "voltage"), mgtwin.Inside.OUTSIDE);
            tc.verifyEqual(env.check("NOT_A_STATE", "loading"), mgtwin.Inside.OUTSIDE);
            [v, why] = env.check("NORMAL", "frequency", step_pu=0.3);
            tc.verifyEqual(v, mgtwin.Inside.PROVISIONAL); tc.verifyTrue(any(contains(why, "assumed")));
            tc.verifyTrue(any(contains(env.undeclared, "ranges over which the dynamic models hold")));
        end

        function test_envelope_identified_amplitudes_bound_a_step(tc)
            % With every forming source identified over 0.1-0.5 pu steps, a
            % 0.3 pu step is inside and a 0.65 pu step is an extrapolation;
            % protection stays provisional while ride-through is assumed.
            site = MgtwinTest.revcRebased();
            isGfm = arrayfun(@(c) c.control ~= mgtwin.ConverterControl.GFL, site.converters);
            gfm = [string({site.converters(isGfm).id}), string({site.machines.id})];
            recs = arrayfun(@(s) mgtwin.IdentificationRecord(source_id=s, verdict="identified", ...
                step_range_pu=[0.1 0.5], parameters=struct("rp", 0.04)), gfm);
            env = mgtwin.buildEnvelope(site, identifications=recs);
            tc.verifyEqual(env.check("NORMAL", "frequency", step_pu=0.3), mgtwin.Inside.INSIDE);
            [v, why] = env.check("NORMAL", "frequency", step_pu=0.65);
            tc.verifyEqual(v, mgtwin.Inside.PROVISIONAL); tc.verifySubstring(why(1), "extrapolation");
            tc.verifyEqual(env.check("NORMAL", "protection"), mgtwin.Inside.PROVISIONAL);
            recs(1).verdict = "structural_mismatch";
            env2 = mgtwin.buildEnvelope(site, identifications=recs);
            tc.verifyEqual(env2.check("NORMAL", "frequency", step_pu=0.3), mgtwin.Inside.PROVISIONAL);
            d = jsondecode(env2.toJson());
            tc.verifyEqual(d.states.NORMAL.rating_mva, 77.0);
            tc.verifyEqual(string(d.phenomena.emt.support), "excluded");
            tc.verifySubstring(env.render(), "# Validity envelope");
            MgtwinTest.verifyThrows(tc, @() mgtwin.buildEnvelope(site, identifications= ...
                mgtwin.IdentificationRecord(source_id="NOPE", verdict="identified", step_range_pu=[0.1 0.5])), "unknown sources");
        end

        % -----------------------------------------------------------------
        % Stage 1: tag ingest (Python v0.6.6)
        % -----------------------------------------------------------------
        function test_ingest_maps_scales_and_flags_tags(tc)
            T = @(t, u, p) mgtwin.Tag(tag=t, unit=u, sample_period_s=p);
            tags = [T("PCS2.P_MW", "MW", 0.02), T("PCS2.F", "Hz", 0.02), T("SOFC01_KW", "kW", 1.0), ...
                T("SOFC01_HZ", "Hz", 1.0), T("SOFC02_KW", "A", []), ...      % wrong unit for power
                T("PCS3.TEMP_C", "degC", []), ...                            % code not in the map
                T("PCS1.P_MW", "MW", []), ...                                % two rules disagree
                T("CB_TIE.POS", "", []), T("CB_TIE.POS", "", []), ...        % a duplicate
                T("HALL7.P", "MW", []), ...                                  % no rule
                T("GEN.P", "kW", 0.1), T("GEN.F", "Hz", 0.1)];
            rep = mgtwin.ingestTags(tags, MgtwinTest.revcRules());
            st = @(t) MgtwinTest.statusOf(rep, t);
            tc.verifyEqual([st("PCS2.P_MW"), st("SOFC01_KW"), st("GEN.P")], [mgtwin.TagStatus.MATCHED, mgtwin.TagStatus.MATCHED, mgtwin.TagStatus.MATCHED]);
            tc.verifyEqual([st("PCS3.TEMP_C"), st("HALL7.P")], [mgtwin.TagStatus.UNMATCHED, mgtwin.TagStatus.UNMATCHED]);
            tc.verifyEqual(st("PCS1.P_MW"), mgtwin.TagStatus.AMBIGUOUS);
            tc.verifyEqual(st("CB_TIE.POS"), [mgtwin.TagStatus.MATCHED, mgtwin.TagStatus.DUPLICATE]);
            k = rep.entityIndex("converter", "SOFC01");
            tc.verifyEqual(rep.measurementResult(k, "P").scale, 1e-3);
            bad = rep.results(arrayfun(@(r) r.tag.tag == "SOFC02_KW", rep.results));
            tc.verifyTrue(any(contains(bad.notes, "is current, but P is power")));
            tc.verifyEqual(rep.measurementResult(rep.entityIndex("machine", "GEN_BS"), "P").scale, 1e-3);
            tc.verifySubstring(rep.render(), "## Flagged tags");
            tc.verifyEqual(rep.toStruct().counts.ambiguous, 1);
        end

        function test_ingest_against_the_site(tc)
            % Against Rev C: telemetry for equipment the Site lacks, equipment
            % no tag observes, and which sources can be identified from
            % operating data at a PMU-grade period.
            T = @(t, u, p) mgtwin.Tag(tag=t, unit=u, sample_period_s=p);
            tags = [T("PCS2.P_MW", "MW", 0.02), T("PCS2.F", "Hz", 0.02), T("SOFC01_KW", "kW", 1.0), ...
                T("SOFC01_HZ", "Hz", 1.0), T("PCS9.P_MW", "MW", []), T("PCS3.P_MW", "MW", [])];
            rep = mgtwin.ingestTags(tags, MgtwinTest.revcRules());
            out = mgtwin.compareWithSite(rep, MgtwinTest.revcExample(), identification_period_s=0.05);
            key = string({out.id}) + "|" + extractBefore(string({out.message}) + ":", ":");
            tc.verifyTrue(ismember("PCS9|telemetry for equipment the Site does not hold", key));
            tc.verifyTrue(ismember("PCS1|in the Site, but no tag observes it", key));
            tc.verifyTrue(ismember("PCS3|cannot be identified from operating data", key));
            tc.verifyTrue(ismember("SOFC01|sampled too slowly to identify (needs <= 0.05 s)", key));
            tc.verifyFalse(any(string({out.id}) == "PCS2"));
        end

        function test_ingest_rules_are_checked(tc)
            MgtwinTest.verifyThrows(tc, @() mgtwin.TagRule(pattern="^(?P<id>X)$", kind="widget", measurement="P"), "unknown kind");
            MgtwinTest.verifyThrows(tc, @() mgtwin.TagRule(pattern="^X\.(?P<meas>P)$", kind="converter", ...
                meas_map=dictionary("P", "P")), "named group 'id'");
            MgtwinTest.verifyThrows(tc, @() mgtwin.TagRule(pattern="^(?P<id>X)\.(?P<meas>P)$", kind="converter", ...
                meas_map=dictionary("P", "POWER")), "unknown measurement");
        end

        % -----------------------------------------------------------------
        % Protection functions, settings groups, screening (Python v0.6.8)
        % -----------------------------------------------------------------
        function test_protection_functions_are_validated(tc)
            PF = @(varargin) mgtwin.ProtectionFunction(varargin{:});
            MgtwinTest.verifyThrows(tc, @() PF(ansi="99X"), "unknown ANSI");
            MgtwinTest.verifyThrows(tc, @() PF(ansi="67N", pickup_a=50.0), "needs a direction");
            MgtwinTest.verifyThrows(tc, @() PF(ansi="87L"), "zone's buses");
            MgtwinTest.verifyThrows(tc, @() mgtwin.OvercurrentRelay(id="R", switch_id="SW", ct_ratio=600.0), ...
                "declares no protection element");
            MgtwinTest.verifyThrows(tc, @() MgtwinTest.twoBessSite(PF(ansi="87L", zone_buses=["B1", "NOPE"])), "unknown bus");
        end

        function test_a_legacy_relay_reads_as_one_phase_element(tc)
            r = mgtwin.OvercurrentRelay(id="R", switch_id="SW", ct_ratio=600.0, pickup_a=300.0, time_dial=0.3);
            e = r.elements();
            tc.verifyNumElements(e, 1);
            tc.verifyEqual(e.ansi, "51"); tc.verifyEqual(e.pickup_a, 300.0); tc.verifyTrue(e.activeIn("BLACKSTART"));
            r2 = mgtwin.OvercurrentRelay(id="R", switch_id="SW", ct_ratio=600.0, pickup_a=300.0, directional=true);
            tc.verifyEqual(r2.elements().ansi, "67");
        end

        function test_protection_gate_fails_an_unset_settings_group(tc)
            % The black-start state runs group BS; a relay set only for the
            % grid-connected group G leaves the breaker unprotected there.
            % Give it a low-set 51 in BS and the state is screened again.
            gridOnly = mgtwin.ProtectionFunction(ansi="51", pickup_a=1200.0, groups="G");
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(gridOnly, [], "BS"));
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.FAIL), ...
                "no element of relay R is active in settings group 'BS'"));
            both = [gridOnly, mgtwin.ProtectionFunction(ansi="51", pickup_a=200.0, groups="BS")];
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(both, [], "BS"));
            tc.verifyFalse(rep.failed());
            fs = rep.findings(contains(string({rep.findings.message}), "pickup available"));
            tc.verifyEqual(string({fs.scope}), "I1/R/51");
        end

        function test_protection_gate_names_magnitude_only_breakers(tc)
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(mgtwin.ProtectionFunction.empty(1,0), 150.0));
            w = rep.bySeverity(mgtwin.Severity.WARN);
            w = w(contains(string({w.message}), "current-limited converters"));
            tc.verifyNotEmpty(w); tc.verifySubstring(w(1).message, "rests on magnitude at R");
            unit = mgtwin.ProtectionFunction(ansi="87L", zone_buses=["B1", "B2"]);
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(unit, 150.0));
            tc.verifyFalse(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.WARN), "current-limited converters"));
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.PASS), "does not rest on magnitude alone"));
        end

        function test_protection_gate_wants_direction_both_sides(tc)
            % A genset beside BESS2 drives 6.7x its rating through SW into a
            % fault on B1: a non-directional 51 sees the through-fault; a 67 or
            % an 87L does not need the WARN. With converters alone on each side
            % the through-fault is within 1.5x their rating - a pickup above load
            % does not see it, and the gate says so in one PASS.
            none = mgtwin.ProtectionFunction.empty(1,0);
            function f = bothSides(rep)
                f = rep.bySeverity(mgtwin.Severity.WARN);
                f = f(contains(string({f.message}), "from both sides"));
            end
            w = bothSides(mgtwin.gateProtection(MgtwinTest.twoBessSite(none, 150.0, genset=true)));
            tc.verifyNumElements(w, 1);
            tc.verifySubstring(w.message, "the far side gives 2.1x its rated current");   % (5 x 1.2 + 1 / 0.15) / 6 MVA
            tc.verifyEmpty(bothSides(mgtwin.gateProtection(MgtwinTest.twoBessSite( ...
                mgtwin.ProtectionFunction(ansi="67", pickup_a=150.0, direction="forward"), [], "A", genset=true))));
            tc.verifyEmpty(bothSides(mgtwin.gateProtection(MgtwinTest.twoBessSite( ...
                mgtwin.ProtectionFunction(ansi="87L", zone_buses=["B1", "B2"]), 150.0, "A", genset=true))));
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(none, 150.0));
            tc.verifyEmpty(bothSides(rep));
            tc.verifyTrue(MgtwinTest.anyMessageContains(rep.bySeverity(mgtwin.Severity.PASS), "fed from both sides by converters only"));
        end

        function test_direction_screened_for_phase_and_earth_apart(tc)
            % A 67N covers earth through-faults, not phase ones: 51 + 67N on a
            % breaker fed from both sides still wants a 67 for phase faults; 67 +
            % 51N wants a 67N; 67 + 67N or an 87L wants nothing. Unset phase
            % pickups are named.
            PF = @(varargin) mgtwin.ProtectionFunction(varargin{:});
            function w = warns(fns)
                rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(fns, [], "A", genset=true, earthed=true));
                f = rep.bySeverity(mgtwin.Severity.WARN);
                f = f(contains(string({f.message}), "from both sides"));
                w = string({f.message}) + " | " + string({f.remedy});
            end
            w = warns([PF("ansi", "51", "pickup_a", 150.0), PF("ansi", "67N", "pickup_a", 40.0, "direction", "forward")]);
            tc.verifyNumElements(w, 1); tc.verifySubstring(w, "sees through-faults: phase"); tc.verifySubstring(w, "(67)");
            w = warns([PF("ansi", "67", "pickup_a", 150.0, "direction", "forward"), PF("ansi", "51N", "pickup_a", 40.0)]);
            tc.verifyNumElements(w, 1); tc.verifySubstring(w, "sees through-faults: earth"); tc.verifySubstring(w, "(67N)");
            tc.verifyEmpty(warns([PF("ansi", "67", "pickup_a", 150.0, "direction", "forward"), ...
                PF("ansi", "67N", "pickup_a", 40.0, "direction", "forward")]));
            tc.verifyEmpty(warns([PF("ansi", "51", "pickup_a", 150.0), PF("ansi", "87L", "zone_buses", ["B1", "B2"])]));
            rep = mgtwin.gateProtection(MgtwinTest.twoBessSite([PF("ansi", "51"), PF("ansi", "67N", "direction", "forward")]));
            u = rep.findings(string({rep.findings.scope}) == "I1/unset");
            tc.verifyNumElements(u, 1); tc.verifyEqual(u.severity, mgtwin.Severity.WARN);
            tc.verifySubstring(u.message, "1 phase overcurrent element(s) with no pickup set are not screened: R 51");
        end

        function test_board_87B_does_not_protect_the_circuit_leaving_it(tc)
            % 87B on a breaker's board covers one side of it: the circuit beyond
            % still rests on its overcurrent (named in the converter-dominance
            % WARN, and fed from both sides it wants direction). Zones on both
            % sides - an 87L, or a bus section between two 87B zones - cover it.
            PF = @(varargin) mgtwin.ProtectionFunction(varargin{:});
            function [mag, both] = screen(fns)
                m = mgtwin.gateProtection(MgtwinTest.twoBessSite(fns));
                b = mgtwin.gateProtection(MgtwinTest.twoBessSite(fns, [], "A", genset=true));
                mag = MgtwinTest.anyMessageContains(m.bySeverity(mgtwin.Severity.WARN), "rests on magnitude at R");
                both = MgtwinTest.anyMessageContains(b.bySeverity(mgtwin.Severity.WARN), "from both sides");
            end
            [mag, both] = screen([PF("ansi", "51", "pickup_a", 150.0), PF("ansi", "87B", "zone_buses", "B1")]);
            tc.verifyTrue(mag); tc.verifyTrue(both);
            [mag, both] = screen([PF("ansi", "51", "pickup_a", 150.0), PF("ansi", "87B", "zone_buses", "B1"), ...
                PF("ansi", "87B", "zone_buses", "B2")]);
            tc.verifyFalse(mag); tc.verifyFalse(both);
        end

        function test_backup_51_under_unit_protection_short_of_margin_warns(tc)
            % A 51 set above the load a circuit carries may have no margin over a
            % converter island's fault current. Where an 87L (or 87B zones on both
            % sides) covers the breaker's circuit in the state's group, that 51 is
            % the backup: a WARN pointing at breaker failure. Under its board's 87B
            % alone it is still the circuit's protection: FAIL.
            PF = @(varargin) mgtwin.ProtectionFunction(varargin{:});
            function [fail, warn] = screen(fns)
                rep = mgtwin.gateProtection(MgtwinTest.twoBessSite(fns));
                f = rep.bySeverity(mgtwin.Severity.FAIL);
                w = rep.bySeverity(mgtwin.Severity.WARN);
                fail = f(arrayfun(@(x) startsWith(x.scope, "I1/R"), f));
                warn = w(arrayfun(@(x) startsWith(x.message, "backup 51"), w));
            end
            hi = PF("ansi", "51", "pickup_a", 600.0);           % two 5 MVA BESS give ~630 A: ratio ~1.05
            [fail, warn] = screen([hi, PF("ansi", "87L", "zone_buses", ["B1", "B2"])]);
            tc.verifyEmpty(fail); tc.verifyNotEmpty(warn);
            tc.verifyTrue(contains(warn(1).message, "87L covers the circuit"));
            [fail, warn] = screen([hi, PF("ansi", "87B", "zone_buses", "B1"), PF("ansi", "87B", "zone_buses", "B2")]);
            tc.verifyEmpty(fail); tc.verifyTrue(contains(warn(1).message, "87B covers the circuit"));
            [fail, warn] = screen([hi, PF("ansi", "87B", "zone_buses", "B1")]);
            tc.verifyNotEmpty(fail); tc.verifyEmpty(warn);
            % the unit element must be active in the state's group to make the 51 a backup
            [fail, warn] = screen([hi, PF("ansi", "87L", "zone_buses", ["B1", "B2"], "groups", "G")]);
            tc.verifyNotEmpty(fail); tc.verifyEmpty(warn);
        end

        function test_envelope_partial_study_stays_provisional(tc)
            % A study that passed the cables it could compute but not the bus
            % breakers: provisional, naming the gap, even on identified models;
            % a partial study that finds a failure still puts the state outside.
            site = MgtwinTest.revcRebased();
            env = mgtwin.buildEnvelope(site, protection_studies=[ ...
                mgtwin.ProtectionStudyRecord(state_id="N1_PCS", tool="Electrisim", passed=true, models_identified=true, ...
                    complete=false, notes="bus-coupler breakers not studied"), ...
                mgtwin.ProtectionStudyRecord(state_id="NORMAL", tool="Electrisim", passed=false, complete=false)]);
            [v, why] = env.check("N1_PCS", "protection");
            tc.verifyEqual(v, mgtwin.Inside.PROVISIONAL);
            tc.verifyEqual(why, "the Electrisim study covers part of this state's protection only: bus-coupler breakers not studied");
            tc.verifyEqual(env.check("NORMAL", "protection"), mgtwin.Inside.OUTSIDE);
            tc.verifySubstring(env.render(), "| partial |");
        end

        function test_envelope_takes_protection_studies(tc)
            % A study supersedes the screening for the state it covers: failed
            % -> outside; passed on assumed converter models -> provisional,
            % naming the study; on identified models -> inside. States it does
            % not cover keep the screening's provisional verdict.
            path = string(tempname) + ".json";
            fid = fopen(path, "w");
            fprintf(fid, '%s', jsonencode({ ...
                struct("state_id", "NORMAL", "tool", "Electrisim", "passed", true, "reference", "C003 report Rev 6, s. 9"), ...
                struct("state_id", "N1_PCS", "tool", "Electrisim", "passed", true, "models_identified", true), ...
                struct("state_id", "MVA_BUS_FAULT", "tool", "Electrisim", "passed", false)}));
            fclose(fid);
            cleanup = onCleanup(@() delete(path));
            site = MgtwinTest.revcRebased();
            env = mgtwin.buildEnvelope(site, protection_studies=mgtwin.loadProtectionStudies(path));
            [v, why] = env.check("NORMAL", "protection");
            tc.verifyEqual(v, mgtwin.Inside.PROVISIONAL);
            tc.verifyEqual(why, "studied in Electrisim (C003 report Rev 6, s. 9) on assumed converter current limits and ride-through");
            [v, why] = env.check("N1_PCS", "protection");
            tc.verifyEqual(v, mgtwin.Inside.INSIDE); tc.verifyEmpty(why);
            [v, why] = env.check("MVA_BUS_FAULT", "protection");
            tc.verifyEqual(v, mgtwin.Inside.OUTSIDE); tc.verifySubstring(why(1), "Electrisim protection study");
            [v, why] = env.check("N1_SOFC", "protection");
            tc.verifyEqual(v, mgtwin.Inside.PROVISIONAL); tc.verifyTrue(any(contains(why, "ride-through assumed")));
            tc.verifySubstring(env.render(), "## Protection studies");
            tc.verifyTrue(env.toStruct().protection_studies.N1_PCS.passed);
            MgtwinTest.verifyThrows(tc, @() mgtwin.buildEnvelope(site, protection_studies= ...
                mgtwin.ProtectionStudyRecord(state_id="NOPE", tool="Electrisim", passed=true)), "does not enumerate");
        end

        function test_protection_findings_match_python_on_banshee(tc)
            % gateProtection on Banshee gives Python v0.6.9's findings exactly:
            % 13, with the three feeder heads fed from both sides in ISL_ALL -
            % the diesel on another feeder drives 5.6-6.7x its rating back.
            tc.assumeBanshee();
            P = banshee_paths();
            site = mgtwin.composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=P.MDL);
            rep = mgtwin.gateProtection(site);
            tc.verifyNumElements(rep.findings, 13);
            both = rep.findings(contains(string({rep.findings.message}), "from both sides"));
            tc.verifyEqual(string({both.scope}), ["ISL_ALL/R_F1_HEAD", "ISL_ALL/R_F2_HEAD", "ISL_ALL/R_F3_HEAD"]);
            tc.verifyEqual(both(1).message, "breaker SW_F1 is fed from both sides; relay R_F1_HEAD's non-directional " + ...
                "overcurrent sees through-faults: phase (the far side gives 6.7x its rated current)");
            tc.verifyEqual(both(1).remedy, "Add a directional element (67) or unit protection (87L) on this breaker.");
            f = rep.findings(string({rep.findings.scope}) == "ISL_F3/R_F2_HEAD");
            tc.verifyEqual(f.message, "fault current 581 A gives only 1.23x pickup, below the 1.5x dependability margin; operating time will be very long");
        end
    end
end
