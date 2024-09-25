x = 1:50; 
y = -0.3*x + 2*randn(1,50);
p = polyfit(x,y,1); % x,y contain the incoming-outcoming flows

% Evaluate the fitted polynomial p and plot:
f = polyval(p,x);
plot(x,y,'o',x,f,'-')
title('Linear regression for synthetic pipe model','Interpreter','latex');
xlabel('incoming flow [LPS]','Interpreter','latex');
ylabel('outcoming flow [LPS]','Interpreter','latex');

% obtain predicted values
new_incoming_flow = 42;
predicted_flow = polyval(p,new_incoming_flow);
hold on;
plot(new_incoming_flow,predicted_flow,'gx', 'MarkerSize', 10, 'LineWidth', 3)
legend('data','linear fit','prediction','Interpreter','latex')