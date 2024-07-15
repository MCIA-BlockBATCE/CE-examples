load('..\..\_data\base_data_2023.mat')
base_data_2023 = base_data_2023(:,[[2:13] 17]);
CER_excedentaria = [4 7 8 10 12 13];
num_participantes = length(CER_excedentaria);
consum = base_data_2023(:,CER_excedentaria);

% ens basarem amb els consums de la mostra anterior (fa 15 min)
sum_consums_instant_anterior=zeros(2976,1);
coeficients=zeros(2976,num_participantes);

for t=2:2976
    sum_consums_instant_anterior(t,1)=sum(base_data_2023(t-1,:));
    for i=1:num_participantes
        coeficients(t,i)=base_data_2023(t-1,i)/sum_consums_instant_anterior(t,1);
    end
    if sum_consums_instant_anterior(t,:) == zeros(1,num_participantes)
        coeficients(t,:) = ones(1,num_participantes)*(1/num_participantes);
    end
end
coeficients(1,:)=coeficients(2,:); %inicialización

writematrix(coeficients,'bbce2_Coeficientes_dinamicos.xlsx','Range','A1');
