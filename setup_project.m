function setup_project()
% SETUP_PROJECT Configure MATLAB paths and the working folder.

wifi8Root = fileparts(mfilename('fullpath'));

addpath(wifi8Root, ...
    fullfile(wifi8Root, 'config'), ...
    fullfile(wifi8Root, 'src'), ...
    fullfile(wifi8Root, 'src', 'engine'), ...
    fullfile(wifi8Root, 'experiments'));

cd(wifi8Root);

fprintf('Project root: %s\n', wifi8Root);
fprintf('MATLAB paths configured.\n');
fprintf('Next: validate_engine, test_cb_integration, then run_demo.\n');
end
