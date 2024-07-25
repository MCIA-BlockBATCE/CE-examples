function [X] = tramo_coef(dia_setmana,hora)
    if (dia_setmana>0 && dia_setmana<6)
              if (hora>0 && hora<=8)
                 X=1;
              end
                
              if (hora>8 && hora<=10)||(hora>14 && hora<=18)||(hora>=23 && hora<=24)
                 X=2;
              end
    
              if (hora>10 && hora<=14)||(hora>18 && hora<=22)
                 X=3;
              end
    else
              X=1;
    end
end
