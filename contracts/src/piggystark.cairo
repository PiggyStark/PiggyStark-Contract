#[starknet::contract]
pub mod PiggyStark {
    use contracts::{
        interfaces::ipiggystark::IPiggyStark, 
        structs::piggystructs::Asset,
        interfaces::ierc20::IERC20Dispatcher,
        interfaces::ierc20::IERC20DispatcherTrait,

    };
    use starknet::ContractAddress;
    use core::array::ArrayTrait;
    use starknet::{ get_caller_address };
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};



    use core::traits::TryInto;
        

    #[storage]
    struct Storage {
       owner: ContractAddress,
       // Mapping from user address to the token address they deposited
        deposited_token: LegacyMap<ContractAddress, ContractAddress>,
        // Mapping from (user address, token address) to deposit amount
        deposit_values: LegacyMap<(ContractAddress, ContractAddress), u256>,
        // Flag to prevent reentrancy
       is_locked: bool,
    }

      // Events
      #[event]
      #[derive(Drop, starknet::Event)]
      pub enum Event {
        WithdrawEvent: WithdrawEvent,
      }

      #[derive(Drop, starknet::Event)]
      struct WithdrawEvent {
        user: ContractAddress,
        token: ContractAddress,
        amount: u256
      }

   
    // Constructor to set initial owner
    #[constructor]
    fn constructor(ref self: ContractState, initial_owner: ContractAddress) {
        self.owner.write(initial_owner);
        self.is_locked.write(false);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {}
        
        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
           
             // Reentrancy protection
             if self.is_locked.read() {
               panic!("Reentrancy");

            }
            self.is_locked.write(true);

            // Input validation
            assert!(amount > 0, "zero amount withdrawal");

            // Get the caller's address
            let caller = get_caller_address();

            // Authorization check 
            // Option 1: Only owner can withdraw
            let contract_owner = self.owner.read();
            assert!(caller == contract_owner, "Unauthorized");


            // Check available balance
            let current_balance = self.deposit_values.read((caller, token_address));
            assert!(current_balance >= amount, "InsufficientBalance");

            // Prepare token transfer
            let token_dispatcher = IERC20Dispatcher { 
                contract_address: token_address 
            };

            // Reduce the user's balance first
                self.deposit_values.write((caller, token_address),current_balance - amount);

                // Perform token transfer
                token_dispatcher.transfer(caller, amount);
                          
               // Emit withdrawal event if needed
                self.emit(WithdrawEvent { 
                    user: caller, 
                    token: token_address, 
                    amount 
                });

            // Release the lock
            self.is_locked.write(false);




        }

        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let mut assets = ArrayTrait::new();
            assets
        }
        fn get_token_balance(self: @ContractState, token_address: ContractAddress) {}
    }
}