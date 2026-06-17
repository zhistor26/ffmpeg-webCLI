# ffmpeg-webCLI × 懒猫网盘对接方案

## 架构约束（先理解再改）

```
懒猫网盘文件  ──inject/URL──►  浏览器内存  ──ffmpeg.wasm──►  输出 Blob  ──inject──►  网盘或本地下载
     ▲                              │
     │                              └── 大文件受 ~2GB WASM 堆限制，与是否接网盘无关
     └── NAS 不跑转码，只提供文件 HTTP 访问
```

**结论**：网盘对接 = 改「文件怎么进/出浏览器」，不改 NAS 端转码逻辑。

---

## 当前 LPK 已具备的能力（上游 ffmpeg-webCLI）

### 视频 / 容器

| 功能 | 说明 |
|---|---|
| 格式转换 | MP4 / WebM / MKV / MOV / AVI |
| 压缩 | CRF + preset |
| 裁剪 Trim | 时间轴起止 |
| 缩放 Resize | 保持比例 |
| 调速 | 0.25×～4×，音频 atempo 链 |
| 旋转/翻转 | 90°/180°/水平/垂直 |
| 区域 Crop | 像素级裁切 |
| GIF | 双 pass 调色板 |
| 缩略图 | JPEG/PNG 单帧 |
| 倒放 Reverse | 单文件，吃内存 |
| 淡入淡出 | in/out 独立秒数 |
| 调色 Adjust | 亮度/对比度/饱和度/灰度 |
| 去元数据 | strip metadata |
| 静音 / 循环 | mute / stream_loop |
| Pad/Letterbox | 16:9、9:16、1:1 等 |
| 降噪/锐化/模糊 | hqdn3d / unsharp / boxblur |
| Boomerang | 正播+倒播 |
| 音量 / 响度归一化 | volume / loudnorm |

### 多输入 / 高级

| 功能 | 说明 |
|---|---|
| 音频提取 | MP3/AAC/WAV/OGG/FLAC |
| 字幕嵌入 | SRT/VTT/ASS 软字幕 |
| 自动字幕 | Whisper（浏览器内，Tiny/Base/Small） |
| Logo 水印 | PNG/JPG 叠加 |
| 混音 | 背景 BGM + amix |
| 拼接 Concat | 两路视频 |
| 并排 / 画中画 | hstack/vstack / overlay |
| 操作链 Stack | 多滤镜一次编码 |
| 批处理 Batch | 25 种操作 + ZIP All |
| Raw FFmpeg | 命令行 + 示例库 |
| Media Info | 元数据 / ffprobe |
| PWA 离线 | Service Worker 缓存 |

### 批处理不支持

Crop（尺寸因文件而异）、Logo/多输入操作、Reverse、Boomerang、Media Info、Raw FFmpeg。

---

## 网盘对接三档方案

### 方案 A：inject 拦截文件选择器（推荐先做）

**改动量**：小，不改 `index.html`  
**手册**：[自动拦截文件选择器](https://developer.lazycat.cloud/06-专题/02-自动拦截文件选择器.html)

上游已有大量 `<input type="file">`（主视频、字幕、Logo、混音、拼接等），inject 可拦截：

- **打开**：弹窗选「本地 / 懒猫微服」→ 从 `/_lzc/files/home/...` 拉文件进浏览器
- **保存**：拦截 `<a download>` → 可选「保存至懒猫微服」

**manifest 增量示例**：

```yaml
# lzc-build.yml 增加
contentdir: ./content

# lzc-manifest.yml 增量
application:
  injects:
    - id: open-save-chooser
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
                openLazyCat: 从懒猫网盘打开
                saveLazyCat: 保存至懒猫网盘
```

**content 目录**：

```text
lzc/content/lazycat-injects/lzc-file-chooser-inject.js
# 从此处下载：https://developer.lazycat.cloud/lazycat-injects/lzc-file-chooser-inject.js
```

**覆盖范围**：

| 入口 | inject 能否接管 |
|---|---|
| 点击选文件（所有 file input） | ✅ |
| Download 输出 | ✅（需 inject 支持 anchor） |
| 拖拽 drop-zone | ❌ 仍只能拖本地文件 |
| 批处理多选 | ⚠️ 每次走选择器，体验尚可 |

**预估**：0.5～1 天（下载 inject、加 contentdir、build/install 验证）。

---

### 方案 B：file_handler 从网盘「用此应用打开」

**改动量**：中，需在 `index.html` 加 URL 入参解析

**manifest**：

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

**前端需新增**（上游无此逻辑）：

```javascript
// 启动时读取 ?file= 网盘路径，fetch 后交给 handleFileInput
const params = new URLSearchParams(location.search);
const filePath = params.get('file');
if (filePath) { /* fetch('/_lzc/files/home' + filePath) → Blob → load */ }
```

**效果**：用户在网盘右键视频 →「用 FFmpeg 剪辑打开」→ 自动载入。

**预估**：1 天（含大文件 fetch 进度 UI）。

---

### 方案 C：服务端代理 + 可选 NAS 直读（不推荐首做）

加 Python/Node sidecar，挂载 `enable_media_access: true` 读 `/lzcapp/media/RemoteFS`，提供 `/api/file?path=...`。

**问题**：

- 文件仍要下载到浏览器才能 wasm 处理，多一层代理收益有限
- 架构从纯静态变有状态服务，维护成本高
- 仅当需要「超大文件分片流式读入」时才值得考虑

---

## 推荐路线

```
Phase 1（本周）  方案 A：inject 打开/保存
Phase 2（可选）  方案 B：file_handler 关联打开
Phase 3（按需）  改 UI 文案「从网盘选择」+ 拖拽说明
Phase 4（不做）  服务端转码 — 那是另一个应用
```

## Phase 1 实施检查表

- [ ] 下载 `lzc-file-chooser-inject.js` 到 `lzc/content/lazycat-injects/`
- [ ] `lzc-build.yml` 增加 `contentdir: ./content`
- [ ] `lzc-manifest.yml` 增加 `injects` 段
- [ ] `project build` + `lpk install`
- [ ] 点击选视频 → 出现「懒猫网盘」选项
- [ ] 处理完点 Download → 出现「保存至懒猫网盘」
- [ ] 用 100MB 以内视频测通（大文件测内存上限）

## 已知限制（对接后仍存在）

1. **文件必须进浏览器内存** — 网盘 4K 长片可能 OOM
2. **拖拽仍仅本地** — inject 不拦截 drag-drop
3. **Whisper 字幕** — 模型仍从 CDN 下，与网盘无关
4. **GPL-3.0** — fork 改造后分发需遵守许可
