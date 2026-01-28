# CodeMate

[English](README.md) | 简体中文

基于 Docker 的 Claude Code 环境，具有自动化 Git/PR 设置功能。

> **⚠️ 安全提示：** 此容器默认使用 `--dangerously-skip-permissions` 运行，允许 Claude 无需确认即可执行命令。仅在隔离环境中使用受信任的代码仓库。

## 为什么选择 CodeMate？

厌倦了在与 AI 结对编程时批准每一个命令？但又不愿在本地机器上授予完全绕过权限？每次 GitHub 交互都需要手动确认会打断你的工作流程。

CodeMate 通过在隔离的 Docker 容器中运行 Claude Code 来解决这个问题，让它可以自由操作而不会危及你的系统。真正的结对编程从这里开始——让 Claude 专注于编码，而你把握全局方向。

## 功能特性

- 自动化仓库克隆和 PR 管理
- 预装：Go、Node.js、Python、Rust、uv
- 配置 Oh My Zsh 的 zsh
- 持久化 Claude 配置
- 内置 Claude Code Skills 用于 PR 工作流自动化
- Slack 通知（当 Claude 停止时，需配置 `SLACK_WEBHOOK`）
- tmux 会话管理与 PR 评论监控

## 快速开始

### 前置要求

- Docker
- GitHub CLI (`gh`) 已认证
- Anthropic API 密钥

运行 `./start.sh --setup` 创建所需的配置文件（`.env`、`settings.json` 等）

#### Mac 用户

在 macOS 上，你需要一个 Docker 运行时，因为 Docker 不能原生运行。选择其中之一：

- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** - 官方 Docker GUI 应用
- **[Colima](https://github.com/abiosoft/colima)** - 轻量级 Docker 运行时（推荐 CLI 用户使用）

### 使用方法

#### 使用 start.sh（推荐）

从任何目录运行 CodeMate 的最简单方法：

```bash
# 下载 start.sh 脚本
curl -O https://raw.githubusercontent.com/BoringHappy/CodeMate/main/start.sh
chmod +x start.sh

# 首次设置 - 在当前目录创建配置文件
./start.sh --setup

# 使用明确的仓库 URL 运行
./start.sh --repo https://github.com/your-org/your-repo.git --branch feature/xyz

# 使用分支名称运行（自动检测仓库来源：--repo > .env > 当前目录的 git remote）
./start.sh --branch feature/your-branch

# 使用现有 PR 运行
./start.sh --pr 123

# 使用自定义卷挂载运行（可选）
./start.sh --branch feature/xyz --mount ~/data:/data

# 使用初始查询运行 Claude
./start.sh --branch feature/xyz --query "请审查代码并修复任何问题"

# 从本地 Dockerfile 构建并运行
./start.sh --build --branch feature/xyz

# 使用自定义 Dockerfile 路径和标签构建
./start.sh --build -f ./custom/Dockerfile --tag my-codemate:v1 --branch feature/xyz

# 中国用户：使用 DaoCloud 镜像加速镜像拉取
./start.sh --branch feature/xyz --image ghcr.m.daocloud.io/boringhappy/codemate:latest
```

脚本将：
1. 如果配置文件不存在，提示你创建
2. 在当前目录创建 `.claude_in_docker/`、`.claude_in_docker.json`、`settings.json` 和 `.env`
3. 使用你的配置运行 CodeMate 容器

**仓库 URL 解析**：脚本按以下优先级确定仓库 URL：
1. `--repo` 命令行参数（最高优先级）
2. `GIT_REPO_URL` 环境变量或 `.env` 文件
3. 当前目录的 git remote origin URL（自动检测）
4. 如果都不可用，则报错

##### 自定义卷挂载

使用 `--mount <主机路径>:<容器路径>` 挂载额外的目录或文件。适用于与容器共享数据、配置或凭证。可以指定多个 `--mount` 选项。

##### 从本地 Dockerfile 构建

对于开发或自定义，你可以从本地 Dockerfile 构建 CodeMate：

```bash
# 从当前目录的默认 Dockerfile 构建
./start.sh --build --branch feature/xyz

# 从自定义 Dockerfile 路径构建
./start.sh --build -f ./path/to/Dockerfile --branch feature/xyz

# 使用自定义镜像标签构建
./start.sh --build --tag my-codemate:dev --branch feature/xyz

# 组合所有选项
./start.sh --build -f ./custom/Dockerfile --tag my-codemate:v1 --branch feature/xyz
```

**选项：**
- `--build` - 运行前从本地 Dockerfile 构建 Docker 镜像
- `-f, --dockerfile PATH` - Dockerfile 路径（默认：`Dockerfile`）
- `--tag TAG` - 本地构建的镜像标签（默认：`codemate:local`）
  - **注意：** 仅与 `--build` 一起使用。要使用预构建镜像，请使用 `--image`

当使用 `--build` 时：
1. 脚本从指定的 Dockerfile 构建 Docker 镜像
2. 默认镜像标签为 `codemate:local`（除非指定 `--tag`）
3. 使用本地构建的镜像而不是从注册表拉取
4. 使用 `--build` 时会忽略 `--image` 选项

**添加自定义工具链：**

要向容器添加额外的工具链或工具，创建一个扩展基础镜像的自定义 Dockerfile：

```dockerfile
# 带有额外工具链的自定义 Dockerfile
FROM ghcr.io/boringhappy/codemate:latest

# 添加 Java
RUN apt-get update && apt-get install -y openjdk-17-jdk maven

# 添加 PHP
RUN apt-get install -y php php-cli php-mbstring composer

# 添加 Ruby
RUN apt-get install -y ruby-full
RUN gem install bundler

# 添加你需要的任何其他工具
RUN apt-get install -y postgresql-client redis-tools

# 清理
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
```

然后使用自定义 Dockerfile 构建并运行：

```bash
./start.sh --build -f ./Dockerfile.custom --tag codemate:custom --branch feature/xyz
```

## 环境变量

> **注意：** 使用 `start.sh` 时，这些变量通过设置过程自动处理。此参考主要用于高级 Docker 使用或故障排除。

| 变量 | 必需 | 描述 |
|----------|----------|-------------|
| `GIT_REPO_URL` | 否 | 仓库 URL（默认为当前仓库的 remote） |
| `GITHUB_TOKEN` | 自动 | GitHub 个人访问令牌（如果未提供，默认为 `gh auth token`） |
| `GIT_USER_NAME` | 自动 | Git 提交作者名称（如果未提供，默认为 `git config user.name`） |
| `GIT_USER_EMAIL` | 自动 | Git 提交作者邮箱（如果未提供，默认为 `git config user.email`） |
| `CODEMATE_IMAGE` | 否 | 自定义镜像（默认：`ghcr.io/boringhappy/codemate:latest`） |
| `SLACK_WEBHOOK` | 否 | Slack Incoming Webhook URL，用于 Claude 停止时的通知 |
| `ANTHROPIC_AUTH_TOKEN` | 否 | Anthropic API 令牌（用于自定义 API 端点） |
| `ANTHROPIC_BASE_URL` | 否 | Anthropic API 基础 URL（用于自定义 API 端点） |
| `QUERY` | 否 | 启动后发送给 Claude 的初始查询 |


## 工作原理

CodeMate 使用单独的[基础镜像（`codemate-base`）](https://github.com/BoringHappy/CodeMate/pkgs/container/codemate-base)，每周重建以保持系统包和开发工具的最新状态。

启动时，容器会：
1. 克隆/更新仓库到 `/home/agent/<repo-name>`
2. 检出指定的分支或 PR
3. 如果在新分支上工作，则创建 PR
4. 在 tmux 会话中使用 `--dangerously-skip-permissions` 标志启动 Claude Code
5. 如果提供了 `--query`，则向 Claude 发送初始查询
6. 运行 cron 作业监控 PR 评论（每分钟）

## 技能

[CodeMate](https://github.com/BoringHappy/CodeMate) 预装了来自 [agent-browser](https://github.com/vercel-labs/agent-browser) 的技能。这些技能在启动容器时自动可用，并为 Git、PR 管理和浏览器交互提供工作流自动化。

### 可用插件

**Git 插件** (`git@codemate`)：
| 命令 | 描述 |
|---------|-------------|
| `/git:commit` | 暂存所有更改，创建有意义的提交消息，并推送到远程 |

**PR 插件** (`pr@codemate`)：
| 命令 | 描述 |
|---------|-------------|
| `/pr:get-details` | 获取 PR 信息，包括标题、描述、文件更改和审查评论 |
| `/pr:fix-comments` | 读取 PR 审查评论，修复问题，提交更改并回复评论 |
| `/pr:update` | 更新 PR 标题和摘要。使用 `--summary-only` 仅更新摘要 |
| `/pr:ack-comments` | 通过添加 👀 表情确认 PR 问题评论 |

**浏览器插件** (`agent-browser`)：
| 命令 | 描述 |
|---------|-------------|
| `/agent-browser` | 自动化浏览器交互，用于 Web 测试、表单填充、截图和数据提取 |

## PR 评论监控

CodeMate 自动监控 PR 评论，并在新反馈到达时通知 Claude。cron 作业每分钟运行一次以检查新评论。

### 评论类型

GitHub PR 有两种类型的评论，CodeMate 会监控：

| 类型 | 位置 | API 端点 | 用例 |
|------|----------|--------------|----------|
| **审查评论** | File Changes | `/pulls/{pr}/comments` | 针对特定行的代码特定反馈 |
| **问题评论** | PR Comment | `/issues/{pr}/comments` | 一般讨论、问题、请求 |

### 审查评论工作流

当有人留下**审查评论**（内联代码评论）时：

1. 监控检测到未解决的审查评论
2. 向 Claude 发送消息：`"Please Use /fix-comments skill to address comments"`
3. Claude 使用 `/pr:fix-comments` 技能：
   - 读取反馈
   - 进行代码更改
   - 提交并推送
   - 回复 "Claude Replied: ..." 标记为已解决

### 问题评论工作流

当有人留下**问题评论**（一般 PR 评论）时：

1. 监控检测到没有 👀 反应的新问题评论
2. 将实际评论内容发送给 Claude
3. Claude 处理请求
4. Claude 使用 `/pr:ack-comments` 技能添加 👀 反应
5. 未来运行会跳过带有 👀 反应的评论

### 过滤逻辑

评论在以下情况下会被过滤掉：
- 以 "Claude Replied:" 开头（已处理）
- 有 👀 反应（已确认）
- 由 Claude 自己创建

## 最佳实践

### 添加 Pull Request 模板

在目标仓库中创建 `.github/PULL_REQUEST_TEMPLATE.md` 以标准化 PR 描述：

```markdown
## 摘要
<!-- 简要描述更改 -->

## 测试计划
<!-- 如何验证更改 -->

## 检查清单
- [ ] 添加/更新测试
- [ ] 更新文档
```

### 安全建议

- 仅在受信任的仓库上运行 CodeMate
- 使用具有最小范围的短期 GitHub 令牌
- 避免挂载敏感的主机目录
- 在合并 Claude 创建的 PR 之前审查更改

## 许可证

MIT
