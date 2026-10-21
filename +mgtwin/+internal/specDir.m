function d = specDir()
%SPECDIR Folder holding the versioned test specifications.
d = fullfile(fileparts(fileparts(mfilename("fullpath"))), "specs");
end
