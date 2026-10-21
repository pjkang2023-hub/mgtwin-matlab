function [zones, info] = zeroSequenceZones(site, isl)
%ZEROSEQUENCEZONES Partition an island's buses into zero-sequence zones.
%
%   Electrical connectivity: branches, transformer windings, and closed
%   switches all connect buses. An OPEN switch between (a, b) severs EVERY
%   edge between a and b -- breakers are in series with whatever they switch,
%   and composed models often carry the switch and the impedance as parallel
%   edges between the same pair.
%
%   Zero-sequence connectivity is the same graph MINUS all transformer edges:
%   a transformer never passes zero sequence between its sides in a way that
%   can be assumed (delta blocks it outright; wye-wye depends on both neutrals
%   and the core, which is exactly the sort of fact that must be declared, not
%   inferred). Grounding then enters per zone:
%     * a GroundingSource at a bus grounds that bus's zone, subject to
%       available_when_islanded;
%     * an energized transformer winding declared WYE_GROUNDED grounds the
%       zone of the bus that winding connects to.
%
%   Returns ZONES, a cell array of string arrays (bus ids per zone, every zone
%   being energized conductor of the island), and INFO, a struct array with
%   fields grounded_by (string array), kinds (string array), buses.

busIds = site.busIds();
n = numel(busIds);
idx = dictionary(busIds, 1:n);

% -- open switches sever every parallel edge between their endpoints ------
opened = site.openSwitchIds(isl);
openKeys = string.empty(1,0);
for k = 1:numel(opened)
    sw = findSwitch(site, opened(k));
    openKeys(end+1) = pairKey(sw.from_bus, sw.to_bus); %#ok<AGROW>
end
severed = @(a, b) ismember(pairKey(a, b), openKeys);

% A composed model may carry the same physical transformer twice: as a
% Branch (power-flow-exact impedance) and as a Transformer (winding facts).
% For zero-sequence purposes any branch that parallels a declared
% transformer IS that transformer and must not conduct in the zone graph.
txKeys = string.empty(1,0);
for k = 1:numel(site.transformers)
    txKeys(end+1) = pairKey(site.transformers(k).hv_bus, site.transformers(k).lv_bus); %#ok<AGROW>
end

% -- electrical islands: everything conducts ------------------------------
elec = 1:n;
for k = 1:numel(site.branches)
    br = site.branches(k);
    if ~severed(br.from_bus, br.to_bus)
        elec = unite(elec, idx(br.from_bus), idx(br.to_bus));
    end
end
for k = 1:numel(site.transformers)
    tx = site.transformers(k);
    if ~severed(tx.hv_bus, tx.lv_bus)
        elec = unite(elec, idx(tx.hv_bus), idx(tx.lv_bus));
    end
end
for k = 1:numel(site.switches)
    sw = site.switches(k);
    if ~ismember(sw.id, opened) && ~severed(sw.from_bus, sw.to_bus)
        elec = unite(elec, idx(sw.from_bus), idx(sw.to_bus));
    end
end

islandRoots = [];
for k = 1:numel(isl.energized_source_ids)
    src = site.source(isl.energized_source_ids(k));
    [elec, r] = find_(elec, idx(src.bus));
    islandRoots(end+1) = r; %#ok<AGROW>
end
islandRoots = unique(islandRoots);

% -- zero-sequence zones: transformers do not conduct ---------------------
parent = 1:n;
for k = 1:numel(site.branches)
    br = site.branches(k);
    if ismember(pairKey(br.from_bus, br.to_bus), txKeys)
        continue;
    end
    if ~severed(br.from_bus, br.to_bus)
        parent = unite(parent, idx(br.from_bus), idx(br.to_bus));
    end
end
for k = 1:numel(site.switches)
    sw = site.switches(k);
    if ~ismember(sw.id, opened) && ~severed(sw.from_bus, sw.to_bus)
        parent = unite(parent, idx(sw.from_bus), idx(sw.to_bus));
    end
end

