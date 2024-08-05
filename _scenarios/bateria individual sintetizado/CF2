function FCoste2 = CF2(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Energy_price3h,Energy_price6h,SoC)
%% 
% Esta funcion de coste trata de comparar si AHORA vamos a necesitar más la
% batería que DESPUÉS, calcularemos el deficit AHORA y el deficit de media DURANTE
% LAS 3 PRÓXIMAS HORAS, y aplcando el coste de la luz ahora y el medio
% durante las próximas 3 horas. Le aplicamos un umbral a la comparacion
% (Aunque luego nos haga más falta no tenemos porqué privarnos ahora).

current_cost = (ConsPred1h - GenPred1h) * Energy_price;
 
cost_next3h = (ConsPred3h/3 - GenPred3h/3) * Energy_price3h;

% coste_ahora =  Precio_compra;
% 
% coste_proximas3h =  Precio_compra_3h;

if ((cost_next3h>current_cost*4.5) || (SoC < 1) || (Energy_price6h>Energy_price*1.25))
    % no usar batería
    FCoste2 = 0;
else
    % usar batería
    FCoste2 = 1;
end

end
    
    