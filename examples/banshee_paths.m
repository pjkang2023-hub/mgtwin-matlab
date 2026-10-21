function P = banshee_paths()
%BANSHEE_PATHS Locations of the Banshee EPHCC release files.
%
%   Resolution order:
%     1. environment variable BANSHEE_DATA, pointing at the extracted
%        "Supporting Data for Banshee Benchmark Paper/00 models and data for
%        system verification" folder (or the same folder from the mgtwin
%        data pack banshee_data_for_rung1_v2.zip);
%     2. a `banshee_data` folder next to this repository (the data pack
%        unzipped beside mgtwin-matlab);
%     3. ~/banshee_raw/... as in the Python original.
%   Download from the EPHCC GitHub release named in Salcedo et al. 2019.
SUB = fullfile("Supporting Data for Banshee Benchmark Paper", "00 models and data for system verification");
root = fileparts(fileparts(mfilename("fullpath")));
candidates = string.empty(1,0);
env = getenv("BANSHEE_DATA");
if ~isempty(env), candidates(end+1) = string(env); end
candidates(end+1) = fullfile(root, "..", "banshee_data", "banshee_data", "00 models and data for system verification");
candidates(end+1) = fullfile(root, "..", "banshee_data", "00 models and data for system verification");
candidates(end+1) = fullfile(getenv("USERPROFILE"), "banshee_raw", SUB);

data = candidates(1);
for c = candidates
    if isfolder(c), data = c; break; end
end
P.DATA = string(data);
P.CASE_V4 = fullfile(P.DATA, "Matpower", "case_banshee_feeder_all_v4.m");
P.CASE_V5 = fullfile(P.DATA, "Matpower", "case_banshee_feeder_all_v5.m");
P.CSV_PATH = fullfile(P.DATA, "topology_verification_datapoints.csv");
P.RELAYS = fullfile(P.DATA, "OPAL-RT", "relay_settings");
P.MDL = fullfile(P.DATA, "OPAL-RT", "BANSHEE.mdl");   % winding configurations; optional
P.available = isfolder(P.DATA) && isfile(P.CASE_V5);
end
