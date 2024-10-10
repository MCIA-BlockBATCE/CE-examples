function [coefficients] = hybrid_coefficients(CER)

    load("..\..\_data\Pgen_real.mat");
    Pgen_real(Pgen_real==0)=0.001; % To solve some NaN issues
    load("..\..\_data\energia_cons_CER.mat");
    Pcons_real = energia_cons_CER/0.25; % Energy to power
    members = length(CER);
    Pcons_real = Pcons_real(:,CER);
    Psurplus_pred = zeros(2976,1);
    Palloc_pred = zeros(2976,members);
    % Previous step power will be used to get KoR predictions
    for t=2:2976
        % First step, equal KoR
        for n=1:members
            if Pcons_real(t-1,n)>(Pgen_real(t-1,1)/members)
                Palloc_pred(t,n) = Palloc_pred(t,n) + (Pgen_real(t-1,1)/members);
            else
                Psurplus_pred(t,1) = Psurplus_pred(t,1)+((Pgen_real(t-1,1)/members)-Pcons_real(t-1,n));
                Palloc_pred(t,n) = Palloc_pred(t,n) + Pcons_real(t-1,n);
            end
        end
        % Second step, KoR based on consumption
        KoR(1,1:members) = Pcons_real(t-1,1:members)/sum(Pcons_real(t-1,1:members));
        for n=1:members
             Palloc_pred(t,n) = Palloc_pred(t,n) + KoR(1,n)*Psurplus_pred(t,1);
        end
        coefficients(t,1:members) = Palloc_pred(t,1:members)/sum(Palloc_pred(t,1:members));
    end
    coefficients(1,:) =  coefficients(2,:);
end

