function [obj,trainset,soln,specSolns,allData] = initialize(obj)
% INITIALIZE Initialize the Koopman Falsification (KF) object and check for required parameters.
%
% Syntax:
%    [obj, trainset] = initialize(obj)
%
% Description:
%    This function initializes the Koopman Falsification (KF) object by checking
%    and setting the required parameters. It also ensures that autokoopman is
%    installed and imported in the Python environment. The function returns the
%    initialized object and an empty training set structure.
%
% Inputs:
%    obj - Koopman Falsification (KF) object
%
% Outputs:
%    obj       - Initialized Koopman Falsification (KF) object
%    trainset  - Empty training set structure
%    soln      - struct to store solution
%    specSolns - dictionary to store previous solution for each spec
%
% Example:
%    [obj, trainset] = initialize(obj);
%
% See also: falsify
%
% Author:      Abdelrahman Hekal
% Written:     19-November-2023
% Last update: ---
% Last revision: ---
% -------------------------- Auxiliary Functions --------------------------
% SETCPBOOL Set control point boolean array for the Koopman Falsification (KF) object.
%
% Syntax:
%    obj = setCpBool(obj)
%
% Description:
%    This function sets the control point boolean array for the Koopman Falsification (KF) object.
%    The boolean array represents the control points in the Koopman model.
%
% Inputs:
%    obj - Koopman Falsification (KF) object
%
% Outputs:
%    obj - Updated Koopman Falsification (KF) object with the control point boolean array
%
% Example:
%    obj = setCpBool(obj);
%
% See also: initialize
%
% Author:      Abdelrahman Hekal
% Written:     19-November-2023
% Last update: ---
% Last revision: ---
% -----------------------------------------------------------------------------
% ------------- BEGIN CODE --------------

%Ensure that autokoopman is installed & imported in your python environment
py.importlib.import_module('autokoopman');

assert(isa(obj.model, 'string') | isa(obj.model,"char")| isa(obj.model,'function_handle'), 'obj.model must be a (1)string: name of simulink obj or a (2)function handle')
assert(isa(obj.R0, 'interval'), 'Initial set (obj.R0) must be defined as a CORA interval')
assert(isnumeric(obj.T) && isscalar(obj.T), 'Time horizon (obj.T) must be defined as a numeric')
assert(isnumeric(obj.dt) && isscalar(obj.dt), 'Time step (obj.dt) must be defined as a numeric')
assert(isa(obj.spec, 'specification'), 'Falsifying spec (obj.spec) must be defined as a CORA specification')
all_steps = obj.T/obj.dt;
assert(floor(all_steps)==all_steps,'Time step (dt) must be a factor of Time horizon (T)')

assert(isnumeric(obj.runs) && isscalar(obj.runs) && obj.runs > 0 && mod(obj.runs, 1) == 0, 'The number of runs must be an integer greater than 0.');
assert(islogical(obj.reach.on) || isnumeric(obj.reach.on) && isscalar(obj.reach.on) && ismember(obj.reach.on, [0, 1]), 'Reachability setting (obj.reach.on) must be a boolean');
assert(isnumeric(obj.reach.tayOrder) && isscalar(obj.reach.tayOrder) && obj.reach.tayOrder > 0 && round(obj.reach.tayOrder) == obj.reach.tayOrder, 'Taylor order (obj.reach.tayOrder) must be a positive, integer, scalar number');

assert(isstruct(obj.solver.opts), 'solver options (obj.solver.opts) must be a struct, see sdpsettings')
assert(islogical(obj.solver.normalize) || isnumeric(obj.solver.normalize) && isscalar(obj.solver.normalize) && ismember(obj.solver.normalize, [0, 1]), 'solver normalization option (obj.solver.normalize) must be a boolean');
assert(islogical(obj.solver.useOptimizer) || isnumeric(obj.solver.useOptimizer) && isscalar(obj.solver.useOptimizer) && ismember(obj.solver.useOptimizer, [0, 1]), 'solver use optimizer option (obj.solver.useOptimizer) must be a boolean');
assert(isnumeric(obj.maxSims) && isscalar(obj.maxSims) && obj.maxSims > 0 && round(obj.maxSims) == obj.maxSims, 'Maximum simulations (obj.maxSims) must be a positive, integer, scalar number');
assert(isnumeric(obj.timeout) && isscalar(obj.timeout) && obj.timeout > 0, 'Timeout (obj.timeout) must be a positive, scalar number');

assert((isnumeric(obj.nResets) && isscalar(obj.nResets) && obj.nResets > 0 && round(obj.nResets) == obj.nResets) || strcmp('auto',obj.nResets), 'Reset number (obj.maxSims) must be a positive, integer, scalar number OR a string (auto)');
assert(isnumeric(obj.trainStrat) && isscalar(obj.trainStrat) && obj.trainStrat >= 0 && obj.trainStrat <= 2 && round(obj.trainStrat) == obj.trainStrat,'Training option (obj.trainStrat) must be an integer between 0 and 2')
assert(islogical(obj.rmRand) || isnumeric(obj.rmRand) && isscalar(obj.rmRand) && ismember(obj.rmRand, [0, 1]), 'Remove random training trajectory (obj.rmRand) must be a boolean');
if obj.trainStrat==1 || obj.trainStrat==2
    if obj.rmRand
        obj.rmRand=false;
        vprintf(obj.verb,1,"Training Strategy selected (obj.trainStrat=%d), consequently obj.rmRand is set to false\n",obj.trainStrat)
    end
