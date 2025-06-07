% elo_2024_animation.m
% ============================================================
% Horizontal "race" of ATP Elo ratings through 2024
% ------------------------------------------------------------
% • Elo stored in a struct  (field = player name)
% • Best player shown at the TOP (YDir = reverse)
% • X-axis completely invisible  (axis off)
% • Player names displayed at the right end of each bar
% • Video saved as elo_2024_animation.mp4
% ============================================================

%% 1. Fetch 2024 match log if missing
csvFile = "atp_matches_2024.csv";
srcURL  = "https://github.com/JeffSackmann/tennis_atp/raw/master/atp_matches_2024.csv";
if ~isfile(csvFile)
    fprintf("Downloading %s …\n", csvFile);
    websave(csvFile, srcURL);                % urlwrite for very old releases
end

T = readtable(csvFile);
T.tourney_date = datetime(string(T.tourney_date), "InputFormat","yyyyMMdd");
T = sortrows(T,"tourney_date");             % chronological order

%% 2. Re-calculate Elo and take weekly snapshots
K          = 32;
defaultElo = 1500;
elo        = struct();                      % ratings container

snapshots    = struct("date",{}, "ratings",{});
nextSnapDate = dateshift(T.tourney_date(1),"start","week"); % first Monday

for i = 1:height(T)
    % players as valid struct fields
    w = matlab.lang.makeValidName(T.winner_name{i});
    l = matlab.lang.makeValidName(T.loser_name{i});
    if ~isfield(elo,w), elo.(w) = defaultElo; end
    if ~isfield(elo,l), elo.(l) = defaultElo; end

    RW = elo.(w);  RL = elo.(l);
    EW = 1/(1+10^((RL-RW)/400));

    elo.(w) = RW + K*(1-EW);
    elo.(l) = RL + K*(0-(1-EW));

    thisDate = T.tourney_date(i);
    if thisDate >= nextSnapDate || i == height(T)
        snapshots(end+1).date    = thisDate;          %#ok<SAGROW>
        snapshots(end  ).ratings = elo;               % struct copied by value
        nextSnapDate = nextSnapDate + calweeks(1);
    end
end

%% 3. Fixed-size figure & video writer
figW = 1350; figH = 780;
fig = figure('Units','pixels','Position',[100 100 figW figH], ...
             'Color','w','Resize','off');
ax  = axes('Parent',fig);
axis(ax,'off');                               % hide every axis element
set(ax,'YDir','reverse');                     % best at the top
ylim(ax,[0.5 10.5]);                          % room for 10 bars

vid = VideoWriter("elo_2024_animation.mp4","MPEG-4");
vid.FrameRate = 4;
open(vid);

%% 4. Draw frames  (start with snapshot #2)
for s = 2:numel(snapshots)

    % ----- struct → arrays, sort DESC -----
    ratingStruct = snapshots(s).ratings;
    fldNames     = fieldnames(ratingStruct);
    vals         = struct2array(ratingStruct).';
    [valsSorted, idx] = sort(vals,"descend");

    topN  = min(10,numel(idx));
    fldT  = fldNames(idx(1:topN));
    valsT = valsSorted(1:topN);
    namesT = strrep(fldT,'_',' ');        % readable names

    % ----- plot horizontal bars -----
    cla(ax);                              % clear previous frame
    b = barh(ax, valsT, ...
        'FaceColor','flat', 'EdgeColor','none');
    colormap(ax, parula(topN));
    b.CData = (1:topN).';                 % colour gradient
    ylim(ax,[0.5, topN+0.5]);
    set(ax,'YDir','reverse');             % best at the top

    % ----- player names at the right end -----
    for k = 1:topN
        text(ax, valsT(k)+5, k, namesT{k}, ...
             'VerticalAlignment','middle', 'FontSize',9);
    end
    xlim(ax,[min(valsT)-20, max(valsT)+90]);

    % ----- title -----
    title(ax, sprintf('ATP Elo race – %s', ...
        datestr(snapshots(s).date,'mmm dd, yyyy')), ...
        'FontWeight','bold');

    % ===== FINAL cosmetics: axe-icide! =====
    axis(ax,'off');                       % hides ticks + all borders

    drawnow;
    writeVideo(vid,getframe(fig));
end

close(vid);

fprintf("🎬  Finished!  Video saved as  elo_2024_animation.mp4\n");