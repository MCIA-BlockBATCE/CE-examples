function FCoste1 = AlmacenarVenderConsumirColectivo(Precio_compra,Precio_venta,DecisionBateria)
    % Vender: 0, Consumir: 1, Almacenar: 2
    FCoste1 = 1;
    
    if DecisionBateria == 2
           FCoste1 = 2;
    end   
    
    if Precio_compra < Precio_venta
            FCoste1 = 0;
    end
end
    
    