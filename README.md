# 智记 SmartNote

> 一款云端 AI 增强的鸿蒙智能笔记应用 —— 课程大作业（赛道 B：传统增强 · 第 3 题 智能待办 / 笔记）

智记是一个运行在 HarmonyOS 上的笔记应用。传统功能包括笔记的新建、编辑、删除、标签管理与关键词检索；
AI 增强功能是：由云端大模型阅读笔记全文，自动生成一段摘要与 2–5 个关键词标签，
结果以「建议」形式先展示，用户确认后才写入本地数据库。

> 📦 **本仓库包含**：应用源码、构建运行说明、系统架构图与关键路径自测清单。
> 课程报告全文与演示视频随课程作业单独提交，不在本仓库内。

关键技术点：ArkTS + ArkUI（Stage 模型）、Navigation 多页面路由、RDB 关系型数据库持久化、
Preferences 键值配置、@kit.NetworkKit 调用云端 LLM、hilog 全链路日志与脱敏。

---

## 一、开发环境与 SDK 版本

| 项目 | 版本 / 取值 |
|---|---|
| 操作系统 | Windows 11（开发机） |
| DevEco Studio | 26.0（内置 hvigor 10.28.2、ohpm、node v24.14.1） |
| HarmonyOS SDK | API 26（HarmonyOS 7.0.0），SDK 版本 26.0.0.105 |
| 编译 SDK（Compile SDK） | 26.0.0 |
| 兼容 SDK（Compatible SDK） | 26.0.0 |
| 目标 SDK（Target SDK） | 26.0.0 |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式） |
| 应用模型 | Stage 模型 |
| 构建命令 | `hvigorw --mode module -p product=default -p module=entry@default assembleHap` |

> 说明：自 API 10 起 DevEco Studio 已移除 FA 模型的创建入口，本工程为 Stage 模型的单 entry 模块工程，
> 判断依据为：模块配置为 `module.json5`，入口类 `EntryAbility` 继承自 `UIAbility`。

---

## 二、工程结构

```
SmartNote/
├── AppScope/                         应用级配置（bundleName、图标、名称）
├── entry/
│   ├── build-profile.json5           模块构建配置
│   ├── oh-package.json5              模块依赖（无第三方依赖）
│   └── src/main/
│       ├── module.json5              模块清单：路由表、INTERNET 权限
│       ├── ets/
│       │   ├── entryability/         EntryAbility（启动、初始化跨页版本号）
│       │   ├── common/               Constants / Logger / LocalConfig / AppEvents
│       │   ├── model/                Note / AiSuggestion / RouteParam
│       │   ├── data/                 DbHelper / NoteRepository
│       │   ├── service/              AiService / SettingsService
│       │   ├── views/                NoteCard / TagChip / StateView
│       │   └── pages/                Index / NoteEditPage / NoteDetailPage
│       │                             AiAssistPage / SettingsPage
│       └── resources/base/
│           ├── element/              string.json / color.json
│           ├── media/                图标资源
│           └── profile/              main_pages.json / router_map.json / backup_config.json
├── docs/                             架构图与测试清单
├── build-profile.json5               工程构建配置（SDK 版本、构建模式）
├── oh-package.json5                  工程依赖声明
├── hvigorfile.ts                     hvigor 构建脚本入口
└── hvigor/hvigor-config.json5        hvigor 版本配置
```

分层约定：页面层只处理状态与渲染，业务层负责编排与外部调用，数据层负责 SQL 与连接，
公共层提供常量、日志、配置与模型。跨层调用被禁止（页面不直接写 SQL）。

---

## 三、构建、安装与运行

### 3.1 用 DevEco Studio 打开并运行（推荐）

1. 打开 DevEco Studio，选择 **File → Open**，选中本目录（含 `build-profile.json5` 的根目录）。
2. 等待工程同步（Sync）完成。工程无第三方依赖，无需额外安装 ohpm 包。
3. 配置 SDK：**File → Settings → SDK**，确认已安装 API 26（HarmonyOS 7.0.0）。
   若 SDK 路径不同，修改工程根目录 `local.properties` 中的 `sdk.dir`。
