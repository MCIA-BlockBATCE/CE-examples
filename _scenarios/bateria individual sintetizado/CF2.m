function FCoste2 = CF2(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Energy_price3h,Energy_price6h,SoC)
% CF2
% This cost function compares the need for the battery now versus later. To do this,
% we calculate the current deficit and the average deficit over the next three hours,
% applying the current cost of electricity and the average cost for the next
% three hours. A threshold is applied to this comparison to ensure that even
% if the battery is needed more later, we don't deprive ourselves of its use now.
% Also, a comparison between the current energy price and the energy 
% price in 6 hours is also used, so we can to look further into the future.

current_cost = (ConsPred1h - GenPred1h) * Energy_price;
 
cost_next3h = (ConsPred3h/3 - GenPred3h/3) * Energy_price3h;

if ((cost_next3h>current_cost*3) || (SoC < 1) || (Energy_price6h>Energy_price*1.25))
    % Do not use stored energy
    FCoste2 = 0;
else
    % Use stored energy
    FCoste2 = 1;
end

end
    
    