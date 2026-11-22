| Run | Verdict | Tracking (µm) | Post-move (µm) | Settling (ms) | Endpoint (µm) |
| --- | --- | ---: | ---: | ---: | ---: |
| Diagonal | Pass | 65.7 | 3.0 | 0.00 | 0.4 |
| X only | Pass | 65.8 | 2.2 | 0.00 | 0.4 |
| Y only | Pass | 65.8 | 2.2 | 0.00 | 0.4 |
| Opposite diagonal | Pass | 65.7 | 3.0 | 0.00 | 0.4 |
| Corner, unshaped | Fail | 137.7 | 64.9 | 107.79 | 23.5 |
| Corner, shaped | Pass | 67.7 | 7.5 | 0.00 | 0.1 |

| Run | A speed (rpm) | B speed (rpm) | A phase peak (A) | B phase peak (A) |
| --- | ---: | ---: | ---: | ---: |
| Diagonal | 635 | 93 | 0.26 | 0.16 |
| X only | 454 | 454 | 0.24 | 0.24 |
| Y only | 454 | 454 | 0.24 | 0.24 |
| Opposite diagonal | 93 | 635 | 0.16 | 0.26 |
| Corner, unshaped | 461 | 454 | 0.34 | 0.26 |
| Corner, shaped | 454 | 454 | 0.23 | 0.23 |

The unshaped corner **failed** the verification case. The shaped corner **passed**. Peak tracking error was 137.7 µm without shaping and 67.7 µm with shaping, against a 100 µm limit.

The measured path came within 155.8 µm of the sharp vertex without shaping and within 188.6 µm with shaping. The nominal quadratic blend passes 176.8 µm from the vertex. This describes corner geometry, while tracking error is measured against each run's own commanded path.
