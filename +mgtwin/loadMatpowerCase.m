function mpc = loadMatpowerCase(path)
%LOADMATPOWERCASE Load a MATPOWER case file (.m) into a struct.
%
%   mpc = mgtwin.loadMatpowerCase("case_banshee_feeder_all_v5.m")
%
%   The Python original re-implements a small MATLAB-expression interpreter
%   (matpower_io.py) because it cannot run MATLAB. Here the case file IS
%   MATLAB: it is executed in an isolated workspace and the resulting `mpc`
%   struct (baseMVA, bus, gen, branch, ...) returned. Both the function form
%   (`function mpc = case_x()`) and the script form are accepted. Nothing is
%   guessed: if the file does not produce `mpc`, this errors.
arguments
    path (1,1) string
end
if ~isfile(path)
    error("mgtwin:FileNotFound", "no such case file: %s", path);
end
[folder, name] = fileparts(path);
oldDir = cd(folder);
restore = onCleanup(@() cd(oldDir));
clear(name);   % make sure a stale copy is not shadowing the file
mpc = runCase(name);
if ~isstruct(mpc) || ~isfield(mpc, "baseMVA")
    error("mgtwin:ValueError", "%s did not produce an mpc struct with baseMVA", path);
end
mpc.baseMVA = double(mpc.baseMVA);
end

function mpc = runCase(name)
try
    % Function-form case file: returns mpc.
    mpc = feval(name);
    return;
catch err
    if ~any(strcmp(err.identifier, ["MATLAB:TooManyOutputs", "MATLAB:scriptNotAFunction", "MATLAB:maxlhs"]))
        rethrow(err);
    end
end
% Script-form case file: run in this function's workspace and pick up mpc.
mpc = []; %#ok<NASGU>
eval(name);
if ~exist("mpc", "var") || isempty(mpc)
    error("mgtwin:ValueError", "case script %s did not define mpc", name);
end
end
