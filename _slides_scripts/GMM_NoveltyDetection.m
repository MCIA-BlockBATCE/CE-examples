%% Start
close all
clear 
clc

% Load the data
load Mat_Nomralizada_val.mat
data_norm = Mat_Normalizada_val(:,6:7);
% H,B7,B14,B21,I7,I14,I21,O7,O14,O21 (8 features each)


% Targets
target = zeros(400,1);
target(1:40,1) = 1;% HT
target(41:80,1) = 2;% B7
target(81:120,1) = 2;% B14
target(121:160,1) = 2;% B21
target(161:200,1) = 3;% I7
target(201:240,1) = 3;% I14
target(241:280,1) = 3;% I21
target(281:320,1) = 4;% O7
target(321:360,1) = 4;% O14
target(361:400,1) = 4;% O21

Targets_names=cell(400,1);%10);
Targets_names(1:40,1)={'HT'};  %Class healthy
Targets_names(41:80,1)={'B7'};%Class Inner Fault Severity 1
Targets_names(81:120,1)={'B14'};%Class Inner Fault Severity 2
Targets_names(121:160,1)={'B21'};%Class Inner Fault Severity 3
Targets_names(161:200,1)={'I7'};%Class Outher Fault Severity 1
Targets_names(201:240,1)={'I14'};%Class Outher Fault Severity 2
Targets_names(241:280,1)={'I21'};%Class Outher Fault Severity 3
Targets_names(281:320,1)={'O7'};%Class Ball Fault Severity 1
Targets_names(321:360,1)={'O14'};%Class Ball Fault Severity 2
Targets_names(361:400,1)={'O21'};%Class Ball Fault Severity 3


% novelty sets
t1 = ones(40,1);
t0 = zeros(40,1);
ta = [t1;t0;t1;t0];
tb = [t1;t1;t1;t1;t0;t1;t0];
tc = [t1;t1;t1;t1;t1;t1;t1;t0;t1;t0];

tar = target(1:160);
tbr = target(1:280);
tcr = target(1:400);

DataCov = cov(data_norm);
[PC, variances, explained] = pcacov(DataCov); 
z = 2; 
PC = PC(:,1:z);

data_PC = Mat_Normalizada_val(:,6:7);


figure(1)
gscatter(data_PC(:,1),data_PC(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6)
xlabel('Feature #1')
ylabel('Feature #2')
title('Data representation')


% Separate the data
% set A
Training_index_A=[1:40-10,41:80-10,81:120-10,121:160-10];
Validation_index_A=[41-10:40,81-10:80,121-10:120,161-10:160];
TA = ta(Training_index_A,:);
VDA = data_PC(Validation_index_A,:);
VTA = ta(Validation_index_A,:);
TAr = tar(Validation_index_A,:);
% set B
Training_index_B=[1:40-10,41:80-10,81:120-10,121:160-10,161:200-10,201:240-10,241:280-10];
Validation_index_B=[41-10:40,81-10:80,121-10:120,161-10:160,201-10:200,241-10:240,281-10:280];
TB = tb(Training_index_B,:);
VDB = data_PC(Validation_index_B,:);
VTB = tb(Validation_index_B,:);
TBr = tbr(Validation_index_B,:);
% set C
Training_index_C=[1:40-10,41:80-10,81:120-10,121:160-10,161:200-10,201:240-10,241:280-10,281:320-10,321:360-10,361:400-10];
Validation_index_C=[41-10:40,81-10:80,121-10:120,161-10:160,201-10:200,241-10:240,281-10:280,321-10:320,361-10:360,401-10:400];
TC = tc(Training_index_C,:);
VDC = data_PC(Validation_index_C,:);
VTC = tc(Validation_index_C,:);
TCr = tc(Validation_index_C,:);

TD = data_PC(Training_index_C,:);
HT = TD(1:30,:);
B7T = TD(31:60,:);
B14T = TD(61:90,:);
B21T = TD(91:120,:);
I7T = TD(121:150,:);
I14T = TD(151:180,:);
I21T = TD(181:210,:);
O7T = TD(211:240,:);
O14T = TD(241:270,:);
O21T = TD(271:300,:);

%% Configuration
X = [HT;B14T];
k = 1:5;
nK = numel(k);
Sigma = {'diagonal','full'};
nSigma = numel(Sigma);
SharedCovariance = {true,false};
SCtext = {'true','false'};
nSC = numel(SharedCovariance);
RegularizationValue = 0.01;
options = statset('MaxIter',10000);

% Preallocation
gm = cell(nK,nSigma,nSC);
aic = zeros(nK,nSigma,nSC);
bic = zeros(nK,nSigma,nSC);
converged = false(nK,nSigma,nSC);
%% Fit all models
for m = 1:nSC
    for j = 1:nSigma
        for i = 1:nK
            gm{i,j,m} = fitgmdist(X,k(i),...
                'CovarianceType',Sigma{j},...
                'SharedCovariance',SharedCovariance{m},...
                'RegularizationValue',RegularizationValue,...
                'Options',options);
            aic(i,j,m) = gm{i,j,m}.AIC;
            bic(i,j,m) = gm{i,j,m}.BIC;
            converged(i,j,m) = gm{i,j,m}.Converged;
        end
    end
end

allConverge = (sum(converged(:)) == nK*nSigma*nSC)

%% Plot the AIC and BIC
figure(2)
bar(reshape(aic,nK,nSigma*nSC));
title('AIC For Various $k$ and $\Sigma$ Choices','Interpreter','latex');
xlabel('$k$','Interpreter','Latex');
ylabel('AIC');
legend({'Diagonal-shared','Full-shared','Diagonal-unshared',...
    'Full-unshared'});



%% Generate the model
% k ; 1:= diagonal and 2:=full; 1:=true and 2:=false (shared cov)
gmBest = gm{5,2,2};
kGMM = gmBest.NumComponents;
n = 1500;
x1 = linspace(2*min(VDA(:,1))-30, max(VDA(:,1))+30,n);
x2 = linspace(2*min(VDA(:,2))-10, max(VDA(:,2))+30,n);
[X1,X2] = meshgrid(x1,x2);
XG = [X1(:),X2(:)];
mahalDist = mahal(gmBest,XG);
threshold = sqrt(chi2inv(0.99,6));

resultaux = zeros(length(XG),1);
for cont = 1:length(XG)
    if min(mahalDist(cont,:))<= threshold
        resultaux(cont,1) = 1;
    end
end

% Plot boundary
figure(3)

title('{\bf GMM training}')
xlabel('Feature #1')
ylabel('Feature #2')
set(gca,'Color','w')
hold on
contour(X1,X2,reshape(resultaux,size(X1,1),size(X2,1)),[1,1],'Color','k');
gscatter(X(:,1),X(:,2))
axis=([-2,16,-10,70]);
%ylim=([-2,16]);
%xlim=([-10,70]);

%gscatter(data_norm(:,1), data_norm(:,2))
legend('off')
hold off


% Validation
mahalDistVal = mahal(gmBest,VDA);
confusion = zeros(3,3);
[p,m] = size(confusion);

matrix_for_data_validation = zeros(length(VDA),2);
labels=cell(length(VDA),1);%10);

