use contracts::structs::piggystructs::Asset;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IPiggyStark<TContractState> {
    fn create_asset(
        ref self: TContractState, token_address: ContractAddress, amount: u256, token_name: felt252,
    );
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);

    /// Withdraws an amount of a supported token from the user’s flexible savings wallet.
    /// Tokens are withdrawn from Nostra (if allocated) and transferred back to the user’s wallet.
    /// Emits a Withdrawal event.
    /// @param token_address The address of the ERC20 token to withdraw.
    /// @param amount The amount of tokens to withdraw (must be <= user’s flexible balance).
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);

    /// Locks an amount of a supported token for a specified duration to earn higher yields.
    /// Funds are moved from the flexible balance to a locked state and may be allocated to Nostra.
    /// Emits a Locked event.
    /// @param token_address The address of the ERC20 token to lock.
    /// @param amount The amount of tokens to lock (must be <= user’s flexible balance).
    /// @param lock_duration The duration (in seconds) for which funds are locked.
    // fn lock_savings(ref self: TContractState, token_address: ContractAddress, amount: u256, lock_duration: u64);

    /// Unlocks and releases funds from a specific lock once the lock duration has expired.
    /// Funds are moved back to the user’s flexible balance and withdrawn from Nostra if applicable.
    /// Emits an Unlocked event.
    /// @param token_address The address of the ERC20 token to unlock.
    /// @param lock_id The unique ID of the lock to release.
    // fn unlock_savings(ref self: TContractState, token_address: ContractAddress, lock_id: u64);

    // === Target Savings Functions ===
    // These functions support goal-based savings, similar to PiggyVest’s Target Savings.

    /// Creates a new savings target with a goal amount and deadline.
    /// Allows users to save toward a specific financial goal, with funds optionally allocated to Nostra.
    /// Emits a TargetCreated event.
    /// @param token_address The address of the ERC20 token for the target.
    /// @param goal The target amount to save (must be > 0).
    /// @param deadline The timestamp (in seconds) when the target expires.
    // fn create_target(ref self: TContractState, token_address: ContractAddress, goal: u256, deadline: u64);

    /// Contributes an amount to an existing savings target.
    /// Funds are moved from the flexible balance to the target and may be allocated to Nostra.
    /// Emits a TargetContributed event.
    /// @param token_address The address of the ERC20 token to contribute.
    /// @param target_id The unique ID of the target to contribute to.
    /// @param amount The amount to contribute (must be <= remaining goal amount).
    // fn contribute_to_target(ref self: TContractState, token_address: ContractAddress, target_id: u64, amount: u256);

    // === Investment & Yield Functions ===
    // These functions handle DeFi investments and yield claiming via Nostra and AVNU.

    /// Allocates funds to an AVNU liquidity pool for yield generation.
    /// Funds are moved from the flexible balance to the AVNU pool, treated as an asset.
    /// Emits a Deposit event.
    /// @param pool The address of the AVNU liquidity pool (must be supported).
    /// @param amount The amount of tokens to invest (must be <= user’s flexible balance).
    // fn invest_in_avnu(ref self: TContractState, pool: ContractAddress, amount: u256);

    /// Claims accumulated yield for a user from a specific token via Nostra.
    /// Yield is added to the user’s flexible balance and withdrawn from Nostra.
    /// Emits a YieldClaimed event.
    /// @param token_address The address of the ERC20 token for which to claim yield.
    // fn claim_yield(ref self: TContractState, token_address: ContractAddress);

    // === View Functions ===
    // These functions allow querying of balances, savings, and yield data without modifying state.

    /// Returns the user’s flexible balance for a specific token.
    /// Useful for displaying available funds in the frontend.
    /// @param user The address of the user to query (defaults to caller in implementation).
    /// @param token_address The address of the ERC20 token.
    /// @return The user’s available balance (in tokens).
    // fn get_balance(self: @TContractState, user: ContractAddress, token_address: ContractAddress) -> u256;

    /// Returns details of a specific locked savings entry.
    /// Useful for displaying locked funds and their unlock times in the frontend.
    /// @param user The address of the user to query.
    /// @param token_address The address of the ERC20 token.
    /// @param lock_id The unique ID of the lock.
    /// @return A tuple containing the locked amount and the unlock timestamp.
    // fn get_locked_balance(self: @TContractState, user: ContractAddress, token_address: ContractAddress, lock_id: u64) -> (u256, u64);

    /// Returns details of a specific savings target.
    /// Useful for displaying target progress in the frontend.
    /// @param user The address of the user to query.
    /// @param target_id The unique ID of the target.
    /// @return A tuple containing the goal amount, current saved amount, and deadline.
    // fn get_target_savings(self: @TContractState, user: ContractAddress, target_id: u64) -> (u256, u256, u64);

    /// Returns the current yield rate for a specific token from Nostra.
    /// Useful for displaying expected returns in the frontend.
    /// @param token_address The address of the ERC20 token.
    /// @return The yield rate (e.g., APR in basis points).
    // fn get_yield_rate(self: @TContractState, token_address: ContractAddress) -> u256;

    /// Returns an array of all assets (tokens and their balances) held by the user.
    /// Aggregates flexible, locked, and target savings balances for a comprehensive view.
    /// Useful for displaying a user’s portfolio in the frontend.
    /// @return An array of Asset structs containing token addresses and balances.
    fn get_user_assets(self: @TContractState) -> Array<Asset>;
}