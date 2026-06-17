# PRD：FFmpeg 浏览器剪辑 × 懒猫网盘对接

| 项 | 内容 |
|---|---|
| **产品** | cloud.lazycat.app.ffmpeg-webcli |
| **版本** | v1.1.0（网盘能力） |
| **状态** | 待开发 |
| **上游** | [zhistor26/ffmpeg-webCLI](https://github.com/zhistor26/ffmpeg-webCLI) |
| **基线** | v1.0.0 LPK 已上架运行（静态 nginx + ffmpeg.wasm） |
| **作者** | zhistor26 |
| **更新** | 2026-06-17 |

---

## 1. 背景与目标

### 1.1 背景

当前 LPK 已成功部署：NAS 托管静态页面，**100% 浏览器本地转码**，文件不上传服务器。用户选文件/下载结果仍走**本机文件系统**，与懒猫网盘数据面割裂——视频在 NAS 上，却要先下载到 PC 再上传进浏览器，体验断层。

### 1.2 产品目标

在**不改变「浏览器内 ffmpeg.wasm 转码」架构**的前提下，打通懒猫网盘：

1. **输入**：从网盘选视频/音频/字幕/图片，直接进入剪辑流程  
2. **输出**：处理结果保存回网盘指定目录  
3. **入口**：网盘右键「用 FFmpeg 剪辑打开」（可选）  
4. **体验**：中文文案、与微服登录态一致，无二次鉴权  

### 1.3 非目标（Out of Scope）

- NAS 端服务端转码（不做 ffmpeg 后端）  
- 拖拽网盘文件到 drop-zone（inject 不支持，v1.1 不做）  
- 突破浏览器 ~2GB WASM 内存上限  
- 多用户协作、版本历史、云端任务队列  
- 修改上游 GPL 许可策略  

### 1.4 成功指标

| 指标 | 目标 |
|---|---|
| 网盘选文件成功率 | ≥ 95%（≤500MB 常见格式） |
| 保存回网盘成功率 | ≥ 95% |
| 核心路径耗时 | 选文件 → 可 Process，≤ 30s（100MB 片） |
| 用户操作步数 | 比「先下到 PC 再选本地」减少 ≥ 2 步 |

---

## 2. 用户与场景

### 2.1 目标用户

- 懒猫微服家庭用户，视频存在网盘  
- 隐私敏感、不愿用 CloudConvert 等云端工具  
- 设备：桌面 Chrome/Edge 为主；手机仅轻度使用  

### 2.2 核心用户故事

| ID | 故事 | 优先级 |
|---|---|---|
| US-01 | 作为用户，我想从网盘选主视频进行压缩，以便省空间且不用先拷到电脑 | P0 |
| US-02 | 作为用户，我想把转码结果直接保存到网盘「视频/output」目录 | P0 |
| US-03 | 作为用户，我在选字幕/Logo/BGM 时也能从网盘选辅助文件 | P0 |
| US-04 | 作为用户，我在网盘右键 MP4 选「FFmpeg 剪辑打开」，应用自动载入 | P1 |
| US-05 | 作为用户，批处理时我能多次从网盘选多个文件 | P1 |
| US-06 | 作为用户，我仍可选择从本机选文件（双通道不丢失） | P0 |
| US-07 | 作为用户，大文件失败时我能看到明确提示而非白屏 | P1 |

---

## 3. 现状分析

### 3.1 应用已有文件入口（`docs/index.html`）

| 入口 | DOM | 用途 |
|---|---|---|
| 主视频 | `#fileInput` | 单文件 / 批处理队列 |
| 字幕 | `#subtitleFileInput` | Embed / Auto-Caption 后嵌入 |
| Logo | `#overlayFileInput` | 水印 |
| 混音 | `#mixAudioFileInput` | BGM |
| 拼接 | `#concatFileInput` | 第二路视频 |
| 并排 | `#sxsFileInput` | 第二路视频 |
| 画中画 | `#pipFileInput` | 叠加视频 |
| Raw FFmpeg | `#rawInput2` | 第二输入 |
| 输出 | `download()` | `<a download>` 触发本地下载 |
| 批处理 ZIP | `downloadBatchAllAsZip()` | 本地 ZIP |

**拖拽区** `#dropZone`：仅 `DataTransfer` 本地文件，**v1.1 不改造**。

### 3.2 懒猫侧可用能力

| 能力 | 机制 | 文档 |
|---|---|---|
| 打开/保存双通道 | `injects` + `lzc-file-chooser-inject.js` | [自动拦截文件选择器](https://developer.lazycat.cloud/06-专题/02-自动拦截文件选择器.html) |
| 网盘文件 HTTP 访问 | `/_lzc/files/home/...` | inject 内置 |
| 关联打开 | `file_handler` + `/?file=%u` | [应用关联](https://developer.lazycat.cloud/04-进阶主题/15-应用关联.html) |
| 静态资源打包 | `contentdir` in `lzc-build.yml` | lzc-build 规范 |

### 3.3 架构约束（不可违反）

```
网盘 ──HTTP──► 浏览器 File/Blob ──ffmpeg.wasm──► 输出 Blob ──HTTP PUT/POST──► 网盘
                      │
                      └── 全链路「数据不出浏览器」语义保持：不经第三方服务器，仅用户 NAS ↔ 用户浏览器
```

---

## 4. 方案设计

### 4.1 总体分期

```
Phase 1 (v1.1.0)  inject 打开 + 保存回网盘     ← 本 PRD 主交付
Phase 2 (v1.2.0)  file_handler 关联打开 + URL 入参
Phase 3 (v1.3.0)  UI 中文化 + 网盘提示 + 大文件友好错误
Phase 4 (搁置)    服务端代理 / NAS 直读
```

### 4.2 Phase 1：inject 方案（P0）

**原则**：不改上游 `index.html` 业务逻辑，仅 LPK 层配置 + content 资源。

#### 4.2.1 配置变更

**`lzc-build.yml`**

```yaml
contentdir: ./content
```

**`lzc/content/` 目录**

```text
content/
└── lazycat-injects/
    └── lzc-file-chooser-inject.js   # 从官方下载并随 LPK 分发
```

**`lzc-manifest.yml` 增量**

```yaml
usage: |
  支持从懒猫网盘选择视频/音频/字幕，处理结果可保存回网盘。
  首次使用需联网下载 ffmpeg.wasm（约 31MB）。
  建议单文件 ≤500MB；超大/4K 可能因浏览器内存不足失败。

application:
  injects:
    - id: ffmpeg-netdisk-chooser
      on: browser
      when:
        - /*
      do:
        - src: file:///lzcapp/pkg/content/lazycat-injects/lzc-file-chooser-inject.js
          params:
            diskRoot: /_lzc/files/home
            locale: auto
            hooks:
              fileInput: true
              fileSystemAccess: true
            text:
              zh-CN:
                openTitle: 打开文件
                saveTitle: 保存文件
                openLocal: 从本机选择
                openLazyCat: 从懒猫网盘选择
                saveLocal: 保存到本机
                saveLazyCat: 保存到懒猫网盘
                cancel: 取消
              en-US:
                openLazyCat: Open from LazyCat Drive
                saveLazyCat: Save to LazyCat Drive
```

#### 4.2.2 功能映射

| 用户操作 | 预期行为 |
|---|---|
| 点击「Click to choose」 | 弹窗：本机 / 懒猫网盘 |
| 选网盘内 MP4 | fetch 为 Blob → 走现有 `handleFileInput` |
| 各 Operations 内 file input | 同上 |
| 点击 Download / ZIP All | 弹窗：本机 / 懒猫网盘 |
| 选网盘保存路径 | 写入用户指定目录，保留原扩展名 |
| 仍选本机 | 与现网行为完全一致 |

#### 4.2.3 覆盖的操作（inject 自动生效）

凡触发 `<input type="file">` 或 `<a download>` 的场景均覆盖，包括：

Convert、Resize、Extract Audio、Mute、GIF、Speed、Rotate、Crop、Thumbnail、Fade、Adjust、Strip Metadata、Auto-Caption、Embed Subtitles、Volume、Loop、Logo、Mix Audio、Concatenate、Side by Side、PiP、Pad、Normalize、Denoise、Boomerang、Sharpen/Blur、Raw FFmpeg、Batch、Stack 等。

**仍不支持网盘直连**：拖拽 drop-zone（需 Phase 3 改 UI 引导用户改点选）。

---

### 4.3 Phase 2：file_handler 关联打开（P1）

#### 4.3.1 manifest

```yaml
application:
  file_handler:
    mime:
      - video/*
      - audio/*
      - "image/gif"
    actions:
      open: /?file=%u
```

#### 4.3.2 前端补丁（`docs/index.html` 或 fork 层 overlay）

启动时检测 URL 参数：

```javascript
// 伪代码
const filePath = new URLSearchParams(location.search).get('file');
if (filePath) {
  const url = '/_lzc/files/home' + decodeURIComponent(filePath);
  const resp = await fetch(url);
  const blob = await resp.blob();
  const name = filePath.split('/').pop();
  loadFile(new File([blob], name, { type: blob.type }));
}
```

需增加：加载进度条、失败 toast、处理完清除 URL 参数避免刷新重复加载。

---

### 4.4 Phase 3：体验优化（P2）

| 项 | 说明 |
|---|---|
| drop-zone 文案 | 「点击从网盘或本机选择；拖拽仅支持本机文件」 |
| 页面顶栏 | 懒猫版增加「网盘已连接」轻提示（检测 inject 是否生效） |
| 大文件 | fetch 前显示文件大小；>500MB 确认框 |
| 中文化 | 关键 UI 字符串 zh-CN（可选 fork overlay，不强制改上游英文） |
| usage 更新 | 安装说明写清网盘能力与限制 |

---

## 5. 详细需求

### 5.1 功能需求

| ID | 需求 | Phase | 验收 |
|---|---|---|---|
| FR-01 | 主视频 input 支持网盘选择 | 1 | 选网盘 MP4 后可 Preview |
| FR-02 | 字幕/Logo/音频/第二路视频 input 支持网盘 | 1 | 各 Operation 实测 1 次 |
| FR-03 | Download 单文件可保存网盘 | 1 | 网盘目标目录可见 output 文件 |
| FR-04 | Batch ZIP All 可保存网盘 | 1 | 网盘出现 zip 文件 |
| FR-05 | 保留本机双通道 | 1 | 选「本机」行为与 v1.0 一致 |
| FR-06 | inject 脚本随 LPK 离线可用 | 1 | 断网（WASM 已缓存）仍可弹网盘选择器 |
| FR-07 | 网盘右键打开视频 | 2 | file_handler 跳转后自动载入 |
| FR-08 | 打开失败可理解错误信息 | 3 | 403/404/过大 有中文提示 |

### 5.2 非功能需求

| ID | 需求 | 说明 |
|---|---|---|
| NFR-01 | 隐私 | 转码仍在浏览器；inject 仅经用户 NAS 网关拉写文件 |
| NFR-02 | 兼容 | Chrome/Edge 桌面优先；Safari/iOS 降级可接受 |
| NFR-03 | 性能 | 500MB 文件 fetch+load ≤ 60s（千兆 LAN） |
| NFR-04 | 许可 | GPL-3.0 fork 变更可追溯；inject 为官方脚本另附来源 |
| NFR-05 | 可维护 | 上游 docs 更新 → 重打 docs.tar.gz → build；inject 独立 content 目录 |

### 5.3 UI/UX 要求

**Phase 1**（inject 弹窗，不改主 UI）：

- 弹窗文案中文优先（`locale: auto`）  
- 「懒猫网盘」字样与微服产品一致  

**Phase 3**（可选改主界面）：

- Input 区：`Click to choose from drive or local` / 「从网盘或本机选择」  
- 保留英文副标题「100% local processing」但补充「Files from your LazyCat drive stay on your network」  

---

## 6. 技术实现清单（Phase 1 开发任务）

```
Task Progress:
- [ ] T1. 下载 lzc-file-chooser-inject.js → lzc/content/lazycat-injects/
- [ ] T2. lzc-build.yml 增加 contentdir: ./content
- [ ] T3. lzc-manifest.yml 增加 injects + 更新 usage
- [ ] T4. 更新 package.yml version → 1.1.0，description 提及网盘
- [ ] T5. tar -czf pack/docs.tar.gz（若 Phase 3 改了 docs）
- [ ] T6. lzc-cli project build
- [ ] T7. lzc-cli lpk install 验证
- [ ] T8. 执行 §7 验收用例
- [ ] T9. 更新 PORTING.md / NETDISK.md 状态
```

**预估工时**：Phase 1 约 **0.5～1 人日**（配置为主，无后端）。

---

## 7. 验收用例（Phase 1）

| # | 步骤 | 预期 |
|---|---|---|
| AC-01 | 打开应用 → Load ffmpeg → 点选主视频 | 出现「本机 / 懒猫网盘」 |
| AC-02 | 网盘选 50MB MP4 | 预览正常，可 Process |
| AC-03 | Convert → WebM → Download | 可选保存到网盘；文件可播放 |
| AC-04 | Embed Subtitles → 网盘选 .srt | 字幕嵌入成功 |
| AC-05 | Logo Overlay → 网盘选 PNG | 水印正常 |
| AC-06 | Batch 模式选 2 个网盘视频 → 压缩 | 两路均成功，ZIP All 可存网盘 |
| AC-07 | 选「本机」路径 | 与 v1.0 行为一致 |
| AC-08 | `crossOriginIsolated === true` | inject 后仍为 true |
| AC-09 | 应用管理无 error state | web 无错误 healthcheck |
| AC-10 | 300MB 网盘文件 | 成功或给出可理解失败（不白屏） |

---

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 大文件 OOM | 处理中途崩溃 | usage/确认框说明 ≤500MB；Phase 3 加大小检测 |
| inject 与 COOP/COEP 冲突 | ffmpeg 无法加载 | 验收 AC-08；冲突则查 inject 加载顺序 |
| 网盘路径权限 | 403 fetch 失败 | FR-08 错误提示；检查登录态 |
| inject 不拦截 programmatic click | drop-zone 内 click 可能绕过 | drop-zone 已用 `fileInput.click()`，应在 hooks.fileInput 覆盖范围内——需 AC-01 实测 |
| 上游 docs 更新覆盖 | fork 漂移 | 网盘改动放 lzc/content + manifest，docs 尽量少改 |
| GPL 合规 | 提审 | 注明 fork 来源与 inject 官方出处 |

---

## 9. 依赖与前置

| 依赖 | 状态 |
|---|---|
| LPK v1.0.0 稳定运行 | ✅ 已完成 |
| lzcos inject 支持 | ✅ 微服已验证其他应用 |
| lzc-file-chooser-inject.js | ⏳ 需下载入 content |
| 用户网盘已有测试视频 | 验收时需要 |
| lzc-cli build/install | ✅ 流水线已通 |

---

## 10. 版本规划

| 版本 | 内容 | 目标日期 |
|---|---|---|
| **v1.1.0** | Phase 1 inject 打开/保存 | 开发启动后 1 天 |
| v1.2.0 | Phase 2 file_handler | +1～2 天 |
| v1.3.0 | Phase 3 体验/中文/大文件提示 | +1 天 |

---

## 11. 开放问题

| # | 问题 | 建议 |
|---|---|---|
| Q1 | 默认保存目录？ | 用户每次选择；不自动写固定路径 |
| Q2 | 是否内嵌 ffmpeg.wasm 去 CDN 依赖？ | 与网盘无关，单列 v1.4 |
| Q3 | 是否做中文 UI fork？ | Phase 3，非 P0 |
| Q4 | Android 端 WebView 是否支持 inject？ | 验收时顺带测；不阻塞 P0 |

---

## 12. 附录

### A. 相关文档

- [ARCH-NETDISK.md](./ARCH-NETDISK.md) — 架构 / 数据流 / ADR  
- [CASES-NETDISK.md](./CASES-NETDISK.md) — 测试金字塔（L0～L4，41 用例）  
- [PORTING.md](./PORTING.md) — LPK 移植踩坑  
- [懒猫：自动拦截文件选择器](https://developer.lazycat.cloud/06-专题/02-自动拦截文件选择器.html)  
- [懒猫：应用关联](https://developer.lazycat.cloud/04-进阶主题/15-应用关联.html)  

### B. 不在本 PRD 内的上游功能清单

Convert / Resize / Extract Audio / Mute / GIF / Speed / Rotate / Crop / Thumbnail / Reverse / Fade / Adjust / Strip Metadata / Auto-Caption / Embed Subtitles / Volume / Loop / Logo / Mix Audio / Concatenate / Side by Side / PiP / Media Info / Pad / Normalize / Denoise / Boomerang / Sharpen-Blur / Raw FFmpeg / Stack / Batch —— **网盘对接不削减上述能力，仅改变 I/O 通道**。

---

**下一步**：按 §6 任务清单执行 Phase 1 开发（T1～T9）。
