clear all
close all

% INPUT Data matrix where
% - Rows are samples
% - Columns are consumption profiles

% OUTPUT Data matrix with results above the principal diagonal
% showing OR for each pair of consumption profiles

% Variable initialization
xCE = 1:1:100;
%y1CE = [1,3,4,5,6,5,4,3,4,3];
%y2CE = [2,3,4,5,6,7,6,5,4,3];
%y2CE = [2,2.5,3,4,5,6,5,4,3,2];
rng('default');
pd = makedist('Normal');
y1CE = random(pd, [1,100]);
y2CE = random(pd, [1,100]);

y1CE = abs(y1CE);
y2CE = abs(y2CE);

y1_is_bigger = false;
start_pos = 1;

% Find points where functions intersect, two cases
    % Matching point is a data point
    % Matching point is not a data point (actualIndex:lastOne)
intersect_indexes = [];

% Look for first datapoint that is not equal
while (y1CE(start_pos) == y2CE(start_pos))
    start_pos = start_pos + 1;

    if start_pos == length(y1CE)+1 
        % return OR = 100, signals are full MATCH
    end
end

if (y1CE(start_pos) > y2CE(start_pos))
    y1_is_bigger = true;
end

for i = start_pos:length(y1CE)
     if (y1_is_bigger)
        % Matching point is a data point
        if (y1CE(i) == y2CE(i))
            intersect_indexes(end+1) = i;
            y1_is_bigger = false;
        % Matching point is between the actual index and the last one
        elseif (y1CE(i) < y2CE(i))
            intersect_indexes(end+1) = i;
            y1_is_bigger = false;
        end
     else
        if (y1CE(i) == y2CE(i))
            intersect_indexes(end+1) = i;
            y1_is_bigger = true;
        % Matching point is between the actual index and the last one
        elseif (y1CE(i) > y2CE(i))
            intersect_indexes(end+1) = i;
            y1_is_bigger = true;
        end
     end
end

% Up to this point, N interesection points can be found

% Case for N = 0
if isempty(intersect_indexes)
    % what to do, one must be contained in the other. Find the smaller one
    % and get its area
    if (y1CE(start_pos) > y2CE(start_pos))
        % y1 is bigger
        total_intersect_area = trapz(y2CE);
    else
        total_intersect_area = trapz(y1CE);
    end
% Case for N = 1 is singular, two "triangles" need to be found, area
% computed and added up
elseif (length(intersect_indexes) == 1)

    % Find which function is smaller in the first triangle
    y1_is_bigger_first_triangle = false;
    y1_is_bigger_second_triangle = false;
    
    if(y1CE(intersect_indexes-1) > y2CE(intersect_indexes-1))
        y1_is_bigger_first_triangle = true;
    end
    
    if (y1_is_bigger_first_triangle)
        first_triangle_area = trapz(y2CE(1:intersect_indexes-1));
        second_triangle_area = trapz(y1CE(intersect_indexes:length(y1CE)));
        total_intersect_area = first_triangle_area + second_triangle_area;
    else
        first_triangle_area = trapz(y1CE(1:intersect_indexes));
        second_triangle_area = trapz(y2CE(intersect_indexes:length(y2CE)));
        total_intersect_area = first_triangle_area + second_triangle_area;
    end

% Case for N = 2 is straight
elseif (length(intersect_indexes) == 2)

    % Take two indexes
    N1 = intersect_indexes(1);
    N2 = intersect_indexes(2);

    % Find which function is in each of the 3 segments
    y1_is_bigger_before_N1 = false;
    y1_is_bigger_between = false;
    y1_is_bigger_after_N2 = false;

    if (y1CE(N1-1) > y2CE(N1-1))
        y1_is_bigger_before_N1 = true;
    end

    if (y1CE(N1+1) > y2CE(N1+1)) 
        y1_is_bigger_between = true;
    end

    if (y1CE(N2+1) > y2CE(N2+1)) 
        y1_is_bigger_after_N2 = true;
    end

    % Area before N1
    if (y1_is_bigger_before_N1)
        area_segment_1 = trapz(y2CE(1:N1));
    else
        area_segment_1 = trapz(y1CE(1:N1));
    end

    % Area between N1 and N2
    if (y1_is_bigger_between)
        area_segment_2 = trapz(y2CE(N1:N2));
    else
        area_segment_2 = trapz(y1CE(N1:N2));
    end

    % Area after N2
    if (y1_is_bigger_before_N1)
        area_segment_3 = trapz(y2CE(N2:end));
    else
        area_segment_3 = trapz(y1CE(N2:end));
    end

    total_intersect_area = area_segment_1 + area_segment_2 + area_segment_3;
