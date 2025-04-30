use contracts::structs::piggystructs::Asset;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IPiggyStark<TContractState> {
    fn create_asset(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn get_user_assets(self: @TContractState) -> Array<Asset>;
    fn get_token_balance(self: @TContractState, token_address: ContractAddress) -> u256;
}
