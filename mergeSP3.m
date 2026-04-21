%% mergeSP3.m
%  Merge WUM GNSS SP3/CLK + LEO SP3 into a combined SP3 product
%  Replaces csp3.exe with full satellite coverage and correct clocks
%
%  Usage:
%    mergeSP3(gsp3_file, clk_file, leo_sp3_file, output_file)
%    e.g. mergeSP3("WUM0MGXFIN_20233480000_01D_05M_ORB.SP3", ...
%                  "WUM0MGXFIN_20233480000_01D_30S_CLK.CLK", ...
%                  "sp3_2023348.sp3", "whu22924_new.sp3")
%
%  Input:
%    gsp3file - WUM GNSS orbit SP3 (5-min interval, IGS20)
%    clkfile  - WUM GNSS clock CLK (30-sec interval)
%    lsp3file - LEO orbit SP3 (60-sec interval, ITRF)
%    outfile  - Output combined SP3 (30-sec interval)
%
%  Author: Auto-generated for GNSS+LEO fusion project
%  Date:   2026-04-20

function mergeSP3(gsp3file, clkfile, lsp3file, outfile)
    fprintf("=== mergeSP3: GNSS+LEO Combined SP3 Generator ===\n\n");

    %% 1. Read WUM GNSS orbit SP3 (5-min)
    fprintf("[1/4] Reading GNSS orbit: %s\n", gsp3file);
    [g_prns, g_pos, g_clk, g_epochs] = readSP3(gsp3file);
    n_gnss = length(g_prns);
    g_dt = seconds(g_epochs(2) - g_epochs(1));
    fprintf("  -> %d GNSS satellites, %d epochs, %.0fs interval\n", ...
        n_gnss, size(g_pos,2), g_dt);

    %% 2. Read WUM CLK (30-sec)
    fprintf("[2/4] Reading GNSS clock: %s\n", clkfile);
    [c_prns, c_clk, c_epochs] = readCLK(clkfile);
    c_dt = seconds(c_epochs(2) - c_epochs(1));
    fprintf("  -> %d satellites, %d epochs, %.0fs interval\n", ...
        length(c_prns), size(c_clk,2), c_dt);

    %% 3. Read LEO SP3 (60-sec)
    fprintf("[3/4] Reading LEO orbit: %s\n", lsp3file);
    [l_prns, l_pos, ~, l_epochs] = readSP3(lsp3file);
    n_leo = length(l_prns);
    l_dt = seconds(l_epochs(2) - l_epochs(1));
    fprintf("  -> %d LEO satellites, %d epochs, %.0fs interval\n", ...
        n_leo, size(l_pos,2), l_dt);

    %% 4. Check satellite consistency
    missing_in_clk = setdiff(g_prns, c_prns);
    if ~isempty(missing_in_clk)
        fprintf("  WARNING: %d GNSS sats in ORB but not in CLK:\n", ...
            length(missing_in_clk));
        for k = 1:length(missing_in_clk)
            fprintf("    %s (will use ORB clock as fallback)\n", missing_in_clk{k});
        end
    end

    %% 5. Build output time vector (30-sec, covering LEO full range)
    t_start = l_epochs(1);
    t_end   = l_epochs(end);
    out_dt  = seconds(30);
    out_epochs = t_start : out_dt : t_end;
    n_out = length(out_epochs);
    fprintf("\n[4/4] Generating output: %d epochs (%.1f hours)\n", ...
        n_out, seconds(t_end - t_start) / 3600);

    % Time axes in seconds for interpolation
    g_t_sec  = seconds(g_epochs - g_epochs(1));
    l_t_sec  = seconds(l_epochs - l_epochs(1));
    c_t_sec  = seconds(c_epochs - g_epochs(1));
    o_t_gnss = seconds(out_epochs - g_epochs(1));
    o_t_leo  = seconds(out_epochs - l_epochs(1));

    %% 6. Interpolate GNSS positions (5-min -> 30s), 9th-order Lagrange
    fprintf("  Interpolating GNSS orbits (9th-order Lagrange, 5min->30s)...\n");
    g_pos_out = zeros(3, n_gnss, n_out);
    for i = 1:n_gnss
        for k = 1:3
            g_pos_out(k,i,:) = lagrange_interp(g_t_sec, g_pos(k,i,:), o_t_gnss, 9);
        end
        if mod(i, 20) == 0, fprintf("    sat %d/%d\n", i, n_gnss); end
    end

    %% 7. Interpolate LEO positions (60s -> 30s), 9th-order Lagrange
    fprintf("  Interpolating LEO orbits (9th-order Lagrange, 60s->30s)...\n");
    l_pos_out = zeros(3, n_leo, n_out);
    for i = 1:n_leo
        for k = 1:3
            l_pos_out(k,i,:) = lagrange_interp(l_t_sec, l_pos(k,i,:), o_t_leo, 9);
        end
        if mod(i, 30) == 0, fprintf("    sat %d/%d\n", i, n_leo); end
    end

    %% 8. GNSS clocks from CLK (30s direct, linear extrapolation at edges)
    fprintf("  Assigning GNSS clocks from CLK...\n");
    g_clk_out = zeros(n_gnss, n_out);
    for i = 1:n_gnss
        prn = g_prns{i};
        clk_idx = find(strcmp(c_prns, prn), 1);
        if ~isempty(clk_idx)
            g_clk_out(i,:) = interp1(c_t_sec, c_clk(clk_idx,:), o_t_gnss, ...
                "linear", "extrap");
        else
            g_clk_out(i,:) = interp1(g_t_sec, g_clk(i,:), o_t_gnss, ...
                "linear", "extrap");
        end
    end

    %% 9. LEO clocks: randomly borrow from one GNSS satellite per LEO
    %    Each LEO satellite picks one GNSS satellite and uses its clock
    %    across ALL epochs (preserving inter-epoch correlation)
    fprintf("  Assigning LEO clocks from GNSS (random selection)...\n");
    rng(42);  % fixed seed for reproducibility
    % Build pool of GNSS satellites that have CLK data
    clk_pool_idx = zeros(n_gnss, 1);
    for i = 1:n_gnss
        clk_pool_idx(i) = find(strcmp(c_prns, g_prns{i}), 1);
    end
    valid_pool = find(clk_pool_idx > 0);
    l_clk_out = zeros(n_leo, n_out);
    leo_gnss_map = zeros(n_leo, 1);  % record actual assignment for display
    for i = 1:n_leo
        pick = valid_pool(randi(length(valid_pool)));
        leo_gnss_map(i) = pick;
        l_clk_out(i,:) = interp1(c_t_sec, c_clk(pick,:), o_t_gnss, ...
            "linear", "extrap");
    end
    % Print assignment summary (first 5 and last 5)
    for i = [1:min(5,n_leo), max(1,n_leo-4):n_leo]
        fprintf("    LEO %s <- GNSS %s\n", l_prns{i}, c_prns{leo_gnss_map(i)});
    end

    %% 10. Write output SP3
    fprintf("  Writing output: %s\n", outfile);
    all_prns = [g_prns(:); l_prns(:)];  % vertical concat of column cells
    writeSP3(outfile, all_prns, g_pos_out, g_clk_out, l_pos_out, l_clk_out, out_epochs, n_gnss);

    fprintf("\n=== Done! %d satellites (%d GNSS + %d LEO), %d epochs ===\n", ...
        length(all_prns), n_gnss, n_leo, n_out);
    fprintf("  LEO clocks: randomly assigned from GNSS (rng seed=42)\n");
