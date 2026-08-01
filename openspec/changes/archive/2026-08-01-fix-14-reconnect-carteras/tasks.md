# Tasks: Reconnect "Desglose por Carteras"

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~3 (2 deletions + 1 line removal) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | N/A |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Uncomment wallet grid + remove stale param | PR 1 | `xcodebuild build -scheme "Crypto Tracker"` | N/A — single view edit, no runtime harness needed | Re-comment lines 49–85 and restore line 56 |

## Phase 1: Reconnect Wallet Grid

- [x] 1.1 In `Views/Portfolio/xCartera/PortfolioDetalleView.swift`, remove the block-comment delimiters: delete `/*` on line 49 and `*/` on line 85.
- [x] 1.2 In the same file, delete the stale parameter `movimientoService: movimientoService` on line 56 (the first `CarteraDetailView` initializer). The second initializer (line 71) already omits it.
- [x] 1.3 Verify the macOS target builds without errors: `xcodebuild build -scheme "Crypto Tracker"`.
