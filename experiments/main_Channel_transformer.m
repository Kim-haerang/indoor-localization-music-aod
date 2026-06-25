clear; close all; clc

rng('shuffle');

%% Parameters

SNRdB           = 20;             % SNR : -6:2:20 
NRBs            = 50;             % # of RBs : 25(5MHz), 50(10MHz), 100(20MHz)
NumAntennas     = 8;              % Port : 0 ~ 3 (1 Layer : 0, 2 Layer : 0 / 1, 4 Layer : 0 / 1 / 2 / 3)
v_tdl           = 30;             % velocity (km/h) : 3km/h, 30km/h, 100km/h
DelaySpread     = 100*10^-9;      % delay spread(10ns, 30ns, 100ns, 300ns, 1000ns) : 10*10^-9 (short), 30*10^-9, 100*10^-9, 300*10^-9, 1000*10^-9 (long); 
fc              = 2*10^9;         % Carrirer Freq
ChModel         = 'TDL-A';        % Channel Model : 'TDL-A'(Rayleigh), 'TDL-D'(Rician)

%% Cell-Wide Settings

enb.NDLRB           = NRBs;           % # of RBs : 25(5MHz), 50(10MHz), 100(20MHz)
enb.CellRefP        = NumAntennas;    % Number of cell-specific reference signal antenna ports
enb.NCellID         = 10;             % Cell ID
enb.TotSubframes    = 10;

%% Basic Parameter

SNR = 10^(SNRdB/20);    % Linear SNR

%% Channel Model Configuration

% nfft_vector = [512, 1024, 2048];
% nfft = nfft_vector(NRBs/25);
nfft = 2048;
sr = 15000 * nfft;

vc = physconst('lightspeed'); % speed of light in m/s
fd = (v_tdl*1000/3600)/vc*fc;

tdl                     = nrTDLChannel;
tdl.DelayProfile        = ChModel;
tdl.DelaySpread         = DelaySpread;
tdl.MaximumDopplerShift = fd;
tdl.SampleRate          = sr;
tdl.RandomStream        = 'Global stream'; % random seed
tdl.NumReceiveAntennas  = NumAntennas;
tdl.NumTransmitAntennas = NumAntennas;
% Low, Custom: 제한 없음
% Medium, High : Co-Polar: 1, 2, 4
%              : Cross-Polar: 1, 2, 4, 8
tdl.Polarization = 'Cross-Polar';
tdl.MIMOCorrelation     = "High"; % "Low", "Medium", "high"
chInfo                  = info(tdl);

%% Load Generated Data
filename = sprintf('./Datasets/m5.csv');
data_buf = csvread(filename);

I = data_buf(:,1);
Q = data_buf(:,2);


% signal과 sync 분리 및 zero_padding 작업 (마지막 안테나에서 싱크 발생)
signal = I(1:4096) + 1j*Q(1:4096);
signal = reshape(signal, [], NumAntennas);

sync = I(4097:end) + 1j*Q(4097:end);
sync_with_zero_padding = zeros(4096, NumAntennas);
sync_with_zero_padding(:, end) = sync;

txWaveform_original = I + 1j*Q;
txWaveform = [signal; sync_with_zero_padding]; % [#, NumAntennas]
% plot(txWaveform)


[rxWaveform, pathGains]  = tdl(txWaveform);
pathFilters = getPathFilters(tdl);

% Calculate noise gain
N0 = 1/(sqrt(2.0*enb.CellRefP*double(length(txWaveform)))*SNR);

% Create additive white Gaussian noise
noise = N0*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));

% Add noise to the received time domain waveform
rxWaveform = rxWaveform + noise;

% 원래 데이터 형태로 다시 맞춤
rxWaveform = [reshape(rxWaveform(1:512, :), [], 1); rxWaveform(513:end,8)];


% Extract I and Q components from the received waveform
I_rx = real(rxWaveform);
Q_rx = imag(rxWaveform);



%% model train_data set

train_input = data_buf;        % model의 train_data: input data
train_target = [I_rx, Q_rx];   % model의 train_data: target data