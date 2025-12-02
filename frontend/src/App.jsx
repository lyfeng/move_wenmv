import { useEffect, useState } from 'react';
import { useWallet } from '@aptos-labs/wallet-adapter-react';
import { WalletSelector } from '@aptos-labs/wallet-adapter-ant-design';
import '@aptos-labs/wallet-adapter-ant-design/dist/index.css';
import { aptosClient } from './utils/aptosClient';
import { MODULE_ADDRESS, MODULE_NAME, TOKEN_MODULE_NAME } from './constants';
import './App.css';

function App() {
  const { account, signAndSubmitTransaction, connected, connect, disconnect, wallets } = useWallet();
  const [balance, setBalance] = useState(0);
  const [faucetBalance, setFaucetBalance] = useState(0);
  const [cooldownLeft, setCooldownLeft] = useState(0);
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState(null);
  const [error, setError] = useState(null);

  const formatBalance = (val) => {
    return (val / 100000000).toFixed(2);
  };

  const fetchData = async () => {
    try {
      // 1. Get Faucet Balance
      const faucetPayload = {
        function: `${MODULE_ADDRESS}::${MODULE_NAME}::get_faucet_balance`,
        type_arguments: [],
        arguments: [],
      };
      
      try {
        const faucetRes = await aptosClient.view(faucetPayload);
        setFaucetBalance(parseInt(faucetRes[0]));
      } catch (e) {
        console.error("Error fetching faucet balance:", e);
      }

      if (connected && account) {
        // 2. Get User Balance
        try {
          const resource = await aptosClient.getAccountResource(
            account.address.toString(),
            `0x1::coin::CoinStore<${MODULE_ADDRESS}::${TOKEN_MODULE_NAME}::WenmoToken>`
          );
          setBalance(parseInt(resource.data.coin.value));
        } catch (e) {
          // User might not have the coin resource yet
          setBalance(0);
        }

        // 3. Check Cooldown
        const cooldownPayload = {
          function: `${MODULE_ADDRESS}::${MODULE_NAME}::can_claim`,
          type_arguments: [],
          arguments: [account.address.toString()],
        };
        
        try {
          const cooldownRes = await aptosClient.view(cooldownPayload);
          const canClaim = cooldownRes[0];
          const timeLeft = parseInt(cooldownRes[1]);
          
          if (canClaim) {
            setCooldownLeft(0);
          } else {
            setCooldownLeft(timeLeft);
          }
        } catch (e) {
          console.error("Error checking cooldown:", e);
        }
      }
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000); // Refresh every 10s
    return () => clearInterval(interval);
  }, [connected, account]);

  // Timer for cooldown countdown
  useEffect(() => {
    if (cooldownLeft > 0) {
      const timer = setInterval(() => {
        setCooldownLeft((prev) => (prev > 0 ? prev - 1 : 0));
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [cooldownLeft]);

  const handleConnect = async (walletName) => {
    try {
      await connect(walletName);
    } catch (e) {
      console.error("Connect error", e);
    }
  };

  const handleClaim = async () => {
    if (!account) return;
    setLoading(true);
    setError(null);
    setTxHash(null);

    const payload = {
      data: {
        function: `${MODULE_ADDRESS}::${MODULE_NAME}::claim_wenmo`,
        typeArguments: [],
        functionArguments: [],
      },
    };

    try {
      const response = await signAndSubmitTransaction(payload);
      await aptosClient.waitForTransaction(response.hash);
      setTxHash(response.hash);
      fetchData(); // Refresh data
    } catch (err) {
      console.error("Claim failed", err);
      if (err.message && (err.message.includes("404") || err.message.includes("Account not found"))) {
        setError("Your account may not be initialized on-chain. Please get some gas tokens first from a faucet to pay for the transaction.");
      } else {
        setError(err.message || "Transaction failed");
      }
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (seconds) => {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${h}h ${m}m ${s}s`;
  };

  return (
    <div className="container">
      <header>
        <h1>WEN MOVED Coin ($WENMO) Faucet</h1>
        <p>Movement M2 Testnet</p>
      </header>

      <div className="card">
        {!connected ? (
          <div className="wallet-section">
            <h2>Connect Wallet</h2>
            <WalletSelector />
          </div>
        ) : (
          <div className="wallet-section">
            <p>Connected: {account && account.address ? `${String(account.address).slice(0, 6)}...${String(account.address).slice(-4)}` : 'Loading...'}</p>
            <button onClick={disconnect} style={{ padding: '5px 10px', fontSize: '0.8rem' }}>Disconnect</button>
          </div>
        )}

        <div className="info-grid">
          <div className="info-item">
            <span className="info-label">Faucet Balance</span>
            <span className="info-value">{formatBalance(faucetBalance)} WENMO</span>
          </div>
          <div className="info-item">
            <span className="info-label">Your Balance</span>
            <span className="info-value">{connected ? formatBalance(balance) : '-'} WENMO</span>
          </div>
        </div>

        {connected && (
          <div>
            <button 
              className="claim-btn" 
              onClick={handleClaim} 
              disabled={loading || cooldownLeft > 0 || faucetBalance < 10000000000}
            >
              {loading ? "Processing..." : 
               cooldownLeft > 0 ? `Wait ${formatTime(cooldownLeft)}` : 
               "CLAIM 100 $WENMO"}
            </button>
            
            {cooldownLeft > 0 && (
              <p className="status-message status-cooldown">
                ⏳ Cooldown active.
              </p>
            )}
            
            {cooldownLeft === 0 && faucetBalance >= 10000000000 && (
              <p className="status-message status-available">
                ✅ Available to claim!
              </p>
            )}

             {faucetBalance < 10000000000 && (
              <p className="status-message status-empty">
                ❌ Faucet Empty
              </p>
            )}

            {txHash && (
              <div style={{ marginTop: '1rem', wordBreak: 'break-all' }}>
                <p style={{ color: 'green' }}>Success!</p>
                <small>Tx: {txHash}</small>
              </div>
            )}
            
            {error && (
              <p style={{ color: 'red', marginTop: '1rem' }}>Error: {error}</p>
            )}
          </div>
        )}
        
        {!connected && (
           <p className="status-message">Please connect wallet to claim.</p>
        )}
      </div>
      
      <footer>
        <p>Daily Limit: 100 WENMO | Cooldown: 24 Hours</p>
      </footer>
    </div>
  );
}

export default App;