end

%% ================================================================
%%  readSP3 - Parse SP3 orbit file
%%  Returns: prns (cell), pos (3 x nsat x nepoch, km),
%%           clk (nsat x nepoch, microseconds), epochs (datetime)
%% ================================================================
function [prns, pos, clk, epochs] = readSP3(filename)
    fid = fopen(filename, "r");
    if fid == -1, error("Cannot open: %s", filename); end
    raw = fread(fid, "*char")';
    fclose(fid);

    lines = strsplit(raw, sprintf("\n"), "CollapseDelimiters", true);

    % First pass: count epochs and collect epoch info
    epoch_mask = strncmp(lines, "*  ", 3);
    data_mask = strncmp(lines, "P", 1);
    n_epoch = sum(epoch_mask);

    % Parse epochs
    epoch_lines = lines(epoch_mask);
    epochs = NaT(1, n_epoch);
    for i = 1:n_epoch
        L = epoch_lines{i};
        epochs(i) = datetime(str2double(L(4:7)), str2double(L(9:10)), ...
            str2double(L(12:13)), str2double(L(15:16)), str2double(L(18:19)), ...
            str2double(L(21:29)));
    end

    % Second pass: parse data lines (skip those before first epoch)
    first_epoch_idx = find(epoch_mask, 1, "first");
    data_lines = lines(first_epoch_idx+1:end);
    data_lines = data_lines(strncmp(data_lines, "P", 1));

    % Pre-allocate temp arrays
    n_rec = length(data_lines);
    prn_list = cell(n_rec, 1);
    pos_temp = zeros(n_rec, 4);  % x, y, z, clk
    eidx_temp = zeros(n_rec, 1);

    cur_epoch = 0;
    rec = 0;
    for i = 1:length(lines)
        if i >= first_epoch_idx && strncmp(lines{i}, "*  ", 3)
            cur_epoch = cur_epoch + 1;
        elseif strncmp(lines{i}, "P", 1) && cur_epoch > 0
            rec = rec + 1;
            prn_list{rec} = strtrim(lines{i}(2:4));
            vals = sscanf(lines{i}(5:end), "%f");
            if length(vals) >= 4
                pos_temp(rec, 1:4) = vals(1:4);
            end
            eidx_temp(rec) = cur_epoch;
        end
    end

    % Build unique PRN list
    prns = unique(prn_list);
    n_sat = length(prns);

    % Build pos (3 x n_sat x n_epoch) and clk (n_sat x n_epoch)
    pos = zeros(3, n_sat, n_epoch);
    clk = zeros(n_sat, n_epoch);
    for i = 1:rec
        pidx = find(strcmp(prns, prn_list{i}), 1);
        eidx = eidx_temp(i);
        pos(1, pidx, eidx) = pos_temp(i, 1);
        pos(2, pidx, eidx) = pos_temp(i, 2);
        pos(3, pidx, eidx) = pos_temp(i, 3);
        clk(pidx, eidx)     = pos_temp(i, 4);
    end
