#[starknet::contract]
pub mod PiggyStark {
    use contracts::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::interfaces::ipiggystark::IPiggyStark;
    use contracts::structs::piggystructs::Asset;
    use core::num::traits::Zero;
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        user_deposits: Map<
            ContractAddress, Map<ContractAddress, Option<Asset>>,
        >, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
        AssetCreated: AssetCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SuccessfulDeposit {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AssetCreated {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub token_name: felt252,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn create_asset(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            assert(token_address.is_non_zero(), 'Token address cannot be zero');
            assert(amount > 0, 'Token amount cannot be zero');

            let caller: ContractAddress = get_caller_address();
            let contract: ContractAddress = get_contract_address();

            let existing_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(existing_asset_ref.is_none(), 'Asset already exists');

            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };

            erc20_dispatcher.transfer_from(caller, contract, amount);

            let token_name: felt252 = erc20_dispatcher.get_name();

            // Create new asset
            let new_asset = Asset { token_name, token_address, balance: amount };

            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));

            self.deposited_tokens.push(token_address);

            self.emit(AssetCreated { caller, token: token_address, token_name, amount });
        }

        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            assert(token_address.is_non_zero(), 'Token address cannot be zero');
            assert(amount > 0, 'Token amount cannot be zero');

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Transfer tokens from user to contract
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(caller, contract, amount);

            // Update user deposit balance
            let prev_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(prev_asset_ref.is_some(), 'User does not possess token');
            let prev_asset = prev_asset_ref.unwrap();
            let new_asset = Asset {
                token_name: prev_asset.token_name,
                token_address: prev_asset.token_address,
                balance: prev_asset.balance + amount,
            };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));
            self.deposited_tokens.append().write(token_address);
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

            // Transfer tokens from contract to user
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(contract, caller, amount);

            user_asset.balance = user_asset.balance - amount;
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(user_asset));
        }


        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let caller = get_caller_address();
            let mut assets = ArrayTrait::new();

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
            }
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
