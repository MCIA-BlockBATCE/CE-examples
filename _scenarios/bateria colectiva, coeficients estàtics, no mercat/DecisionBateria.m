function FCoste3 = DecisionBateria(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Precio_compra,Precio_compra_3h,Precio_compra_6h)
%% 
% Esta funcion de coste trata de comparar si AHORA vamos a necesitar más la
% batería que DESPUÉS, calcularemos el deficit AHORA y el deficit de media DURANTE
% LAS 3 PRÓXIMAS HORAS, y aplcando el coste de la luz ahora y el medio
% durante las próximas 3 horas.

votos_consumirBat=0;
votos_noconsumirBat=0;
votos_almacenarBat=0;

for n=1:8

    if ConsPred1h(1,n) > GenPred1h(1,n) * 1.20 %aplicamos un umbral para considerar que lo consumido es mayor que lo generado

        coste_ahora = (ConsPred1h(1,n)-GenPred1h(1,n)) * Precio_compra;

        coste_proximas3h = (ConsPred3h(1,n)/3-GenPred3h(1,n)/3) * Precio_compra_3h;

        if (coste_ahora*1.5>coste_proximas3h) && (Precio_compra*1.25>Precio_compra_6h) 
            votos_consumirBat=votos_consumirBat+1;
        else
            votos_noconsumirBat=votos_noconsumirBat+1;
        end 
      
    else
        
        coste_ahora = (ConsPred1h(1,n)-GenPred1h(1,n)) * Precio_compra;

        coste_proximas3h = (ConsPred3h(1,n)/3-GenPred3h(1,n)/3) * Precio_compra_3h;

        if (coste_ahora*2.5>coste_proximas3h) && (Precio_compra*1.5>Precio_compra_6h) && (GenPred1h(1,n)<ConsPred1h(1,n)*1.33)
            votos_noconsumirBat=votos_noconsumirBat+1;
        else
            votos_almacenarBat=votos_almacenarBat+1;
        end    
        
    end   
end

if (votos_consumirBat > votos_noconsumirBat) && (votos_consumirBat > votos_almacenarBat)
    FCoste3=1;
end

if (votos_noconsumirBat > votos_consumirBat) && (votos_noconsumirBat > votos_almacenarBat)
    FCoste3=0;
end

if (votos_almacenarBat > votos_consumirBat) && (votos_almacenarBat > votos_noconsumirBat)
    FCoste3=2;
end

if (votos_almacenarBat == votos_consumirBat) && (votos_almacenarBat > votos_noconsumirBat) %Caso de empate
    FCoste3=1;
end

if (votos_almacenarBat == votos_noconsumirBat) && (votos_almacenarBat > votos_consumirBat) %Caso de empate
    FCoste3=2;
end

if (votos_consumirBat == votos_noconsumirBat) && (votos_noconsumirBat > votos_almacenarBat) %Caso de empate
    FCoste3=1;
end


end

    
    