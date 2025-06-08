#[starknet::contract]
pub mod PiggyStark {
    use piggystark::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use piggystark::interfaces::ipiggystark::IPiggyStark;
    use piggystark::structs::piggystructs::{Asset, LockedSavings};
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
        user_deposits: Map<ContractAddress, Map<ContractAddress, Option<Asset>>>, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
        balance: Map<ContractAddress, u256>, // Track total balance per token
        locks_count: u64,
        user_locks: Map::<(ContractAddress, u64), bool>, // Maps user addresses to locks by ID
        locks: Map::<u64, LockedSavings>, // Maps lock IDs to LockedSavings
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
        AssetCreated: AssetCreated,
        Withdrawal: Withdrawal,
        Locked: Locked,
        Unlocked: Unlocked,
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

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Locked {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub lock_id: u64,
        pub lock_duration: u64,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Unlocked {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub lock_id: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.locks_count.write(0);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn create_asset(ref self: ContractState, token_address: ContractAddress, amount: u256, token_name: felt252) {
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
            // self.deposited_tokens.push(token_address);
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
            // assert(prev_asset_ref.is_none(), errors.ASSET_DOES_NOT_EXIST);
            assert(prev_asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);

            let prev_asset = prev_asset_ref.unwrap();
            let new_balance = prev_asset.balance + amount;
            assert(new_balance > prev_asset.balance, errors.AMOUNT_OVERFLOWS_BALANCE);

            let new_asset = Asset { token_name: prev_asset.token_name, token_address, balance: new_balance };
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

            assert(!caller.is_zero(), errors.ZERO_ADDRESS_CALLER); 

            // Check if user has the asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.ASSET_DOES_NOT_EXIST);

            let asset = asset_ref.unwrap();
            assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);

            // Update user's asset balance
            let new_balance = asset.balance - amount;
            let updated_asset = Asset { token_name: asset.token_name, token_address, balance: new_balance };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(updated_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance - amount);

            // Transfer tokens back to user
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer(caller, amount);

            self.emit(Withdrawal { caller, token: token_address, amount });
        }

        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            let errors = Errors::new();
            let caller = get_caller_address();
            assert(!caller.is_zero(), errors.CALLED_WITH_ZERO_ADDRESS);
            
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);
            match asset_ref {
                Option::Some(asset) => asset.balance,
                Option::None => 0
            }
        }

        fn lock_savings(ref self: ContractState, token_address: ContractAddress, amount: u256, lock_duration: u64) -> u64 {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);
            assert(lock_duration > 0, 'Lock duration must be positive');

            let caller = get_caller_address();
            assert(!caller.is_zero(), errors.ZERO_ADDRESS_CALLER);

            // Check if user has sufficient balance
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.ASSET_DOES_NOT_EXIST);

            let asset = asset_ref.unwrap();
            assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);

            // Create new lock
            let lock_id = self.locks_count.read() + 1;
            self.locks_count.write(lock_id);

            let current_time = get_block_timestamp();
            let new_lock = LockedSavings {
                id: lock_id,
                owner: caller,
                token_address,
                amount,
                lock_duration,
                lock_timestamp: current_time,
                active: true,
            };

            // Store the lock
            self.locks.entry(lock_id).write(new_lock);
            self.user_locks.entry((caller, lock_id)).write(true);

            // Update user's asset balance
            let new_balance = asset.balance - amount;
            let updated_asset = Asset { token_name: asset.token_name, token_address, balance: new_balance };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(updated_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance - amount);

            // Emit event
            self.emit(Locked { caller, token: token_address, amount, lock_id, lock_duration });

            lock_id
        }

        fn unlock_savings(ref self: ContractState, token_address: ContractAddress, lock_id: u64) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(lock_id > 0, errors.ZERO_LOCK_ID);

            let caller = get_caller_address();
            assert(!caller.is_zero(), errors.ZERO_ADDRESS_CALLER);

            // Check if lock exists and belongs to caller
            let mut lock = self.locks.entry(lock_id).read();
            assert(lock.active, 'Inactive lock');
            assert(lock.owner == caller, 'Not lock owner');
            assert(lock.token_address == token_address, 'Token address mismatch');

            // Check if lock duration has passed
            let current_time = get_block_timestamp();
            assert(current_time >= lock.lock_timestamp + lock.lock_duration, 'Lock duration not passed');

            // Get user's asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.ASSET_DOES_NOT_EXIST);

            let asset = asset_ref.unwrap();

            // Update user's asset balance
            let new_balance = asset.balance + lock.amount;
            let updated_asset = Asset { token_name: asset.token_name, token_address, balance: new_balance };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(updated_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance + lock.amount);

            // Deactivate lock
            lock.active = false;
            self.locks.entry(lock_id).write(lock);

            // Remove from user's locks
            self.user_locks.entry((caller, lock_id)).write(false);

            // Emit event
            self.emit(Unlocked { caller, token: token_address, amount: lock.amount, lock_id });
        }

        fn get_locked_balance(self: @ContractState, user: ContractAddress, token_address: ContractAddress, lock_id: u64) -> (u256, u64) {
            let errors = Errors::new();
            assert(user.is_non_zero(), errors.ZERO_USER_ADDRESS);
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(lock_id > 0, errors.ZERO_LOCK_ID);

            let lock = self.locks.entry(lock_id).read();
            if !lock.active || lock.owner != user || lock.token_address != token_address {
                return (0, 0);
            }

            (lock.amount, lock.lock_timestamp + lock.lock_duration)
        }
    }
}
            