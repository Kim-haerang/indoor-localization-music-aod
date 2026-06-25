function [I, Q] = Gen_Data(t, set_angle_deg, Amplitude, phase_jitter_scale, amplitude_jitter_scale, I_Q_jitter_scale, num_antennas , fc, d_scale)
    %{
    parameters

    t = [0:pi/100:10*pi];                      % samples_per_ant: 1001개
    set_angle_deg                  = 20;       % 설정 angle 값 | phase_difference = 2*pi * (d/lambda) * sin(set_angle_rad)
    Amplitude                      = 1;        % 평균 Amplitude 값
    phase_jitter_scale             = 0.00;     % 범위 (-scale, +scale)인 난수 생성
    amplitude_jitter_scale         = 0.00;     % 범위 (-scale, +scale)인 난수 생성
    I_Q_jitter_scale               = 0.00;     % 범위 (-scale, +scale)인 난수 생성
    fc                             = 2e9;      % carrier frequency: 2x10^9
    d_scale                        = 0.5;      % d = d_scale * lambda
    num_antennas                   = 8;        % 안테나 갯수
    %}
    

    set_angle_rad = deg2rad(set_angle_deg);
    
    lambda = physconst('LightSpeed') / fc;
    d = d_scale * lambda;
    
    samples_per_ant = length(t);
    
    phase_difference = 2*pi * (d/lambda) * sin(set_angle_rad);
    phase_offsets = (0:num_antennas-1) * phase_difference;  % 1 x num_antennas

    t_col = t(:);  % samples_per_ant x 1
    
    phase_jitter = phase_jitter_scale * (2*rand(samples_per_ant*num_antennas*2, 1) - 1); % samples_per_ant x num_antennas
    
    amplitude_jitter = amplitude_jitter_scale * (2*rand(samples_per_ant*num_antennas*2, 1) - 1); % samples_per_ant x num_antennas
    
    I_jitter = I_Q_jitter_scale * (2*rand(samples_per_ant*num_antennas*2, 1) - 1); % samples_per_ant x num_antennas
    Q_jitter = I_Q_jitter_scale * (2*rand(samples_per_ant*num_antennas*2, 1) - 1);
    
    
    % Broadcasting: (samples_per_ant x 1) + (1 x num_antennas) -> (samples_per_ant x num_antennas)
    total_phase = t_col + phase_offsets;


    
    sync_scale = abs(phase_difference) * 1.5;
    sync = {zeros(samples_per_ant/2, 1), sync_scale*ones(samples_per_ant/2, 1), zeros(samples_per_ant, 1), sync_scale*ones(samples_per_ant, 1)};
    
    seqeunce = [1; 2; 3; 2; 1; 4; 3; 2; 1; 4; 1; 2];
    sync_phase = [];
    for idx=1:length(seqeunce)
        sync_phase = [sync_phase; sync{seqeunce(idx)}];
    end
    
    t_last = t(end);             
    dt = t(2) - t(1);
    sync_len = length(sync_phase);   
    t_sync = t_last + dt * (1:sync_len)';
    
    sync_phase = t_sync + sync_phase(:) + phase_offsets(end) + t(end);

    signal_sync_phase = [total_phase(:); sync_phase];

    S = (Amplitude + amplitude_jitter) .* exp(1j * signal_sync_phase + phase_jitter);
    S = S(:);


    I = real(S) + I_jitter;
    I = I(:);
    Q = imag(S) + Q_jitter;
    Q = Q(:);

end