classdef MetricValue
    %METRICVALUE A measured quantity reported by the runner.
    %   m = mgtwin.MetricValue(metric, value, unit, note)
    properties
        metric (1,1) string = ""
        value (1,1) double = NaN
        unit (1,1) string = ""
        note (1,1) string = ""
    end
    methods
        function obj = MetricValue(metric, value, unit, note)
            if nargin == 0, return; end
            obj.metric = metric; obj.value = value; obj.unit = unit;
            if nargin >= 4, obj.note = note; end
        end
    end
end
