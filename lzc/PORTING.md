# ffmpeg-webCLI 懒猫微服移植经验

> 上游：https://github.com/tejaswigowda/ffmpeg-webCLI  
> Fork：https://github.com/zhistor26/ffmpeg-webCLI  
> 验证环境：微服 `zhistor`，lzc-cli 2.0.8

## 一、应用形态

| 项 | 结论 |
|---|---|
| 类型 | 纯静态 PWA，算力在**用户浏览器**（ffmpeg.wasm） |
| NAS 角色 | 仅托管 HTML/JS，不参与转码 |
| 持久化 | 默认不需要 `/lzcapp/var` |
| 许可 | GPL-3.0（提审需合规说明） |

## 二、目录结构

```text
ffmpeg-webCLI/
├── docs/                    # 上游静态资源
└── lzc/
    ├── package.yml
    ├── lzc-manifest.yml
    ├── lzc-build.yml
    ├── lzc-build.dev.yml
    ├── icon.png
    ├── content/               # v1.1.0+ inject 静态资源
    │   └── lazycat-injects/
    │       └── lzc-file-chooser-inject.js
    ├── images/
    │   ├── Dockerfile
    │   └── nginx.conf       # 必须含 COOP/COEP
    └── pack/
        └── docs.tar.gz      # embed 构建用，docs 变更后需重新打包
```

## 三、踩坑与解法（必读）

### 1. 微服拉不到 docker.io

**现象**：`project build` 在远程构建时 `nginx:1.27-alpine` 超时。

**解法**：基础镜像改用懒猫仓库：

```dockerfile
FROM registry.lazycat.cloud/snyh1010/library/nginx:54809b2f36d0ff38
```

### 2. embed 构建 context 不含 `docs/`

**现象**：`COPY docs/` 报 `no such file or directory`。  
**原因**：lzc-cli 远程 build-pack 只打包 Dockerfile 引用的路径，不会自动带上整个 repo。

**解法**：预打包静态资源：

```powershell
tar -czf lzc/pack/docs.tar.gz -C docs .
```

Dockerfile 内解压：

```dockerfile
COPY lzc/pack/docs.tar.gz /tmp/docs.tar.gz
RUN mkdir -p /usr/share/nginx/html \
 && tar -xzf /tmp/docs.tar.gz -C /usr/share/nginx/html --no-same-owner \
 && rm /tmp/docs.tar.gz
```

> `docs/` 有改动后，**必须先重新打 tar 再 build**。

### 3. COOP/COEP 响应头

ffmpeg.wasm 依赖 `SharedArrayBuffer`，nginx 必须加：

```nginx
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;
add_header Cross-Origin-Resource-Policy "cross-origin" always;
```

验证：浏览器控制台 `crossOriginIsolated === true`。

### 4. Windows 中文路径 + bash buildscript

**现象**：`buildscript: bash scripts/prepare-build.sh` 在中文路径下 tar 失败。  
**解法**：在 PowerShell 手动打 `docs.tar.gz`，build 时跳过 buildscript。

### 5. 路由 DNS 健康检查失败

**现象**：`app-1` 日志 `lookup web.cloud.lazycat.app.ffmpeg.lzcapp ... server misbehaving`。

**解法**：单 service 应用路由用 **service 名**，不用 FQDN：

```yaml
routes:
  - /=http://web:8080
```

### 6. healthcheck 导致「应用状态错误」

**现象**：nginx 日志正常，UI 报 `container entered error state`；docker inspect 里 web 为 `unhealthy`，输出 `wget: not found`。

**原因**：manifest 里 healthcheck 用了 `wget`，懒猫 nginx 基础镜像未预装。

**解法**：纯静态 nginx **不要配** `services.web.healthcheck`；网关 `app` 容器自带探活。

### 7. 首次使用需联网

ffmpeg-core WASM（~31MB）和 Whisper 模型从 CDN 加载；PWA 缓存后可离线。usage 里应说明。

## 四、构建与安装命令

```powershell
cd ffmpeg-webCLI/lzc

# docs 有更新时
tar -czf pack/docs.tar.gz -C ../docs .

# 发布包（提审前必走此路径）
lzc-cli project build
# → cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk

lzc-cli lpk info .\cloud.lazycat.app.ffmpeg-webcli-v1.0.0.lpk
lzc-cli lpk install .\cloud.lazycat.app.ffmpeg-webcli-v1.0.0.lpk

# 日常改 nginx / 静态资源
lzc-cli project deploy
```

## 五、验收清单

- [ ] 启动器可打开，HTTPS 无白屏
- [ ] `crossOriginIsolated === true`
- [ ] Load ffmpeg 成功
- [ ] 小 MP4 压缩/转码可预览下载
- [ ] `project log` 无 nginx 重启循环

## 六、镜像体积参考

- LPK 内嵌层：约 110 KiB（nginx 上游混合分发 + docs.tar.gz）
- 远程 build 耗时：约 10s（缓存后）～首次数分钟

## 七、网盘对接（已放弃）

v1.1.0～v1.3.x 曾尝试 inject / 应用内 `lzc-file-picker` 对接网盘，因 COEP 与客户端 picker 兼容问题未稳定落地。

**v1.4.0 最终版**：纯本机选文件 / 下载，无 inject、无 `contentdir`、无网盘 UI。详见 `NETDISK.md`（历史记录）。
