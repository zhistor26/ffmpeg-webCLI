## 测试报告 — ffmpeg-webcli v1.1.0 网盘

| 项 | 值 |
|---|---|
| 日期 | 2026-06-17 |
| 微服 | zhistor |
| 执行 | `powershell -File lzc/scripts/run-cases.ps1 -SkipBuild -SkipInstall -E2E` |
| 浏览器 | Playwright Chromium（无 `LZC_MS_USER`/`LZC_MS_PASS` 时 E2E 在登录页阻断） |
| LPK | cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk (1.34 MiB) |
| URL | https://ffmpeg.zhistor.heiyu.space |
| CLI token | `lzc-cli config get token` 可用于 CLI；**不能**替代 HTTPS 微服 Web 会话（外网 curl 仍 307 → `/sys/login`） |

| 层级 | 通过 | 失败 | 跳过 |
|---|---|---|---|
| L0 | 6/6 | 0 | 0 |
| L1 | 8/8 | 0 | 0 |
| L2 | 1/10 | 0 | 9 |
| L3 | 0/12 | 0 | 12 |
| L4 | 0/5 | 0 | 5 |

**Phase 1 最小集（28 条，见 CASES §12）**：自动化 **15/28 通过**（L0+L1+ L2-10）；其余 13 条需已登录浏览器 + 网盘素材/手工选文件。

### 自动化脚本

| 文件 | 作用 |
|---|---|
| `lzc/scripts/run-cases.ps1` | L0–L1、`L2-10`（`project info` / `project exec`）；`-E2E` 调用 Playwright |
| `lzc/tests/e2e-netdisk.mjs` | L2-01–L2-04 等（需 `LZC_MS_USER`/`LZC_MS_PASS`）；网盘树与 L3 长流程标为 skip/手工 |
| `lzc/test-results-netdisk.json` | 本次机器运行 JSON 摘要（本地生成，未入库） |

### L0 / L1（全部通过）

与上一版一致：inject 1 060 283 bytes、`contentdir`、`=http://web:8080`、web 无 healthcheck、1.1.0、`Status_Running`、`project exec -s app ls .../lazycat-injects/` 含 inject.js；COOP/COEP 见 `images/nginx.conf`。

### L2

| ID | 结果 | 说明 |
|---|---|---|
| L2-01–L2-09 | 跳过 | 未设置微服账号；Playwright 无法越过登录页验证 COI/inject/Load ffmpeg |
| L2-10 | 通过 | `project info` 容器 Up；日志含 Internal health check successful |

### L3 / L4

全部 **跳过**（同上：无 Web 登录 + 网盘测试资产未挂载到自动化）。

### 失败明细

无失败项；未达成 28/28 的原因是 **环境阻塞**（凭据/会话），非 manifest 回归。

### 结论

- [x] Phase 1 构建/安装/inject 分发链路已验证（L0+L1+L2-10）
- [ ] **不可** 宣称 v1.1.0 网盘 28 条全绿，直至提供 `LZC_MS_USER`/`LZC_MS_PASS` 并完成 CASES §6 网盘样例与 L3 P0 手工或补全 E2E

**建议下一步**：在运行 E2E 的 shell 中 `$env:LZC_MS_USER=...; $env:LZC_MS_PASS=...`，再执行 `run-cases.ps1 -SkipBuild -SkipInstall -E2E`；网盘路径准备 `sample-s.mp4` 等后补 L3-01/08 与 L4 验收。
