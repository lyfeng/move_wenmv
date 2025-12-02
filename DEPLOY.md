# 🚀 WEN MOVED Coin ($WENMO) 部署指南

本文档将指导您如何在 Movement M2 测试网（或任何 Aptos 兼容链）上部署智能合约和前端应用。

## 📋 前置条件

1.  **安装 Movement CLI**
    *   请参考 [Movement 官方文档](https://docs.movementnetwork.xyz/devs/movementcli) 安装 CLI 工具。
    *   确保 `movement` 命令在终端中可用。

2.  **安装 Node.js & npm**
    *   建议使用 Node.js v16 或更高版本。

3.  **配置钱包账户**
    *   运行 `movement init` 初始化配置。
    *   选择网络（例如 Movement M2 RPC URL）。
    *   这将生成一个 `default` 配置文件 (`.aptos/config.yaml`)。

## 🛠 1. 智能合约部署

我们提供了一个自动化脚本来简化部署过程。

### 方法 A: 使用自动部署脚本 (推荐)

1.  确保您在项目根目录下。
2.  赋予脚本执行权限：
    ```bash
    chmod +x deploy_contract.sh
    ```
3.  运行脚本：
    ```bash
    ./deploy_contract.sh
    ```
4.  脚本将引导您完成以下步骤：
    *   输入要使用的 Movement Profile 名称（默认为 `default`）。
    *   自动编译并发布合约。
    *   自动初始化水龙头并存入资金。

### 方法 B: 手动部署

如果您想手动控制每一步，请执行以下命令：

1.  **进入合约目录**
    ```bash
    cd move_contracts
    ```

2.  **获取账户地址**
    假设您使用 `default` profile：
    ```bash
    export ADDR=$(movement account list --query balance --profile default | grep "account" | cut -d '"' -f 4 | head -n 1)
    echo "Deploying to address: $ADDR"
    ```

3.  **发布合约**
    ```bash
    movement move publish \
      --named-addresses wenmo=$ADDR \
      --profile default \
      --assume-yes
    ```

4.  **初始化水龙头**
    发布成功后，初始化水龙头并存入 5 亿枚 WENMO (总量的 50%)：
    ```bash
    # 500,000,000 * 10^8 = 50000000000000000
    movement move run \
      --function-id $ADDR::wenmo_faucet::init_faucet \
      --args u64:50000000000000000 \
      --profile default \
      --assume-yes
    ```

---

## 💻 2. 前端部署

### 配置前端

1.  **更新合约地址**
    部署合约后，您会获得合约部署的地址。
    打开 `frontend/src/constants.js` 文件：

    ```javascript
    // 将此处替换为您刚才部署的地址
    export const MODULE_ADDRESS = "0x您的合约地址..."; 
    
    // 如果您在 Movement M2 以外的网络部署，请更新 RPC URL
    export const NODE_URL = "https://aptos.testnet.m2.movementlabs.xyz"; 
    ```

2.  **安装依赖**
    ```bash
    cd frontend
    npm install
    ```

### 本地运行

```bash
npm run dev
```
打开浏览器访问 `http://localhost:5173`。

### 构建与发布

1.  **构建生产版本**
    ```bash
    npm run build
    ```
    构建产物将位于 `frontend/dist` 目录。

2.  **部署到 Vercel / Netlify**
    *   **Vercel**: 安装 `vercel` CLI (`npm i -g vercel`)，然后在 `frontend` 目录下运行 `vercel`。
    *   **Netlify**: 将 `frontend/dist` 文件夹拖入 Netlify 控制台，或配置 Git 自动部署。

---

## 🔍 常见问题

**Q: 部署时提示 `INSUFFICIENT_BALANCE`?**
A: 您的部署账户需要少量的 MOVE 作为 Gas 费。请先前往 Movement 水龙头领取测试代币。

**Q: 前端无法连接钱包?**
A: 确保您的浏览器安装了 Petra、Pontem 或其他兼容 Aptos 标准的钱包，并且切换到了正确的网络 (Movement M2)。
