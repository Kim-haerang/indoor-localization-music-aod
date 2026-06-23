# 실험 흐름

## 1. 데이터 생성

MATLAB에서 각도, SNR, 채널 모델 조건을 설정하고 수신 신호 데이터를 생성했습니다.

주요 조건:

- AoD / DoA angle
- SNR
- MISO / SIMO / MIMO 구조
- TDL channel model
- phase / CFO 영향

## 2. 신호 분석

생성된 신호를 바탕으로 아래 항목을 확인했습니다.

- 원본 신호
- 수신 신호
- wrapped phase
- unwrapped phase
- CFO 보정 전후 phase
- ground truth phase

## 3. MUSIC 기반 추정

안테나 배열의 covariance 정보를 활용해 MUSIC 기반 각도 추정 결과를 관찰했습니다.

확인한 내용:

- 실제 각도와 추정 각도 차이
- SNR에 따른 추정 안정성
- covariance accumulation 적용 시 추정 변화

## 4. CNN denoising 실험

잡음이 섞인 채널/위상 신호를 CNN으로 복원하는 실험을 진행했습니다.

확인한 내용:

- clean signal과 CNN output 비교
- RMSE 변화
- 학습 loss 감소 여부

## 5. 결과 정리

대표 결과 이미지는 `docs/images`에 저장했고, 결과 해석은 `results/README.md`에 정리했습니다.
