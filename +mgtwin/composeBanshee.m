function site = composeBanshee(case_path, opts)
%COMPOSEBANSHEE Compose the Banshee benchmark into a canonical Site.
%
%   site = mgtwin.composeBanshee(case_path, relay_dir=..., mdl_path=...)
%
%   Sources, in decreasing order of authority:
%     1. case_banshee_feeder_all_v5.m  -- machine-readable network (EPHCC release)
%     2. F{1,2,3} relay spreadsheets   -- real settings (same release)
%     3. Paper-level documentation     -- DER placement and ratings
%
%   What each source CANNOT provide is recorded rather than papered over:
%     * The MATPOWER case is positive-sequence. It carries NO winding
%       configurations and NO grounding information. Without mdl_path,
%       grounding is left UNDECLARED and gateGrounding is expected to FAIL
%       on the islanded configurations. That failure is the correct output.
%     * DER control parameters are NOT in the release in machine-readable
%       form. They are entered as paper-level assumptions with
%       ride_through_identified=false, so gateModelHonesty flags every one.
%
%   Bus numbering follows the case file: feeder 1 = 1..15, feeder 2 =
%   20..150 (tens), feeder 3 = 200..1200 (hundreds). Bus 1 is the 13.8 kV
%   substation bus (slack); bus 13 carries the diesel genset; bus 110 the
%   PV inverter.
arguments
    case_path (1,1) string
    opts.relay_dir string = string.empty
    opts.mdl_path string = string.empty
end
import mgtwin.*

% DER placement, from the paper and the RTDS description. Ratings are
% documentation-level facts; control parameters are assumptions.
DIESEL_BUS = 13;   DIESEL_MVA = 4.0;   % RTDS description: "4MW DIESEL GEN"
PV_BUS = 110;      PV_MVA = 1.0;       % assumed order of magnitude
CHP_BUS = 800;     CHP_MVA = 2.5;      % RTDS description transformer rating near the CHP
FEEDER_HEAD_BUSES = [1 2; 2 20; 3 200];   % feeder -> first bus downstream of substation

mpc = loadMatpowerCase(case_path);
bus_m = mpc.bus; branch_m = mpc.branch;
base = Base(s_base_mva=mpc.baseMVA, v_base_kv=13.8, f_base_hz=60.0);

kv_of = dictionary(bus_m(:, 1), bus_m(:, 10));

buses = Bus.empty(0,1);
loads = Load.empty(0,1);
for k = 1:size(bus_m, 1)
    n = bus_m(k, 1);
    buses(end+1, 1) = Bus(id=sprintf("B%d", n), v_nom_kv=bus_m(k, 10), is_poi=(n == 1)); %#ok<AGROW>
    if bus_m(k, 3) > 0 || bus_m(k, 4) ~= 0
        loads(end+1, 1) = Load(id=sprintf("LD_B%d", n), bus=sprintf("B%d", n), ...
            p_mw=bus_m(k, 3), q_mvar=bus_m(k, 4)); %#ok<AGROW>
    end
end

% Branch rows: every row becomes a Branch (power-flow-exact, pu on the
% system base with the ratio absorbed by the differing bus voltage bases).
% Rows spanning voltage levels ADDITIONALLY become Transformer entities
% when winding data is available from the OPAL-RT model (mdl_path).
branches = Branch.empty(0,1);
for k = 1:size(branch_m, 1)
    f = branch_m(k, 1); t = branch_m(k, 2);
    is_tx = kv_of(f) ~= kv_of(t);
    if is_tx, id = sprintf("TX_%d_%d", f, t); else, id = sprintf("LN_%d_%d", f, t); end
    if branch_m(k, 6) > 0, rating = branch_m(k, 6); else, rating = mpc.baseMVA; end
    branches(end+1, 1) = Branch(id=id, from_bus=sprintf("B%d", f), to_bus=sprintf("B%d", t), ...
        r_pu=branch_m(k, 3), x_pu=branch_m(k, 4), b_pu=branch_m(k, 5), ...
        s_base_mva=mpc.baseMVA, v_base_kv=13.8, rating_mva=rating); %#ok<AGROW>
end

