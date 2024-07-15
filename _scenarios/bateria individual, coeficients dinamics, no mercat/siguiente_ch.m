function [ch,hora,dia_setmana] = siguiente_ch(ch,hora,dia_setmana)

ch = ch + 1;
hora = ceil(ch/4);

if ch == 97
        dia_setmana=dia_setmana+1;
        ch = 1;
    if dia_setmana==8
        dia_setmana=1;
    end
    hora=1;
end

end