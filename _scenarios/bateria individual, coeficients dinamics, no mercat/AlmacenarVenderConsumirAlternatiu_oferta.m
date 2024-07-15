function [FCoste1, P_discharge_max_oferta] = AlmacenarVenderConsumirAlternatiu_oferta(cantidad_bat_CER,cantidad_oferta,instante_actual,instante_oferta,ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Precio_compra,Precio_venta,Precio_compra_3h,SoC,Precio_compra_6h,P_discharge_max)
FCoste1 = 1;

P_discharge_max_oferta = P_discharge_max;
% TODO: Falta añadir consideración respecto al caño de descarga de la
% batería cuando se quiere garantizar cumplir con una oferta durante la
% tarde

% TODO: Falta tunear la FC para promover almacenamiento para ver diferentes
% comportamientos (que SoC no se asemeje tanto a función seno).

coste_ahora = (ConsPred1h-GenPred1h) * Precio_compra;

coste_proximas3h = ((ConsPred3h-GenPred3h) * Precio_compra_3h);

diff_bat = cantidad_bat_CER-cantidad_oferta;

if ((coste_proximas3h>coste_ahora*2.5) && (SoC<15)) || ((Precio_compra_6h > Precio_compra*1.5))
       FCoste1 = 2;
end   

% En los momentos de cumplimiento de la oferta, no se saca energia de la
% batería (se modifica el SoC en main)
if((instante_actual >= instante_oferta)  && (instante_actual <= instante_oferta + 3))
       P_discharge_max_oferta = 0;

% Se cubre el caso en el que en las horas anteriores a la oferta se tiene suficiente energía almacenada, y
% y se gestiona la descarga progresiva (limitando la potencia de descarga máxima) asegurando la capacidad de
% satisfacer la oferta.
elseif((cantidad_oferta/0.97) <= cantidad_bat_CER)
       % FCoste1 = 2; % almacenar

       P_discharge_max_oferta = P_discharge_max * (diff_bat/(cantidad_oferta/0.97));
       
       % decision = "Corrijo según SoC"
       % instante_actual

% Se cubre el caso en el que en las horas anteriores a la oferta NO se
% tiene suficiente energía almacenada, necesitando priorizar el
% almacenamiento.
% Se entiende que esto solo se va a poder aplicar en casos en los que antes
% de la oferta se disponga de alguna energía de generación disponible para
% cargar la batería.
elseif((cantidad_oferta/0.97) > cantidad_bat_CER)
       Fcoste1 = 2;
else
       P_discharge_max_oferta = P_discharge_max;

end

if Precio_compra < Precio_venta
        FCoste1 = 0;
end

end