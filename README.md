# mgtwin (MATLAB)

MATLAB port of `mgtwin` v0.6.8 -- staged, gated authoring of microgrid
digital twins. The Python original (pydantic + numpy + scipy) is reproduced
module for module as a MATLAB package `+mgtwin`; the design decisions,
gate logic, identification honesty rules, unbalanced solver, fault module,
test runner and adversarial eval battery are all carried over. Read the
Python README for the engineering rationale; this file covers the port.

Requires MATLAB R2021a or newer (`name=value` syntax, `dictionary` needs
R2022b+; developed and tested on R2024a) and **Optimization Toolbox**
(`lsqnonlin`, used only by `mgtwin.identify`). Everything else is base
MATLAB. The Banshee rung-1 example additionally needs
[MATPOWER](https://matpower.org) on the path as the external power-flow
solver (the Python original uses pandapower for the same job).

New here? Start with [TUTORIAL.md](TUTORIAL.md) and its runnable companion
`examples/tutorial.m`, which walk the whole pipeline on a small microgrid.

```matlab
addpath("mgtwin-matlab")            % the folder containing +mgtwin
runtests("tests/MgtwinTest.m")      % 76 tests; the 7 Banshee ones skip without data
site = mgtwin.siteFromJson("examples/c003_revC_site.json");   % a Site written by Python's mgtwin
disp(mgtwin.runAllGates(site).render())                      % all seven gates
env = mgtwin.buildEnvelope(site); disp(env.render())         % stage 6: where the twin is valid
[v, why] = env.check("NORMAL", "frequency", step_pu=0.3)     % INSIDE / PROVISIONAL / OUTSIDE + reasons
cd examples; demo                   % gates + identification A/B/C/D
ieee4_rung2                          % rung 2: IEEE 4-node verification
banshee_slg                          % rung 2: SLG grounding design triangle
rung4_identifiability_evals          % rung 4 battery, 5 seeds x 9 scenarios x 2 protocols, ~1 min
```

## Layout

```
+mgtwin/                 the package (Python module -> MATLAB files)
  units      Base, PowerSign, AngleRef, plausibleRanges, checkPlausible
  ontology   Bus, Branch, Transformer, WindingConfig, Switch, OvercurrentRelay,
             Converter, ConverterControl, ConverterParams, SynchronousGen,
             Load, LoadModel, GroundingSource, GroundingKind, IslandConfig, Site
  gates      Severity, Finding, GateReport, gateForming, gateUnits, gateGrounding,
             gateProtection, gateModelHonesty, gateEnergisation, gateLoading,
             runAllGates (+internal/sections, +internal/zoneName)
  json       siteFromJson, siteFromStruct (Python's model_dump_json -> Site)
  models     simulateGfm, loadStep, frequencyHz
  identify   Verdict, WhitenessResult, assessWhiteness, IdentificationResult,
             identify, MultiIdentificationResult, identifyMulti, identifyConstants
  unbalanced LineSegment, TransformerGYGY, TransformerDGY, RadialFeeder,
             polar, balancedSourceLn
  fault      SLGResult, slgFault, zigzagZ0Pu
  testspec   CoreFunction, Criterion, TestCase, TestSuite, loadSuite,
             availableSuites, specs/ieee2030_8_2018.json (+ original .yaml)
  testrun    CaseStatus, CaseVerdict, ParamProvenance, MetricValue,
             CriterionResult, TestResult, RunReport, evaluateCriterion, judge
  runner     runSuite  (+internal/aggregateSource, +internal/islandLoadMw)
  truthgen   PlantParams, simulatePlant, Scenario, battery, scenarioByName,
             makeMeasurement
  evals      EvalRun, EvalReport, evalConstants, evalExperiment, runOne, runBattery
  io         loadMatpowerCase (matpower_io), MdlTransformer,
             extractMdlTransformers (mdl_io), composeBanshee (banshee)
  +internal  requireFields, zeroSequenceZones, fmtThousands, specDir, ...
examples/                demo, ieee4_rung2, banshee_slg, rung4_identifiability_evals,
                         banshee_rung1, banshee_rung3, plus shared helpers
tests/MgtwinTest.m       matlab.unittest port of tests/test_mgtwin.py
```

## What's new since the v0.6.0 port (Python v0.6.1-v0.6.8)

* **Declared IT grounding (v0.6.1).** A `GroundingSource` of kind
  `UNGROUNDED` is a design declaration, not a zero-sequence source: its zone
  WARNs with the ground-detector requirement instead of FAILing.
* **Forming gate (v0.6.2).** `gateForming`: every electrical section of
  every islanded state needs a grid-forming source.
* **Energisation gate (v0.6.3).** `gateEnergisation`: transformers a state
  switches in together (`IslandConfig.energise_transformer_ids`) must fit
  their summed inrush (`Transformer.inrush_pu`, ASSUMED unless
  `inrush_identified`) inside the forming sources' current headroom. A step
  that no energised source reaches FAILs as "the step energises nothing".
* **Loading gate and reactance check (v0.6.4).** `gateLoading`: per
  energised section, FAIL when the load exceeds every source's rating, WARN
  when it runs on storage, FAIL for a transformer feeding more than its
  rating on a side with no source. `gateUnits` FAILs transformer reactances
  outside 0.02-0.25 pu on their own rating (`plausibleRanges().tx_x_pu`).
* **Switch states (v0.6.5).** `IslandConfig.closed_switches` lists the
  normally open switches a state closes; `site.openSwitchIds(isl)` gives every
  gate one reading (open if the state opens it, or normally open and not
  closed). A state that both opens and closes a switch, or names an unknown
  one, fails validation.
* **JSON Sites.** `mgtwin.siteFromJson` reads a Site as Python writes it;
  `examples/c003_revC_site.json` (CAMPAIGN-003 Rev C) gives the same 394
  findings as Python's `run_all`, gate by gate, scope by scope and message by
  message.
* **Banshee transformers paired by impedance (Python v0.6.7).**
  `composeBanshee` copied the MATPOWER branch impedance (system base) into
  `Transformer.x_pu` (own rating), and paired each branch with an .mdl
  rating in list order. It now pairs the .m's transformer branches with the .mdl's instances by impedance (one-to-one within each voltage class, ties in order) and rebases their pu impedance to the paired unit's own rating;
  `mgtwin.transformerPairing` lists the pairs for review. Three branches
  match no instance (TX_30_40, TX_80_110, TX_50_60, 32-51 % apart) and take
  their class's remaining unit. Pairs identical to Python's.
* **Stage 1, tag ingest (v0.6.6).** `mgtwin.ingestTags(tags, rules)` maps a
  SCADA/historian tag list (`mgtwin.readTags`, CSV) to canonical entities and
  measurements through the site's own naming rules (`mgtwin.TagRule`, or
  `mgtwin.loadRules` from JSON; Python's `(?P<name>...)` tokens accepted, and
  like `re.match` a pattern matches from the tag's start). Every tag is
  MATCHED / UNMATCHED / AMBIGUOUS / DUPLICATE, units are checked and scaled;
  `mgtwin.compareWithSite` reports telemetry without equipment, equipment
  without telemetry, and sources that cannot be identified from operating
  data. On the parity set the render, every tag result and every comparison
  finding are identical to Python's.
* **Stage 6, the validity envelope (v0.6.6, v0.6.8).** `mgtwin.buildEnvelope`
  declares where the twin is valid; `Envelope.check(state, phenomenon,
  load_mva=, step_pu=)` answers `mgtwin.Inside` INSIDE / PROVISIONAL /
  OUTSIDE with the reasons; `render` (Markdown) and `toJson` give the
  artifact. `mgtwin.IdentificationRecord` bounds steps to the identified
  amplitudes; `mgtwin.ProtectionStudyRecord` (`mgtwin.loadProtectionStudies`,
  JSON) lets a protection study (Electrisim) supersede the screening for
  the states it covers. On Rev C - as given, rebased, and with records and
  studies - three renders and 48 check answers are identical to Python's.
* **Protection functions and settings groups (v0.6.8).** A relay carries a
  list of `mgtwin.ProtectionFunction`s (ANSI code, primary-amp pickup,
  direction, curve, settings groups, unit-protection zone buses; a 67 needs
  a direction, an 87 its zone); the legacy pickup fields still declare one
  51 / 67 element active in every group. `IslandConfig.settings_group`
  (default "A") picks the group a state runs. `gateProtection` screens, on
  the elements active in that group: breakers with nothing active (FAIL),
  phase pickups against converter-limited fault current (FAIL), breakers
  whose primary protection rests on magnitude alone in converter-dominated
  states (WARN, PASS when none), and breakers fed from both sides with only
  non-directional overcurrent (WARN). On Banshee its 13 findings are
  identical to Python's - including the three feeder heads fed back by the
  other feeders' DER in ISL_ALL. `mgtwin.version()` gives the Python release
  the port is at parity with.

## Conventions of the port

* **Names.** Data fields keep the Python `snake_case` names so the ontology
  reads the same in both languages (`site.base.s_base_mva`,
  `c.params.ride_through_identified`). Functions and methods are
  `camelCase` per MATLAB style: `gate_units` -> `mgtwin.gateUnits`,
  `run_all` -> `mgtwin.runAllGates`, `identify_multi` ->
  `mgtwin.identifyMulti`, `fault_contribution_a` -> `faultContributionA`.
  Two Python field names are MATLAB keywords and are renamed:
  `TestCase.function` -> `core_function`, `TestResult.case` -> `test_case`.
* **Construction.** Entities are constructed with name-value arguments,
  exactly like the pydantic models: `mgtwin.Bus(id="B1", v_nom_kv=11)`.
  Required fields are enforced (`mgtwin:ValidationError`), cross-field
  validators run in the constructor, and referential integrity is checked
  when a `Site` is built. Zero-argument construction is allowed only so
  MATLAB can grow object arrays; such objects are not valid models.
* **None.** Optional values are `[]` (`p_f_droop_pu`, `h_sec`,
  `i_limit_steady_pu`, `Criterion.limit`, `z0_pu`, `ramp_limit_pu_s`).
* **Value vs handle.** Entities and results are value classes; the
  accumulating containers `GateReport`, `TestResult`, `RunReport`,
  `EvalReport` are handle classes. `Site` is a value class, so the Python
  `site.model_copy(deep=True)` is simply `site2 = site`.
* **Enums** carry the Python string in `.Value`
  (`mgtwin.Severity.FAIL.Value == "fail"`).
* **Dicts.** Parameter vectors are structs (`struct("rp_pu", 0.03,
  "tp_sec", 0.4)`; bounds are `[lo hi]` per field). Project limits for
  `runSuite` are a `dictionary` keyed `"<case_id>/<metric>"`.
  Multi-experiment inputs are `{ {predict, y}, {predict, y} }`.
* **Predictors** are function handles taking a theta struct and returning a
  column vector; see `examples/demo.m` or `mgtwin.evalExperiment` for the
  pattern (a small named function replaces the Python closure).
* **Test specs** live in JSON rather than YAML (R2024a has no YAML reader;
  the original YAML is kept alongside for provenance). Content is identical.
* **MATPOWER cases** are executed directly (`mgtwin.loadMatpowerCase`)
  instead of being parsed by a mini-interpreter: the case file is MATLAB.
* **Random numbers.** Seeds map to `RandStream("mt19937ar", "Seed", s)`;
  the streams differ from numpy's `default_rng`, so noisy figures in the
  demo differ in the last digits from the Python printout. Every verdict
  and every regression assertion reproduces.
* **Least squares.** `scipy.optimize.least_squares(method="trf",
  x_scale="jac")` -> `lsqnonlin` with the trust-region-reflective
  algorithm, bounds, and tight tolerances; the Jacobian returned by
  `lsqnonlin` feeds the Fisher information exactly as in the original.
  Chi-square and normal tails use `gammainc(...,"upper")` and `erfc`, so
  no Statistics Toolbox is needed.

## What was verified here

`tests/MgtwinTest.m` ports every pytest case, including the ones that
matter most: the gates that must FAIL, `STRUCTURAL_MISMATCH` overriding
tight intervals, `NOT_IDENTIFIABLE` on historian-grade data, the IEEE
4-node solutions within 2 V / 0.15 deg, the exact 30-degree DYg shift and
zero-sequence blocking, the LRG-exceeds-sqrt(3) lesson, the runner's
BLOCKED / DEFERRED / UNEVALUATED taxonomy (exercised on the demo site,
since it does not need the Banshee release), the single-experiment
amplitude blind spot, and the multi-amplitude protocol closing it.

Example outputs reproduce the Python README's numbers: the IEEE 4-node
solutions agree to 0.6 V / 0.05 deg; the SLG design triangle gives 605 A
at 1.872 pu (12-ohm zig-zag) and 798 A at 1.159 pu (effective grounding);
the demo's case D lands at +180% on `tp_sec` with 1.5% intervals and is
refused as `STRUCTURAL_MISMATCH`. The rung-4 battery (5 seeds) measures a
28.9% false-confidence rate for the single-experiment protocol (Python:
33%; the difference is the noise stream, the blind spot is the same --
deadband, saturation and knee-droop all pass whiteness) and 0.0% for the
multi-amplitude protocol with 2.2% over-refusal, in about 40 s.

Banshee-dependent tests and examples (`banshee_rung1`, `banshee_rung3`)
need the EPHCC data pack (`banshee_data_for_rung1_v2.zip`, unzipped as a
`banshee_data` folder next to this repository, or anywhere with
`BANSHEE_DATA` pointing at its "00 models and data for system verification"
folder). With it, the composition test pins the same finding as the Python
original -- 22 DYg transformers, exactly four grounding FAILs, all on the
islanded 13.8 kV zones -- and rung 3 on ISL_F1 reads 3 executed (ISL-P-01
PASS at 0.29 Hz, SS-01 PASS at a 2.30 Hz band, ISL-U-01 FAIL at 2.57 Hz /
4.9 Hz/s), 1 blocked, 5 deferred, with PROT-01 unblocking into an
INDETERMINATE screening at 1.88 pu after the zig-zag. Every transformer's
reactance, paired by impedance and rebased, is 0.037-0.074 pu on its own
rating, so the units gate passes Banshee. Rung 1a (the
cross-tool current table) and its test need MATPOWER's `runpf` on the path
and skip with a notice otherwise; with MATPOWER 8.0 they reproduce the
Python result exactly: 28 of 32 scored meters to machine precision, mean
deviation 0.49% against a published five-tool spread of 4.49% mean / 7.10%
max, the same four bus-9-subtree deviations, and the +3.5% v5 load-model
offset.

## Not in scope, as in the original

No network solver beyond the verified radial ladder; no invented limits;
no normative standard text (the `clause` field is blank by design).
