function [Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, generation_allocation, factor_gen, CoR_type, members, week_day, hour, steps)
%PV_POWER_FORECASTING Summary of this function goes here
%   Detailed explanation goes here

    if CoR_type == 0
    
        for n=1:members     
            Pgen_pred_1h_allocated(:,n) = Pgen_pred_1h * generation_allocation(1,n).'*factor_gen;
            Pgen_pred_3h_allocated(:,n) = Pgen_pred_3h * generation_allocation(1,n).'*factor_gen; 
            
            Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(1,n).'*factor_gen;
    
        end
    
    elseif CoR_type == 2
    
        for n=1:members     
            Pgen_pred_1h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_1h*factor_gen;
            Pgen_pred_3h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_3h*factor_gen; 
            
            Pgen_real_allocated(:,n) = generation_allocation(:,n).*Pgen_real*factor_gen;
    
        end

    elseif CoR_type == 1

        for t=1:steps % EMPIEZA EL AÑO
            [X] = time_band(week_day,hour);
    
            for n=1:members     
                Pgen_pred_1h_allocated(:,n) = Pgen_pred_1h * generation_allocation(n,X)*factor_gen;
                Pgen_pred_3h_allocated(:,n) = Pgen_pred_3h * generation_allocation(n,X)*factor_gen; 
                
                Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X)*factor_gen;
            
            end
        end
    
    end

end