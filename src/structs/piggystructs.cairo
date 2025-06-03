use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Asset {
    pub token_name: felt252,
    pub token_address: ContractAddress,
    pub balance: u256,
}
