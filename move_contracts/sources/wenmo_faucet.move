module wenmo::wenmo_faucet {
    use std::signer;
    use std::error;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::account;

    // Errors
    const ENOT_OWNER: u64 = 1;
    const EALREADY_INITIALIZED: u64 = 2;
    const ENOT_INITIALIZED: u64 = 3;
    const EINSUFFICIENT_BALANCE: u64 = 4;
    const ECOOLDOWN_ACTIVE: u64 = 5;
    const EINVALID_AMOUNT: u64 = 6;
    const EFAUCET_INACTIVE: u64 = 7;

    // Constants
    const DEFAULT_DRIP_AMOUNT: u64 = 10_000_000_000; // 100 WENMO (8 decimals)
    const DEFAULT_COOLDOWN_SECONDS: u64 = 86400; // 24 hours
    const MAX_DRIP_AMOUNT: u64 = 1_000_000_000_000; // 10,000 WENMO

    // Contract state
    struct FaucetConfig has key {
        owner: address,
        drip_amount: u64,
        cooldown_seconds: u64,
        total_distributed: u64,
        is_active: bool,
        signer_cap: account::SignerCapability,
        resource_addr: address,
    }

    struct UserLastClaim has key {
        last_claim_timestamp: u64,
    }

    // Events
    #[event]
    struct FaucetInitializedEvent has drop, store {
        owner: address,
        resource_addr: address,
        drip_amount: u64,
        cooldown_seconds: u64,
    }

    #[event]
    struct TokensClaimedEvent has drop, store {
        claimant: address,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct FaucetConfigUpdatedEvent has drop, store {
        owner: address,
        drip_amount: u64,
        cooldown_seconds: u64,
        is_active: bool,
    }

    // Initialize the faucet
    public entry fun initialize(account: &signer, drip_amount: u64, cooldown_seconds: u64, seed: vector<u8>) {
        let account_addr = signer::address_of(account);
        
        // Check if already initialized
        assert!(!exists<FaucetConfig>(account_addr), error::invalid_state(EALREADY_INITIALIZED));
        
        // Validate parameters
        assert!(drip_amount <= MAX_DRIP_AMOUNT, error::invalid_argument(EINVALID_AMOUNT));
        assert!(drip_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(cooldown_seconds > 0, error::invalid_argument(EINVALID_AMOUNT));
        
        // Create resource account
        let (resource_signer, signer_cap) = account::create_resource_account(account, seed);
        let resource_addr = signer::address_of(&resource_signer);
        
        // Register resource account to receive tokens
        if (!coin::is_account_registered<wenmo::wenmo_token::WenmoToken>(resource_addr)) {
            coin::register<wenmo::wenmo_token::WenmoToken>(&resource_signer);
        };

        // Store faucet config
        move_to(account, FaucetConfig {
            owner: account_addr,
            drip_amount,
            cooldown_seconds,
            total_distributed: 0,
            is_active: true,
            signer_cap,
            resource_addr,
        });

        // Emit initialization event
        event::emit(FaucetInitializedEvent {
            owner: account_addr,
            resource_addr,
            drip_amount,
            cooldown_seconds,
        });
    }

    // Initialize with default parameters
    public entry fun initialize_default(account: &signer) {
        initialize(account, DEFAULT_DRIP_AMOUNT, DEFAULT_COOLDOWN_SECONDS, b"WENMO_FAUCET");
    }

    // Claim tokens from faucet
    public entry fun claim_wenmo(account: &signer) acquires FaucetConfig, UserLastClaim {
        let claimant_addr = signer::address_of(account);
        
        // Check if faucet exists
        assert!(exists<FaucetConfig>(@wenmo), error::invalid_state(ENOT_INITIALIZED));
        
        let faucet_config = borrow_global_mut<FaucetConfig>(@wenmo);
        
        // Check if faucet is active
        assert!(faucet_config.is_active, error::invalid_state(EFAUCET_INACTIVE));

        // Check if faucet has enough balance
        let resource_balance = coin::balance<wenmo::wenmo_token::WenmoToken>(faucet_config.resource_addr);
        assert!(resource_balance >= faucet_config.drip_amount, error::invalid_state(EINSUFFICIENT_BALANCE));

        // Auto-register user if needed
        if (!coin::is_account_registered<wenmo::wenmo_token::WenmoToken>(claimant_addr)) {
            coin::register<wenmo::wenmo_token::WenmoToken>(account);
        };
        
        // Check cooldown
        if (exists<UserLastClaim>(claimant_addr)) {
            let user_claim = borrow_global<UserLastClaim>(claimant_addr);
            let current_time = timestamp::now_seconds();
            let time_since_last_claim = current_time - user_claim.last_claim_timestamp;
            assert!(time_since_last_claim >= faucet_config.cooldown_seconds, error::invalid_state(ECOOLDOWN_ACTIVE));
        };
        
        // Update last claim time
        if (exists<UserLastClaim>(claimant_addr)) {
            let user_claim = borrow_global_mut<UserLastClaim>(claimant_addr);
            user_claim.last_claim_timestamp = timestamp::now_seconds();
        } else {
            move_to(account, UserLastClaim {
                last_claim_timestamp: timestamp::now_seconds(),
            });
        };
        
        // Get current time for event
        let current_time = timestamp::now_seconds();
        
        // Transfer tokens from resource account
        let resource_signer = account::create_signer_with_capability(&faucet_config.signer_cap);
        coin::transfer<wenmo::wenmo_token::WenmoToken>(&resource_signer, claimant_addr, faucet_config.drip_amount);
        
        // Update total distributed
        faucet_config.total_distributed = faucet_config.total_distributed + faucet_config.drip_amount;
        
        // Emit claim event
        event::emit(TokensClaimedEvent {
            claimant: claimant_addr,
            amount: faucet_config.drip_amount,
            timestamp: current_time,
        });
    }

    // Update faucet configuration (owner only)
    public entry fun update_config(account: &signer, drip_amount: u64, cooldown_seconds: u64, is_active: bool) acquires FaucetConfig {
        let account_addr = signer::address_of(account);
        
        // Check if faucet exists
        assert!(exists<FaucetConfig>(@wenmo), error::invalid_state(ENOT_INITIALIZED));
        
        let faucet_config = borrow_global_mut<FaucetConfig>(@wenmo);
        
        // Check if caller is owner
        assert!(faucet_config.owner == account_addr, error::permission_denied(ENOT_OWNER));
        
        // Validate parameters
        assert!(drip_amount <= MAX_DRIP_AMOUNT, error::invalid_argument(EINVALID_AMOUNT));
        assert!(drip_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(cooldown_seconds > 0, error::invalid_argument(EINVALID_AMOUNT));
        
        // Update config
        faucet_config.drip_amount = drip_amount;
        faucet_config.cooldown_seconds = cooldown_seconds;
        faucet_config.is_active = is_active;
        
        // Emit update event
        event::emit(FaucetConfigUpdatedEvent {
            owner: account_addr,
            drip_amount,
            cooldown_seconds,
            is_active,
        });
    }

    // Deposit tokens to faucet (anyone can fund the faucet)
    public entry fun fund_faucet(account: &signer, amount: u64) acquires FaucetConfig {
        // Check if faucet exists
        assert!(exists<FaucetConfig>(@wenmo), error::invalid_state(ENOT_INITIALIZED));
        let faucet_config = borrow_global<FaucetConfig>(@wenmo);
        
        coin::transfer<wenmo::wenmo_token::WenmoToken>(account, faucet_config.resource_addr, amount);
    }

    // Get faucet info
    #[view]
    public fun get_faucet_info(): (address, u64, u64, u64, bool, address) acquires FaucetConfig {
        assert!(exists<FaucetConfig>(@wenmo), error::invalid_state(ENOT_INITIALIZED));
        let config = borrow_global<FaucetConfig>(@wenmo);
        (config.owner, config.drip_amount, config.cooldown_seconds, config.total_distributed, config.is_active, config.resource_addr)
    }

    // Get user's last claim time
    #[view]
    public fun get_user_last_claim(user_addr: address): u64 acquires UserLastClaim {
        if (exists<UserLastClaim>(user_addr)) {
            let user_claim = borrow_global<UserLastClaim>(user_addr);
            user_claim.last_claim_timestamp
        } else {
            0
        }
    }

    // Get faucet balance
    #[view]
    public fun get_faucet_balance(): u64 acquires FaucetConfig {
         assert!(exists<FaucetConfig>(@wenmo), error::invalid_state(ENOT_INITIALIZED));
         let config = borrow_global<FaucetConfig>(@wenmo);
         coin::balance<wenmo::wenmo_token::WenmoToken>(config.resource_addr)
    }

    // Check if user can claim and return remaining cooldown
    #[view]
    public fun can_claim(user_addr: address): (bool, u64) acquires FaucetConfig, UserLastClaim {
        if (!exists<FaucetConfig>(@wenmo)) {
            return (false, 0)
        };
        
        let faucet_config = borrow_global<FaucetConfig>(@wenmo);
        
        if (!faucet_config.is_active) {
            return (false, 0)
        };
        
        if (!exists<UserLastClaim>(user_addr)) {
            return (true, 0)
        };
        
        let user_claim = borrow_global<UserLastClaim>(user_addr);
        let current_time = timestamp::now_seconds();
        let time_since_last_claim = current_time - user_claim.last_claim_timestamp;
        
        if (time_since_last_claim >= faucet_config.cooldown_seconds) {
            (true, 0)
        } else {
            (false, faucet_config.cooldown_seconds - time_since_last_claim)
        }
    }
}