function [hora,dia_setmana] = siguiente_hora(hora,dia_setmana)

hora=hora+1;
if hora==25
    dia_setmana=dia_setmana+1;
    if dia_setmana==8
        dia_setmana=1;
    end
    hora=1;
end

end

