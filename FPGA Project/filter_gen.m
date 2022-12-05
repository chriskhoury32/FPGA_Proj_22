fs = 41000;
num_samples = 1024;
cutoffs = 100 * 1.4.^(0:15);

table = zeros(1, 32*num_samples);

for i = 1:length(cutoffs)
    [h_low, h_high] = find_impulses(cutoffs(i), fs, num_samples);
    
    data_low = arrayfun(@float_to_int, h_low);
    data_high = arrayfun(@float_to_int, h_high);
    
    start = num_samples*(i-1)+1;
    stop = num_samples*i;
    table(start:stop) = fliplr(data_low);
    table((start:stop)+16*num_samples) = fliplr(data_high);
end

mk_rom(table, 'filter_table', 'signed');

function [h_low, h_high] = find_impulses(cutoff, fs, num_samples)
    pass_width = floor(cutoff / fs * 2*num_samples);
    H = zeros(1, 2*num_samples);
    H(1:pass_width) = 1;
    H((end-(pass_width-2)):end) = 1;
    h_low = ifft(H);
    h_low = h_low(1:num_samples);
    h_high = ifft(1-H);
    h_high = h_high(1:num_samples);
end

function n = float_to_int(x)
    n = floor(2^14 * x);
end