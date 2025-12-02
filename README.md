# WEN MOVED Coin ($WENMO)

WEN MOVED Coin 是一个在 Movement M2 测试网（Aptos 兼容）上构建的 Move 原生代币和水龙头项目。

## 📁 项目结构

*   **`move_contracts/`**: 包含 Move 智能合约代码 (`wenmo_token` 和 `wenmo_faucet`)。
*   **`frontend/`**: 基于 React + Vite 的前端水龙头应用。
*   **`deploy_contract.sh`**: 自动化部署脚本（使用 Movement CLI）。
*   **`DEPLOY.md`**: 详细的部署指南。

## 🚀 快速开始

### 1. 部署合约

详细步骤请参考 [部署指南](DEPLOY.md)。

最简单的方法是运行脚本（确保已安装 [Movement CLI](https://docs.movementnetwork.xyz/devs/movementcli)）：
```bash
chmod +x deploy_contract.sh
./deploy_contract.sh
```

### 2. 运行前端

1.  部署合约后，获取合约地址。
2.  修改 `frontend/src/constants.js` 中的 `MODULE_ADDRESS`。
3.  启动前端：
    ```bash
    cd frontend
    npm install
    npm run dev
    ```

## 📄 功能特性

*   **$WENMO 代币**: 标准 Move 代币，总供应量 10 亿。
*   **水龙头**: 每日限额领取 100 $WENMO，24小时冷却时间。
*   **Web 界面**: 连接钱包，实时查看余额和冷却状态，一键领取。
