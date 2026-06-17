# CASES：FFmpeg 浏览器剪辑 × 懒猫网盘 — 测试金字塔

| 项 | 内容 |
|---|---|
| **关联 PRD** | [PRD-NETDISK.md](./PRD-NETDISK.md) |
| **关联 ARCH** | [ARCH-NETDISK.md](./ARCH-NETDISK.md) |
| **版本** | v1.1.0-cases |
| **更新** | 2026-06-17 |

---

## 1. 金字塔总览

```text
                    ┌─────────────┐
                    │   L4 验收   │  5 条  发布门禁 / 用户故事闭环
                    ├─────────────┤
                  ┌─┴─────────────┴─┐
                  │    L3 E2E 端到端   │  12 条  浏览器真实操作
                  ├───────────────────┤
                ┌─┴───────────────────┴─┐
                │   L2 集成 Integration  │  10 条  inject+网关+nginx+wasm
                ├─────────────────────────┤
              ┌─┴─────────────────────────┴─┐
              │      L1 冒烟 Smoke / 配置       │  8 条  build/install/静态
              ├─────────────────────────────────┤
            ┌─┴─────────────────────────────────┴─┐
            │         L0 基线 Baseline / 契约         │  6 条  文件/版本/契约
            └─────────────────────────────────────────┘
                              41 用例
```

| 层级 | 数量 | 执行时机 | 通过标准 | 失败处理 |
|---|---|---|---|---|
| **L0** | 6 | 每次改 manifest/content 前 | 100% | 阻塞开发 |
| **L1** | 8 | `project build` 后 | 100% | 阻塞 install |
| **L2** | 10 | `lpk install` 后 | ≥ 90% | 修配置/inject |
| **L3** | 12 | 浏览器手工/半自动 | ≥ 95% P0 | 阻塞 v1.1.0 |
| **L4** | 5 | 提审前 | 100% P0 | 阻塞发布 |

**原则**：下层全绿再跑上层；L3/L4 需准备网盘测试素材（见 §6）。

---

## 2. L0 — 基线 / 契约（6）

> 不启动浏览器；验证仓库与配置契约。

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| L0-01 | content 目录存在 | 检查 `lzc/content/lazycat-injects/lzc-file-chooser-inject.js` | 文件存在且 >10KB |
| L0-02 | contentdir 已声明 | 读 `lzc-build.yml` | 含 `contentdir: ./content` |
| L0-03 | inject manifest 契约 | 读 `lzc-manifest.yml` | 含 `injects` + `diskRoot` + `hooks.fileInput:true` |
| L0-04 | 路由契约 | 读 manifest routes | `=http://web:8080`，无 FQDN |
| L0-05 | 无错误 healthcheck | 读 manifest services.web | **无** healthcheck 段 |
| L0-06 | 版本号递增 | 读 `package.yml` | version ≥ 1.1.0 |

---

## 3. L1 — 冒烟 / 构建（8）

> build + install 后；CLI + 静态头。

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| L1-01 | LPK 构建成功 | `lzc-cli project build` | exit 0，产出 `.lpk` |
| L1-02 | LPK 含 content | `lzc-cli lpk info *.lpk` | 包信息含 content / inject 资源 |
| L1-03 | 安装成功 | `lzc-cli lpk install *.lpk` | Installation successful + URL |
| L1-04 | 应用状态正常 | 微服应用管理 | 非 error state |
| L1-05 | nginx 响应 200 | `curl -I https://ffmpeg.{box}/` | HTTP 200 |
| L1-06 | COOP 头 | curl 查响应头 | `Cross-Origin-Opener-Policy: same-origin` |
| L1-07 | COEP 头 | curl 查响应头 | `Cross-Origin-Embedder-Policy: require-corp` |
| L1-08 | inject 脚本可访问 | GET `.../lzcapp/pkg/content/lazycat-injects/lzc-file-chooser-inject.js` 或页面 Network | 200（登录态下） |

---

## 4. L2 — 集成（10）

