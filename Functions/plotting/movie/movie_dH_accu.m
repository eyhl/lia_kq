function [] = movie_dH_accu(md, movieName, nstep)
    % TODO: ADD d(thicknesss)/dt plot
    set(0,'defaultfigurecolor',[1, 1, 1])
    % n_times = size(md.results.TransientSolution(:).Vel, 2)
    time = [md.results.TransientSolution.time];
    % output_freq = md.settings.output_frequency;
    % time = time(1:output_freq:end);
    length(time)
    Nt = length(time);
    nframes = floor(Nt/nstep) - 1;
    xl = [0.4002, 0.5121] * 1e6;
    yl = [-2.3107, -2.2116] * 1e6;

    % most retreated front
    if isfield(md.results.TransientSolution, 'MaskIceLevelset')
        masks = cell2mat({md.results.TransientSolution(:).MaskIceLevelset});
        [~, index] = min(sum(masks<0,1));
    end
 
    clear mov;
    close all;
    figure()
    mov(1:nframes) = struct('cdata', [],'colormap', []);
    count = 1;
    H = 0; %md.results.TransientSolution(1).Thickness;
    for i = 2:nstep:Nt
        if isfield(md.results.TransientSolution, 'MaskIceLevelset')
            masked_values = md.results.TransientSolution(index).MaskIceLevelset;
        else
            masked_values = md.mask.ice_levelset;
        end
        
        dH = md.results.TransientSolution(i).Thickness - md.results.TransientSolution(i-1).Thickness;
        H = H + dH;
        c_val = 3 * mad(H(masked_values<0));
        plotmodel(md,'data', H,...
            'levelset', masked_values, 'gridded', 1,...
            'caxis', [-c_val, c_val], 'colorbar', 'off',...
            'xtick', [], 'ytick', [], ...
            'colormap', redblue);%, ...
            % 'xlim', xl, 'ylim', yl, ...
            % 'tightsubplot#all', 1,...
            % 'hmargin#all', [0.01,0.0], 'vmargin#all',[0,0.06], 'gap#all',[.0 .0]); %,...
            % 'subplot', [nRows,nCols,subind(j)]);
        title(sprintf('Accumulated thicknening \n %s', datestr(decyear2date(time(i)), 'yyyy')))
        set(gca,'fontsize', 10);
        h = colorbar();
        title(h, 'm')
        % colormap(redblue)
        img = getframe(1);
        img = img.cdata;
        mov(count) = im2frame(img);
        % set(h, 'visible','off');
        % clear h;
        fprintf(['step ', num2str(count),' done\n']);
        count = count+1;
        clf;
    end
    % create video writer object
    writerObj = VideoWriter(movieName);
    % set the frame rate to one frame per second
    set(writerObj,'FrameRate', 20);
    % open the writer
    open(writerObj);

    for i=1:nframes
        img = frame2im(mov(i));
        [imind,cm] = rgb2ind(img,256,'dither');
        % convert the image to a frame using im2frame
        frame = im2frame(img);
        % write the frame to the video
        writeVideo(writerObj,frame);
    end
    close(writerObj);