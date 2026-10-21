function recs = loadProtectionStudies(path)
%LOADPROTECTIONSTUDIES Protection-study records from a JSON list of
%   {state_id, tool, passed, models_identified?, reference?, notes?,
%   complete?}; other fields - a tool's own working detail beside the record
%   - are left out.
arguments
    path (1,1) string
end
items = jsondecode(fileread(path));
if ~iscell(items), items = num2cell(items); end
recs = mgtwin.ProtectionStudyRecord.empty(1,0);
known = string(properties("mgtwin.ProtectionStudyRecord"))';
for k = 1:numel(items)
    it = items{k};
    nv = {};
    for f = string(fieldnames(it))'
        if ~ismember(f, known), continue; end
        v = it.(f);
        if ischar(v), v = string(v); end
        nv = [nv, {char(f), v}]; %#ok<AGROW>
    end
    recs(end+1) = mgtwin.ProtectionStudyRecord(nv{:}); %#ok<AGROW>
end
end
