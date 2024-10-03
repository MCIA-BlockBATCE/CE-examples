clear
clc
close all
%load FeaturesHIOB_360samples_4classess_4operatingconditions_3severities.mat
load FeaturesHIOB_LDA.mat

%% -------------- Parte 1 Feature Normalization and classification --------
rng(1989)

%FeaturesHIOv3=normal(FeaturesHIOB(241:end,:));
%FeaturesHIOv3_raw=normal(FeaturesHIOB_LDA(:,:));
%FeaturesHIOv3=FeaturesHIOv3_raw';

FeaturesHIOv3=FeaturesHIOB_LDA;
FeaturesHIOv3_raw=FeaturesHIOB_LDA;

Targets=zeros(1200,10);
Targets(1:120,1)=1;  %Class healthy
Targets(121:480,2)=1;%Class Inner Fault
Targets(481:840,3)=1;%Class Outer Fault
Targets(841:1200,4)=1;%Class Ball Fault

Targets=Targets';

Targets1C(1:120,1)=1;
Targets1C(121:240,1)=2;%Class Inner Fault Severity 1
Targets1C(241:360,1)=2;%Class Inner Fault Severity 2
Targets1C(361:480,1)=2;%Class Inner Fault Severity 3
Targets1C(481:600,1)=3;%Class Outer Fault Severity 1
Targets1C(601:720,1)=3;%Class Outer Fault Severity 2
Targets1C(721:840,1)=3;%Class Outer Fault Severity 3
Targets1C(841:960,1)=4;%Class Ball Fault Severity 1
Targets1C(961:1080,1)=4;%Class Ball Fault Severity 2
Targets1C(1081:1200,1)=4;%Class Ball Fault Severity 3
Targets1C=Targets1C';


Targets_names=cell(1200,1);%10);
Targets_names(1:120,1)={'Healthy'};  %Class healthy
Targets_names(121:480,1)={'Inner Fault'};%Class Inner Fault
Targets_names(481:840,1)={'Outer Fault'};%Class Outher Fault
Targets_names(841:1200,1)={'Ball Fault'};%Class Ball Fault



%% Part_2 Apply the neural network to the data prepared in the part 1

% Neural Network Architecture Configuration
n=10; % Number of neurons in hidden layer
trainFcn='trainrp';
% {'tansig','purelin'};% Activation functions

% Training function
%TRNF='trainrp';%  Backpropagation training functions
 
% Training goals of the network
epochs=25;% Numbe of epochs in train mode
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

k = 3;
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
     figure
     plotconfusion(yTest,yPred,'All Features')
     hold off
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
     
     AccuracyALL(i)=Accuracy;
     PrecisionALL(i)=Precision;
     RecallALL(i)=Recall;
     SpecificityALL(i)=Specificity;
 
     % perf = perform(Net,yTest,yPred);
     % disp(perf);
     % 
     % %store results     
     % netAry{i} = Net;
     % perfAry(i) = perf;
     
end

    AccuracyAVG=mean(AccuracyALL);
    PrecisionAVG=mean(PrecisionALL);
    RecallAVG=mean(RecallALL);
    SpecificityAVG=mean(SpecificityALL);
    figure
    bar (AccuracyALL)
    xlabel('k-th iteration')
    ylabel('Accuracy')
    title(['Avg Accuracy, K-fold crossvalidation =' num2str(AccuracyAVG)])
    
    figure
    bar (PrecisionALL)
    xlabel('k-th iteration')
    ylabel('Precision')
    title(['Avg Precision, K-fold crossvalidation =' num2str(PrecisionAVG)])
    
    figure
    bar (RecallALL)
    xlabel('k-th iteration')
    ylabel('Recall')
    title(['Avg Recall, K-fold crossvalidation =' num2str(RecallAVG)])
    
    figure
    bar (SpecificityALL)
    xlabel('k-th iteration')
    ylabel('Specificity')
    title(['Avg Specificity, K-fold crossvalidation =' num2str(SpecificityAVG)])
    
