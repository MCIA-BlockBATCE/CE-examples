function [ADR,POR_CE,avg_days] = consumption_profile_metrics(Pcons_real)
% CONSUMPTION_PROFILE_METRICS
%   Consumption profile metrics are:
%       - Average Difference Rate (ADR) [kW], as the cummulative increment of
%       average power consumption of all CE members. A small value
%       indicates that all consumption profiles are close in terms of
%       amplitude, whereas a large value indicates that some of
%       the consumption profiles have different magnitude orders.
%       - Profile Overlapping Rate (POR), as the intersection of the
%       areas below two consumption profile curves. A high value indicates
%       similar consumption patterns, whereas a low POR indicates different
%       consmpution patterns. As consumption profile curves are compared in
%       pairs, it is of interest to obtain the minimum and maximum OR, as
%       well as the average value for all pairs of consumption profiles.

% Average-day for each member is computeed
aux = size(Pcons_real);
members = aux(2);

avg_days = zeros(96,members);
day = 1;
for j = 1:members
    
    q = 1;
    for i=1:672
        avg_days(q,j) = avg_days(q,j) + Pcons_real(i,j); 
        q = q + 1;
        if q == 97
            q = 1;
        end
    end
end

% --- ADR calculation ---
for j = 1:members
    mean_part(1,j) = mean(avg_days(:,j));
end

mean_part = sort(mean_part);
ADR = 0;

for j = 1:members-1
    ADR = ADR + (mean_part(j+1)-mean_part(j));
end

% --- OR calculation ---
POR_vector = [];
POR_CE = zeros(3,1);

for i = 1:members-1
    for j = i+1:members
        y1CE = Pcons_real(:,i);
        y2CE = Pcons_real(:,j);
        POR = POR_calculation(y1CE, y2CE);
        POR_vector(end+1) = POR;
    end

end

POR_CE = [min(POR_vector)*100, mean(POR_vector)*100, max(POR_vector)*100];
end