4. 启动模拟器：**Tools → Device Manager**，启动任一 phone 类型模拟器（推荐 API 26 镜像）。
5. 点击工具栏 **Run**，或使用命令 `entry` 模块的 `default` 构建变体运行。

### 3.2 用命令行构建（可选）

```bash
# 在工程根目录执行
# 1) 设置 SDK 环境变量（路径按本机实际位置修改）
set DEVECO_SDK_HOME=<DevEco Studio 安装目录>\sdk

# 2) 构建 HAP
<DevEco Studio 安装目录>\tools\hvigor\bin\hvigorw.bat \
  --mode module -p product=default -p module=entry@default -p buildMode=debug \
  assembleHap --no-daemon

# 3) 产物位置
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 3.3 安装与启动（hdc）

```bash
hdc list targets                       # 确认模拟器已连接（TCP 模式形如 127.0.0.1:5555）
hdc tconn 127.0.0.1:5555               # 如未连接，手动连接
hdc install -r entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.smartnote
```

> 本工程为调试构建，产物为未签名 HAP，模拟器可直接安装。若在真机安装，需要用 DevEco Studio
> 配置自动签名后重新构建。

### 3.4 卸载与清理数据

```bash
hdc shell aa force-stop com.example.smartnote          # 停止应用
hdc shell bm clean -n com.example.smartnote -d         # 清空应用数据（含数据库与配置）
hdc uninstall com.example.smartnote                    # 卸载
```

---

## 四、测试设备 / 模拟器信息

| 项目 | 取值 |
|---|---|
| 设备类型 | 本地模拟器（DevEco Studio 自带 Emulator） |
| 型号 | Pura 90 Pro（phone） |
| 系统版本 | HarmonyOS 7.0.0（API 26），软件版本 7.0.0.107 |
| 屏幕 | 1256 × 2760，密度 560 dpi |
| 连接方式 | hdc over TCP，`127.0.0.1:5555` |
| 应用安装方式 | `hdc install -r`（未签名调试 HAP） |

未在真机上验证。模拟器与宿主机共享网络，因此云端 AI 调用与宿主机走同一出口。

---

## 五、默认数据与演示路径

### 5.1 默认数据

首次启动（或清空数据后重新启动）会自动写入 **3 条演示笔记**，内容分别是：
「鸿蒙课程大作业选题」、「周四组会要准备的内容」、「读《人类简史》第五章」。
三条笔记都带有标签，正文长度足够触发 AI 摘要。

演示数据只写入一次。写入后会在 Preferences 中记录 `seeded = true`，
即使用户在设置页清空全部笔记，应用也不会再次自动写入，避免数据"复活"。

本应用无账号体系，不需要登录，也不存在测试账号。

### 5.2 核心功能演示路径

```
首页（列表）
  ├─ 点右下角「+」→ 新建笔记 → 填标题/标签/正文 → 保存 → 回到列表（计数 +1）
  ├─ 点任意笔记卡片 → 详情页
  │    ├─ 点「编辑」→ 修改正文 → 保存 → 返回详情（内容已更新）
  │    │    └─ 在编辑页点「删除」→ 二次确认 → 返回后自动退回列表（记录消失）
  │    └─ 点「AI 生成摘要与标签」→ AI 助手页
  │         ├─ 点「生成摘要与标签」→ 等待 1.5–2 秒 → 展示摘要 + 推荐标签 + 耗时/token
  │         ├─ 点「应用到笔记」→ 返回详情（摘要出现，带 AI 角标，标签已合并）
  │         ├─ 点「放弃结果」→ 丢弃结果，数据库不变
  │         └─ 点「重新生成」→ 再次请求云端
  ├─ 顶部搜索框输入关键词 → 列表实时过滤（无结果显示空态）
  └─ 点右上角「设置」→ 设置页
       ├─ 关闭「启用云端 AI」→ 返回详情页，AI 按钮消失并提示已关闭
       ├─ 切换「默认排序」→ 按更新时间 / 按创建时间
       └─ 点「清空全部笔记」→ 二次确认 → 列表立即变为空态
