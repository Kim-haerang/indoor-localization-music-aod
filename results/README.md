# Results

대표 결과 이미지를 정리한 폴더입니다.

## 이미지 목록

| 이미지 | 설명 |
| --- | --- |
| `docs/images/music_covariance_heatmap.png` | MUSIC covariance accumulation 기반 각도 추정 결과 |
| `docs/images/phase_correction_result.png` | wrapped phase, unwrapped phase, CFO/AoD correction 비교 |
| `docs/images/cnn_denoising_result.png` | clean signal과 CNN denoising 결과 비교 |
| `docs/images/training_rmse_progress.png` | CNN 학습 중 RMSE/loss 변화 |

## 해석 요약

- MUSIC 기반 추정은 각도와 SNR 조건에 따라 안정성이 달라집니다.
- phase 보정은 각도 추정 전처리에서 중요합니다.
- CNN denoising은 잡음 완화 가능성을 보여주지만, 실제 시스템 적용 전 추가 검증이 필요합니다.
- 학습 RMSE가 감소하더라도 위치추정 정확도로 바로 연결되는지는 별도 평가가 필요합니다.
