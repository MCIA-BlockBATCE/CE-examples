%clear
%clc
clear all
close all

load FeaturesHIOB_LDA.mat

%% -------------- Parte 1 Feature Normalization and classification --------
rng(1989)

%FeaturesHIOv3=normal(FeaturesHIOB(241:end,:));
%FeaturesHIOv3=FeaturesHIOv3';
FeaturesHIOv3=FeaturesHIOB_LDA';

Targets=zeros(1200,4);%10);
Targets(1:120,1)=1;  %Class healthy
Targets(121:240,2)=1;%Class Inner Fault Severity 1
Targets(241:360,2)=1;%3)=1;%Class Inner Fault Severity 2
Targets(361:480,2)=1;%4)=1;%Class Inner Fault Severity 3
Targets(481:600,3)=1;%5)=1;%Class Outher Fault Severity 1
Targets(601:720,3)=1;%6)=1;%Class Outher Fault Severity 2
Targets(721:840,3)=1;%7)=1;%Class Outher Fault Severity 3
Targets(841:960,4)=1;%8)=1;%Class Ball Fault Severity 1
Targets(961:1080,4)=1;%9)=1;%Class Ball Fault Severity 2
Targets(1081:1200,4)=1;%10)=1;%Class Ball Fault Severity 3

Targets=Targets';

Targets1C(1:120,1)=1;
Targets1C(121:240,1)=2;%Class Inner Fault Severity 1
Targets1C(241:360,1)=2;%3;%Class Inner Fault Severity 2
Targets1C(361:480,1)=2;%4;%Class Inner Fault Severity 3
Targets1C(481:600,1)=3;%5;%Class Outher Fault Severity 1
Targets1C(601:720,1)=3;%6;%Class Outher Fault Severity 2
Targets1C(721:840,1)=3;%7;%Class Outher Fault Severity 3
Targets1C(841:960,1)=4;%8;%Class Ball Fault Severity 1
Targets1C(961:1080,1)=4;%9;%Class Ball Fault Severity 2
Targets1C(1081:1200,1)=4;%10;%Class Ball Fault Severity 3
Targets1C=Targets1C';

Training_index=[1:120-40,121:240-40,241:360-40,361:480-40,481:600-40,601:720-40,721:840-40,841:960-40,961:1080-40,1081:1200-40];
Validation_index=[121-40:120,241-40:240,361-40:360,481-40:480,601-40:600,721-40:720,841-40:840,961-40:960,1081-40:1080,1201-40:1200];

Training_Data=FeaturesHIOv3(:,Training_index);% Separe data for Trainning
Training_Targets=Targets(:,Training_index);

Validation_Data=FeaturesHIOv3(:,Validation_index);% Separe data for Validation
Validation_Targets=Targets(:,Validation_index);

%% -------------- Part 2 Neural Network with   Data------------------------

% Part_2 Apply the neural network to the data prepared in the part 1

% Neural Network Architecture Configuration
n=10; % Number of neurons in hidden layer
trainFcn='trainrp';
 
% Training goals of the network
epochs=25;% Numbe of epochs in train mode
min_err=0.000001;% Minimum error for goal

% Creating a new neural network with the specific data
Net = feedforwardnet(n,trainFcn);

% Specify the data origin.
Net.divideParam.trainRatio = 1;
Net.divideParam.valRatio = 0;
Net.divideParam.testRatio = 0;

% Configuration of the training parameters
Net.trainParam.epochs=epochs; % select the eppoch defined previously
Net.trainParam.goal=min_err;  % select the minimum error defined prev.

% Train the selected NN
[Net,TR] = train(Net,Training_Data,Training_Targets);

% Apply the validation data to the network
Simu_Net=Net(Validation_Data);
% Show the confusion matrix
plotconfusion(Validation_Targets,Simu_Net,'All Features')

% mesh for decission boundary plot
x = min(FeaturesHIOv3(1,:))*2:0.001:max(FeaturesHIOv3(1,:))*2;
y = min(FeaturesHIOv3(2,:))*2:0.001:max(FeaturesHIOv3(2,:))*2;
[X, Y] = meshgrid(x,y);
X = X(:);
Y = Y(:);
grid = [X Y];
Simu_Net2=Net(grid');

% limits for plotting
[foo , class] = max(Simu_Net2);
class = class';
colors = ['g.'; 'm.'; 'b.';'y.';'r.';'k.'];
figure;
% plot each point for mesh
for i = 1:4
  thisX = X(class == i);
  thisY = Y(class == i);
  plot(thisX, thisY, colors(i,:));
  hold on
end

% set different colors and styles for each class
num_samples=80;
Training_Data=Training_Data';
hold on
p(1) = plot(Training_Data(1:num_samples,1),Training_Data(1:num_samples,2),'square','LineWidth',1,'MarkerEdgeColor','k','MarkerFaceColor','g','MarkerSize',8);
p(2) = plot(Training_Data(num_samples+1:num_samples*4,1),Training_Data(num_samples+1:num_samples*4,2),'diamond','LineWidth',1,'MarkerEdgeColor','k','MarkerFaceColor','m','MarkerSize',8);
p(3) = plot(Training_Data(4*num_samples+1:num_samples*7,1),Training_Data(4*num_samples+1:num_samples*7,2),'o','LineWidth',1,'MarkerEdgeColor','k','MarkerFaceColor','b','MarkerSize',8);
p(4) = plot(Training_Data(7*num_samples+1:num_samples*10,1),Training_Data(7*num_samples+1:num_samples*10,2),'hexagram','LineWidth',1,'MarkerEdgeColor','k','MarkerFaceColor','y','MarkerSize',8);
hold off
legend(p(1:4))
ylim([min(Y) max(Y)])
xlim([min(X) max(X)])
xlabel('Dimension 1')
ylabel('Dimension 2')
title('Decision regions for each class');






