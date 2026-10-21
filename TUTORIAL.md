# Using the mgtwin digital twin: a tutorial

This guide walks through one complete pass of the pipeline on a small
microgrid. The companion script [`examples/tutorial.m`](examples/tutorial.m)
contains every line of code below in runnable form; open it in MATLAB and
step through it with Ctrl+Enter.

The twin is not a simulator you press "run" on. It is a staged, gated
authoring pipeline: you describe the plant, the gates tell you what in the
description cannot be trusted, you quantify and fix, you identify the
parameters you assumed, and only then you run the compliance-shaped test
suite. Each stage produces an artifact you can read and sign.

```
compose  ->  verify (gates)  ->  quantify  ->  identify  ->  test  ->  import real data
```

## 0. Setup

```matlab
addpath("C:\PJWork\MATLAB APPs\mgtwin-matlab")   % the folder containing +mgtwin
import mgtwin.*
```

Everything lives in the `mgtwin` package. With the `import`, `Bus(...)`
means `mgtwin.Bus(...)`.

## 1. Compose: describe the microgrid

### The base first

```matlab
base = Base(s_base_mva=10, v_base_kv=11, f_base_hz=50);
```

Nothing in mgtwin carries an implicit base. Most defects in composed
models are a factor of 1000 or sqrt(3), so every impedance says which base
it refers to and the units gate checks them.

### Buses, transformer, feeder, switches

```matlab
buses = [Bus(id="BUS_UTIL", v_nom_kv=33, is_poi=true)
         Bus(id="BUS_MV",   v_nom_kv=11)
         Bus(id="BUS_LOAD", v_nom_kv=11)];

tx = Transformer(id="TX1", hv_bus="BUS_UTIL", lv_bus="BUS_MV", s_rated_mva=15, ...
    hv_kv=33, lv_kv=11, x_pu=0.08, r_pu=0.006, ...
    hv_config=WindingConfig.WYE_GROUNDED, lv_config=WindingConfig.DELTA);

feeder = Branch(id="FDR1", from_bus="BUS_MV", to_bus="BUS_LOAD", ...
    r_pu=0.012, x_pu=0.028, s_base_mva=10, v_base_kv=11, rating_mva=12);

switches = [Switch(id="SW_PCC", from_bus="BUS_UTIL", to_bus="BUS_MV", is_pcc=true)
            Switch(id="SW_MV",  from_bus="BUS_MV",   to_bus="BUS_LOAD")];
```

Winding configuration is required, not optional. It decides where
zero-sequence current can flow, which is what the grounding gate reasons
about. A grounded-wye on the utility side with a delta on the microgrid
side is the most common arrangement, and it means the microgrid has no
zero-sequence source of its own once it islands.

### Sources

```matlab
bess = Converter(id="BESS_1", bus="BUS_MV", s_rated_mva=5, ...
    control=ConverterControl.GFM_DROOP, ...
    params=ConverterParams(p_f_droop_pu=0.05, h_sec=2.0, tp_sec=0.20, ...
        i_limit_transient_pu=1.2, ride_through_identified=false), ...
    energy_mwh=10);
pv = Converter(id="PV_1", bus="BUS_LOAD", s_rated_mva=3, ...
    control=ConverterControl.GFL, params=ConverterParams(tp_sec=0.05));
diesel = SynchronousGen(id="DG_1", bus="BUS_MV", s_rated_mva=2, h_sec=1.2, ...
    xd_subtransient_pu=0.18, droop_pu=0.04);
```

`ConverterParams` follows the WECC generic model shape. The field that
matters most is `ride_through_identified`. Leave it `false` until you have
measured the inverter's fault behaviour. The honesty gate will keep
reminding you, which is the point.

A converter is modelled as a current-limited source, not a voltage source
behind reactance. Its islanded fault contribution is rated current times
`i_limit_transient_pu`, typically 1.1 to 1.5 pu, not the 5 to 10 pu of a
synchronous machine.

### Loads, grounding, protection, islands

