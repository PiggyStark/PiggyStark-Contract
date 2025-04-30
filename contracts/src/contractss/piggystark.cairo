#[starknet::contract]
pub mod PiggyStark {
    use contracts::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::interfaces::ipiggystark::IPiggyStark;
    use contracts::structs::piggystructs::Asset;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        user_deposits: Map::<
            ContractAddress, Map<ContractAddress, Option<Asset>>,
        >, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct SuccessfulDeposit {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            assert(token_address.is_non_zero(), 'Token address cannot be zero');
            assert(amount > 0, 'Token amount cannot be zero');

            let caller = get_caller_address();
            let contract = get_contract_address();
            // Transfer tokens from user to contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher.transfer_from(caller, contract, amount);

            // Update user deposit balance
            let prev_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            // Handle both new and existing deposits
            if prev_asset_ref.is_some() {
                // User has deposited this token before, update the balance
                let prev_asset = prev_asset_ref.unwrap();
                let new_asset = Asset {
                    token_name: prev_asset.token_name,
                    token_address: prev_asset.token_address,
                    balance: prev_asset.balance + amount,
                };
                self
                    .user_deposits
                    .entry(caller)
                    .entry(token_address)
                    .write(Option::Some(new_asset));
            } else {
                // This is the user's first deposit of this token, create a new record
                let new_asset = Asset {
                    token_name: 'STRK', token_address: token_address, balance: amount,
                };
                self
                    .user_deposits
                    .entry(caller)
                    .entry(token_address)
                    .write(Option::Some(new_asset));

                // Add this token to the deposited tokens list if it's not already theredf
                self.deposited_tokens.append().write(token_address);
            }
            //self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));
            //self.deposited_tokens.append().write(token_address);
            self.emit(SuccessfulDeposit { caller, token: token_address, amount });
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');
            let user_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(user_asset_ref.is_some(), 'Asset does not exist');
            let mut user_asset = user_asset_ref.unwrap();
            let contract = get_contract_address();
            assert(user_asset.balance >= amount, 'Amount overflows balance');

            user_asset.balance = user_asset.balance - amount;
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(user_asset));
        }


        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let caller = get_caller_address();
            let mut assets = ArrayTrait::new();
            assert(self.deposited_tokens.len() > 0, 'no token availabe');
            for i in 0..self.deposited_tokens.len() {
                let token_address = self.deposited_tokens.at(i).read();
                let current_user_possesses = self
                    .user_deposits
                    .entry(caller)
                    .entry(token_address)
                    .read();
                assert(current_user_possesses.is_some(), 'Not owned by user');
                let user_asset = current_user_possesses.unwrap();
                assets.append(user_asset);
            };
            assets
        }


        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Called with the zero address');
            let user_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(user_asset_ref.is_some(), 'User does not possess token');
            let user_asset = user_asset_ref.unwrap();
            user_asset.balance
        }
    }
}