% zone root -> member bus indices, restricted to the energized island(s)
zoneRoot = zeros(1, n);
inIsland = false(1, n);
for b = 1:n
    [elec, er] = find_(elec, b);
    if ~ismember(er, islandRoots)
        continue;  % outside the energized island entirely
    end
    [parent, zr] = find_(parent, b);
    zoneRoot(b) = zr;
    inIsland(b) = true;
end
roots = unique(zoneRoot(inIsland));
% Python sorts zones by root bus id (string order); mirror that.
[~, ord] = sort(busIds(roots));
roots = roots(ord);

nz = numel(roots);
grounded = repmat({string.empty(1,0)}, 1, nz);
kinds = repmat({string.empty(1,0)}, 1, nz);
declaredIt = repmat({string.empty(1,0)}, 1, nz);
rootPos = dictionary(roots, 1:nz);

for k = 1:numel(site.grounding)
    g = site.grounding(k);
    if g.kind == mgtwin.GroundingKind.UNGROUNDED
        % A declared IT (isolated) system: not a zero-sequence source, but a
        % design decision that must travel with a ground detector.
        [parent, r] = find_(parent, idx(g.bus));
        if isKey(rootPos, r) && inIsland(idx(g.bus))
            p = rootPos(r);
            declaredIt{p}(end+1) = g.id;
        end
        continue;
    end
    if isl.grid_connected || g.available_when_islanded
        [parent, r] = find_(parent, idx(g.bus));
        if isKey(rootPos, r) && inIsland(idx(g.bus))
            p = rootPos(r);
            grounded{p}(end+1) = g.id;
            kinds{p}(end+1) = g.kind.Value;
        end
    end
end
for k = 1:numel(site.transformers)
    tx = site.transformers(k);
    if severed(tx.hv_bus, tx.lv_bus)
        continue;
    end
    [elec, er] = find_(elec, idx(tx.hv_bus));
    if ~ismember(er, islandRoots)
        continue;  % de-energized transformer grounds nothing
    end
    if tx.lv_config == mgtwin.WindingConfig.WYE_GROUNDED
        [parent, r] = find_(parent, idx(tx.lv_bus));
        if isKey(rootPos, r)
            p = rootPos(r);
            grounded{p}(end+1) = tx.id + ":lv_Yg";
            kinds{p}(end+1) = "transformer_wye_grounded";
        end
    end
    if tx.hv_config == mgtwin.WindingConfig.WYE_GROUNDED
        [parent, r] = find_(parent, idx(tx.hv_bus));
        if isKey(rootPos, r)
            p = rootPos(r);
            grounded{p}(end+1) = tx.id + ":hv_Yg";
            kinds{p}(end+1) = "transformer_wye_grounded";
        end
    end
end

% Every zone here is part of an energized electrical island, so every zone
% is energized conductor and needs a grounding verdict -- including pure
% transit zones with no local source or load, which is exactly the case of
% an MV network backfed through a DYg service transformer.
zones = cell(1, nz);
info = struct("grounded_by", cell(1, nz), "kinds", cell(1, nz), "buses", cell(1, nz), ...
    "declared_it", cell(1, nz));
for p = 1:nz
    members = busIds(zoneRoot == roots(p) & inIsland);
    zones{p} = sort(members);
    info(p).grounded_by = unique(grounded{p});
    info(p).kinds = unique(kinds{p});
    info(p).buses = zones{p};
    info(p).declared_it = unique(declaredIt{p});
end
end

% -------------------------------------------------------------------------
function key = pairKey(a, b)
s = sort([string(a), string(b)]);
key = s(1) + "|" + s(2);
end

function sw = findSwitch(site, swid)
for k = 1:numel(site.switches)
    if site.switches(k).id == swid
        sw = site.switches(k); return;
    end
end
error("mgtwin:KeyError", "no switch with id '%s'", swid);
end

function [parent, r] = find_(parent, x)
r = x;
while parent(r) ~= r
    parent(r) = parent(parent(r));
    r = parent(r);
end
end

function parent = unite(parent, a, b)
[parent, ra] = find_(parent, a);
[parent, rb] = find_(parent, b);
if ra ~= rb
    parent(ra) = rb;
end
end
