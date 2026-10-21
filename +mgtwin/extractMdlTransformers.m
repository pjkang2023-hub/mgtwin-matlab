function out = extractMdlTransformers(mdl_path)
%EXTRACTMDLTRANSFORMERS Extract transformer instances from a plain-text
%   Simulink .mdl file.
%
%   Scope: the Banshee OPAL-RT models, where every transformer is a
%   reference block into transformer_lib with parameters Rating [kVA], Vp,
%   Vs [V], Z [%], XR, and a SourceBlock name encoding the connection
%   ("XFR DYg-30 HIL" = delta primary / grounded-wye secondary, 30 degree
%   shift). Anything that is not that pattern raises rather than guessing.
%
%   The .mdl is parsed as text deliberately (not opened in Simulink): the
%   Banshee model needs OPAL-RT libraries that are not available, and text
%   parsing is what the Python original does.
arguments
    mdl_path (1,1) string
end
CONNECTION_MAP = { ...
    "DYg",  ["delta", "wye_grounded"]; ...
    "YgYg", ["wye_grounded", "wye_grounded"]; ...
    "YgD",  ["wye_grounded", "delta"]; ...
    "DD",   ["delta", "delta"]};

fid = fopen(mdl_path, "r", "n", "ISO-8859-1");
if fid < 0
    error("mgtwin:FileNotFound", "cannot open %s", mdl_path);
end
text = fread(fid, [1 Inf], "*char");
fclose(fid);
[~, nm, ext] = fileparts(mdl_path);
source_file = string(nm) + string(ext);

blocks = regexp(text, "Block \{(.*?)\n\t\}", "tokens");
out = mgtwin.MdlTransformer.empty(1,0);
for k = 1:numel(blocks)
    b = blocks{k}{1};
    sb = param(b, "SourceBlock");
    if ~contains(sb, "transformer_lib/")
        continue;
    end
    parts = split(sb, "/");
    block_type = parts(end);
    conn = [];
    for j = 1:size(CONNECTION_MAP, 1)
        frag = CONNECTION_MAP{j, 1};
        if ~isempty(regexp(block_type, "\<" + frag + "\>|XFR " + frag, "once"))
            conn = CONNECTION_MAP{j, 2};
            break;
        end
    end
    if isempty(conn)
        error("mgtwin:ValueError", "%s: transformer block type '%s' has no known " + ...
            "connection mapping; refusing to guess", mdl_path, block_type);
    end
    t = mgtwin.MdlTransformer();
    t.source_file = source_file;
    t.name = replace(param(b, "Name"), "\n", " ");
    t.block_type = block_type;
    t.kva = str2double(param(b, "Rating"));
    t.vp_v = str2double(param(b, "Vp"));
    t.vs_v = str2double(param(b, "Vs"));
    t.z_pct = str2double(param(b, "Z"));
    t.xr = str2double(param(b, "XR"));
    t.hv_connection = conn(1);
    t.lv_connection = conn(2);
    out(end+1) = t; %#ok<AGROW>
end
end

function v = param(block, key)
tok = regexp(block, "\<" + key + '\s+"([^"]*)"', "tokens", "once");
if isempty(tok)
    v = "";
else
    v = string(tok{1});
end
end