```

---

## 六、网络依赖与 AI 服务配置

### 6.1 使用的云端 AI 服务

| 项目 | 内容 |
|---|---|
| 服务商 | DeepSeek 开放平台（https://platform.deepseek.com） |
| 接口地址 | `https://api.deepseek.com/v1/chat/completions` |
| 协议 | HTTPS POST，OpenAI 兼容格式，JSON 请求与响应 |
| 模型名 | `deepseek-chat` |
| 鉴权方式 | 请求头 `Authorization: Bearer <API Key>` |
| 计费方式 | 按输入/输出 token 计费（不是会员制）。课程不提供配额，由使用者自行开通 |

**费用与额度说明**：按量计费，单价很低。本项目实测一次摘要调用消耗约 **265 token**，
单条笔记成本不足一分钱；整个开发与验收过程累计调用不足百次，总费用可忽略。
可在 DeepSeek 控制台设置消费上限，避免超支。

**免费替代方案**：如需零成本验证，可换用任一 OpenAI 兼容接口的厂商，仅需改
`entry/src/main/ets/common/LocalConfig.ets` 里的 `baseUrl` 与 `model`，业务代码无需改动。例如：

| 厂商 | 接口地址 | 模型名示例 |
|---|---|---|
| 智谱清言 | `https://open.bigmodel.cn/api/paas/v4/chat/completions` | `glm-4-flash`（有免费档） |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` | `qwen-plus` |
| 月之暗面 | `https://api.moonshot.cn/v1/chat/completions` | `moonshot-v1-8k` |

### 6.2 如何配置密钥（重要）

密钥集中放在一个文件里：`entry/src/main/ets/common/LocalConfig.ets`。

```typescript
export const AI_CONFIG: AiConfig = {
  baseUrl: 'https://api.deepseek.com/v1/chat/completions',
  model: 'deepseek-chat',
  apiKey: '',          // ← 在这里填入你自己的密钥
  enabled: true
};
```

> **提交包内的该文件已把 `apiKey` 置为空串**，需要你自行填写后重新构建。
> 填写后请勿把带真实密钥的文件提交或上传到代码托管平台。

### 6.3 没有密钥时的表现

**这是正常设计，不是故障。** 未填写密钥时：

- 应用启动、笔记增删改查、搜索、手动填写摘要、数据持久化全部正常工作（传统功能不依赖 AI）。
- 详情页仍显示「AI 生成摘要与标签」入口，进入 AI 助手页点生成后，
  不会发起网络请求，直接提示：**「未配置 AI 密钥，请在 LocalConfig.ets 中填写后重试」**。
- 用户可以在编辑页的「摘要」输入框里手动填写摘要，效果与 AI 生成一致。

---

## 七、AI 调用失败时的提示方式

所有失败都被归类为 10 类错误码，页面给出具体中文提示，并附一行「技术细节」便于排查。
应用不会因为 AI 失败而崩溃，也不会阻塞传统功能。

| 情况 | 触发条件 | 界面提示 | 是否自动重试 |
|---|---|---|---|
| 未配置密钥 | 密钥为空或仍是占位符 | 未配置 AI 密钥，请在 LocalConfig.ets 中填写后重试 | 否 |
| AI 已关闭 | 设置页关闭开关 | AI 功能已在设置中关闭 | 否 |
| 正文过短 | 正文少于 20 字 | 正文太短，无法生成摘要 | 否 |
| 网络不可用 | DNS/连接失败（2300006/2300007） | 网络不可用，请检查网络后重试 | 是，1 次 |
| 请求超时 | 读取超时（2300028） | 请求超时，请稍后重试 | 是，1 次 |
| 密钥无效 | HTTP 401 / 403 | 密钥无效或已过期，请检查配置 | 否 |
| 额度不足 | HTTP 402 / 429 | 账户额度不足，请充值后重试 | 否 |
| 服务端异常 | HTTP 5xx / 响应含 error | 服务暂时不可用，请稍后重试 | 是，1 次 |
| 返回格式异常 | 非 JSON / 字段缺失 / 校验失败 | 返回内容格式异常，请重新生成 | 是，1 次 |
| 其他 | 未归类异常 | 生成失败，请重试 | 否 |

失败页面上始终显示一行降级说明：「AI 不可用时，你仍可在编辑页手动填写摘要」。

**超时配置**：连接超时 12 秒，读取超时 20 秒，见 `common/Constants.ets` 中的
`AI_CONNECT_TIMEOUT_MS` 与 `AI_TIMEOUT_MS`。

