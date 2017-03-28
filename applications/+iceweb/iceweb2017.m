function iceweb2017(subnetName, ds, ChannelTagList, ...
    snum, enum, nummins, products)
    debug.printfunctionstack('>');

    % load state
    statefile = sprintf('iceweb_%s_state.mat',subnetName);
    if exist(statefile, 'file')
        load(statefile)
    end

    % end time
    if enum==0
        enum = utnow - delaymins/1440;
    end
    
    % generate list of timewindows
    timewindows = iceweb.get_timewindow(enum, nummins, snum);
    
    % loop over timewindows
    for count = 1:length(timewindows.start)
        process_timewindow(subnetName, ChannelTagList, timewindows.start(count), timewindows.stop(count), ds, products);
    end
    debug.printfunctionstack('<');
end


function process_timewindow(subnetName, ChannelTagList, snum, enum, ds, products)
    debug.printfunctionstack('>');

    MILLISECOND_IN_DAYS = (1 / 86400000);
    enum = enum - MILLISECOND_IN_DAYS; % try to skip last sample

%     % load state
%     statefile = sprintf('iceweb_%s_state.mat',subnetName);
%     if exist(statefile, 'file')
%         load(statefile)
%         if snum < snum0 
%             return
%         end
%     end
% 		
%     % save state
%     ds0=ds; ChannelTagList0=ChannelTagList; snum0=snum; enum0=enum; subnetName0 = subnetName;
%     save(statefile, 'ds0', 'ChannelTagList0', 'snum0', 'enum0', 'subnetName0');
%     clear ds0 ChannelTagList0 snum0 enum0 subnetName0
           
    %% Save raw waveform data to MAT file
    jjj = datenum2julday(snum);
    wavrawmat = fullfile('iceweb', 'waveforms_raw', subnetName, datestr(snum,'yyyy-mm-dd'), datestr(snum,30));
    if ~exist(wavrawmat,'file')
        %% Get waveform data
        debug.print_debug(0, sprintf('%s %s: Getting waveforms for %s from %s to %s at %s',mfilename, datestr(utnow), subnetName , datestr(snum), datestr(enum)));
        %w = waveform(ds, ChannelTagList, snum, enum);
        w = iceweb.waveform_wrapper(ds, ChannelTagList, snum, enum); % returns 1 waveform per channeltag, in same order
        if isempty(w)
            ds
            ChannelTagList
            datestr(snum)
            datestr(enum)
                debug.printfunctionstack('<');
            return
        end
        mkdir(fileparts(wavrawmat));
        disp(sprintf('Saving waveform data to %s',wavrawmat));
        save(wavrawmat,'w');   
    end
    debug.printfunctionstack('<');

    % Save the cleaned waveform data to MAT file
    wavcleanmat = fullfile('iceweb', 'waveforms_clean', subnetName, datestr(snum,'yyyy-mm-dd'), datestr(snum,30));
    if ~exist(wavcleanmat,'file')

        % Eliminate empty waveform objects
        w = iceweb.waveform_remove_empty(w);
        if numel(w)==0
            debug.print_debug(0, 'No waveform data returned - skipping');
            return
        end

        % Clean the waveforms
        w = clean(w);

%         % Apply calibs which should be stored within sites structure to
%         % waveform objects to convert from counts to real physical
%         % units
%         w = iceweb.apply_calib(w, sites);

        % Pad all waveforms to same start/end
        [wsnum wenum] = gettimerange(w); % assume gaps already filled, signal
        w = pad(w, min([snum wsnum]), max([enum wenum]), 0);

        % Apply filter to all signals
%         w = iceweb.apply_filter(w); %%%%%%%%%%%%%%%% PARAMS dropped

        mkdir(fileparts(wavcleanmat));
        disp(sprintf('Saving waveform data to %s',wavcleanmat));
        save(wavcleanmat,'w');   
    end
    
    %% ICEWEB PRODUCTS
    
    % WAVEFORM PLOT
    if products.waveform_plot.doit
        close all
        plot_panels(w, 'visible', 'off')
        fname = fullfile('iceweb', 'plots', 'waveforms', subnetName, sprintf('%s.png',datestr(snum,30)) );
        orient tall;
        iceweb.saveImageFile(fname, 72); % this should make directory tree too
    end
    
    % RSAM
    if products.rsam.doit
        for measureNum = 1:numel(products.rsam.measures)
            measure = products.rsam.measures{measureNum};
            rsamobj = waveform2rsam(w, measure, products.rsam.samplingIntervalSeconds);
            %rsamobj.plot_panels()
            rsamobj.save_to_bob_file(fullfile('iceweb', 'rsam_data', 'SSSS.CCC.YYYY.MMMM.bob'));
        end
    end

    
    % PLOT SPECTROGRAMS
    if products.spectrograms.doit
        spectrogramFilename = fullfile('iceweb', 'plots', 'spectrograms', subnetName, sprintf('%s.png',datestr(snum,30)) );
        debug.print_debug(1, sprintf('Creating %s',spectrogramFilename))
        close all
        spectrogramFraction = 0.75;
        specObj = spectralobject(1024, 924, 10, [60 120]);
        [sgresult, Tcell, Fcell, Ycell] = iceweb.spectrogram_iceweb(specObj, w, spectrogramFraction, iceweb.extended_spectralobject_colormap);

            
        if sgresult > 0 % sgresult = number of waveforms for which a spectrogram was successfully plotted
            % SAVE SPECTROGRAM PLOT TO IMAGE FILE AND CREATE THUMBNAIL
            orient tall;

            if iceweb.saveImageFile(spectrogramFilename, 72)

                fileinfo = dir(spectrogramFilename); % getting a weird Index exceeds matrix dimensions error here.
                debug.print_debug(0, sprintf('%s %s: spectrogram PNG size is %d',mfilename, datestr(utnow), fileinfo.bytes));	

%                 % make thumbnails
%                 makespectrogramthumbnails(spectrogramFilename, spectrogramFraction);

            end
        end
    end
    
  
    debug.printfunctionstack('<');
end
