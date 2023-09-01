function model = modelNeural()
% modelCars - model parameters for the Neural-network Controller (NN).
%
% Syntax:
%       model = modelNeural()
%
% Description:
%       Model parameters for the Neural-network Controller (NN) benchmark.
%
% Output Arguments:
%
%       -model:             a koopman falsification model      
%
%------------------------------------------------------------------
    
    model = KF_model(@run_neural);
    model.R0 = interval([0.5000;-1.4129],[0.5000;-1.4129]); 
    model.U = interval(1,3); 

    model.T=40; 
    model.ak.dt=40/12; %40/12;
%     model.solver.dt=10;
    model.cp=12;

end