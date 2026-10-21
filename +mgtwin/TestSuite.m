classdef TestSuite
    %TESTSUITE A versioned set of test cases (one edition of a standard).
    properties
        edition (1,1) string = ""
        source (1,1) string = ""
        disclaimer (1,1) string = ""
        cases (1,:) mgtwin.TestCase = mgtwin.TestCase.empty(1,0)
    end
    methods
        function obj = TestSuite(opts)
            arguments
                opts.edition (1,1) string
                opts.source (1,1) string
                opts.disclaimer (1,1) string
                opts.cases (1,:) mgtwin.TestCase
            end
            if mgtwin.internal.requireFields(opts, ["edition", "source", "disclaimer", "cases"], "TestSuite"), return; end
            for f = string(fieldnames(opts))'
                obj.(f) = opts.(f);
            end
        end
        function cs = byFunction(obj, fn)
            cs = obj.cases([obj.cases.core_function] == fn);
        end
        function cs = emtCases(obj)
            cs = obj.cases([obj.cases.requires_emt]);
        end
        function c = caseById(obj, id)
            for k = 1:numel(obj.cases)
                if obj.cases(k).id == id, c = obj.cases(k); return; end
            end
            error("mgtwin:KeyError", "no test case with id '%s'", id);
        end
    end
end