> 浏览器 DevTools；验证 inject × wasm × 网关。

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| L2-01 | 跨域隔离 | Console: `crossOriginIsolated` | `true` |
| L2-02 | inject 已注册 | Console: 点选文件前查 Network/Scripts | inject js 已加载 |
| L2-03 | Load ffmpeg | 点击 Load ffmpeg | status loaded；无 COEP 报错 |
| L2-04 | 双通道弹窗 | 点击主视频 Choose | 出现「本机 / 懒猫网盘」 |
| L2-05 | 本机通道回退 | 弹窗选本机 | 原生 file picker；可选文件 |
| L2-06 | 网盘 fetch 鉴权 | 弹窗选网盘 → 选小文件 | Network: `/_lzc/files/home` 200 |
| L2-07 | File 对象注入 | 网盘选 MP4 后 | 预览区有视频；时长 >0 |
| L2-08 | Process 最小链 | 10s 片 → Mute → Process | Log 有 ffmpeg；Output 可预览 |
| L2-09 | Download 拦截 | 点 Download | 出现保存双通道弹窗 |
| L2-10 | 网关路由 | `lzc-cli project log` | app/web 无 crash loop；无 DNS misbehaving |

---

## 5. L3 — E2E 端到端（12）

> 完整用户路径；P0 标 ★。

### 5.1 输入路径

| ID | 用例 | 步骤 | 预期 | P |
|---|---|---|---|---|
| L3-01 | ★ 网盘主视频压缩 | 网盘选 50MB MP4 → Convert → CRF 28 → Process → 网盘保存 | 输出 MP4 可播放；体积变小 | P0 |
| L3-02 | ★ 网盘转 WebM | 同上 → Output WebM | WebM 可播放 | P0 |
| L3-03 | 网盘 + Trim | 网盘选片 → 设 Trim → GIF | GIF 时长符合 trim | P1 |
| L3-04 | 网盘字幕嵌入 | 主视频网盘 + Embed Subtitles → 网盘选 .srt | 软字幕可开关 | P0 |
| L3-05 | 网盘 Logo | Logo Overlay → 网盘 PNG | 水印可见 | P1 |
| L3-06 | 网盘 BGM 混音 | Mix Audio → 网盘 MP3 | 混音正常 | P1 |
| L3-07 | Batch 网盘两文件 | Batch ON → 两次网盘选片 → Mute → Queue | 两路均 Done；ZIP All 可存网盘 | P1 |

### 5.2 输出 / 回退路径

| ID | 用例 | 步骤 | 预期 | P |
|---|---|---|---|---|
| L3-08 | ★ 保存网盘指定目录 | Process 后 Download → 网盘 → 选 `视频/test/` | 该目录出现 output 文件 | P0 |
| L3-09 | ★ 保存本机回退 | Download → 本机 | 浏览器下载正常 | P0 |
| L3-10 | 本机输入回退 | 选本机 MP4 → Process | 与 v1.0 一致 | P0 |

### 5.3 边界

| ID | 用例 | 步骤 | 预期 | P |
|---|---|---|---|---|
| L3-11 | 拖拽仍本机 | 拖本地 MP4 到 drop-zone | 正常加载（不经过网盘弹窗） | P1 |
| L3-12 | 大文件提示/失败 | 网盘选 >800MB（若有） | 失败时有提示或 OOM 可理解；不白屏 | P2 |

---

## 6. L4 — 验收门禁（5）

> 发布 v1.1.0 必须 100% 通过（对应 PRD §7）。

| ID | 用户故事 | 验收步骤 | 通过标准 |
|---|---|---|---|
| L4-01 | US-01 网盘压缩 | L3-01 全流程 | 网盘输入→网盘输出，≤3 分钟（50MB） |
| L4-02 | US-02 结果回盘 | L3-08 | 目标目录文件 MD5 稳定、可播放 |
| L4-03 | US-03 辅助文件 | L3-04 或 L3-05 任一 | 网盘辅助素材可用 |
| L4-04 | US-06 本机回退 | L3-09 + L3-10 | 双通道无损 |
| L4-05 | 平台稳定 | L1-04 + L2-01 + L2-03 | 无 error state；wasm 可 Load |

---

