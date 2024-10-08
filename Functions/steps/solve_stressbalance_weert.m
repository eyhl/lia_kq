function [md] = solve_stressbalance_weert(md, coefs, cw_min, cw_max)
    md = sethydrostaticmask(md);
    md.friction = frictionweertman();
    % initial guess if given
    % try
    %     disp('Using initial guess')
    %     md.friction.C = mdb.results.StressbalanceSolution.FrictionCoefficient;
    %     % normalize
    %     md.friction.C = (md.friction.C - min(md.friction.C)) / (max(md.friction.C) - min(md.friction.C));
    %     md.friction.C = 800 .* md.friction.C;
    % catch
    %     md.friction.C = 3000 * ones(md.mesh.numberofvertices,1);
    % end
    m = 3.0;
    md.friction.m = m * ones(md.mesh.numberofelements,1);
    md.friction.C = 1150 * ones(md.mesh.numberofvertices,1);

    % Control general
    md.inversion = m1qn3inversion(md.inversion);
    md.inversion.iscontrol = 1;
    md.verbose = verbose('solution', false, 'control', true);
    
    %Cost functions
    md.inversion.cost_functions = [101 103 501];
    md.inversion.cost_functions_coefficients = zeros(md.mesh.numberofvertices, numel(md.inversion.cost_functions));
    md.inversion.cost_functions_coefficients(:,1) = coefs(1);
    md.inversion.cost_functions_coefficients(:,2) = coefs(2);
    md.inversion.cost_functions_coefficients(:,3) = coefs(3);
    
    % remove non-ice and nans from misfit in cost function (will only rely on regularisation)
    pos = find(md.mask.ice_levelset > 0);
    md.inversion.cost_functions_coefficients(pos, 1:2) = 0;

    pos = find(isnan(md.inversion.vel_obs) | md.inversion.vel_obs == 0);
    md.inversion.cost_functions_coefficients(pos, 1:2) = 0;

    %Controls
    md.inversion.control_parameters={'FrictionC'};
    md.inversion.maxsteps = 200;
    md.inversion.maxiter = 200;
    md.inversion.min_parameters = cw_min * ones(md.mesh.numberofvertices, 1);
    md.inversion.max_parameters = cw_max * ones(md.mesh.numberofvertices, 1);
    md.inversion.control_scaling_factors = 1;
    md.inversion.gttol = 1e-10;
    md.inversion.dxmin = 1e-30;

    %Additional parameters
    md.stressbalance.restol = 0.01; % mechanical equilibrium residual convergence criterion
    md.stressbalance.reltol = 0.1; % velocity relative convergence criterion
    md.stressbalance.abstol = NaN; % velocity absolute convergence criterion (NaN=not applied)

    % Solve
    md = solve(md, 'sb');

    % Put results back into the model
    md.friction.C = md.results.StressbalanceSolution.FrictionC;
    md.initialization.vx = md.results.StressbalanceSolution.Vx;
    md.initialization.vy = md.results.StressbalanceSolution.Vy;
    md.initialization.vel = md.results.StressbalanceSolution.Vel;

    % Save present day inversion results in misc (If SB is recomputed for LIA these are lost)
    md.miscellaneous.dummy.J = md.results.StressbalanceSolution.J;
    md.miscellaneous.dummy.Adjointx = md.results.StressbalanceSolution.Adjointx;
    md.miscellaneous.dummy.Adjointy = md.results.StressbalanceSolution.Adjointy;
    md.miscellaneous.dummy.FrictionC = md.results.StressbalanceSolution.FrictionC;
    md.miscellaneous.dummy.Gradient1 = md.results.StressbalanceSolution.Gradient1;
end
