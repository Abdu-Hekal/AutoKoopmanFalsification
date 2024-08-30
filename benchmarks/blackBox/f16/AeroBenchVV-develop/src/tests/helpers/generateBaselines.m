%GENERATEBASELINES

% This script helps generate test baselines. This is a one-off process
% I'm recording it in this script so I don't forget how to make one.
testCase.printOn = false;
testCase.t = 0;

aerobench_path = addAeroBenchPaths(testCase.printOn);

[testCase.x_f16,...
    testCase.xequil,...
    testCase.uequil,...
    testCase.K_lqr,...
    testCase.F16_model,...
    testCase.lin_f16,...
    testCase.flightLimits,...
    testCase.ctrlLimits,...
    testCase.autopilot,...
    ] = getTestInitialConditions();
            
[ xd, u, Nz, ps, Ny_r ] = controlledF16( ...
    testCase.t, ...
    testCase.x_f16,... 
    testCase.xequil,...
    testCase.uequil,...
    testCase.K_lqr,...
    testCase.F16_model,...
    testCase.lin_f16,...
    testCase.flightLimits,...
    testCase.ctrlLimits,...
    testCase.autopilot);

% Rename outputs to something you want to load in from the workspace
xd_expected = xd
u_expected = u
Nz_expected = Nz
ps_expected = ps
Ny_r_expected = Ny_r
% I can even include the test inputs if I'm being lazy
trial_inputs = testCase

% Define the baseline.mat output filename
fileName = 'foo_baseline';

outpath = fullfile(aerobench_path,'src','tests',...
    'resources',fileName)

% Save .mat file
save(outpath,...
    'xd_expected',...
    'u_expected',...
    'Nz_expected',...
    'ps_expected',...
    'Ny_r_expected',...
    'trial_inputs');