classdef ConverterControl
    %CONVERTERCONTROL Control class. GFM_DROOP / GFM_VSM map onto the WECC
    %   generic library shapes (REGFM_A1 and REGFM_B1 respectively); GFL maps
    %   onto REGCA/REECA; GFM_HYBRID onto the REGFM_C1 shape.
    enumeration
        GFL        ("grid_following")
        GFM_DROOP  ("grid_forming_droop")
        GFM_VSM    ("grid_forming_vsm")
        GFM_HYBRID ("grid_forming_hybrid")
    end
    properties (SetAccess = immutable)
        Value (1,1) string
    end
    methods
        function obj = ConverterControl(v)
            obj.Value = v;
        end
        function tf = isGridForming(obj)
            tf = obj ~= mgtwin.ConverterControl.GFL;
        end
    end
end
