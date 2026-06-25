clear; close all; clc;
rng('shuffle');

%% 1. 파라미터 설정
% --- 시뮬레이션 조건 ---
TOTAL_SAMPLES   = 512;
SNRdB_vec       = 0:5:20;
PLOT_ANTENNA_IDX = 1;

% --- 채널 조건 ---
NumAntennas     = 1; % 단일 안테나
v_tdl           = 30;
DelaySpread     = 100e-9;
fc              = 2e9;
ChModel         = 'TDL-A';

% --- 신호 구조 조건 ---
BLOCK_SIZE      = 64;
PHASE_STEP      = 2.5;
DATA_LEN        = 448;
SYNC_LEN        = TOTAL_SAMPLES - DATA_LEN;

% --- 유도 파라미터 ---
c = physconst('LightSpeed');
fd = (v_tdl*1000/3600)/c*fc;
ofdmInfo = nrOFDMInfo(50, 15); % SampleRate 계산용
SampleRate = ofdmInfo.SampleRate;

% --- 결과 저장용 ---
rmse_vs_snr = zeros(size(SNRdB_vec));

%% 2. 송신 신호 생성 (Transmitter)
fprintf('Generating transmit waveform (Data + Sync)...\n');

% --- 이상적인 위상 생성 ---
ideal_mod_ph = zeros(TOTAL_SAMPLES, 1);
% 데이터 구간 (계속 증가)
numBlocks_data = DATA_LEN / BLOCK_SIZE;
for i = 0:(numBlocks_data - 1)
    start_idx = i * BLOCK_SIZE + 1;
    end_idx = (i + 1) * BLOCK_SIZE;
    ideal_mod_ph(start_idx:end_idx) = PHASE_STEP * i;
end
% 동기 신호 구간 (0으로 고정)
sync_template_phase = zeros(SYNC_LEN, 1);
ideal_mod_ph(DATA_LEN + 1 : TOTAL_SAMPLES) = sync_template_phase;
ideal_data_ph = ideal_mod_ph(1:DATA_LEN); % 데이터 부분의 이상적인 위상

% --- 주파수 오프셋(CFO) 추가 ---
cfo_slope = 0.245; % 수신기는 이 값을 모름
linear_phase_cfo = (cfo_slope * (1:TOTAL_SAMPLES))';
total_tx_phase = ideal_mod_ph + linear_phase_cfo;
txWaveform = exp(1j * total_tx_phase);

%% 3. 채널 모델 설정
tdl = nrTDLChannel('DelayProfile', ChModel, 'DelaySpread', DelaySpread, ...
    'MaximumDopplerShift', fd, 'SampleRate', SampleRate, ...
    'NumReceiveAntennas', NumAntennas, 'NumTransmitAntennas', 1);

%% 4. 메인 SNR 루프
fprintf('Starting SNR sweep simulation...\n');
for snr_idx = 1:length(SNRdB_vec)
    snr_db = SNRdB_vec(snr_idx);
    fprintf('Processing SNR = %d dB...\n', snr_db);

    % --- 4.1. 채널 시뮬레이션 (TDL 페이딩 + AWGN) ---
    reset(tdl);
    rxWaveform_ideal = tdl(txWaveform);
    signal_power = mean(abs(rxWaveform_ideal).^2);
    noise_power = signal_power / (10^(snr_db/10));
    noise = sqrt(noise_power/2) * (randn(size(rxWaveform_ideal)) + 1j * randn(size(rxWaveform_ideal)));
    rxSignal = rxWaveform_ideal + noise;

    % --- 수신기 처리 시작 ---
    % --- 4.2. 동기 신호 탐색 ---
    sync_template_tx = exp(1j * sync_template_phase);
    [corr_val, lag] = xcorr(rxSignal, sync_template_tx);
    [~, max_idx] = max(abs(corr_val));
    sync_start_idx = lag(max_idx) + 1;
    
    % --- 4.3. 동기 신호를 이용한 채널 추정 (h8) ---
    rx_sync_block = rxSignal(sync_start_idx : sync_start_idx + SYNC_LEN - 1);
    h8_est = mean(rx_sync_block ./ sync_template_tx);

    % --- 4.4. 데이터 복원 ---
    rx_data_block = rxSignal(1:DATA_LEN);
    rx_data_eq = rx_data_block / h8_est; % 채널 보상
    
    recovered_phase_raw = unwrap(angle(rx_data_eq));
    cfo_slope_est = mean(diff(recovered_phase_raw)); % CFO 기울기 추정
    
    estimated_linear_phase = (1:DATA_LEN)' * cfo_slope_est;
    final_recovered_phase = recovered_phase_raw - estimated_linear_phase; % CFO 제거
    
    phase_offset = mean(final_recovered_phase(1:BLOCK_SIZE)) - mean(ideal_data_ph(1:BLOCK_SIZE));
    final_recovered_phase = final_recovered_phase - phase_offset; % 초기 위상 보정
    
    % --- 4.5. 오차 계산 (RMSE) ---
    rmse_vs_snr(snr_idx) = sqrt(mean((final_recovered_phase - ideal_data_ph).^2));
    
    % --- 4.6. 4분할 상세 플롯 생성 ---
    if snr_db == SNRdB_vec(1) || snr_db == SNRdB_vec(end)
        figure('Name', sprintf('CFO Estimation Analysis (SNR %d dB)', snr_db));
        sgtitle(sprintf('CFO Estimation Analysis (SNR = %d dB)', snr_db), 'FontSize', 14, 'FontWeight', 'bold');
        x_limit_range = [1 TOTAL_SAMPLES]; x_tick_steps = 0:BLOCK_SIZE:TOTAL_SAMPLES;
        
        subplot(2, 2, 1);
        plot(unwrap(angle(rxSignal))); title('1. Unwrapped Received Phase');
        grid on; xlim(x_limit_range); xticks(x_tick_steps);

        subplot(2, 2, 2);
        plot(unwrap(angle(rxSignal(1:DATA_LEN)/h8_est))); title('2. Phase after Channel Correction');
        grid on; xlim([1 DATA_LEN]); xticks(0:BLOCK_SIZE:DATA_LEN);

        subplot(2, 2, 3);
        plot(final_recovered_phase); title('3. Final Recovered Phase');
        grid on; xlim([1 DATA_LEN]); xticks(0:BLOCK_SIZE:DATA_LEN);

        subplot(2, 2, 4);
        plot(ideal_mod_ph); title('4. Ideal Phase (Ground Truth)');
        grid on; xlim(x_limit_range); xticks(x_tick_steps);
        xline(DATA_LEN, 'k--', 'Label', 'Sync Start');
    end
end
fprintf('Simulation finished.\n');

%% 5. 최종 성능 요약 플롯
figure;
semilogy(SNRdB_vec, rmse_vs_snr, '-o', 'LineWidth', 2, 'MarkerSize', 8);
title('CFO 추정 기반 위상 복원 성능 (RMSE)');
xlabel('SNR (dB)');
ylabel('Phase RMSE (radians)');
grid on;
xticks(SNRdB_vec);
set(gca, 'FontSize', 12);