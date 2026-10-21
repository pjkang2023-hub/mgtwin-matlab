classdef Site
    %SITE A complete canonical microgrid model.
    %
    %   Design rules
    %   1. Grounding is a first-class entity, not an attribute buried in a
    %      transformer. It changes on islanding and positive-sequence models
    %      are blind to it.
    %   2. Converter parameters follow the shape of the WECC generic library.
    %   3. Every island configuration is enumerable.
    %   4. Nothing carries an implicit base.
    %
    %   Referential integrity is checked once, in the constructor (as pydantic
    %   does). Site is a value class: copies are independent, so remediation
    %   scenarios can be built by copying and appending.
    properties
        id (1,1) string = ""
        name (1,1) string = ""
        base (1,1) mgtwin.Base = mgtwin.Base()
        buses (:,1) mgtwin.Bus = mgtwin.Bus.empty(0,1)
        branches (:,1) mgtwin.Branch = mgtwin.Branch.empty(0,1)
        transformers (:,1) mgtwin.Transformer = mgtwin.Transformer.empty(0,1)
        switches (:,1) mgtwin.Switch = mgtwin.Switch.empty(0,1)
        relays (:,1) mgtwin.OvercurrentRelay = mgtwin.OvercurrentRelay.empty(0,1)
        converters (:,1) mgtwin.Converter = mgtwin.Converter.empty(0,1)
        machines (:,1) mgtwin.SynchronousGen = mgtwin.SynchronousGen.empty(0,1)
        loads (:,1) mgtwin.Load = mgtwin.Load.empty(0,1)
        grounding (:,1) mgtwin.GroundingSource = mgtwin.GroundingSource.empty(0,1)
        islands (:,1) mgtwin.IslandConfig = mgtwin.IslandConfig.empty(0,1)
    end
    methods
        function obj = Site(opts)
            arguments
                opts.id (1,1) string
                opts.name (1,1) string = ""
                opts.base (1,1) mgtwin.Base
                opts.buses (:,1) mgtwin.Bus = mgtwin.Bus.empty(0,1)
                opts.branches (:,1) mgtwin.Branch = mgtwin.Branch.empty(0,1)
                opts.transformers (:,1) mgtwin.Transformer = mgtwin.Transformer.empty(0,1)
                opts.switches (:,1) mgtwin.Switch = mgtwin.Switch.empty(0,1)
                opts.relays (:,1) mgtwin.OvercurrentRelay = mgtwin.OvercurrentRelay.empty(0,1)
                opts.converters (:,1) mgtwin.Converter = mgtwin.Converter.empty(0,1)
                opts.machines (:,1) mgtwin.SynchronousGen = mgtwin.SynchronousGen.empty(0,1)
                opts.loads (:,1) mgtwin.Load = mgtwin.Load.empty(0,1)
                opts.grounding (:,1) mgtwin.GroundingSource = mgtwin.GroundingSource.empty(0,1)
                opts.islands (:,1) mgtwin.IslandConfig = mgtwin.IslandConfig.empty(0,1)
            end
            if mgtwin.internal.requireFields(opts, ["id", "base"], "Site"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
            obj.checkReferentialIntegrity();
        end

        % -- lookups -------------------------------------------------------
        function ids = busIds(obj)
            ids = string({obj.buses.id});
        end
        function ids = sourceIds(obj)
            ids = [string({obj.converters.id}), string({obj.machines.id})];
        end
        function ids = openSwitchIds(obj, isl)
            %OPENSWITCHIDS The switches open in state ISL: those it opens, and
            %   the normally open ones it does not close.
            normallyOpen = string.empty(1,0);
            for k = 1:numel(obj.switches)
                if ~obj.switches(k).normally_closed && ~ismember(obj.switches(k).id, isl.closed_switches)
                    normallyOpen(end+1) = obj.switches(k).id; %#ok<AGROW>
                end
            end
            ids = unique([isl.open_switches, normallyOpen]);
        end
        function src = source(obj, sid)
            %SOURCE Return the Converter or SynchronousGen with id SID.
            for k = 1:numel(obj.converters)
                if obj.converters(k).id == sid, src = obj.converters(k); return; end
            end
            for k = 1:numel(obj.machines)
                if obj.machines(k).id == sid, src = obj.machines(k); return; end
            end
            error("mgtwin:KeyError", "no source with id '%s'", sid);
        end
        function r = relayForSwitch(obj, switch_id)
            %RELAYFORSWITCH Relay on SWITCH_ID, or empty if none.
            r = mgtwin.OvercurrentRelay.empty(0,1);
            for k = 1:numel(obj.relays)
                if obj.relays(k).switch_id == switch_id, r = obj.relays(k); return; end
            end
        end
        function isl = island(obj, island_id)
            %ISLAND Return the IslandConfig with id ISLAND_ID.
            for k = 1:numel(obj.islands)
                if obj.islands(k).id == island_id, isl = obj.islands(k); return; end
            end
            error("mgtwin:KeyError", "no island with id '%s'", island_id);
        end
    end
    methods (Access = private)
        function checkReferentialIntegrity(obj)
            busList = obj.busIds();
            problems = string.empty(1,0);
            function need(bus, owner)
                if ~ismember(bus, busList)
                    problems(end+1) = sprintf("%s references unknown bus '%s'", owner, bus);
                end
            end
            for k = 1:numel(obj.branches)
                br = obj.branches(k);
                need(br.from_bus, sprintf("branch '%s'", br.id));
                need(br.to_bus, sprintf("branch '%s'", br.id));
            end
            for k = 1:numel(obj.transformers)
                tx = obj.transformers(k);
                need(tx.hv_bus, sprintf("transformer '%s'", tx.id));
                need(tx.lv_bus, sprintf("transformer '%s'", tx.id));
            end
            for k = 1:numel(obj.switches)
                sw = obj.switches(k);
                need(sw.from_bus, sprintf("switch '%s'", sw.id));
                need(sw.to_bus, sprintf("switch '%s'", sw.id));
            end
            for k = 1:numel(obj.converters)
                need(obj.converters(k).bus, sprintf("converter '%s'", obj.converters(k).id));
            end
            for k = 1:numel(obj.machines)
                need(obj.machines(k).bus, sprintf("machine '%s'", obj.machines(k).id));
            end
            for k = 1:numel(obj.loads)
                need(obj.loads(k).bus, sprintf("load '%s'", obj.loads(k).id));
            end
            for k = 1:numel(obj.grounding)
                need(obj.grounding(k).bus, sprintf("grounding source '%s'", obj.grounding(k).id));
            end
            switch_ids = string({obj.switches.id});
            for k = 1:numel(obj.relays)
                r = obj.relays(k);
                if ~ismember(r.switch_id, switch_ids)
                    problems(end+1) = sprintf("relay '%s' references unknown switch '%s'", r.id, r.switch_id); %#ok<AGROW>
                end
                for j = 1:numel(r.functions)
                    for b = r.functions(j).zone_buses
                        need(b, sprintf("relay '%s' %s zone", r.id, r.functions(j).ansi));
                    end
                end
            end
            srcs = obj.sourceIds();
            for k = 1:numel(obj.islands)
                isl = obj.islands(k);
                for sid = isl.energized_source_ids
                    if ~ismember(sid, srcs)
                        problems(end+1) = sprintf("island '%s' references unknown source '%s'", isl.id, sid); %#ok<AGROW>
                    end
                end
                for swid = [isl.open_switches, isl.closed_switches]
                    if ~ismember(swid, switch_ids)
                        problems(end+1) = sprintf("island '%s' references unknown switch '%s'", isl.id, swid); %#ok<AGROW>
                    end
                end
                both = intersect(isl.open_switches, isl.closed_switches);
                if ~isempty(both)
                    problems(end+1) = sprintf("island '%s' both opens and closes ['%s']", isl.id, strjoin(sort(both), "', '")); %#ok<AGROW>
                end
            end
            if ~isempty(problems)
                error("mgtwin:ValidationError", "%s", strjoin(problems, "; "));
            end
        end
    end
end