```matlab
loads = [Load(id="LD_CRIT", bus="BUS_LOAD", p_mw=2.5, q_mvar=0.8, critical=true)
         Load(id="LD_GEN",  bus="BUS_LOAD", p_mw=3.5, q_mvar=1.1)];

grounding = GroundingSource(id="G_UTIL", bus="BUS_UTIL", kind=GroundingKind.SOLID, ...
    available_when_islanded=false);

relay = OvercurrentRelay(id="R_MV", switch_id="SW_MV", ct_ratio=600, pickup_a=600, time_dial=0.3);

islands = [IslandConfig(id="GRID",  grid_connected=true,  energized_source_ids=["BESS_1","PV_1","DG_1"])
           IslandConfig(id="ISL_1", grid_connected=false, open_switches="SW_PCC", ...
                        energized_source_ids=["BESS_1","PV_1","DG_1"])
           IslandConfig(id="ISL_2", grid_connected=false, open_switches="SW_PCC", ...
                        energized_source_ids=["BESS_1","PV_1"])];
```

Three things to notice.

- **Grounding is an entity.** `available_when_islanded=false` records that
  the utility neutral is upstream of the PCC and disappears on islanding.
- **Relay pickup is in primary amperes**, as set in the field. Converting
  is where errors enter, so the model stores what the relay stores.
- **Islands are enumerated.** Gates run per island. A site that passes
  grid-connected and fails when the genset is on outage is exactly the
  finding you want before energization.

### Assemble

```matlab
site = Site(id="TUTORIAL_MG", base=base, buses=buses, branches=feeder, ...
    transformers=tx, switches=switches, relays=relay, converters=[bess; pv], ...
    machines=diesel, loads=loads, grounding=grounding, islands=islands);
```

The constructor validates everything: required fields, cross-field rules
(a grid-forming converter must declare a droop gain, a "solid" ground
cannot have 25 ohms in it), and referential integrity (every referenced
bus, switch and source exists). A bad model errors here, with
`mgtwin:ValidationError`, not three stages later.

## 2. Verify: run the gates

```matlab
report = runAllGates(site);
disp(report.render())
report.failed()        % true if any FAIL
```

Rendered findings are sorted FAIL, WARN, PASS. On this site you get:

```
FAIL grounding [ISL_1/zone(11kV:BUS_LOAD,BUS_MV)]: no zero-sequence source in this zone; ...
FAIL grounding [ISL_2/zone(11kV:BUS_LOAD,BUS_MV)]: no zero-sequence source in this zone; ...
FAIL protection [ISL_2/R_MV]: available islanded fault current 504 A is below pickup 600 A ...
WARN protection [ISL_2]: 100% of islanded fault current comes from current-limited converters ...
WARN honesty [BESS_1]: current-limit / ride-through behaviour was assumed ...
...
PASS grounding [GRID/zone(...)]: zero-sequence source present
PASS protection [ISL_1/R_MV]: 1.8x pickup available when islanded
```

How to read it:

- **FAIL is a safety finding.** The two grounding FAILs say that every
  islanded 11 kV zone has no ground reference, so a single-line-to-ground
  fault will push the healthy phases toward 1.73 pu and no neutral current
  exists for a ground relay to see. The protection FAIL says a 600 A pickup
  is unreachable when the sources are two converters limited to 1.2 pu.
- **WARN is an honesty or plausibility finding.** It does not block, but it
  travels with every downstream number.
- **Zones, not islands.** A delta winding splits an island into
  independent zero-sequence zones. The gate names the zone by voltage
  class and buses so you can see which level floats.

You can also run a single gate and filter:

```matlab
g = gateGrounding(site);
g.bySeverity(Severity.FAIL)
```

### Remediate and re-run

`Site` is a value class, so a copy is an independent scenario:

```matlab
site2 = site;
site2.grounding(end+1) = GroundingSource(id="G_ZZ", bus="BUS_MV", ...
    kind=GroundingKind.LOW_RESISTANCE, z0_ohm=12, available_when_islanded=true);
site2.relays(1).pickup_a = 150;     % islanded settings group
report2 = runAllGates(site2);
report2.failed()                    % false
```

