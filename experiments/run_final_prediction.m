clear; close all; clc;

%% 1. 학습된 ONNX 딥러닝 모델 불러오기
onnxFile = 'signal_model.onnx';
if ~exist(onnxFile, 'file')
    error(['오류: "', onnxFile, '" 파일을 찾을 수 없습니다. ', ...
           'Google Drive에서 다운로드하여 이 스크립트와 같은 폴더에 넣어주세요.']);
end
disp(['학습된 AI 모델 파일 "', onnxFile, '"을 불러옵니다...']);
net = importONNXNetwork(onnxFile, "TargetNetwork", "dlnetwork");
disp('모델 불러오기 완료.');

%% 2. 테스트용 실제 데이터 불러오기
% AI 모델이 한 번도 본 적 없는 새로운 데이터를 테스트용으로 사용합니다.
test_angle_deg = 25; % 테스트할 데이터의 실제 각도
test_filename = sprintf('p%d.csv', test_angle_deg);
test_filepath = fullfile('Datasets', test_filename);

if ~exist(test_filepath, 'file')
    error(['테스트 파일 "', test_filepath, '"을 찾을 수 없습니다.']);
end
fprintf('\n테스트용 데이터 파일 "%s"를 불러옵니다...\n', test_filepath);

% 원본 신호 (정답)
data_buf = readmatrix(test_filepath);
I_clean = data_buf(:, 1);
Q_clean = data_buf(:, 2);
clean_signal = I_clean + 1j*Q_clean;

% 딥러닝 모델에 맞는 형태로 reshape
required_length = 8192;
num_antennas = 8;
samples_per_ant = required_length / num_antennas;
clean_signal = clean_signal(1:required_length);
clean_signal = reshape(clean_signal, samples_per_ant, num_antennas);

% 수신 신호 시뮬레이션 (임의의 채널 왜곡 및 잡음 추가)
snr_db = 20;
h = 0.75 * exp(1j * deg2rad(-35)); % 임의의 테스트용 채널
distorted_signal = clean_signal * h;
signal_power = mean(abs(distorted_signal(:)).^2);
noise_power = signal_power / (10^(snr_db/10));
noise = sqrt(noise_power/2) * (randn(size(distorted_signal)) + 1j*randn(size(distorted_signal)));
received_signal = distorted_signal + noise;

%% 3. AI 모델 입력을 위한 데이터 형태 변환
% (샘플 수, 안테나 수, 채널=2) -> (채널, 샘플 수, 안테나 수) -> dlarray
X_test_matlab = cat(3, real(received_signal), imag(received_signal));
X_test_matlab = permute(X_test_matlab, [3, 1, 2]); 
X_test = dlarray(single(X_test_matlab), 'SSCB');

%% 4. AI 모델로 예측 실행
disp('AI 모델이 예측을 시작합니다...');
[pred_signal_dl, pred_angle_dl] = predict(net, X_test);

% 결과 변환
predicted_angle = extractdata(pred_angle_dl);
pred_signal_permuted = extractdata(pred_signal_dl);
pred_signal_matlab = ipermute(pred_signal_permuted, [3, 1, 2]);
restored_signal = pred_signal_matlab(:,:,1) + 1j * pred_signal_matlab(:,:,2);

%% 5. 최종 결과 확인
fprintf('\n========================================\n');
fprintf('## 최종 예측 결과 ##\n');
fprintf(' -> 실제 신호 각도: %.2f 도\n', test_angle_deg);
fprintf(' -> AI 모델 예측 각도: %.2f 도\n', predicted_angle);
fprintf('========================================\n');

% 성상도로 신호 복원 성능 시각화
figure;
sgtitle('AI 모델 최종 성능 검증');

subplot(1, 3, 1);
plot(clean_signal(:), '.', 'DisplayName','Original'); 
axis equal; grid on; title('1. 원본 신호 (정답)');
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');

subplot(1, 3, 2);
plot(received_signal(:), '.', 'DisplayName','Received'); 
axis equal; grid on; title('2. 수신 신호 (왜곡됨)');
xlabel('In-Phase (I)');

subplot(1, 3, 3);
plot(restored_signal(:), '.', 'DisplayName','Restored'); 
axis equal; grid on; title('3. AI가 복원한 신호');
xlabel('In-Phase (I)');