transformers = Transformer.empty(0,1);
grounding = GroundingSource.empty(0,1);
if ~isempty(opts.mdl_path)
    insts = extractMdlTransformers(opts.mdl_path);
    insts = insts(~arrayfun(@(t) t.isHilArtifact(), insts));
    % Branch-to-instance pairing within a voltage class, by impedance (the
    % rating feeds the units and loading gates): see pairByImpedance.
    paired = mgtwin.internal.pairByImpedance(branches, kv_of, insts, mpc.baseMVA);
    conn_map = dictionary(["delta", "wye_grounded"], [WindingConfig.DELTA, WindingConfig.WYE_GROUNDED]);
    for k = 1:numel(branches)
        br = branches(k);
        if ~startsWith(br.id, "TX_"), continue; end
        f = double(extractAfter(br.from_bus, 1)); t = double(extractAfter(br.to_bus, 1));
        kv_f = kv_of(f); kv_t = kv_of(t);
        if kv_f >= kv_t
            hv_bus = br.from_bus; lv_bus = br.to_bus;
        else
            hv_bus = br.to_bus; lv_bus = br.from_bus;
        end
        hv_kv = max(kv_f, kv_t); lv_kv = min(kv_f, kv_t);
        inst = [];
        if isKey(paired, br.id), inst = paired{br.id}; end
        if isempty(inst)
            s_rated = 1.0; hv_cfg = WindingConfig.DELTA; lv_cfg = WindingConfig.WYE_GROUNDED;
        else
            s_rated = inst.kva / 1e3; hv_cfg = conn_map(inst.hv_connection); lv_cfg = conn_map(inst.lv_connection);
        end
        % The branch's pu impedance is on the case's system base; a
        % Transformer's is on its own rating (gateUnits checks it there).
        own = s_rated / mpc.baseMVA;
        transformers(end+1, 1) = Transformer(id="X" + br.id, hv_bus=hv_bus, lv_bus=lv_bus, ...
            s_rated_mva=s_rated, hv_kv=hv_kv, lv_kv=lv_kv, x_pu=br.x_pu * own, r_pu=br.r_pu * own, ...
            hv_config=hv_cfg, lv_config=lv_cfg); %#ok<AGROW>
    end
    % The three 50 MVA 115/13.8 kV substation banks are DYg with the Yg on
    % the 13.8 kV side -- but they sit UPSTREAM of the feeder-head breakers,
    % so their grounding is lost the moment a feeder islands.
    grounding(end+1, 1) = GroundingSource(id="G_SUBSTATION_Yg", bus="B1", kind=GroundingKind.SOLID, ...
        available_when_islanded=false, ...
        notes="50 MVA 115/13.8 kV DYg substation banks (from BANSHEE.mdl); Yg on the 13.8 kV side, " + ...
              "upstream of the feeder-head breakers.");
    % Machine note: the released synchronous machine blocks provide no
    % zero-sequence path, and no grounding transformer exists anywhere in
    % the model -- so NO islanded MV grounding source is declared. That is
    % the finding, not an omission.
end

% Feeder-head breakers (the reconfiguration/islanding points) plus the PCC.
switches = Switch(id="SW_PCC", from_bus="B1", to_bus="B1", is_pcc=true);
for k = 1:size(FEEDER_HEAD_BUSES, 1)
    switches(end+1, 1) = Switch(id=sprintf("SW_F%d", FEEDER_HEAD_BUSES(k, 1)), from_bus="B1", ...
        to_bus=sprintf("B%d", FEEDER_HEAD_BUSES(k, 2))); %#ok<AGROW>
end

% Relays from the release spreadsheets: the feeder-head 51P elements.
relays = OvercurrentRelay.empty(0,1);
if ~isempty(opts.relay_dir)
    for fdr = 1:3
        xlsx = fullfile(opts.relay_dir, sprintf("F%d_relay_banshee.xlsx", fdr));
        if ~isfile(xlsx), continue; end
        rows = readRelays(xlsx);
        head = rows(1);   % relay #1 in each sheet is the feeder-head device
        relays(end+1, 1) = OvercurrentRelay(id=sprintf("R_F%d_HEAD", fdr), switch_id=sprintf("SW_F%d", fdr), ...
            ct_ratio=head.ct_ratio, pickup_a=head.pickup_primary_a, curve="SEL-U1", ...
            time_dial=head.time_dial, ...
            notes=sprintf("51P from %s, relay #1, primary amperes", sprintf("F%d_relay_banshee.xlsx", fdr))); %#ok<AGROW>
    end
