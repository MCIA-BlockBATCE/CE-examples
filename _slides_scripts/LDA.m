clear
clc
close all
load FeaturesHIOB_360samples_4classess_4operatingconditions_3severities.mat

%% -------------- Parte 1 Feature Normalization and classification --------
rng(1989)

FeaturesHIOv3=normal(FeaturesHIOB(241:end,:));
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


%% -------------- Parte 5 LDA Calculation ---------------------------------
figure,

X=FeaturesHIOv3;
y=Targets1C;
[Sw,Sb,Sm]=scatter_mat(X,y);

% Eigendecomposition
[V,D]=eig(inv(Sw)*Sb);

% Sort the eigenvalues in descending order and rearrange the eigenvectors accordingly
s=diag(D);
[s,ind]=sort(s,1,'descend');
V=V(:,ind);
% Select in A the eigenvectors corresponding to non-zero eigenvalues
A=V(:,1:2);
% Project the data set on the space spanned by the column vectors of A
FeaturesHIO_LDA=A'*X;
FeaturesHIO_LDA=FeaturesHIO_LDA';
plot(FeaturesHIO_LDA(:,1),FeaturesHIO_LDA(:,2),'g*')

for buc_2=1:length(FeaturesHIO_LDA)
   if(Targets1C(1,buc_2)==1)
   color='go';
     elseif(Targets1C(1,buc_2)==2)
       color='ro';
        elseif(Targets1C(1,buc_2)==3)
         color='yo';
          elseif(Targets1C(1,buc_2)==4)
           color='bo';
            elseif(Targets1C(1,buc_2)==5)
             color='mo';
              elseif(Targets1C(1,buc_2)==6)
               color='co';
                elseif(Targets1C(1,buc_2)==7)
                 color='ko';
                  elseif(Targets1C(1,buc_2)==8)
                   color='g.';
                    elseif(Targets1C(1,buc_2)==9)
                     color='r.';
                      elseif(Targets1C(1,buc_2)==10)
                       color='b*';
   end
    plot(FeaturesHIO_LDA(buc_2,1),FeaturesHIO_LDA(buc_2,2),color)
    hold on
    grid on
    title('LDA data Representation');
    
end