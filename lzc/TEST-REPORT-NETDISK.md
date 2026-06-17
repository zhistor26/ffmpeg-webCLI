## 测试报告 — ffmpeg-webcli v1.1.0 网盘

| 项 | 值 |
|---|---|
| 日期 | 2026-06-17 |
| 微服 | zhistor |
| 浏览器 | 待用户 L2～L4 手工验收（Agent 环境无法访问 HTTPS 微服） |
| LPK | cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk (1.34 MiB) |
| URL | https://ffmpeg.zhistor.heiyu.space |

| 层级 | 通过 | 失败 | 跳过 |
|---|---|---|---|
| L0 | 6/6 | 0 | 0 |
| L1 | 8/8 | 0 | 0 |
| L2 | 2/10 | 0 | 8 |
| L3 | 0/12 | 0 | 12 |
| L4 | 1/5 | 0 | 4 |

### L0 明细（全部通过）

| ID | 结果 | 证据 |
|---|---|---|
| L0-01 | ✅ | inject.js 1060283 bytes |
| L0-02 | ✅ | `contentdir: ./content` |
| L0-03 | ✅ | injects + diskRoot + hooks.fileInput |
| L0-04 | ✅ | `=http://web:8080` |
| L0-05 | ✅ | services.web 无 healthcheck |
| L0-06 | ✅ | version 1.1.0 |

### L1 明细（全部通过）

| ID | 结果 | 证据 |
|---|---|---|
| L1-01 | ✅ | `project build` exit 0 |
| L1-02 | ✅ | LPK 1.34 MiB（含 ~1MB content） |
| L1-03 | ✅ | Installation successful |
| L1-04 | ✅ | `Status_Running`, app healthy, web Up |
| L1-05 | ✅ | 网关日志 Internal health check successful |
| L1-06 | ✅ | nginx.conf COOP same-origin |
| L1-07 | ✅ | nginx.conf COEP require-corp |
| L1-08 | ✅ | `exec -s app ls .../lazycat-injects/` 有 inject.js |

### L2 明细（待浏览器补测）

| ID | 结果 | 说明 |
|---|---|---|
| L2-01 | ⏭ | 需浏览器 Console `crossOriginIsolated` |
| L2-02 | ⏭ | 需 Network 确认 inject 加载 |
| L2-03 | ⏭ | 需点击 Load ffmpeg |
| L2-04 | ⏭ | 需验证双通道弹窗 |
| L2-05 | ⏭ | 需验证本机回退 |
| L2-06 | ⏭ | 需网盘选文件 |
| L2-07 | ⏭ | 需网盘 MP4 预览 |
| L2-08 | ⏭ | 需 Process 最小链 |
| L2-09 | ⏭ | 需 Download 双通道 |
| L2-10 | ✅ | project log 无 DNS misbehaving / crash loop |

### L3 / L4

L3 全部 ⏭ 待用户在已登录浏览器 + 网盘测试素材下执行（见 CASES §6）。  
L4-05 部分 ✅（L1-04 + 部署稳定）；L4-01～04 依赖 L3 网盘 E2E。

### 失败明细

无。

### 结论

- [x] Phase 1 配置与 build/install 链路已验证
- [ ] L2～L4 浏览器网盘 E2E 待用户补测后可将本报告更新为「可发布 v1.1.0」

**建议补测步骤**：登录微服 → 打开应用 → 点「Click to choose」确认双通道 → 网盘选 50MB MP4 → Mute → Process → 保存到网盘。
