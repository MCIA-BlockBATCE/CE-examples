function [coefficients] = previous_sample_coefficients(CER)

% This function returns generation allocation coefficients depending on
% measured consumption of previous step

    load("..\..\_data\energia_cons_CER.mat")
    members = length(CER);
    consumption = energia_cons_CER(:,CER);
    
    sum_previous_consumption=zeros(2976,1);
    coefficients=zeros(2976,members);
    
    for t=2:2976
        sum_previous_consumption(t,1)=sum(consumption(t-1,:));
        for i=1:members
            coefficients(t,i)=consumption(t-1,i)/sum_previous_consumption(t,1);
        end
        if sum_previous_consumption(t,:) == zeros(1,members)
            coefficients(t,:) = ones(1,members)*(1/members);
        end
    end
    coefficients(1,:)=coefficients(2,:);

end
