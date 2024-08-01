function [coeficients] = previous_sample_coefficients(CER)
    load("..\..\_data\energia_cons_CER.mat")
    num_participantes = length(CER);
    consum = energia_cons_CER(:,CER);
    
    % ens basarem amb els consums de la mostra anterior (fa 15 min)
    sum_consums_instant_anterior=zeros(2976,1);
    coeficients=zeros(2976,num_participantes);
    
    for t=2:2976
        sum_consums_instant_anterior(t,1)=sum(consum(t-1,:));
        for i=1:num_participantes
            coeficients(t,i)=consum(t-1,i)/sum_consums_instant_anterior(t,1);
        end
        if sum_consums_instant_anterior(t,:) == zeros(1,num_participantes)
            coeficients(t,:) = ones(1,num_participantes)*(1/num_participantes);
        end
    end
    coeficients(1,:)=coeficients(2,:); %inicialización

end
