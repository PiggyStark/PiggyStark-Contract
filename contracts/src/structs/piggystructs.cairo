use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Asset {
    pub token_name: ByteArray,
    pub token_address: ContractAddress,
    pub balance: u256,
}