The honesty warnings survive remediation on purpose. No relay setting can
be trusted until the converters' fault behaviour is measured rather than
assumed, and the report keeps saying so.

## 3. Quantify: what an ungrounded island costs

The gate says "no zero-sequence source". `slgFault` says what that means.

```matlab
z1 = 1i * 0.18 * (base.s_base_mva / diesel.s_rated_mva);   % Xd'' rebased to site base

r = slgFault(z1, z0_pu=[]);                    % [] means no zero-sequence path
disp(r.render(i_base_a=base.i_base_a))
%   fault current  : ~0 (capacitive charging only)
%   max unfaulted  : 1.732 pu

z0 = 3 * zigzagZ0Pu(12, 11, base.s_base_mva) + 1i * 0.10;
r = slgFault(z1, z0_pu=z0);
disp(r.render(i_base_a=base.i_base_a))
%   fault current  : 0.850 pu = 446 A
%   max unfaulted  : 1.862 pu
```

The lesson worth remembering: low-resistance grounding buys
**detection** (hundreds of amperes for a 51G element) but not
overvoltage relief. A resistive Z0 against a reactive Z1 rotates the
unfaulted phasors and can push the worst phase past sqrt(3). Insulation
coordination is a separate design decision. `examples/banshee_slg.m` adds
the third corner of the triangle, effective grounding.

## 4. Identify: fit converter parameters from a step response

The library model is a grid-forming converter feeding an islanded load:

```matlab
[omega_pm] = simulateGfm(t, p_load, rp_pu, tp_sec, h_sec)   % columns [omega_pu, Pm_pu]
```

In practice you load a PMU record of a load-step test. The tutorial
manufactures one from a known truth so the answer can be checked:

```matlab
[t, p] = loadStep(t_end=8, dt=0.002, t_step=1, p_before=0.20, p_after=0.50);
truth = simulateGfm(t, p, 0.05, 0.20, 2.0);
idx = (1:10:numel(t))';                                    % 50 samples/s
y_meas = truth(idx, 1) + 2e-4 * randn(numel(idx), 1);      % omega_pu with noise
```

Identification needs three things: a predictor, a starting guess, and
bounds. The predictor is a function handle from a parameter struct to a
prediction the size of the measurement.

```matlab
predict = @(theta) tutorialPredict(t, p, idx, theta.rp_pu, theta.tp_sec, 2.0);
theta0  = struct("rp_pu", 0.03, "tp_sec", 0.40);
bounds  = struct("rp_pu", [0.005 0.20], "tp_sec", [0.01 2.0]);

res = identify(predict, y_meas, theta0, bounds);
disp(res.render())
```

```
verdict: IDENTIFIED
  parameter       estimate     std err    rel se
  rp_pu           0.050007    2.34e-05     0.0%
  tp_sec           0.20136     0.00206     1.0%
  cond(scaled sensitivity) = 2.280e+01
  residuals: white | Ljung-Box Q=28.9 (p=4.96e-02), ...
```

The result carries an estimate **and a verdict**, and the verdict is what
you act on:

| Verdict | Meaning | What to do |
|---|---|---|
| `IDENTIFIED` | white residuals, well-conditioned, tight intervals | use `res.thetaStruct()` |
| `WEAKLY_IDENTIFIED` | some parameter has > 20% relative standard error | usable for trend, not a setting |
| `NOT_IDENTIFIABLE` | the experiment cannot separate the parameters | change the instrumentation or stimulus |
| `STRUCTURAL_MISMATCH` | residuals are structured; the model form is wrong | add the missing mechanism |

### When the identifier refuses

Give it data from a plant with a ramp limiter the model does not contain:

```matlab
truth = simulateGfm(t, p, 0.05, 0.20, 2.0, ramp_limit_pu_s=0.30);
res = identify(predict, truth(idx,1) + noise, theta0, bounds);
```

```
verdict: STRUCTURAL_MISMATCH
  tp_sec           0.55936     0.00845     1.5%
  residuals: STRUCTURED | Ljung-Box Q=3569.4 (p=0.00e+00), ...
```

