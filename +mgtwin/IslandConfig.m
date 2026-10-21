classdef IslandConfig
    %ISLANDCONFIG One reachable operating configuration. Enumerating these is
    %   the whole point: a gate that passes in grid-connected mode and fails
    %   in island 2 is the finding you want before energization, not after.
    %
    %   closed_switches lists the normally open switches this state closes (a
    %   tie, an alternate leg after a transfer); a normally open switch not
    %   listed there is open. energise_transformer_ids lists the transformers
    %   switched in SIMULTANEOUSLY in this state (one ATS step, one black-start
    %   step); the energisation gate checks their summed inrush against the
    %   grid-forming current headroom of the section they land in.
    %   settings_group names the protection settings group the relays run in
    %   this state (black start, islanded and grid-connected states differ).
    %   load_factors maps a load id to the factor on its p and q in this
    %   state: a load transfer a Site's fixed loads cannot express - the
    %   dual-corded halls' cord-A load doubling when board B is lost
    %   (load_factors=dictionary("IT_cordA", 2.0)). Loads not listed run at 1.
    %   A struct (as jsondecode gives it) is accepted too.
    properties
        id (1,1) string = ""
        description (1,1) string = ""
        open_switches (1,:) string = string.empty(1,0)
        closed_switches (1,:) string = string.empty(1,0)
        grid_connected (1,1) logical = false
        load_factors dictionary = dictionary(string.empty, double.empty)
        settings_group (1,1) string = "A"   % protection settings group the relays run in this state
        energized_source_ids (1,:) string = string.empty(1,0)
        energise_transformer_ids (1,:) string = string.empty(1,0)
    end
    methods
        function obj = IslandConfig(opts)
            arguments
                opts.id (1,1) string
                opts.description (1,1) string = ""
                opts.open_switches (1,:) string = string.empty(1,0)
                opts.closed_switches (1,:) string = string.empty(1,0)
                opts.grid_connected (1,1) logical
                opts.load_factors = dictionary(string.empty, double.empty)
                opts.settings_group (1,1) string = "A"
                opts.energized_source_ids (1,:) string = string.empty(1,0)
                opts.energise_transformer_ids (1,:) string = string.empty(1,0)
            end
            if mgtwin.internal.requireFields(opts, ["id", "grid_connected"], "IslandConfig"), return; end
            if isstruct(opts.load_factors)
                st = opts.load_factors;
                ks = string(fieldnames(st))';
                vs = zeros(1, numel(ks));
                for j = 1:numel(ks), vs(j) = double(st.(ks(j))); end
                if isempty(ks)
                    opts.load_factors = dictionary(string.empty, double.empty);
                else
                    opts.load_factors = dictionary(ks, vs);
                end
            end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
    end
end
