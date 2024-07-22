function FCoste2 = ConsumirBatAlternatiu(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Precio_compra,Precio_compra_3h,Precio_compra_6h,SoC)
%% 
% Esta funcion de coste trata de comparar si AHORA vamos a necesitar más la
% batería que DESPUÉS, calcularemos el deficit AHORA y el deficit de media DURANTE
% LAS 3 PRÓXIMAS HORAS, y aplcando el coste de la luz ahora y el medio
% durante las próximas 3 horas. Le aplicamos un umbral a la comparacion
% (Aunque luego nos haga más falta no tenemos porqué privarnos ahora).

coste_ahora = (ConsPred1h - GenPred1h) * Precio_compra;
 
coste_proximas3h = (ConsPred3h/3 - GenPred3h/3) * Precio_compra_3h;

% coste_ahora =  Precio_compra;
% 
% coste_proximas3h =  Precio_compra_3h;

if ((coste_proximas3h>coste_ahora*4.5) || SoC < 1)
    % no usar batería
    FCoste2 = 0;
else
    % usar batería
    FCoste2 = 1;
end

end
    
    