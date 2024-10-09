function [coefficients] = hybrid_coefficients(CER)

    load("..\..\_data\Pgen_pred_1h.mat");
    Pgen_pred_1h(Pgen_pred_1h==0)=0.001; % To solve some NaN issues
    load("..\..\_data\Pcons_pred_1h.mat");
    members = length(CER);
    consumption_pred = Pcons_pred_1h(:,CER);
    Psurplus_pred = zeros(2976,1);
    Palloc_pred = zeros(2976,members);
    for t=1:2976
        % First step, equal KoR
        for n=1:members
            if consumption_pred(t,n)>(Pgen_pred_1h(t,1)/members)
                Palloc_pred(t,n) = Palloc_pred(t,n) + (Pgen_pred_1h(t,1)/members);
            else
                Psurplus_pred(t,1) = Psurplus_pred(t,1)+((Pgen_pred_1h(t,1)/members)-consumption_pred(t,n));
                Palloc_pred(t,n) = Palloc_pred(t,n) + consumption_pred(t,n);
            end
        end
        % Second step, KoR based on consumption
        KoR(1,1:members) = consumption_pred(t,1:members)/sum(consumption_pred(t,1:members));
        for n=1:members
             Palloc_pred(t,n) = Palloc_pred(t,n) + KoR(1,n)*Psurplus_pred(t,1);
        end
        coefficients(t,1:members) = Palloc_pred(t,1:members)/sum(Palloc_pred(t,1:members));
    end
end

