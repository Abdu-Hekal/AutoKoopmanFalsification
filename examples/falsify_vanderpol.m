% load your python environment that autokoopman is installed & imported in
% pyenv("Version",'/Users/b6062805/Documents/Koopman/autokoopman_vitualenv/bin/python','ExecutionMode','InProcess');
% py.importlib.import_module('autokoopman');

model = model_vanderpol();
max_train_size=10; %maximum number of training trajectories before quitting

[falsified, trainset, crit_x] = coreFalsify(model, max_train_size);

if falsified
    disp("falsifying trace found")
    visualize_falsification(crit_x, model.spec)
end

figure; hold on; box on;
visualize_train(trainset)