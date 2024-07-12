load new_CER_Year.mat

% ens basarem amb els consums de la mostra anterior (fa 15 min)
sum_consums_instant_anterior=zeros(2976,1);
coeficients=zeros(2976,6);

for t=2:2976
    sum_consums_instant_anterior(t,1)=sum(new_CER_Year(t-1,:));
    for i=1:6
        coeficients(t,i)=new_CER_Year(t-1,i)/sum_consums_instant_anterior(t,1);
    end
    if sum_consums_instant_anterior(t,:) == zeros(1,6)
        coeficients(t,:) = ones(1,6)*(1/6);
    end
end
coeficients(1,:)=coeficients(2,:); %inicialización

writematrix(coeficients,'bbce2_Coeficientes_dinamicos.xlsx','Range','A1');
