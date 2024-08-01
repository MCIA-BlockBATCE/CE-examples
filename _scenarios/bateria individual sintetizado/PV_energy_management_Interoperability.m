function [FCoste1, P_discharge_max_bid] = PV_energy_management_Interoperability(stored_energy,bid_amount,current_step,bid_step,ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Selling_price,Energy_price3h,SoC,Energy_price6h,P_discharge_max)
FCoste1 = 1;

P_discharge_max_bid = P_discharge_max;
% TODO: Falta añadir consideración respecto al caño de descarga de la
% batería cuando se quiere garantizar cumplir con una oferta durante la
% tarde

% TODO: Falta tunear la FC para promover almacenamiento para ver diferentes
% comportamientos (que SoC no se asemeje tanto a función seno).

current_cost = (ConsPred1h-GenPred1h) * Energy_price;

cost_next3h = ((ConsPred3h-GenPred3h) * Energy_price3h);

diff_bat = stored_energy-bid_amount;

if ((cost_next3h>current_cost*2.5) && (SoC<15)) || ((Energy_price6h > Energy_price*1.5))
       FCoste1 = 2;
end   

% En los momentos de cumplimiento de la oferta, no se saca energia de la
% batería (se modifica el SoC en main)
if((current_step >= bid_step)  && (current_step <= bid_step + 3))
       P_discharge_max_bid = 0;

% Se cubre el caso en el que en las horas anteriores a la oferta se tiene suficiente energía almacenada, y
% y se gestiona la descarga progresiva (limitando la potencia de descarga máxima) asegurando la capacidad de
% satisfacer la oferta.
elseif((bid_amount/0.97) <= stored_energy)
       % FCoste1 = 2; % almacenar

       P_discharge_max_bid = P_discharge_max * (diff_bat/(bid_amount/0.97));
       
       % decision = "Corrijo según SoC"
       % instante_actual

% Se cubre el caso en el que en las horas anteriores a la oferta NO se
% tiene suficiente energía almacenada, necesitando priorizar el
% almacenamiento.
% Se entiende que esto solo se va a poder aplicar en casos en los que antes
% de la oferta se disponga de alguna energía de generación disponible para
% cargar la batería.
elseif((bid_amount/0.97) > stored_energy)
       FCoste1 = 2;
else
       P_discharge_max_bid = P_discharge_max;

end

if Energy_price < Selling_price
        FCoste1 = 0;
end

end