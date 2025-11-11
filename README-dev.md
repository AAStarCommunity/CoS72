# COS72: Developer README

COS72 is an AI dApps Builder designed as a public good to simplify the creation of community-centric decentralized applications.

## Core Components & User Flow

The COS72 ecosystem is built around a core user engagement loop, supported by the following components:

*   **xPNTs**: A points system based on a contract factory that allows any community to mint and manage their own tokens (points). A basic management UI is available.
*   **Tasks**: A task marketplace where communities can post tasks and users can complete them to earn xPNTs.
*   **Shops**: The primary feature for user engagement. Users can spend their earned xPNTs here. This component is already implemented on the `main` branch and is under active iteration.

The flow is as follows: `Community issues xPNTs -> User completes Tasks to earn xPNTs -> User spends xPNTs in the Shop`.

## Architecture Overview

*   **Layer 3**: Built on top of the **Mycelium Protocol / Mushroom Protocol**.
*   **Layer 2**: Deployed on the **Optimism Layer 2 Superchain**.
*   **Decentralized Infrastructure**: dApps run on **SDSS (Standard Decentralized Service System) / Rain Computing**.
*   **Core Components**: Integrates with other protocols from the ecosystem:
    *   **AirAccount**: For decentralized, social-recovery accounts (ERC-4337).
    *   **SuperPaymaster**: For decentralized gas fee sponsorship.

## How to Contribute

This project is open source (MIT License) and we welcome contributions.

*Contribution guidelines are currently being drafted and will be available soon.*

---

# COS72: 开发者自述文件

COS72 是一个AI dApps构建器，它被设计成一个公共物品，旨在简化以社区为中心的去中心化应用的创建过程。

## 核心组件与用户流

COS72生态系统围绕一个核心的用户参与循环构建，由以下组件支持：

*   **xPNTs**: 一个基于合约工厂的积分系统，允许任何社区发行和管理他们自己的代币（积分）。提供了一个基础的管理页面。
*   **Tasks (任务广场)**: 一个任务市场，社区可以在此发布任务，用户通过完成任务来赚取 xPNTs。
*   **Shops (商店)**: 用户参与的核心功能。用户可以在这里消费他们赚取的 xPNTs。该组件已在 `main` 分支上实现，并正在积极迭代中。

其流程如下: `社区发行 xPNTs -> 用户完成任务赚取 xPNTs -> 用户在商店中消费 xPNTs`。

## 技术架构概览

*   **Layer 3**: 构建于 **Mycelium Protocol / Mushroom Protocol** 之上。
*   **Layer 2**: 部署在 **Optimism Layer 2 Superchain** 上。
*   **去中心化基础设施**: dApp运行在 **SDSS (Standard Decentralized Service System) / Rain Computing** 之上。
*   **核心组件**: 项目集成了生态系统中的其他协议：
    *   **AirAccount**: 用于去中心化的、可社交恢复的账户 (ERC-4337)。
    *   **SuperPaymaster**: 用于去中心化的Gas费用代付。

## 如何贡献

本项目基于 MIT 许可证开源，我们欢迎所有形式的贡献。

*贡献指南目前正在草拟中，将很快发布。*