---

## 八、数据存储说明

### 8.1 关系型数据库（业务数据）

- 库名：`smartnote.db`，路径 `/data/app/el2/100/database/com.example.smartnote/entry/rdb/`
- 表名：`notes`
- 字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | INTEGER | 主键，自增 |
| `title` | TEXT | 标题（限 60 字） |
| `content` | TEXT | 正文 |
| `tags` | TEXT | 标签，英文逗号分隔，最多 5 个 |
| `summary` | TEXT | 摘要（AI 生成或手动填写，限 160 字） |
| `ai_status` | INTEGER | 0 未生成 / 1 成功 / 2 失败 |
| `is_pinned` | INTEGER | 1 表示置顶 |
| `created_at` | INTEGER | 创建时间戳（毫秒） |
| `updated_at` | INTEGER | 更新时间戳（毫秒） |

### 8.2 首选项（配置）

`Preferences` 名称：`smartnote_settings`，包含三个键：

| 键 | 类型 | 说明 |
|---|---|---|
| `ai_enabled` | boolean | AI 总开关 |
| `sort_mode` | number | 0 按更新时间 / 1 按创建时间 |
| `seeded` | boolean | 是否已写入过演示数据 |

---

## 九、日志说明

日志统一通过 `common/Logger.ets` 封装 `hilog`，domain 为 `0x1A01`，tag 为 `SmartNote`。
查看方式：

```bash
hdc shell hilog -x -T SmartNote
```

日志中**不含敏感信息**：密钥只输出掩码（形如 `key=sk-8****c1c7`），正文只输出长度（形如 `contentLen=137`）。

一条完整的 AI 调用链路日志长这样：

```
AiAssistPage  | 准备为 id=3 生成摘要
AiService     | 发起云端调用 model=deepseek-chat key=sk-8****c1c7 contentLen=137
AiService     | 收到响应 elapsed=1467ms，响应长度=586
AiService     | 调用成功 elapsed=1467ms tokens=269 tags=5
NoteRepository| 更新笔记 id=3，影响行数=1
AiAssistPage  | 已应用 AI 结果 id=3
NoteDetailPage| 加载笔记成功 id=3 aiStatus=1
```

---

## 十、AI 工具使用说明

本项目在开发过程中使用了 AI 编码助手（DeepSeek Harness 编码智能体）参与以下工作：

- 需求梳理与选题确认；
- 工程脚手架搭建与目录规划；
- 页面、数据层、AI 服务层代码的编写初稿；
- ArkTS 编译错误排查与修复；
- 模拟器联调、截图取证；
- 课程报告、本 README、测试清单等文档的初稿整理。

**未由 AI 完成的部分**：演示视频的录制与讲解、最终功能验收。

**第三方资源**：未使用任何第三方开源库或第三方代码；图标使用 DevEco Studio 工程模板自带的系统图标资源。
云端 AI 服务为 DeepSeek 开放平台，按其服务条款使用。

**关于密钥**：源码、本 README、报告与提交包中均不包含真实 API Key。

---

## 十一、常见问题

**Q1：构建报错找不到 SDK。**
修改工程根目录 `local.properties` 中的 `sdk.dir`，或在 DevEco Studio 的 SDK 设置里重新指定路径。

**Q2：模拟器里 AI 一直失败。**
先确认宿主机能否访问 `https://api.deepseek.com`（在宿主机执行 `curl` 验证）；
校园网或需要代理认证的网络下，模拟器会继承同样的限制，建议改用手机热点。
应用内的失败提示会给出具体原因（如 `http 401` / `timeout`）。

**Q3：填了密钥还是提示未配置。**
检查密钥长度是否大于 20 位，以及是否仍包含占位符文本（如 `请填入`、`xxxxxxxx`）。
修改 `LocalConfig.ets` 后需要重新构建并安装应用。

**Q4：修改了联网权限或重新配置密钥后要不要重装？**
需要。请重新 `assembleHap` 并重新 `install`，然后强制停止应用再启动。

**Q5：数据在哪，怎么彻底清空？**
执行 `hdc shell bm clean -n com.example.smartnote -d`，或在设置页点「清空全部笔记」。
