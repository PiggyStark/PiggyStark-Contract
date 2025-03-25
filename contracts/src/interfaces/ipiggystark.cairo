use starknet::ContractAddress;
use contracts::structs::piggystructs::Asset;

#[starknet::interface]
pub trait IPiggyStark<TContractState> {
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn get_user_assets(self: @TContractState) -> Array<Asset>;
    // Added return type to get_token_balance
    fn get_token_balance(self: @TContractState, token_address: ContractAddress) -> u256;
}