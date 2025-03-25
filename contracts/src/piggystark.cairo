#[starknet::contract]
pub mod PiggyStark {
    use contracts::interfaces::ipiggystark::IPiggyStark;
    use contracts::structs::piggystructs::Asset;
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};
    
    #[storage]
    struct Storage {
        owner: ContractAddress,
        // Mapping from user address to the token address they deposited
        deposited_token: Map<ContractAddress, ContractAddress>,
        // Mapping from (user address, token address) to deposit amount
        deposit_values: Map<(ContractAddress, ContractAddress), u256>,
    }

    fn constructor() {}

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {}
        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {}

        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let caller = get_caller_address();
            let mut assets = ArrayTrait::new();

            // Get the token address for the caller
            let token_address = self.deposited_token.entry(caller).read();

            // If the user has deposited a token (address is not zero)
            if !token_address.is_zero() {
                let amount = self.deposit_values.entry((caller, token_address)).read();
                assets
                    .append(
                        Asset {
                            token_name: "PIGGY STARK", //hardcoded this since, I don't see where token name is coming from
                            token_address,
                            balance: amount,
                        },
                    );
            }

            assets
        }

        fn get_token_balance(self: @ContractState, token_address: ContractAddress) {}
    }
}