% Case for N > 2 can be tackled as N = 2, if intersections are treated in
% pairs, so area between Nk and Nk+1 can be performed N-1 times. E.G, for
% N = 3, there are 4 areas to compute, and there are N-1 (2) intermediate
% areas.
else
    % Compute area for the first segment
    N1 = intersect_indexes(1);

    y1_is_bigger_before_N1 = false;
    if (y1CE(N1-1) > y2CE(N1-1))
        y1_is_bigger_before_N1 = true;
    end

    if (y1_is_bigger_before_N1)
        area_segment_1 = trapz(y2CE(1:N1));
    else
        area_segment_1 = trapz(y1CE(1:N1));
    end

    intermediate_area = 0;
    % Take intersection indexes in pairs
    i = 2;
    while (i <= length(intersect_indexes))
        
        % Take two indexes
        NK = intersect_indexes(i-1); % Here is Nk
        NKK = intersect_indexes(i); % Here is Nk+1

        % Find which function is bigger from Nk to Nk+1
        y1_is_bigger_between = false;
        if (y1CE(NK+1) > y2CE(NKK+1)) 
            y1_is_bigger_between = true;
        end
    
        if (y1_is_bigger_between)
            intermediate_area = intermediate_area + trapz(y2CE(NK:NKK));
        else
            intermediate_area = intermediate_area + trapz(y1CE(NK:NKK));
        end
        i = i + 1;
    end

    % Compute area for the last segment
    NZ = intersect_indexes(end);
    y1_is_bigger_after_NZ = false;

    if (y1CE(NZ+1) > y2CE(NZ+1)) 
        y1_is_bigger_after_NZ = true;
    end

    if (y1_is_bigger_after_NZ)
        area_segment_Z = trapz(y2CE(NZ:end));
    else
        area_segment_Z = trapz(y1CE(NZ:end));
    end

    total_intersect_area = area_segment_1 + intermediate_area + area_segment_Z;
end

% Run through all vectors and find biggest for each sample

biggest_signal = [];
for j = 1:length(y1CE)
    if y1CE(j) > y2CE(j)
        biggest_signal(j) = y1CE(j);
    else
        biggest_signal(j) = y2CE(j);
    end
end

max_area = trapz(biggest_signal);

OR = total_intersect_area/max_area;

plot(xCE, y1CE, 'b.-', 'LineWidth', 2, 'MarkerSize', 20);
grid on;
hold on;
plot(xCE, y2CE, 'r.-', 'LineWidth', 2, 'MarkerSize', 20);
grid on;
hold on;
plot(xCE, biggest_signal, 'g.-', 'LineWidth', 2, 'MarkerSize', 20)
legend('P1', 'P2', 'MAX', 'location', 'southwest');	
xlabel('Time', 'FontSize', 20);
ylabel('Power consumption', 'FontSize', 20);


% % Run through the vector length
% for i = start_pos:length(y1CE)
% 
%     if (y1_is_bigger)
%         % Matching point is a data point
%         if (y1CE(i) == y2CE(i))
%             y = y1CE(i);
%             matchPoint = i;
%             y1_is_bigger = false;
% 
%         % Matching point is between the actual index and the last one
%         elseif (y1CE(i) < y2CE(i))
%         % % Get equations for the last two line segments.
%             coeff1 = polyfit(xCE(i-1:i), y1CE(i-1:i), 1);
%             coeff2 = polyfit(xCE(i-1:i), y2CE(i-1:i), 1);
% 
%             % Find out where the lines are equal.
%             % ax + b = cx + d.  Find x
%             % x = (d-b) / (a-c)
% 
%             matchPoint = (coeff2(2) - coeff1(2)) / (coeff1(1) - coeff2(1));
%             y = coeff1(1) * matchPoint + coeff1(2);
%             y1_is_bigger = false;
%         % Almacenar [x,y] del punto de cruce
%         end
%     else
%         % Matching point is a data point
%         if (y1CE(i) == y2CE(i))
%             y = y1CE(i);
%             matchPoint = i;
%             y1_is_bigger = true;
% 
%         % Matching point is between the actual index and the last one
%         elseif (y1CE(i) > y2CE(i))
%         % % Get equations for the last two line segments.
%             coeff1 = polyfit(xCE(i-1:i), y1CE(i-1:i), 1);
%             coeff2 = polyfit(xCE(i-1:i), y2CE(i-1:i), 1);
% 
%             % Find out where the lines are equal.
%             % ax + b = cx + d.  Find x
%             % x = (d-b) / (a-c)
% 
%             matchPoint = (coeff2(2) - coeff1(2)) / (coeff1(1) - coeff2(1));
%             y = coeff1(1) * matchPoint + coeff1(2);
%             y1_is_bigger = true;
%         % Almacenar [x,y] del punto de cruce
%         end
%     end
% 
% end

% caption = sprintf('Match at x = $%.2f, y = $%.2f', matchPoint, y);
% title(caption, 'FontSize', 20);
% % Draw lines in dark green color.
% darkGreen = [0, 0.5, 0];
% line([matchPoint, matchPoint], [0, y], 'Color', darkGreen, 'LineWidth', 2);
% line([0, matchPoint], [y, y], 'Color', darkGreen, 'LineWidth', 2);
% fprintf('Done running %s.m ...\n', mfilename);
% 
% % Una vez resuelto donde se cruzan, calculo de areas con trapz
% A1 = trapz(y1CE);
% A11 = trapz(y1CE(round(matchPoint):length(y1CE)));