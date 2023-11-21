function Sys = koopSetupAlpha(Sys)
% koopSetupAlpha Set up the optimization variables and constraints for the
% alpha parameters in the Koopman MILP formulation.
%
% Syntax:
%    Sys = koopSetupAlpha(Sys)
%
% Description:
%    This function sets up the optimization variables and constraints for
%    the alpha parameters in the Koopman MILP formulation. The function is
%    part of the KoopMILP class and is called during the setup process.
%
% Inputs:
%    Sys - KoopMILP object
%
% Outputs:
%    Sys - KoopMILP object with updated properties related to alpha
%          optimization variables and constraints.
%
%
% See also: KoopMILP
%
% Author:      Abdelrahman Hekal
% Written:     19-November-2023
% Last update: ---
% Last revision: ---


%% setup
L=Sys.L; % horizon (# of steps)
cpBool=Sys.cpBool; %boolean of control points
reachZonos=Sys.reachZonos;

%% System dimensions and variables
nx=Sys.nx; %number of states
% variables
Sys.x = sdpvar(nx, L+1); %states
alpha = sdpvar(1, size(reachZonos{end}.generators,2));
if ~isempty(Sys.U)
    alphaU = alpha(size(reachZonos{1}.generators,2)+1:end);
    U = zonotope(Sys.U); c_u = center(U); G_u = generators(U);
    alphaU = reshape(alphaU,[size(G_u,2),length(alphaU)/size(G_u,2)]);
    c_u_ = repmat(c_u,1,size(alphaU,2));

    %append empty sdpvar for consistent length with states X
    Sys.u = [c_u_ + G_u*alphaU, sdpvar(size(c_u,1),size(c_u,2))];
end

%constraints for alpha
Falpha= -1<=alpha<=1;

% TODO: fix this section, constrain to same value as prev only makes sense
% for piecewise-constant inputs. otherwise, different interpolation must be
% considered

%constraint for control points
cpBool = cpBool(1:L,:); %get cpbool corresponding to number of steps
if ~isempty(cpBool) %piecewise constant signal and not pulse.
    %skip alphas that correspond to initial points
    k = size(reachZonos{1}.generators,2)+1;
    for row=1:size(cpBool,1)
        for col=1:size(cpBool,2)
            %if bool is zero constrain alpha to be same value as prev
            if ~cpBool(row,col)
                Falpha=[Falpha, alpha(k)==alpha(k-size(cpBool,2))];
            end
            k=k+1; %next alpha
        end
    end
end

%assign optim variables and outputs to system
Sys.Finit=Falpha; Sys.alpha=alpha;