end

%% ================================================================
%%  readCLK - Parse RINEX 3.0 CLK file
%%  Returns: prns (cell), clk (nsat x nepoch, microseconds),
%%           epochs (datetime)
%% ================================================================
function [prns, clk, epochs] = readCLK(filename)
    % Read entire file at once (much faster than line-by-line fgetl)
    fid = fopen(filename, "r");
    if fid == -1, error("Cannot open: %s", filename); end
    raw = fread(fid, "*char")';
    fclose(fid);

    % Split into lines and find AS records
    lines = strsplit(raw, sprintf("\n"), "CollapseDelimiters", true);
    as_lines = lines(strncmp(lines, "AS ", 3));

    % Pre-allocate arrays
    n_rec = length(as_lines);
    prn_arr = cell(n_rec, 1);
    yr_arr  = zeros(n_rec, 1);
    mo_arr  = zeros(n_rec, 1);
    dy_arr  = zeros(n_rec, 1);
    hr_arr  = zeros(n_rec, 1);
    mi_arr  = zeros(n_rec, 1);
    sc_arr  = zeros(n_rec, 1);
    clk_arr = zeros(n_rec, 1);

    % Parse all AS records
    for i = 1:n_rec
        L = as_lines{i};
        prn_arr{i} = strtrim(L(4:6));
        yr_arr(i)  = str2double(L(9:12));
        mo_arr(i)  = str2double(L(14:15));
        dy_arr(i)  = str2double(L(17:18));
        hr_arr(i)  = str2double(L(20:21));
        mi_arr(i)  = str2double(L(23:24));
        sc_arr(i)  = str2double(L(26:34));
        clk_arr(i) = str2double(L(41:59)) * 1e6;  % seconds -> microseconds
    end

    % Build unique PRN list
    prns = unique(prn_arr);
    n_prn = length(prns);

    % Build unique epoch list using numeric MJD-like key
    ekey_arr = yr_arr*1e10 + mo_arr*1e8 + dy_arr*1e6 + hr_arr*1e4 + mi_arr*1e2 + floor(sc_arr);
    [uekeys, ~, eidx_map] = unique(ekey_arr);
    n_epoch = length(uekeys);

    % Build datetime epochs
    epochs = NaT(1, n_epoch);
    for i = 1:n_epoch
        idx = find(eidx_map == i, 1, "first");
        epochs(i) = datetime(yr_arr(idx), mo_arr(idx), dy_arr(idx), ...
            hr_arr(idx), mi_arr(idx), sc_arr(idx));
    end

    % Build clk matrix (n_prn x n_epoch)
    clk = zeros(n_prn, n_epoch);
    for i = 1:n_rec
        pidx = find(strcmp(prns, prn_arr{i}), 1);
        eidx = eidx_map(i);
        clk(pidx, eidx) = clk_arr(i);
    end
    epochs = epochs(:)';
end

