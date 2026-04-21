%% run_batch.m
%  Batch processing: merge GNSS+LEO SP3 for multiple DOYs
%  2025 DOY 166-169, GPS week 2371, WUM RAP products
%
%  Naming: whu{GPS_week}{weekday}  (weekday: Sun=0, Mon=1, ... Sat=6)
%  DOY 166 = Sun Jun 15 -> whu23710, ..., DOY 169 = Wed Jun 18 -> whu23713
%
%  WUM RAP source: ftp://igs.gnsswhu.cn/pub/whu/phasebias/2025/

doy_list  = [166, 167, 168, 169];
wk_list   = [2371, 2371, 2371, 2371];
wd_list   = [0, 1, 2, 3];  % weekday index (Sun=0)

for i = 1:length(doy_list)
    d  = doy_list(i);
    wk = wk_list(i);
    wd = wd_list(i);

    gsp3 = sprintf('WUM0MGXRAP_2025%d0000_01D_05M_ORB.SP3', d);
    clk  = sprintf('WUM0MGXRAP_2025%d0000_01D_30S_CLK.CLK', d);
    lsp3 = sprintf('sp3_2025%d.sp3', d);
    outf = sprintf('whu%d%d_new.sp3', wk, wd);

    fprintf('\n========== DOY %d -> %s ==========\n', d, outf);
    mergeSP3(gsp3, clk, lsp3, outf);
end

fprintf('\n=== All done! ===\n');