end

% DERs. Ratings documented; control parameters assumed and flagged.
machines = [ ...
    SynchronousGen(id="DG_DIESEL", bus=sprintf("B%d", DIESEL_BUS), s_rated_mva=DIESEL_MVA, ...
        h_sec=1.0, xd_subtransient_pu=0.15, droop_pu=0.05, neutral_grounded=false); ...
    SynchronousGen(id="DG_CHP", bus=sprintf("B%d", CHP_BUS), s_rated_mva=CHP_MVA, ...
        h_sec=1.5, xd_subtransient_pu=0.18, droop_pu=0.05, neutral_grounded=false)];
converters = Converter(id="PV_F2", bus=sprintf("B%d", PV_BUS), s_rated_mva=PV_MVA, ...
    control=ConverterControl.GFL, ...
    params=ConverterParams(i_limit_transient_pu=1.2, ride_through_identified=false), ...
    vendor="", firmware="");

% Island configurations: grid-connected, whole-site island, and one island
% per feeder (interties open in v5, so per-feeder islands are the natural
% reachable set).
islands = [ ...
    IslandConfig(id="GRID", description="Grid-connected, all feeders on utility", grid_connected=true, ...
        energized_source_ids=["DG_DIESEL", "DG_CHP", "PV_F2"]); ...
    IslandConfig(id="ISL_ALL", description="Whole site islanded at the PCC", open_switches="SW_PCC", ...
        grid_connected=false, energized_source_ids=["DG_DIESEL", "DG_CHP", "PV_F2"]); ...
    IslandConfig(id="ISL_F1", description="Feeder 1 islanded on the diesel genset", open_switches="SW_F1", ...
        grid_connected=false, energized_source_ids="DG_DIESEL"); ...
    IslandConfig(id="ISL_F2", description="Feeder 2 islanded on the PV inverter alone", open_switches="SW_F2", ...
        grid_connected=false, energized_source_ids="PV_F2"); ...
    IslandConfig(id="ISL_F3", description="Feeder 3 islanded on the CHP", open_switches="SW_F3", ...
        grid_connected=false, energized_source_ids="DG_CHP")];

site = Site(id="BANSHEE", name="Banshee distribution benchmark (EPHCC release, case v5)", base=base, ...
    buses=buses, branches=branches, transformers=transformers, switches=switches, relays=relays, ...
    converters=converters, machines=machines, loads=loads, grounding=grounding, islands=islands);
end

function out = readRelays(xlsx)
% Read the release relay spreadsheet (first sheet). Column lookup is by
% header name where present, with the same positional fallbacks as the
% Python original.
raw = readcell(xlsx, "Sheet", 1);
header = raw(1, :);
col = dictionary(string.empty, double.empty);
for i = 1:numel(header)
    h = header{i};
    if ~isBlank(h)
        col(strtrim(string(h))) = i;
    end
end
out = struct("relay_no", {}, "v_ll", {}, "ct_ratio", {}, "pickup_primary_a", {}, "time_dial", {});
for r = 2:size(raw, 1)
    first = raw{r, 1};
    if isBlank(first) || ~isnumeric(first), continue; end
    ct_primary = double(raw{r, col("CT Primary : 5")});
    if isKey(col, "51P TOC Trip Pickup [A]")
        pickup_sec = double(raw{r, col("51P TOC Trip Pickup [A]")});
    else
        pickup_sec = double(raw{r, 11});
    end
    if isKey(col, "51P TOC Time Dial"), tdc = col("51P TOC Time Dial"); else, tdc = 13; end
    out(end+1) = struct( ...
        "relay_no", double(first), "v_ll", double(raw{r, 2}), ...
        "ct_ratio", ct_primary / 5.0, ...
        "pickup_primary_a", pickup_sec * (ct_primary / 5.0), ...
        "time_dial", double(raw{r, tdc})); %#ok<AGROW>
end
end

function tf = isBlank(v)
% readcell yields <missing> for empty cells, chars for text, doubles for numbers.
tf = isempty(v) || (isa(v, "missing")) || (ischar(v) && isempty(strtrim(v))) || ...
     (isstring(v) && all(ismissing(v) | strlength(strtrim(v)) == 0));
end