for cont = 1:length(VDA)
   if min(mahalDistVal(cont,:))<= threshold && VTA(cont)==1 % True Positive
       confusion(1,1) = confusion(1,1)+1;
       matrix_for_data_validation(cont,:) = [VDA(cont,1) VDA(cont,2)];
       labels(cont,1) = {'True Positive'};
   elseif min(mahalDistVal(cont,:))<= threshold && VTA(cont)==0 % False Positive
       confusion(2,1) = confusion(2,1)+1;   
       matrix_for_data_validation(cont,:) = [VDA(cont,1) VDA(cont,2)];
       labels(cont,1) = {'False Positive'};
   elseif min(mahalDistVal(cont,:))>= threshold && VTA(cont)==1 % False Negative
       confusion(1,2) = confusion(1,2)+1;   
       matrix_for_data_validation(cont,:) = [VDA(cont,1) VDA(cont,2)];
       labels(cont,1) = {'False Negative'};
   elseif min(mahalDistVal(cont,:))>= threshold && VTA(cont)==0 % True Negative
       confusion(2,2) = confusion(2,2)+1;   
       matrix_for_data_validation(cont,:) = [VDA(cont,1) VDA(cont,2)];
       labels(cont,1) = {'True Negative'};
   end
end

confusion(3,1) = confusion(1,1)+confusion(2,1);
confusion(3,2) = confusion(1,2)+confusion(2,2);
confusion(1,3) = confusion(1,1)+confusion(1,2);
confusion(2,3) = confusion(2,1)+confusion(2,2);

confusion_per = zeros(2,2);
for i = 1:p-1
    for j = 1:m
        confusion_per(i,j) = confusion(i,j)/confusion(i,3);
    end
end
known = zeros(confusion(3,1),3);
a = 1;
for cont = 1:length(VDA)
   if min(mahalDistVal(cont,:))<= threshold
    known(a,1) = TAr(cont);
    known(a,2) = VDA(cont,1);
    known(a,3) = VDA(cont,2);
    a=a+1; 
   end
end

total_acc = (confusion_per(1,1)+confusion_per(2,2))/2;
GMM_A = known;
confusion_per;
%(1,1):= N classified as N
%(1,2):= N classified as UN
%(2,1):= UN classified as N
%(2,2):= UN classified as UN

figure(4)
contour(X1,X2,reshape(resultaux,size(X1,1),size(X2,1)),[1,1],'Color','k');
hold on
gscatter(VDA(:,1), VDA(:,2), labels, 'rgbcmyk', 'xo*+sd><^', 8)
title('Data Validation')
xlabel('Feature #1')
ylabel('Feature #2')
ax = gca;
ax.FontSize = 12;
ax.XAxis.Label.FontSize = 14;
ax.YAxis.Label.FontSize = 14;
xlim([-10 70])
ylim([-2 16])