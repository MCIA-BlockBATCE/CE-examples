function [X] = time_band(week_day,hour)
    if (week_day>0 && week_day<6)
              if (hour>0 && hour<=8)
                 X=1;
              end
                
              if (hour>8 && hour<=10)||(hour>14 && hour<=18)||(hour>=23 && hour<=24)
                 X=2;
              end
    
              if (hour>10 && hour<=14)||(hour>18 && hour<=22)
                 X=3;
              end
    else
              X=1;
    end
end
