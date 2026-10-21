classdef MdlTransformer
    %MDLTRANSFORMER One transformer instance extracted from a Simulink .mdl.
    properties
        source_file (1,1) string = ""
        name (1,1) string = ""
        block_type (1,1) string = ""
        kva (1,1) double = NaN
        vp_v (1,1) double = NaN
        vs_v (1,1) double = NaN
        z_pct (1,1) double = NaN
        xr (1,1) double = NaN
        hv_connection (1,1) string = ""
        lv_connection (1,1) string = ""
    end
    methods
        function tf = isHilArtifact(obj)
            %ISHILARTIFACT Stub-line coupling transformers exist for HIL
            %   decomposition, not in the physical plant (Z = 0.1%, Vs = 500 V).
            tf = contains(lower(obj.name), "stubline") || obj.vs_v == 500.0;
        end
    end
end
