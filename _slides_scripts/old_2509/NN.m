clear
clc
close all
%load FeaturesHIOB_360samples_4classess_4operatingconditions_3severities.mat
load FeaturesHIOB_LDA.mat

%% -------------- Parte 1 Feature Normalization and classification --------
rng(1989)

%FeaturesHIOv3=normal(FeaturesHIOB(241:end,:));
FeaturesHIOv3=normal(FeaturesHIOB_LDA(:,:));
FeaturesHIOv3=FeaturesHIOv3';

Targets=zeros(1200,10);
Targets(1:120,1)=1;  %Class healthy
Targets(121:240,2)=1;%Class Inner Fault Severity 1
Targets(241:360,3)=1;%Class Inner Fault Severity 2
Targets(361:480,4)=1;%Class Inner Fault Severity 3
Targets(481:600,5)=1;%Class Outher Fault Severity 1
Targets(601:720,6)=1;%Class Outher Fault Severity 2
Targets(721:840,7)=1;%Class Outher Fault Severity 3
Targets(841:960,8)=1;%Class Ball Fault Severity 1
Targets(961:1080,9)=1;%Class Ball Fault Severity 2
Targets(1081:1200,10)=1;%Class Ball Fault Severity 3

Targets=Targets';

Targets1C(1:120,1)=1;
Targets1C(121:240,1)=2;%Class Inner Fault Severity 1
Targets1C(241:360,1)=3;%Class Inner Fault Severity 2
Targets1C(361:480,1)=4;%Class Inner Fault Severity 3
Targets1C(481:600,1)=5;%Class Outher Fault Severity 1
Targets1C(601:720,1)=6;%Class Outher Fault Severity 2
Targets1C(721:840,1)=7;%Class Outher Fault Severity 3
Targets1C(841:960,1)=8;%Class Ball Fault Severity 1
Targets1C(961:1080,1)=9;%Class Ball Fault Severity 2
Targets1C(1081:1200,1)=10;%Class Ball Fault Severity 3
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
% {'tansig','purelin'};% Activation functions

% Training function
%TRNF='trainrp';%  Backpropagation training functions
 
% Training goals of the network
epochs=1000;% Numbe of epochs in train mode
min_err=0.000001;% Minimum error for goal

% Creating a new neural network with the specific data
%Net=newff(Training_Data,Training_Targets,n,TRF,TRNF);

% NEW FUNCTION FOR FFNET
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