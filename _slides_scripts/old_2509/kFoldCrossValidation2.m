clear
clc
close all
%load FeaturesHIOB_360samples_4classess_4operatingconditions_3severities.mat
load FeaturesHIOB_LDA.mat

%% -------------- Parte 1 Feature Normalization and classification --------
rng(1989)

%FeaturesHIOv3=normal(FeaturesHIOB(241:end,:));
FeaturesHIOv3_raw=normal(FeaturesHIOB_LDA(:,:));
FeaturesHIOv3=FeaturesHIOv3_raw';

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


Targets_names=cell(1200,1);%10);
Targets_names(1:120,1)={'Healthy'};  %Class healthy
Targets_names(121:240,1)={'Inner Fault Severity 1'};%Class Inner Fault Severity 1
Targets_names(241:360,1)={'Inner Fault Severity 2'};%Class Inner Fault Severity 2
Targets_names(361:480,1)={'Inner Fault Severity 3'};%Class Inner Fault Severity 3
Targets_names(481:600,1)={'Outher Fault Severity 1'};%Class Outher Fault Severity 1
Targets_names(601:720,1)={'Outher Fault Severity 2'};%Class Outher Fault Severity 2
Targets_names(721:840,1)={'Outher Fault Severity 3'};%Class Outher Fault Severity 3
Targets_names(841:960,1)={'Ball Fault Severity 1'};%Class Ball Fault Severity 1
Targets_names(961:1080,1)={'Ball Fault Severity 2'};%Class Ball Fault Severity 2
Targets_names(1081:1200,1)={'Ball Fault Severity 3'};%Class Ball Fault Severity


%% Part_2 Apply the neural network to the data prepared in the part 1

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
%Net = feedforwardnet(n,trainFcn);
Net = patternnet(n,trainFcn);

% Specify the data origin.
Net.divideParam.trainRatio = 1;
Net.divideParam.valRatio = 0;
Net.divideParam.testRatio = 0;

% Configuration of the training parameters
Net.trainParam.epochs=epochs; % select the eppoch defined previously
Net.trainParam.goal=min_err;  % select the minimum error defined prev.

y = Targets_names;
x = FeaturesHIOv3_raw;

k = 4;
c = cvpartition(y,'kFold', k, 'Stratify', true);
%c = cvpartition(y,'kFold', k);

for i = 1:k
    
    %get Train and Test data for this fold
     trIdx = c.training(i);
     teIdx = c.test(i);
     xTrain = x(trIdx);
     yTrain = y(trIdx);
     xTest = x(teIdx);
     yTest = y(teIdx);
    
     yTest2 = Targets1C(teIdx);
     
     %transform data to columns as expected by neural nets
     xTrain = xTrain';
     xTest = xTest';
     yTrain = dummyvar(grp2idx(yTrain))';
     yTest = dummyvar(grp2idx(yTest))';
     
     %create net and set Test and Validation to zero in the input data
     % net = patternnet(10);
     % net.divideParam.trainRatio = 1;
     % net.divideParam.testRatio = 0;
     % net.divideParam.valRatio = 0;
     
     %train network
     Net = train(Net,xTrain,yTrain);
     yPred = Net(xTest);
    
     [~, Predicted_Labels] = max(yPred, [], 1);
    
     Conf_Mat = confusionmat(yTest2, Predicted_Labels);
     
     % Calcular las métricas
     Accuracy = sum(diag(Conf_Mat)) / sum(Conf_Mat(:));
    
     Precision = mean(diag(Conf_Mat) ./ sum(Conf_Mat, 1)');
    
     Recall = mean(diag(Conf_Mat) ./ sum(Conf_Mat, 2));
    
     Specificity = mean((sum(Conf_Mat(:)) - sum(Conf_Mat, 2) - sum(Conf_Mat, 1)' + diag(Conf_Mat)) ./ (sum(Conf_Mat(:)) - sum(Conf_Mat, 2)));
    
     % Mostrar los resultados
     disp(['Accuracy: ', num2str(Accuracy)]);
     disp(['Precision: ', num2str(Precision)]);
     disp(['Recall: ', num2str(Recall)]);
     disp(['Specificity: ', num2str(Specificity)]);
     
     % perf = perform(Net,yTest,yPred);
     % disp(perf);
     % 
     % %store results     
     % netAry{i} = Net;
     % perfAry(i) = perf;
     
end
