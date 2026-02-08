# Tech Decision

本文记录一次关于认证方案与本地后端形态（community server）的技术决策讨论。

## 问题（原文）

> 我有点问题，第一个就是betterauth呃，我们使用它的开源代码库，应该就不需要它的一些。比如说saas化的收费的项目，对不对？因为我们要的功能实际上很基础和核心，也有替代的开源产品。换句话说，如果需要pass key的产品serv的话，呃，我们依赖于自己搭建的啊，如果只是需要比如说谷歌或者gitthub账号的这种呃登录绑定的话，应该开源代码就足够了，不需要它呃依赖于它的存在嘛，只需要依赖这个开源代码库就可以，对不对？不需要跟它的商业公司打交道，获取saas的 API key吧。还有其他商业依赖么？这第一个问题，第二个问题就是我们的community server作为pin的后端，呃，呃这个server未来是呃交互的方式，就是API的方式吧。换句话说我们指定一个。啊，HTTP或local host的APUL就可以访问我们本地的这个服务了吧。然后communityserv这个本地服务呢是用来负责和数据库啊存储啊，还有和AI等一些打交道，对不对？未来我可以把它啊因为两边plin和community server之间通信是API，http请求，那我可以把它呃包装为一个呃客户端的CS结构的程序。比如说用tauri，rust和node jS。这个评估一下当前是不是可以支持这个的未来的扩展和建移，以及你的评估的建议。然后用中文回答我。

## 回答与结论

### 1) Better Auth 是否需要 SaaS / API Key / 商业依赖？

结论：不需要跟它的商业公司打交道，也不需要它的 SaaS API key。我们现在用的是 better-auth 的开源代码库，它在你自己部署/本地运行的 community server 中执行登录、会话、passkey 等逻辑。

- BETTER_AUTH_SECRET 不是“因为 passkey 才需要”。它是 better-auth 服务端用来保护认证状态的核心密钥。
  - 用途：签名/校验会话相关的 cookie/token 以及完整性校验。
  - 没有它：服务端无法可信地验证会话，认证状态容易被伪造或篡改。
- Passkey（WebAuthn）本身依赖浏览器/系统的 WebAuthn 能力 + 服务端 challenge/verify。
  - 不需要第三方 SaaS。
  - 生产环境需要满足 WebAuthn 规范约束（域名/HTTPS/正确的 RP ID），这不是商业依赖。
- Google / GitHub 登录不需要 SaaS API key，但必须在 Google/GitHub 开发者后台创建 OAuth App 获取平台侧凭证：
  - GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
  - GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET
  这是 OAuth 平台必需的配置，一般免费，不属于 better-auth 的商业服务。
- 当前实现的外部依赖主要是：
  - OAuth 平台（Google/GitHub）的开发者配置（可选）
  - 你自己的数据库（PostgreSQL）
  - 你自己的部署环境（本地/服务器）
- 如果担心 vendor lock-in：我们现在使用的功能较基础，未来替换认证框架的成本主要在“API 契约 + 数据模型 + 会话策略”，整体是可迁移的。

### 2) community server 作为插件后端、未来包装为桌面 CS（Tauri/Rust/Node）是否可行？

结论：可行，并且当前形态非常适合“先 HTTP 化、再桌面化”。

- 插件与 community server 之间就是 HTTP API 通信：
  - 插件侧只需要指定一个 Origin（例如 http://localhost:8787）即可访问本地服务。
- community server 的职责可以自然扩展：
  - 现在负责认证、会话、bind relations、数据库读写
  - 未来可以继续承担 AI、存储、同步、索引等后端能力
- 未来包装成 CS（Tauri/Rust + Node）有两条常见路线：
  1) 保持现有 Node community server 不变，把它当作桌面应用里启动的 sidecar 进程（Tauri 负责启动/守护/配置/更新）
  2) 等 API 稳定后，将服务逐步迁移到 Rust（仍保持 HTTP API），获得更好的单文件分发、资源占用与系统集成
- 推荐落地路线（从易到难）：
  1) 先保持 Node community server，桌面端只负责安装、启动、管理端口与配置
  2) API 稳定后再评估 Rust 化重写

### 3) 未来扩展/迁移的关键注意点（建议）

- 端口与发现机制：
  - 桌面应用里本地服务端口最好可配置或自动选择，并提供服务发现（固定端口 + health check，或写入本地配置文件）
- CORS 与安全边界：
  - 需要控制允许访问本地服务的 origin，避免本机其他网页滥用 localhost API
- 鉴权方式与 token 存储：
  - 继续用 bearer token + 会话机制是合理的
  - 桌面化后 token 存储建议迁移到更安全的存储（Keychain/系统安全存储）
- 数据库随应用分发策略：
  - 坚持 PostgreSQL：桌面端依赖用户本机已有 PG 或内置 PG（复杂）
  - 追求“一键安装离线可用”：更适合默认 SQLite/嵌入式 DB，再提供迁移到 Postgres 的选项
- API 契约稳定性：
  - 建议把 community server 当作“产品 API”，长期保持向后兼容，降低前端/桌面端迭代成本

