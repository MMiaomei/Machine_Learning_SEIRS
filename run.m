clear all; clc;
close all;
load('Infectious_data', 'T', 'X'); % load data generated by ODE45
load('prediction'); % Data from NN
X   = X';

% Generate training data
train_size  = 20; % size of trainning data
x_idx   = randperm(1000);
T_train = T(x_idx(1:train_size));
X_train = X(:,x_idx(1:train_size));
Y_train = X(:,x_idx(1:train_size)+1);

%% DMD Main 
% Dynamic mode decomposition: Classic
Ad      = Y_train * pinv(X_train);
[U,S,~] = svd(X_train,'econ');
eig_tru = sum(diag(S)>=0.01*max(diag(S))); % Truncate eigenvalues to reduce noise
U       = U(:,1:eig_tru); 
Ad_til  = U'*Ad*U;
[W,D]   = eig(Ad_til);
Omega   = diag(log(diag(D)));
Phi     = U*W;
c       = W \ U' * X(:,1);

X_DMD   = zeros(size(X,1),length(T));
for t = 0:length(T)-1
    X_DMD(:,t+1)    = Phi*expm(Omega*t)*c;
end

%% Koopman Main
% Define feature according to Brusselator
Psi = @(x) [x(1); x(2); x(3); x(4); x(5); x(6); x(7); x(1)*x(3); x(1)*x(4); x(1)*x(5)];
Psi_X   = [];
Psi_Y   = [];
for i = 1:train_size
    Psi_X   = [Psi_X,Psi(X_train(:,i))];
    Psi_Y   = [Psi_Y,Psi(Y_train(:,i))];
end
K   = Psi_Y * pinv(Psi_X);
% Define observables g(x) = x
C   = [eye(7), zeros(7,3)];
% Koopman decomposition
[W, Lambda]     = eig(K);
V       = C*W;
Phi     = @(x) pinv(W)*Psi(x);
X_KOOP  = zeros(size(X,1),length(T));
X_KOOP(:,1)     = X(:,1);
% Prediction using Koopman
for i = 2:length(T)
    X_KOOP(:,i)     = V*Lambda*Phi(X_KOOP(:,i-1));
end

%% Error 
err_NN      = X(:,2:end-1) - prediction';
err_DMD     = X - X_DMD;
err_KOOP    = X - X_KOOP;

%% Plot
% True
figure(1);
plot(T,X,'LineWidth',2); hold on;
plot(T_train,X_train,'ro','LineWidth',2);
title('True Data: '); 
hl  = legend('S','E','I_1','I_2','H','R','D','Traning Point');
hl.NumColumns   = 3;
xlabel('Time [Days]'); ylabel('Population [People]')
set(gca,'Fontsize',16); grid on;

% NN
figure(2);
subplot(2,1,1)
plot(t_pred, prediction,'LineWidth',2);
title('NN Prediction: 4000 epoch / batch size 20');
hl  = legend('S','E','I_1','I_2','H','R','D','Traning Point');
hl.NumColumns   = 3;
xlabel('Time [Days]'); ylabel('Population [People]')
set(gca,'Fontsize',16); grid on;
subplot(2,1,2)
plot(t_pred, err_NN,'LineWidth',2);
xlabel('Time [Days]'); ylabel('Error [People]')
set(gca,'Fontsize',16); grid on;

% DMD
figure(3);
subplot(2,1,1)
plot(T,X_DMD,'LineWidth',2);
title(['DMD Prediction: ', num2str(train_size), ' Data Points / ', num2str(eig_tru), ' Eigen-modes'])
hl  = legend('S','E','I_1','I_2','H','R','D','Traning Point');
hl.NumColumns   = 3;
xlabel('Time [Days]'); ylabel('Population [People]')
set(gca,'Fontsize',16); grid on;
subplot(2,1,2)
plot(T, err_DMD,'LineWidth',2);
xlabel('Time [Days]'); ylabel('Error [People]')
set(gca,'Fontsize',16); grid on;

% DMD eig
figure(4)
plot(real(diag(D)), imag(diag(D)), 'x',...
     'MarkerSize', 10, 'LineWidth', 2); hold on;
plot(cos(0:0.1:2*pi+0.5), sin(0:0.1:2*pi+0.5), 'g', 'LineWidth', 1); 
grid on; pbaspect([1 1 1]);
title('Eigenvalues of DMD'); xlabel('Re(\lambda)'); ylabel('Im(\lambda)'); 
set(gca,'Fontsize',16);

% Koopman
figure(5);
subplot(2,1,1)
plot(T,X_KOOP,'LineWidth',2);
title(['Koopman Prediction: ', num2str(train_size), ' Data Points'])
hl  = legend('S','E','I_1','I_2','H','R','D','Traning Point');
hl.NumColumns   = 3;
xlabel('Time [Days]'); ylabel('Population [People]')
set(gca,'Fontsize',16); grid on;
subplot(2,1,2)
plot(T, err_KOOP,'LineWidth',2);
xlabel('Time [Days]'); ylabel('Error [People]')
set(gca,'Fontsize',16); grid on;

% Koopman eigen
figure(6)
plot(real(diag(Lambda)), imag(diag(Lambda)), 'x',...
     'MarkerSize', 10, 'LineWidth', 2); hold on;
plot(cos(0:0.1:2*pi+0.5), sin(0:0.1:2*pi+0.5), 'g', 'LineWidth', 1); 
grid on; pbaspect([1 1 1]);
title('Eigenvalues of Koopman'); xlabel('Re(\lambda)'); ylabel('Im(\lambda)'); 
set(gca,'Fontsize',16);

% % All
% figure(7);
% subplot(2,2,1)
% plot(T,X,'LineWidth',2); hold on;
% plot(T_train,X_train,'ro','LineWidth',2);
% title('True Data: '); 
% hl  = legend('S','E','I_1','I_2','H','R','D','Traning Point');
% hl.NumColumns   = 3;
% xlabel('Time [Days]'); ylabel('Population [People]')
% set(gca,'Fontsize',16); grid on;
% subplot(2,2,2)
% plot(t_pred, prediction,'LineWidth',2);
% title('NN Prediction: 4000 epoch / batch size 20');
% xlabel('Time [Days]'); ylabel('Population [People]')
% set(gca,'Fontsize',16); grid on;
% subplot(2,2,3)
% plot(T,X_DMD,'LineWidth',2);
% title(['DMD Prediction: ', num2str(train_size), ' Data Points / ', num2str(eig_tru), ' Eigen-modes'])
% xlabel('Time [Days]'); ylabel('Population [People]')
% set(gca,'Fontsize',16); grid on;
% subplot(2,2,4)
% plot(T,X_KOOP,'LineWidth',2);
% title(['Koopman Prediction: ', num2str(train_size), ' Data Points'])
% xlabel('Time [Days]'); ylabel('Population [People]')
% set(gca,'Fontsize',16); grid on;
