function [coefficients] = hybrid_coefficients(CER)

    load("..\..\_data\Pgen_pred_1h.mat");
    load("..\..\_data\Pcons_pred.mat");
    members = length(CER);
    consumption_pred = Pcons_pred_1h(:,CER);

end

