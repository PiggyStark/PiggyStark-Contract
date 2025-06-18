use starknet::ContractAddress;

#[starknet::interface]
pub trait IAVNU<TContractState> {
    /// Adds tokens to an AVNU liquidity pool for yield generation.
    /// @param pool The address of the liquidity pool.
    /// @param amount The amount of tokens to add.
    /// @return True if successful, false otherwise.
    fn add_liquidity(ref self: TContractState, pool: ContractAddress, amount: u256) -> bool;

    /// Removes tokens from an AVNU liquidity pool.
    /// @param pool The address of the liquidity pool.
    /// @param amount The amount of tokens to remove.
    /// @return True if successful, false otherwise.
    fn remove_liquidity(ref self: TContractState, pool: ContractAddress, amount: u256) -> bool;

    /// Returns the yield rate for a specific pool.
    /// @param pool The address of the liquidity pool.
    /// @return The yield rate (e.g., APR in basis points).
    fn get_pool_yield(self: @TContractState, pool: ContractAddress) -> u256;
}
