#[starknet::contract]
pub mod PiggyStark {
    use piggystark::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use piggystark::interfaces::ipiggystark::IPiggyStark;
    use piggystark::structs::piggystructs::{Asset, Target};
    use piggystark::errors::piggystark_errors::Errors;
    use core::num::traits::Zero;
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        user_deposits: Map<
            ContractAddress, Map<ContractAddress, Option<Asset>>,
        >, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
        balance: Map<ContractAddress, u256>, // Track total balance per token
        user_targets: Map<u64, Option<Target>>, // Track target
        targets_count: u64,
        contract_to_target_storage: Map<ContractAddress, bool>,
        mock_token: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
        AssetCreated: AssetCreated,
        Withdrawal: Withdrawal,
        TargetCreated: TargetCreated,
        TargetContributed: TargetContributed,
    }

    #[derive(Drop, Serde, starknet::Event)]
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

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawal {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetCreated {
        pub target_id: u64,
        pub user: ContractAddress,
        pub goal: u256,
        pub deadline: u64,
        pub current_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetContributed {
        pub amount: u256,
        pub target_id: u64,
        pub last_updated: u64,
        pub user: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, mock_token: ContractAddress) {
        self.owner.write(owner);
        self.mock_token.write(mock_token);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn create_asset(
            ref self: ContractState,
            token_address: ContractAddress,
            amount: u256,
            token_name: felt252,
        ) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller: ContractAddress = get_caller_address();
            let contract: ContractAddress = get_contract_address();

            let existing_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(existing_asset_ref.is_none(), errors.ASSET_ALREADY_EXISTS);

            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, contract, amount);

            // Create new asset
            let new_asset = Asset { token_name, token_address, balance: amount };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));
            self.deposited_tokens.append().write(token_address);

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance + amount);

            self.emit(AssetCreated { caller, token: token_address, token_name, amount });
        }

        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Transfer tokens from user to contract
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, contract, amount);

            // Update user deposit balance
            let prev_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(prev_asset_ref.is_none(), errors.ASSET_DOES_NOT_EXIST);

            let prev_asset = prev_asset_ref.unwrap();
            let new_balance = prev_asset.balance + amount;
            assert(new_balance > prev_asset.balance, errors.AMOUNT_OVERFLOWS_BALANCE);

            let new_asset = Asset {
                token_name: prev_asset.token_name, token_address, balance: new_balance,
            };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance + amount);

            self.emit(SuccessfulDeposit { caller, token: token_address, amount });
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Check if user has the asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.ASSET_DOES_NOT_EXIST);

            let asset = asset_ref.unwrap();
            assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);

            // Update user's asset balance
            let new_balance = asset.balance - amount;
            let updated_asset = Asset {
                token_name: asset.token_name, token_address, balance: new_balance,
            };
            self
                .user_deposits
                .entry(caller)
                .entry(token_address)
                .write(Option::Some(updated_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance - amount);

            // Transfer tokens back to user
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer(caller, amount);

            self.emit(Withdrawal { caller, token: token_address, amount });
        }

        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            let caller = get_caller_address();
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();

            match asset_ref {
                Option::Some(asset) => asset.balance,
                Option::None => 0,
            }
        }
        fn create_target(ref self: ContractState, goal: u256, deadline: u64) -> u64 {
            let caller = get_caller_address();
            // get a new target id
            let mut new_target_count: u64 = self.targets_count.read() + 1;

            // assert that user can only create on target
            assert(
                self.contract_to_target_storage.entry(caller).read(), 'user already has a target'
            );
            // create a target for the user
            let new_target = Target {
                user: caller,
                goal: goal,
                deadline: deadline,
                current_amount: 0,
                created_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
                is_active: true,
            };

            self.user_targets.entry(new_target_count).write(Option::Some(new_target));
            self.targets_count.write(new_target_count);

            self.contract_to_target_storage.entry(caller).write(true);

            self
                .emit(
                    TargetCreated {
                        target_id: new_target_count,
                        user: caller,
                        goal,
                        deadline,
                        current_amount: 0,
                    },
                );

            new_target_count
        }

        fn contribute_to_target(ref self: ContractState, target_id: u64, amount: u256) {
            let errors = Errors::new();
            self.contribute_to_target_checks(target_id, amount);

            // get target and caller
            let mut target: Target = self.user_targets.entry(target_id).read().unwrap();
            let caller = get_caller_address();

            // transfer tokens from user to contract to update target
            let dispatcher = IERC20Dispatcher { contract_address: self.mock_token.read() };
            self.check_balance(dispatcher, caller, amount);
            self.check_allowance(dispatcher, caller, amount);
            dispatcher.transfer_from(caller, get_contract_address(), amount);

            // Update target's current_amount
            target.current_amount += amount;
            target.last_updated = get_block_timestamp();
            self.user_targets.entry(target_id).write(Option::Some(target));

            self
                .emit(
                    TargetContributed {
                        amount, target_id, last_updated: target.last_updated, user: caller,
                    },
                );
        }

        fn get_target(self: @ContractState, target_id: u64) -> Option<Target> {
            let target_ref = self.user_targets.entry(target_id).read();
            match target_ref {
                Option::Some(target) => Option::Some(target),
                Option::None => Option::None,
            }
        }

        fn get_target_count(self: @ContractState) -> u64 {
            self.targets_count.read()
        }
    }

    #[generate_trait]
    impl SecurityImpl of SecurityImplTrait {
        fn contribute_to_target_checks(self: @ContractState, target_id: u64, amount: u256) {
            let errors = Errors::new();
            assert(amount > 0, errors.ZERO_AMOUNT);

            // Get caller and target
            let target_ref = self.user_targets.entry(target_id).read();
            let target = target_ref.unwrap();
            let caller = get_caller_address();

            // assert target exists
            assert(target_ref.is_some(), errors.TARGET_DOES_NOT_EXIST);

            // Assert target not reached
            assert(target.current_amount < target.goal, errors.TARGET_ALREADY_REACHED);

            // assert target is active
            assert(target.is_active == true, 'Target isnt active');
            // Assert deadline not passed
            let block_timestamp = starknet::get_block_timestamp();
            assert(block_timestamp <= target.deadline, errors.TARGET_DEADLINE_PASSED);

            // Ensure contribution does not exceed the target goal
            assert(target.current_amount + amount <= target.goal, errors.AMOUNT_OVERFLOWS_GOAL);

            let target_owner = target.user;
            assert(caller == target_owner, 'Only owner contribute to target');
        }

        fn check_allowance(
            self: @ContractState,
            token_dispatcher: IERC20Dispatcher,
            caller: ContractAddress,
            amount: u256,
        ) {
            let contract_address = get_contract_address();
            let allowed_amount = token_dispatcher.allowance(caller, contract_address);
            assert(allowed_amount >= amount, 'Insufficient allowance');
        }

        fn check_balance(
            self: @ContractState,
            token_dispatcher: IERC20Dispatcher,
            caller: ContractAddress,
            amount: u256,
        ) {
            let user_balance = token_dispatcher.balance_of(caller);
            assert(user_balance >= amount, 'Insufficient balance');
        }
    }
}

