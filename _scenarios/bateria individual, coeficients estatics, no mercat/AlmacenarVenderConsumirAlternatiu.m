function FCoste1 = AlmacenarVenderConsumirAlternatiu(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Precio_compra,Precio_venta,Precio_compra_3h,SoC,Precio_compra_6h,Precio_compra_7h)
FCoste1 = 1;

coste_ahora = (ConsPred1h-GenPred1h) * Precio_compra;

coste_proximas3h = ((ConsPred3h-GenPred3h) * Precio_compra_3h);

%if ((coste_proximas3h>coste_ahora*2.5) && (SoC<15)) || ((Precio_compra_6h > Precio_compra*1.15))
if ((coste_proximas3h>coste_ahora*2.5) && (SoC<5)) || ((Precio_compra_6h > Precio_compra*1.25))

       FCoste1 = 2;
end   

if Precio_compra < Precio_venta
        FCoste1 = 0;
end

end
    
    