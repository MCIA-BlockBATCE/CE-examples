function FCoste1 = PV_energy_management(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Selling_price,Energy_price3h,SoC,Energy_price6h)
FCoste1 = 1;

current_cost = (ConsPred1h-GenPred1h) * Energy_price;

cost_next3h = ((ConsPred3h-GenPred3h) * Energy_price3h);

if ((cost_next3h>current_cost*2.5) && (SoC<5)) || ((Energy_price6h > Energy_price*1.25))

       FCoste1 = 2;
end   

if Energy_price < Selling_price
        FCoste1 = 0;
end

end
    
    