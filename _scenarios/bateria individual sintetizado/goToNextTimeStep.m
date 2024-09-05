function [ch,hour,week_day] = goToNextTimeStep(ch,week_day)

% This function returns updated time variables as time step increases

ch = ch + 1;
hour = ceil(ch/4);

if ch == 97
        week_day=week_day+1;
        ch = 1;
    if week_day==8
        week_day=1;
    end
    hour=1;
end

end