## 7. Phase 2 增量用例（file_handler）

> v1.2.0 启用；当前 **Skip**。

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| P2-01 | 网盘关联打开 | 网盘右键 MP4 → 用 FFmpeg 打开 | 跳转应用且自动载入 |
| P2-02 | 深链参数 | URL 含 `?file=/xxx/a.mp4` | 自动 fetch 并 preview |
| P2-03 | 刷新不重复 | 处理完刷新 | 不重复加载（参数已清） |

---

## 8. 测试数据准备

| 资产 | 规格 | 路径建议（网盘） |
|---|---|---|
| T-VIDEO-S | H.264 MP4, 10～30s, ~20MB | `/测试/ffmpeg/sample-s.mp4` |
| T-VIDEO-M | H.264 MP4, 1～3min, ~80MB | `/测试/ffmpeg/sample-m.mp4` |
| T-VIDEO-L | MP4 ~300～500MB（可选） | `/测试/ffmpeg/sample-l.mp4` |
| T-SRT | UTF-8 字幕 | `/测试/ffmpeg/sample.srt` |
| T-PNG | 透明 Logo 512px | `/测试/ffmpeg/logo.png` |
| T-MP3 | 30s BGM | `/测试/ffmpeg/bgm.mp3` |

**环境**：

- 浏览器：Chrome/Edge 最新桌面版  
- 微服：已登录；网盘有上述素材  
- 网络：首次测需能访问 CDN（Load ffmpeg）  

---

## 9. 执行命令速查

```powershell
# L0：本地契约
Get-Item lzc/content/lazycat-injects/lzc-file-chooser-inject.js
Select-String -Path lzc/lzc-manifest.yml -Pattern "injects|web:8080"

# L1：构建安装
cd lzc
tar -czf pack/docs.tar.gz -C ../docs .   # docs 有变时
lzc-cli project build
lzc-cli lpk install .\cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk
lzc-cli project log -f

# L2/L3：浏览器
# 打开 Target URL → F12 Console
# crossOriginIsolated
# 按 L2/L3 表逐项打勾
```

---

## 10. 结果记录模板

```markdown
## 测试报告 — ffmpeg-webcli v1.1.0 网盘

| 项 | 值 |
|---|---|
| 日期 | YYYY-MM-DD |
| 微服 | zhistor |
| 浏览器 | Chrome xxx |
| LPK | cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk |

| 层级 | 通过 | 失败 | 跳过 |
|---|---|---|---|
| L0 | /6 | | |
| L1 | /8 | | |
| L2 | /10 | | |
| L3 | /12 | | |
| L4 | /5 | | |

### 失败明细
- Lx-xx: 现象 / 截图 / 日志

### 结论
- [ ] 可发布 v1.1.0
- [ ] 需修复后复测
```

---

## 11. 用例 ↔ 需求追溯矩阵

| PRD FR | 用例 ID |
|---|---|
| FR-01 主视频网盘 | L2-06, L2-07, L3-01, L4-01 |
| FR-02 辅助 input 网盘 | L3-04, L3-05, L3-06, L4-03 |
| FR-03 Download 存网盘 | L2-09, L3-08, L4-02 |
| FR-04 Batch ZIP 网盘 | L3-07 |
| FR-05 本机双通道 | L2-05, L3-09, L3-10, L4-04 |
| FR-06 inject 离线分发 | L0-01, L1-02, L1-08 |
| FR-07 file_handler | P2-01～P2-03 |
| FR-08 大文件错误 | L3-12 |
| NFR-01 隐私 | ARCH §5 数据流审计 |
| NFR-05 可维护 | L0-02, L1-01 |

---

## 12. 金字塔执行顺序（一页）

```text
1. L0 全绿 ──► 2. build (L1-01~03) ──► 3. L1 余项
       ──► 4. L2 全跑 ──► 5. L3 P0(★) ──► 6. L4 门禁
       ──► 7. L3 P1/P2 有余力再跑
```

**v1.1.0 最小发布集**：L0 + L1 + L2 + L3 中 ★ 四项 + L4 五项 = **28 条必跑**。
