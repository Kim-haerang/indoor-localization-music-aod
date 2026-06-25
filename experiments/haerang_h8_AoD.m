clear; close all; clc;
rng('shuffle');

%% 1. MISO 시스템 파라미터 정의
% =========================================================================
receiver_angles = -80:5:80;     % 테스트할 단일 수신기의 실제 각도
SNRdBs_to_test = 0:5:20;       % 테스트할 SNR 범위
angles_to_search = -90:0.1:90; % 송신기가 탐색할 AoD 범위

% 시스템 파라미터
fc = 2*10^9;                        
vc = physconst('lightspeed');       
lambda = vc/fc;                     
num_tx_antennas = 8; % MISO 송신기의 안테나 수            
tx_pos = [0; -0.4026; -0.9101; -1.4826; -2.4249; -3.0320; -3.8025; -4.6786]; % 송신기 안테나 위치

% 결과 저장을 위한 행렬 초기화
results_aod_phase = zeros(length(receiver_angles), length(SNRdBs_to_test));
results_aod_music = zeros(length(receiver_angles), length(SNRdBs_to_test));

%% 2. 파일럿 신호 생성 파라미터
% =========================================================================
pilot_len = 512; % 수신기가 보내는 파일럿 신호의 길이(스냅샷 수)
epsilon = 1e-9; 

%% 3. 시뮬레이션 루프: MISO 송신기가 최적 AoD를 추정하는 과정
% =========================================================================
fprintf('MISO Transmitter''s AoD Estimation Simulation Start...\n');
fprintf('%s\n', repmat('-', 1, 60));
fprintf('%-15s | %-7s | %-20s | %-15s\n', 'Receiver Angle', 'SNR', 'Phase Method AoD', 'MUSIC Method AoD');
fprintf('%s\n', repmat('-', 1, 60));

for i = 1:length(receiver_angles)
    true_angle = receiver_angles(i); 
    
    for j = 1:length(SNRdBs_to_test)
        SNRdB = SNRdBs_to_test(j);
        
        % 단일 수신기가 송신하는 파일럿 신호 생성
        tx_pilot = pskmod(randi([0 3], pilot_len, 1), 4, 0, 'gray');
        TX_PILOT_F = fft(tx_pilot);
        [~, max_power_idx] = max(abs(TX_PILOT_F));

        % MISO 송신기가 이 파일럿 신호를 수신하는 상황 모델링
        sv = exp(-1j * 2 * pi / lambda * tx_pos * sind(true_angle));
        rx_signal_at_tx_array = tx_pilot * sv.';
        
        % 수신된 파일럿 신호에 노이즈 추가
        p_rx = mean(abs(rx_signal_at_tx_array(:)).^2);
        rx_signal_normalized = rx_signal_at_tx_array / sqrt(p_rx);
        SNR_linear = 10^(SNRdB/10);
        noise_power = 1 / SNR_linear;
        noise = sqrt(noise_power/2) * (randn(size(rx_signal_normalized)) + 1j*randn(size(rx_signal_normalized)));
        X = rx_signal_normalized + noise;

        % --- [재추가] 방법 1: Phase Method ---
        RX_PILOT_F = fft(X);
        H_est = RX_PILOT_F ./ (TX_PILOT_F + epsilon);
        phases_at_max_power = angle(H_est(max_power_idx, :));
        phases_unwrapped = unwrap(phases_at_max_power);
        
        x_fit = (2 * pi / lambda) * tx_pos;
        p = polyfit(x_fit, phases_unwrapped.', 1);
        sin_theta = p(1);

        if abs(sin_theta) <= 1
            estimated_aod_phase = asind(sin_theta);
        else
            estimated_aod_phase = nan;
        end
        results_aod_phase(i, j) = estimated_aod_phase;

        % --- 방법 2: MUSIC 알고리즘 ---
        R = (X' * X) / pilot_len;
        [EVecs, ~] = eig(R);
        [~, idx] = sort(diag(eig(R)), 'ascend');
        EVecs = EVecs(:, idx);
        En = EVecs(:, 1:end-1);
        
        P = zeros(size(angles_to_search));
        for k = 1:length(angles_to_search)
            a = exp(+1j * 2 * pi / lambda * tx_pos * sind(angles_to_search(k)));
            P(k) = 1 / abs(a' * (En * En') * a);
        end
        
        [~, max_idx_music] = max(P);
        estimated_aod_music = angles_to_search(max_idx_music);
        results_aod_music(i, j) = estimated_aod_music;
        
        fprintf('%-15d | %-7d | %-20.2f | %-15.2f\n', ...
            true_angle, SNRdB, results_aod_phase(i, j), estimated_aod_music);
    end
end
fprintf('Simulation Finished.\n');

%% 4. 결과 시각화
% =========================================================================
% 특정 SNR에서의 성능 비교
snr_to_plot_idx = find(SNRdBs_to_test == 15);
if ~isempty(snr_to_plot_idx)
    figure;
    plot(receiver_angles, results_aod_phase(:, snr_to_plot_idx), 'b-o', 'LineWidth', 1.5, 'DisplayName', 'Phase Method');
    hold on;
    plot(receiver_angles, results_aod_music(:, snr_to_plot_idx), 'r-s', 'LineWidth', 1.5, 'DisplayName', 'MUSIC');
    plot(receiver_angles, receiver_angles, 'k--', 'LineWidth', 1, 'DisplayName', 'Ideal (Y=X)');
    grid on;
    xlabel('실제 수신기 각도 (도)');
    ylabel('추정된 출발각 (AoD) (도)');
    title(sprintf('실제 각도 대비 추정 AoD (SNR = %d dB)', SNRdBs_to_test(snr_to_plot_idx)));
    legend('Location', 'northwest');
end

% SNR에 따른 RMSE 성능 비교
rmse_phase = sqrt(mean((results_aod_phase - receiver_angles').^2, 1, 'omitnan'));
rmse_music = sqrt(mean((results_aod_music - receiver_angles').^2, 1, 'omitnan'));

figure;
semilogy(SNRdBs_to_test, rmse_phase, 'b-o', 'LineWidth', 1.5, 'DisplayName', 'Phase Method');
hold on;
semilogy(SNRdBs_to_test, rmse_music, 'r-s', 'LineWidth', 1.5, 'DisplayName', 'MUSIC');
grid on;
xlabel('SNR (dB)');
ylabel('AoD 추정 오차 (RMSE, 도)');
title('SNR에 따른 AoD 추정 알고리즘 성능 비교');
legend;