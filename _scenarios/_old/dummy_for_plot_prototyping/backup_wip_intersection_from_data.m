clear all
close all

% Para 2 señales
Sell = [12,22,28]
Price1 = [15,30,50]
Buy = [10,18,29]
Price2 = [25,42,50,]


plot(Sell, Price1, 'b.-', 'LineWidth', 2, 'MarkerSize', 20);
grid on;
hold on;
plot(Buy, Price2, 'r.-', 'LineWidth', 2, 'MarkerSize', 20);
legend('Sell', 'Buy', 'location', 'southwest');	
xlabel('Sell or Buy Price in $', 'FontSize', 20);
ylabel('Price1 or Price2 in $', 'FontSize', 20);

% Get equations for the last two line segments.
coeff1 = polyfit(Sell(2:3), Price1(2:3), 1)
coeff2 = polyfit(Buy(2:3), Price2(2:3), 1)

% Find out where the lines are equal.
% ax + b = cx + d.  Find x
% x = (d-b) / (a-c)

% Aquí hay que tener en cuenta casos en los que haya 0 cortes, 1 corte o
% más de 1
matchPrice = (coeff2(2) - coeff1(2)) / (coeff1(1) - coeff2(1))
y = coeff1(1) * matchPrice + coeff1(2)


caption = sprintf('Match at x = $%.2f, y = $%.2f', matchPrice, y);
title(caption, 'FontSize', 20);
% Draw lines in dark green color.
darkGreen = [0, 0.5, 0];
line([matchPrice, matchPrice], [0, y], 'Color', darkGreen, 'LineWidth', 2);
line([0, matchPrice], [y, y], 'Color', darkGreen, 'LineWidth', 2);
fprintf('Done running %s.m ...\n', mfilename);