use starknet::ContractAddress;

#[starknet::interface]
pub trait INostra<TContractState> {
    /// Deposits tokens into a Nostra lending pool for yield generation.
    /// @param asset The address of the ERC20 token to deposit.
    /// @param amount The amount of tokens to deposit.
    /// @return True if the deposit succeeds, false otherwise.
    fn deposit(ref self: TContractState, asset: ContractAddress, amount: u256) -> bool;

    /// Withdraws tokens from a Nostra lending pool.
    /// @param asset The address of the ERC20 token to withdraw.
    /// @param amount The amount of tokens to withdraw.
    /// @return True if the withdrawal succeeds, false otherwise.
    fn withdraw(ref self: TContractState, asset: ContractAddress, amount: u256) -> bool;

    /// Returns the yield rate for a specific token in the Nostra protocol.
    /// @param asset The address of the ERC20 token.
    /// @return The yield rate (e.g., APR in basis points).
    fn get_yield_rate(self: @TContractState, asset: ContractAddress) -> u256;

    /// Returns the accumulated yield for a user and token in the Nostra protocol.
    /// @param account The address of the user.
    /// @param asset The address of the ERC20 token.
    /// @return The accrued yield amount.
    fn get_user_yield(self: @TContractState, account: ContractAddress, asset: ContractAddress) -> u256;
}