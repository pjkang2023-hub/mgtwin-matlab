function isDefault = requireFields(opts, names, owner)
%REQUIREFIELDS Enforce required name-value arguments.
%
%   isDefault = requireFields(opts, names, owner)
%
%   Name-value arguments in MATLAB `arguments` blocks are always optional
%   (and `nargin` is 0 for name-value calls), so this restores pydantic's
%   "required field" behaviour for the ontology:
%     * if NONE of the required names is present, this is a default
%       (zero-argument) construction as MATLAB needs for object arrays --
%       returns true so the constructor can return an empty-valued object;
%     * if SOME but not all are present, errors naming the missing field;
%     * otherwise returns false.
present = isfield(opts, names);
if ~any(present)
    isDefault = true;
    return;
end
isDefault = false;
for n = names(~present)
    error("mgtwin:ValidationError", "%s: missing required argument '%s'", owner, n);
end
end