The interval reads 1.5% and the estimate is 180% wrong. Whiteness is
tested first and overrides the intervals, because a tight interval on a
misspecified model is worse than no answer: it converts an unknown into a
false certainty that then lands in a protection study.

### The two-amplitude protocol

Some mismatches (governor deadband, output clamps, piecewise droop) are
invisible on any single trajectory. They look like a different parameter
value with white residuals. The only cure is a second experiment at a
different amplitude and a consistency demand:

```matlab
exps = { {predict_large, y_large}, {predict_small, y_small} };
multi = identifyMulti(exps, theta0, bounds);
disp(multi.render())
```

On a plant with a deadband the single fit says `IDENTIFIED` with the droop
17% off; `identifyMulti` says `STRUCTURAL_MISMATCH`. The commissioning
rule that follows: a load-step test must be run at two amplitudes minimum.
`examples/rung4_identifiability_evals.m` measures this across nine
adversarial plants.

## 5. Test: run the controller suite on an island

Test definitions are versioned data shaped after IEEE 2030.8-2018:

```matlab
suite = loadSuite("ieee2030_8_2018");     % 9 cases
```

Limits are never invented. Supply the ones your interconnection agreement
or project spec defines, keyed `"<case_id>/<metric>"`:

```matlab
limits = dictionary( ...
    ["ISL-P-01/frequency_nadir_deviation", "ISL-U-01/frequency_nadir_deviation", ...
     "ISL-U-01/rocof_peak", "SS-01/steady_state_frequency_band"], ...
    [0.5, 2.0, 3.0, 2.5]);

run = runSuite(site, suite, "ISL_1", project_limits=limits);
disp(run.render())
run.counts()
run.byCaseId("PROT-01")
```

Every case ends in one of three states, and the report says which and why:

- **EXECUTED** with a verdict of PASS, FAIL or INDETERMINATE. A criterion
  with no limit is left UNEVALUATED with its measured value shown.
  A PASS on assumed dynamic parameters carries a note saying so; section 4
  is what discharges that note.
- **BLOCKED**, with the gate findings attached. On the unremediated site
  PROT-01 is blocked because the grounding gate already answered it.
- **DEFERRED**, with the tier named: black start and power quality need
  EMT; dispatch and reconnection need models this harness does not have.

On the tutorial site the unplanned-islanding case FAILs on ROCOF at
3.4 Hz/s against a 3 Hz/s example limit. That FAIL is the deliverable: it
is the engineering to-do list (a load-shed scheme) with a number on it.

## 6. Import: composing from real data

For a real network you compose from machine-readable sources instead of
typing entities:

```matlab
P = banshee_paths();                       % locates the EPHCC data pack
site = composeBanshee(P.CASE_V5, relay_dir=P.RELAYS, mdl_path=P.MDL);
```

`composeBanshee` reads a MATPOWER case for buses, branches and loads, relay
spreadsheets for pickups, and transformer winding configurations out of a
Simulink `.mdl`. It records what those sources cannot provide: converter
control parameters are entered as assumptions with
`ride_through_identified=false`, so the honesty gate flags every one. Then
sections 2 to 5 apply unchanged. `examples/banshee_rung1.m` and
`banshee_rung3.m` are the full walkthroughs.

To import your own site, follow the same shape: build a `mgtwin.Site` from
whatever you can read mechanically, and leave undeclared what the data
does not contain. The gates will tell you what is missing. That is the
finding, not a failure of the import.

## Where to go next

| Script | What it shows |
|---|---|
| `examples/demo.m` | gates on a defective then remediated site, four identification verdicts |
| `examples/ieee4_rung2.m` | the unbalanced solver verified against the IEEE 4-node feeder |
| `examples/banshee_slg.m` | the grounding design triangle with numbers |
| `examples/rung4_identifiability_evals.m` | the adversarial identification battery |
| `tests/MgtwinTest.m` | every behaviour above pinned as a regression test |

Three rules the package will not let you break: no invented limits, no
solvers written ad hoc, and no confidence the data has not earned.
