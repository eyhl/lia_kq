function [mass_balance_curve_struct, CM, all_names, leg] = mass_loss_curves_comparing_front_obs(md_list, md_control_list, md_names, folder, validate, retreat_advance, yaxis_lim) %md1, md2, md3, md_control, folder)

    if isfield(md_list(1), 'mesh') % the alternative is structs only holding relevant data, not the full model
        model_struct = true;
    else
        model_struct = false;
    end
    model_struct = true;
    if nargin < 7
        yaxis_lim = [-400, 10];
    end
    if nargin < 6
        retreat_advance = false;
    end
    if nargin < 5
        validate = true;
    end
    fast_flow_domain = false;

    plot_smb = false;
    historic = false;
    N = length(md_list);
    % CM = copper(N);
    CM = turbo(N);
    % if N > 1
    %     CM = CM(end-6:end, :);
    % end
    CM(1, :) = [0, 0, 0];

    % dt = 1/12;
    % start_time = md_list(1).smb.mass_balance(end, 1);
    % final_time = md_list(1).smb.mass_balance(end, end);
    line_styles = {'-', '-', '-', '-', '-', '-', '-', '-', '-'};
    % if nargin > 4
    %     present_thickness needs to be defined
    %     final_mass_loss = integrate_field_spatially(md_list(1), md_list(1).geometry.thickness - present_thickness) / (1e9) * 0.9167
    % end
    j = 1; % counting to place correct in struct
    mass_balance_curve_struct = struct();
    mass_balance_curve_struct.mass_balance = {};
    mass_balance_curve_struct.time = {};
    mass_balance_curve_struct.mouginot_t = {};
    mass_balance_curve_struct.mouginot_mb = {};
    mass_balance_curve_struct.mouginot_eps = {};
    mass_balance_curve_struct.mouginot_offset = {};
    mass_balance_curve_struct.patches = {};
    % set(gcf,'Position',[100 100 1500 750])

    if retreat_advance
        % plot a retreat advance background
        flowline = load("/home/eyhli/IceModeling/work/lia_kq/Data/validation/flowline_positions/central_flowline.mat"); 
        flowline = flowline.flowlineList{:};
        try 
            distance_analysis = load("/home/eyhli/IceModeling/work/lia_kq/Data/validation/flowline_positions/distance_analysis.mat", 'distance_analysis');
            distance_analysis = distance_analysis.distance_analysis;
            gradient_sign = distance_analysis.gradient_sign;
            gradient_interp = distance_analysis.gradient_interp;
            time_interp = distance_analysis.time_interp;
        catch
            [distance, distance_interp, gradient_interp, gradient_sign, time_interp] = get_central_front_position(md_list(1), flowline); % distance is measured from most extended front
            distance_analysis.distance = distance;
            distance_analysis.distance_interp = distance_interp;
            distance_analysis.gradient_interp = gradient_interp;
            distance_analysis.gradient_sign = gradient_sign;
            distance_analysis.time_interp = time_interp;
            save("/home/eyhli/IceModeling/work/lia_kq/Data/validation/flowline_positions/distance_analysis.mat", 'distance_analysis');
        end 

        % OBS OBS!! gradient interp is the gradient of the spatial retreat along flowline (should be in meters or kilometers)
        [xx1, yy1, xx2, yy2, grad1, grad2] = plot_background(time_interp, gradient_sign, [-400, 200], gradient_interp);
        grad1 = grad1(1:end-1);
        cmin = min(abs(horzcat(grad1, grad2)));
        cmax = max(abs(horzcat(grad1, grad2)));
        c1 = (grad1 - cmin)/(cmax - cmin);
        c2 = (grad2 - cmin)/(cmax - cmin);
    
        advance_N = size(grad1, 2);
        green = [0, 1, 0];
        light_green = [231, 255, 231]/255;
        greens = flipud([linspace(green(1), light_green(1), advance_N)', linspace(green(2), light_green(2), advance_N)', linspace(green(3), light_green(3), advance_N)']);
    
        retreat_N = size(grad2, 2);
        red = [1, 0, 0];
        pink = [255, 231, 231]/255;
        reds = ([linspace(red(1), pink(1), retreat_N)', linspace(red(2), pink(2), retreat_N)', linspace(red(3), pink(3), retreat_N)']);
    
        colormap([greens; reds])
        c1 = c1 * advance_N;
        c2 = c2 * retreat_N + advance_N + 1;
    
        p1 = patch(xx1, yy1, c1, 'FaceAlpha', 1, 'EdgeColor','none');
        hold on 
        p2 = patch(xx2, yy2, c2, 'FaceAlpha', 1, 'EdgeColor','none');

        mass_balance_curve_struct.patches = {[xx1, yy1, xx2, yy2]};
    end


    for i=1:N
        md = md_list(i);
        
        if fast_flow_domain
            %% Volume plot 1
            if model_struct
                [mass_balance, ~] = compute_mass_balance(md);
                vol1 = mass_balance;
                vol_times1 = cell2mat({md.results.TransientSolution(:).time});
            else
                vol1 = md.mass_balance{1};
                vol_times1 = md.time{1};
            end
        else
            %% Volume plot 1
            if model_struct
                vol1 = cell2mat({md.results.TransientSolution(:).IceVolume}) ./ (1e9) .* 0.9167; % Convert from m^3 km^3. 0.9167 is the density of ice in Gt/km^3, so this is Gt
                vol_times1 = cell2mat({md.results.TransientSolution(:).time});
            else
                vol1 = md.mass_balance{1};
                vol_times1 = md.time{1};
            end
        end
        p = plot(vol_times1, vol1 - vol1(1), 'color', CM(i,:), 'LineWidth', 2.0, 'LineStyle', line_styles{i});
        hold on;
        % p.Color(4) = 0.70 - (i-1)*0.40;
        mass_balance_curve_struct.mass_balance{j} = vol1 - vol1(1);
        mass_balance_curve_struct.time{j} = vol_times1;
        j = j + 1;

        if length(md_control_list) ~= 0
            md_control = md_control_list(i);
            if model_struct
                vol_c = cell2mat({md_control.results.TransientSolution(:).IceVolume}) ./ (1e9) .* 0.9167;
                vol_times_c = cell2mat({md_control.results.TransientSolution(:).time});
                q_times = md_control.levelset.spclevelset(end, :);

            else
                vol_c = md.mass_balance{1};
                vol_times_c = md_control.time{1};
                q_times = [];
                disp("spclevelset not saved in struct, load md instead")
            end
            % scatter(vol_times_c, vol_c - vol_c(1), 'color', CM(i,:), 'Marker', marker_control{i});
            %% Volume plot CONTROL

            % plot(vol_times_c, vol_c - vol_c(1), 'color', CM(i,:), 'LineWidth', 3.5, 'LineStyle', marker_control{i});
            % CM(i,:)
            vol_tmp = interp1(vol_times_c, vol_c - vol_c(1), q_times);
            plot(q_times, vol_tmp, 'color', CM(i,:) .* 0.7, 'marker', '+', 'LineStyle', 'none', 'MarkerSize', 7, 'LineWidth', 2);


            if historic
                if i == 1
                    q_times_historic = q_times(1:5);
                else
                    q_times_historic = [q_times(1:4), q_times(6)];
                end
                vol_tmp_historic = interp1(vol_times_c, vol_c - vol_c(1), q_times_historic);
                plot(q_times_historic, vol_tmp_historic, 'color', 'magenta', 'marker', 'o', 'LineStyle', 'none', 'MarkerSize', 7, 'LineWidth', 1);
            end
            mass_balance_curve_struct.mass_balance{j} = vol_c - vol_c(1);
            mass_balance_curve_struct.time{j} = vol_times_c;
        end
    end


    if validate
        % Assumes first model is the reference one
        md = md_list(1);
        [mb0, ~] = compute_mass_balance(md);
        mb0 = mb0 - mb0(1);

        model_times = cell2mat({md.results.TransientSolution(:).time});
        [~, index_1972] = min(abs(model_times - 1972));

        [cum_mb_1972_2018, cum_mb_errors] = get_mouginot2019_mb('cumulativeMassBalance');
        s = [-1, 1];
        [~, ind] = min([mb0(index_1972), cum_mb_1972_2018(1)]);

        offset = s(ind) * dist(mb0(index_1972), cum_mb_1972_2018(1));
        cum_mb_1972_2018 = cum_mb_1972_2018 + offset;
        mouginot_time_span = linspace(1972, 2018, length(cum_mb_1972_2018));
        % plot(mouginot_time_span, cum_mb_1972_2018 + offset_prior_1972, '-', 'color', 'red', 'LineWidth', 1.5);
        % h = errorbar(mouginot_time_span, cum_mb_1972_2018, cum_mb_errors, '*', 'color', [0.25, 0.25, 0.25], 'LineWidth', 1.0);
        % h = errorbar(mouginot_time_span, cum_mb_1972_2018, cum_mb_errors, '*', 'color', [0.25, 0.25, 0.25], 'LineWidth', 1.0);
        s1 = shadedErrorBar(mouginot_time_span, cum_mb_1972_2018, cum_mb_errors, 'lineProps', {'.','color',[.60,0.60,0.60], 'MarkerSize', 8}, 'patchSaturation', 0.1);
        set(s1.edge,'LineWidth',1.2,'LineStyle','--')
        mass_balance_curve_struct.mouginot_t{1} = mouginot_time_span;
        mass_balance_curve_struct.mouginot_mb{1} = cum_mb_1972_2018;
        mass_balance_curve_struct.mouginot_eps{1} = cum_mb_errors;
        mass_balance_curve_struct.mouginot_offset{1} = offset;
        % Set transparency level (0:1)
        alpha = 0.65;   
        % Set transparency (undocumented)
        % set([h.Bar, h.Line], 'ColorType', 'truecoloralpha', 'ColorData', [h.Line.ColorData(1:3); 255*alpha]);

        abbas_data = readtable('/home/eyhli/IceModeling/work/lia_kq/Data/validation/altimetry/khan2020/mass_loss_ts_KG_all.txt');
        % offset = s * sqrt((abbas_data.Var2(3) - mb0(index_1972(1)))^2) % index 3 is 1972
        [~, index_1972] = min(abs(model_times - 1993.4770));
        [~, ind] = min([mb0(index_1972), abbas_data.Var2(3)]);
        offset = s(ind) * dist(abbas_data.Var2(3), mb0(index_1972));

        abbas_mb_relative = abbas_data.Var2(1:end) + offset + 27 + 24;

        h = errorbar(abbas_data.Var1(1:end), abbas_mb_relative, abbas_data.Var3(1:end), '*', 'color', [0.65, 0.45, 0.65], 'LineWidth', 1.0, 'MarkerSize', 4);
        % shadedErrorBar(abbas_data.Var1(3:end), abbas_mb_relative, abbas_data.Var3(3:end), 'lineProps', {'.','color',[.75,0.55,0.75]}, 'patchSaturation', 0.1)

    end
    if plot_smb
        %% Volume plot CONTROL
        smb = cell2mat({md_list(1).results.TransientSolution(:).TotalSmb}) * 1e-12 * md_list(1).constants.yts; % from kg s^-1 to Gt/yr !! TotalSMB is already in Gt/yr
        smb_times = cell2mat({md_list(1).results.TransientSolution(:).time});
        dt = diff(smb_times);
        dt = [dt dt(end)]; % duplicate last time step as simple padding;        
        cumulative_smb = dt .* cumtrapz(smb);
        dt_avg = mean(dt);
        mov_window = int8(3 / dt_avg); % window over 3 years
        plot(smb_times, cumulative_smb, 'color', 'k', 'LineWidth', 1.5);  % dt=1/12
    end

    % scatter(vol_times_c(end), final_mass_loss, 'r');
    xlabel('Year')
    ylabel('Mass change (Gt)')
    xlim([1933, 2021.1])
    ylim([yaxis_lim(1), yaxis_lim(2)])
    % set(gca,'fontsize', 12)
    Ax = gca;
    Ax.YGrid = 'on';
    Ax.XGrid = 'on';
    Ax.Layer = 'top';
    Ax.GridLineStyle = ':';
    Ax.LineWidth = 0.5;
    Ax.GridAlpha = 0.4;

    if length(md_names) > 0
        all_names = md_names;
        if validate
            all_names = [all_names, "Mouginot et al. (2019)", "Khan et al. (2020)"];
        end
        if retreat_advance
            all_names = ["Advancing", "Retreating", all_names];
        end
        leg = legend([all_names], 'Location', 'SouthWest', 'Interpreter', 'latex', 'NumColumns', 2);
    else
        all_names = {};
        leg = [];
    end
    % title(leg,'Extrapolation constant')

    folder = string(folder);
    if exist(folder, 'dir') == 7 % checks if folder is a folder, returns 7 if it is a folder
        print(fullfile(folder, 'mass_balance_time_series.eps'), '-dpdf', '-r300')
        % exportgraphics(gcf, fullfile(folder, 'mass_balance_time_series.png'), 'Resolution', 300)
    end

end