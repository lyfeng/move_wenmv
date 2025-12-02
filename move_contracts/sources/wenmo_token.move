module wenmo::wenmo_token {
    use std::signer;
    use std::string;
    use std::error;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::event;

    // Errors
    const ENOT_OWNER: u64 = 1;
    const EALREADY_INITIALIZED: u64 = 2;
    const ENOT_INITIALIZED: u64 = 3;

    // Token info
    const TOKEN_NAME: vector<u8> = b"WEN MOVED Coin";
    const TOKEN_SYMBOL: vector<u8> = b"WENMO";
    const TOKEN_DECIMALS: u8 = 8;
    const TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_00; // 1 billion * 10^8

    // Contract state
    struct WenmoTokenCapabilities has key {
        mint_cap: MintCapability<WenmoToken>,
        burn_cap: BurnCapability<WenmoToken>,
    }

    struct WenmoTokenInfo has key {
        name: string::String,
        symbol: string::String,
        decimals: u8,
        total_supply: u64,
    }

    // Token type
    struct WenmoToken has drop { }

    // Events
    #[event]
    struct TokenInitializedEvent has drop, store {
        owner: address,
        name: string::String,
        symbol: string::String,
        decimals: u8,
    }

    #[event]
    struct TokenMintedEvent has drop, store {
        to: address,
        amount: u64,
    }

    #[event]
    struct TokenBurnedEvent has drop, store {
        from: address,
        amount: u64,
    }

    // Initialize the token
    public entry fun initialize(account: &signer) {
        let account_addr = signer::address_of(account);
        
        // Check if already initialized
        assert!(!exists<WenmoTokenCapabilities>(account_addr), error::invalid_state(EALREADY_INITIALIZED));
        
        // Register the coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<WenmoToken>(
            account,
            string::utf8(TOKEN_NAME),
            string::utf8(TOKEN_SYMBOL),
            TOKEN_DECIMALS,
            true, // monitor_supply
        );

        // Remove freeze capability as it's not used
        coin::destroy_freeze_cap(freeze_cap);

        // Register the account to receive the coin
        coin::register<WenmoToken>(account);

        // Mint total supply
        let coins = coin::mint(TOTAL_SUPPLY, &mint_cap);
        coin::deposit(account_addr, coins);

        // Store capabilities
        move_to(account, WenmoTokenCapabilities {
            mint_cap,
            burn_cap,
        });

        // Store token info
        move_to(account, WenmoTokenInfo {
            name: string::utf8(TOKEN_NAME),
            symbol: string::utf8(TOKEN_SYMBOL),
            decimals: TOKEN_DECIMALS,
            total_supply: TOTAL_SUPPLY,
        });

        // Emit initialization event
        event::emit(TokenInitializedEvent {
            owner: account_addr,
            name: string::utf8(TOKEN_NAME),
            symbol: string::utf8(TOKEN_SYMBOL),
            decimals: TOKEN_DECIMALS,
        });
    }

    // Mint tokens
    public entry fun mint(account: &signer, to: address, amount: u64) acquires WenmoTokenCapabilities, WenmoTokenInfo {
        let account_addr = signer::address_of(account);
        
        // Check if initialized
        assert!(exists<WenmoTokenCapabilities>(account_addr), error::invalid_state(ENOT_INITIALIZED));
        
        // Get capabilities and info
        let capabilities = borrow_global_mut<WenmoTokenCapabilities>(account_addr);
        let token_info = borrow_global_mut<WenmoTokenInfo>(account_addr);
        
        // Mint tokens
        let coins = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(to, coins);
        
        // Update total supply
        token_info.total_supply = token_info.total_supply + amount;
        
        // Emit mint event
        event::emit(TokenMintedEvent {
            to,
            amount,
        });
    }

    // Burn tokens
    public entry fun burn(account: &signer, amount: u64) acquires WenmoTokenCapabilities, WenmoTokenInfo {
        let account_addr = signer::address_of(account);
        
        // Check if initialized
        assert!(exists<WenmoTokenCapabilities>(account_addr), error::invalid_state(ENOT_INITIALIZED));
        
        // Get capabilities and info
        let capabilities = borrow_global_mut<WenmoTokenCapabilities>(account_addr);
        let token_info = borrow_global_mut<WenmoTokenInfo>(account_addr);
        
        // Withdraw and burn coins
        let coins = coin::withdraw<WenmoToken>(account, amount);
        let burned_amount = coin::value(&coins);
        coin::burn<WenmoToken>(coins, &capabilities.burn_cap);
        
        // Update total supply
        token_info.total_supply = token_info.total_supply - burned_amount;
        
        // Emit burn event
        event::emit(TokenBurnedEvent {
            from: account_addr,
            amount: burned_amount,
        });
    }

    // Transfer tokens
    public entry fun transfer(from: &signer, to: address, amount: u64) {
        coin::transfer<WenmoToken>(from, to, amount);
    }

    // Get balance
    #[view]
    public fun balance_of(addr: address): u64 {
        coin::balance<WenmoToken>(addr)
    }

    // Get token info
    #[view]
    public fun get_token_info(owner: address): (string::String, string::String, u8, u64) acquires WenmoTokenInfo {
        assert!(exists<WenmoTokenInfo>(owner), error::invalid_state(ENOT_INITIALIZED));
        let info = borrow_global<WenmoTokenInfo>(owner);
        (info.name, info.symbol, info.decimals, info.total_supply)
    }

    // Check if token is initialized
    #[view]
    public fun is_initialized(owner: address): bool {
        exists<WenmoTokenCapabilities>(owner)
    }
}