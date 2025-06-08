use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Asset {
    pub token_name: felt252,
    pub token_address: ContractAddress,
    pub balance: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct LockedSavings {
    pub id: u64,
    pub owner: ContractAddress,
    pub token_address: ContractAddress,
    pub amount: u256,
    pub lock_duration: u64,
    pub lock_timestamp: u64,
    pub active: bool,
}
