clear; close all; clc

addpath('.\Generate_Data_Funcs');
addpath('.\Est_AoD_StepDiff_Funcs');


t = [0:pi/51.1:10*pi];                      % samples_per_ant: 1001개
set_angle_deg                  = 20;       % 설정 angle 값 | phase_difference = 2*pi * (d/lambda) * sin(set_angle_rad)
Amplitude                      = 1;        % 평균 Amplitude 값
phase_jitter_scale             = 0.00;     % 범위 (-scale, +scale)인 난수 생성
amplitude_jitter_scale         = 0.00;     % 범위 (-scale, +scale)인 난수 생성
I_Q_jitter_scale               = 0.00;     % 범위 (-scale, +scale)인 난수 생성 
fc                             = 2e9;      % carrier frequency: 2x10^9
d_scale                        = 0.5;      % d = d_scale * lambda
num_antennas                   = 8;        % 안테나 갯수

save_file = "Datasets\\";
% [I, Q] = Gen_Data(t, set_angle_deg, Amplitude, phase_jitter_scale, amplitude_jitter_scale, I_Q_jitter_scale, num_antennas , fc, d_scale);
for set_angle_deg = -90:5:90
    [I, Q] = Gen_Data(t, set_angle_deg, Amplitude, phase_jitter_scale, amplitude_jitter_scale, I_Q_jitter_scale, num_antennas, fc, d_scale);
    if set_angle_deg >=0
        filename = save_file + "p" + num2str(abs(set_angle_deg)) + ".csv";
    else
        filename = save_file + "m" + num2str(abs(set_angle_deg)) + ".csv";
    end
    writematrix([I, Q], filename);
end
fprintf("Data generated successfully.\n");

% set_angle_deg = 20;
% [I, Q] = Gen_Data(t, set_angle_deg, Amplitude, phase_jitter_scale, amplitude_jitter_scale, I_Q_jitter_scale, num_antennas , fc, d_scale);
% 
% txWaveform = I + 1j*Q;
%
% figure()
% plot(abs(txWaveform));
% 
% phase = angle(txWaveform(:));
% unwrap_phase = unwrap(phase);
% figure()
% plot(unwrap_phase);
% 
% 
% tolerance               = 0.4;  % diff_phase 허용 오차
% minIntervalLength       = 30;   % 최소 간격 길이
% intervals = detectLPInterval(unwrap_phase, tolerance, minIntervalLength);
% unwrapped_phase_wo_lp = eliminateLP(unwrap_phase, intervals, 0.1);
% angle_deg = estimateAoD(unwrapped_phase_wo_lp, intervals, length(unwrapped_phase_wo_lp)/2, fc, 0.5)