use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> ByteArray;
    fn get_symbol(self: @TContractState) -> ByteArray;
    fn get_decimals(self: @TContractState) -> u8;

    fn get_total_supply(self: @TContractState) -> u256;
    fn get_balance_of(self: @TContractState, account: ContractAddress);
    fn get_allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress);

    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    );

    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}