end
assert(isnumeric(obj.offsetStrat) && isscalar(obj.offsetStrat) && obj.offsetStrat >= -1 && obj.offsetStrat <= 1 && round(obj.offsetStrat) == obj.offsetStrat,'Offset strategy (obj.offsetStrat) must be an integer between -1 and 1')
assert(isnumeric(obj.verb) && isscalar(obj.verb) && obj.verb >= 0 && obj.verb <= 3 && round(obj.verb) == obj.verb,'Verbosity level (obj.verb) must be an integer between 0 and 3')



%set autokoopman timestep if it is not set, else check it is compliant.
if ~isfield(obj.ak,'dt')
    obj.ak.dt=obj.dt;
else
    allAbstrSteps = obj.T/obj.ak.dt;
    assert(floor(allAbstrSteps)==allAbstrSteps,'Time step of koopman (ak.dt) must be a factor of Time horizon (T)')
end

%set solver timestep if it is not set, else check it is compliant.
if ~isfield(obj.solver,'dt')
    obj.solver.dt=obj.ak.dt;
else
    abstr = obj.solver.dt/obj.ak.dt; %define abstraction ratio
    assert(floor(abstr)==abstr,'Time step of solver (solver.dt) must be a multiple of koopman time step (ak.dt)')
    allAbstrSteps = obj.T/obj.solver.dt;
    assert(floor(allAbstrSteps)==allAbstrSteps,'Time step of solver (solver.dt) must be a factor of Time horizon (T)')
end

% ensure that autokoopman rank is an integer
obj.ak.rank=int64(obj.ak.rank);

% clear yalmip
yalmip('clear')

if ~isempty(obj.U) %check if obj has inputs
    assert(isa(obj.U, 'interval'), 'Input (obj.U) must be defined as an CORA interval')
    %if no control points defined, set as control point at every step ak.dt
    if isempty(obj.cp)
        obj.cp=obj.T/obj.ak.dt*ones(1,length(obj.U));
    end
    assert(length(obj.U)==length(obj.cp),'Number of control points (obj.cp) must be equal to number of inputs (obj.U)')
    %set cpBool
    obj=setCpBool(obj);
end
%set input interval
obj=setInputsInterval(obj);
%struct to store soln
soln=struct;
soln.falsified=false;
soln.koopTime=0; soln.reachTime=0;
soln.optimTime=0; soln.simTime=0;
soln.sims=0;
%struct for best soln found
soln.best.rob=inf;
soln.best.x=NaN; soln.best.u=NaN; soln.best.t=NaN;
soln.best.koopModel=NaN;
%reset dict to store prev soln for each spec
specSolns = dictionary(obj.spec,struct);
%empty struct to store training data
trainset.X = {}; trainset.XU={}; trainset.t = {};
%empty struct to store all data
allData.X={}; allData.XU={}; allData.t={}; allData.Rob=[];
allData.koopModels={};
end

% -------------------------- Auxiliary Functions --------------------------

function obj=setCpBool(obj)
all_steps = obj.T/obj.ak.dt;
obj.cpBool = zeros(all_steps,length(obj.U));
for k=1:length(obj.cp)
    obj.cp(k) = min(obj.cp(k),all_steps); %set control points to a max of number of ak discrete timesteps
    assert(isnumeric(obj.cp(k)) && isscalar(obj.cp(k)) && obj.cp(k)>0 && round(obj.cp(k)) == obj.cp(k), 'number of control points must be an integer greater than zero')
    if obj.cp(k) == 1
       assert(strcmp(obj.inputInterpolation,'previous'), 'if number of control points is 1, previous interpolation must be used')
    end
    step = (obj.T/obj.ak.dt)/obj.cp(k);
    assert(floor(step)==step,'number of control points (cp) must be a factor of T/ak.dt')
    obj.cpBool(1:step:end,k) = 1;
    if ~all(obj.cpBool(:,k)) %if cpbool is not just ones, then interpolation scheme must be 'previous' (pconst)
        assert(strcmp(obj.inputInterpolation,'previous'),'Currently only an input interpolation of "previous" is supported for a number of control points less than T/ak.dt')
    end
end
end

function obj=setInputsInterval(obj)
lowerBound=[obj.R0.inf];
upperBound=[obj.R0.sup];
for i=1:size(obj.U,1)
    cp=find(obj.cpBool(:,i));
    numU = numel(cp);
    lowerBound=[lowerBound;repmat(obj.U.inf(i),numU,1)];
    upperBound = [upperBound;repmat(obj.U.sup(i),numU,1)];
end
obj.inputsInterval = interval(lowerBound,upperBound);
end