%% ================================================================
%%  lagrange_interp - Nth-order Lagrange interpolation
%%  Standard IGS method for orbit interpolation (order=9)
%% ================================================================
function yq = lagrange_interp(x, y, xq, order)
    if nargin < 4, order = 9; end
    n = length(x);
    yq = zeros(size(xq));
    half = floor(order / 2);

    for i = 1:length(xq)
        t = xq(i);
        [~, c] = min(abs(x - t));
        left = c - half;
        right = c + half;
        if mod(order, 2) == 0, right = right + 1; end
        while left < 1, left = left+1; right = right+1; end
        while right > n, right = right-1; left = left-1; end

        xw = x(left:right);
        yw = y(left:right);
        nw = length(xw);
        val = 0;
        for j = 1:nw
            basis = 1;
            for k = 1:nw
                if k ~= j
                    basis = basis * (t - xw(k)) / (xw(j) - xw(k));
                end
            end
            val = val + yw(j) * basis;
        end
        yq(i) = val;
    end
end

%% ================================================================
%%  writeSP3 - Write combined SP3 file
%% ================================================================
function writeSP3(filename, all_prns, g_pos, g_clk, l_pos, l_clk, epochs, n_gnss)
    n_all = length(all_prns);
    n_epoch = length(epochs);

    fid = fopen(filename, "w");
    if fid == -1, error("Cannot create: %s", filename); end

    t0 = epochs(1);
    sc = second(t0); sc_i = floor(sc); sc_f = sc - sc_i;

    fprintf(fid, "#aP%4d %2d %2d %2d %2d %2d%11.8f    %4d ORBIT WGS84 HLM  SGG \n", ...
        year(t0), month(t0), day(t0), hour(t0), minute(t0), sc_i, sc_f, n_all);

    % GPS week
    gps_ep = datetime(1980, 1, 6);
    dg_days = days(t0 - gps_ep) + 5;
    gw = floor(dg_days / 7);
    gs = mod(dg_days, 7) * 86400 + hour(t0)*3600 + minute(t0)*60 + sc;
    mjd = datenum(t0) - datenum(1858, 11, 17);
    fprintf(fid, "## %4d %14.8f    %11.8f %5d %17.13f \n", ...
        gw, gs, 30.0, floor(mjd), mjd - floor(mjd));

    % PRN list (17 per line, padded to multiple of 4 lines)
    ptr = ''; lc = 0;
    for i = 1:n_all
        ptr = [ptr, sprintf('%3s', all_prns{i})]; %#ok<AGROW>
        if mod(i, 17) == 0 || i == n_all
            if lc == 0
                fprintf(fid, "+  %3d   %s\n", n_all, char(ptr));
            else
                fprintf(fid, "+        %s\n", char(ptr));
            end
            ptr = ''; lc = lc + 1;
        end
    end
    while mod(lc, 4) ~= 0
        fprintf(fid, "+  \n"); lc = lc + 1;
    end

    for i = 1:lc
        fprintf(fid, "++         0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0\n");
    end

    fprintf(fid, "%%c G  cc GPS ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc \n");
    fprintf(fid, "%%c cc cc ccc ccc cccc cccc cccc cccc ccccc ccccc ccccc ccccc \n");
    fprintf(fid, "%%f  1.2500000  1.025000000  0.00000000000  0.000000000000000 \n");
    fprintf(fid, "%%f  0.0000000  0.000000000  0.00000000000  0.000000000000000 \n");
    fprintf(fid, "%%i    0    0    0    0      0      0      0      0         0 \n");
    fprintf(fid, "%%i    0    0    0    0      0      0      0      0         0 \n");
    fprintf(fid, "/* Combined GNSS+LEO SP3 generated by mergeSP3.m                \n");
    fprintf(fid, "/* GNSS orbits: WUM final products (IGS20, 5min -> 30s interp) \n");
    fprintf(fid, "/* GNSS clocks: WUM final products (30s direct from CLK)        \n");
    fprintf(fid, "/* LEO orbits:  PANDA integration (ITRF, 60s -> 30s interp)     \n");

    % Data epochs
    for e = 1:n_epoch
        t = epochs(e);
        s2 = second(t); s2i = floor(s2); s2f = s2 - s2i;
        fprintf(fid, "*  %4d %2d %2d %2d %2d %2d%11.8f\n", ...
            year(t), month(t), day(t), hour(t), minute(t), s2i, s2f);

        for i = 1:n_gnss
            fprintf(fid, "P%s %14.6f %14.6f %14.6f %14.6f\n", ...
                all_prns{i}, g_pos(1,i,e), g_pos(2,i,e), g_pos(3,i,e), g_clk(i,e));
        end
        for i = 1:(n_all - n_gnss)
            fprintf(fid, "P%s %14.6f %14.6f %14.6f %14.6f\n", ...
                all_prns{n_gnss+i}, l_pos(1,i,e), l_pos(2,i,e), l_pos(3,i,e), l_clk(i,e));
        end
    end

    fprintf(fid, "EOF\n");
    fclose(fid);
end