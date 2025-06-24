#[starknet::contract]
mod STARKTOKEN {
    use openzeppelin::token::erc20::ERC20;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, initial_supply: u256, recipient: ContractAddress, decimals: u8,
    ) {
        let name: felt252 = 'Stark Token';
        let symbol: felt252 = 'STK';
        ERC20::ERC20_constructor(ref self, name, symbol, decimals);
        ERC20::_mint(ref self, recipient, initial_supply);
    }

    #[external(v0)]
    impl STARKTOKENImpl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            ERC20::name(self)
        }

        fn symbol(self: @ContractState) -> felt252 {
            ERC20::symbol(self)
        }

        fn decimals(self: @ContractState) -> u8 {
            ERC20::decimals(self)
        }

        fn total_supply(self: @ContractState) -> u256 {
            ERC20::total_supply(self)
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            ERC20::balance_of(self, account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            ERC20::allowance(self, owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            ERC20::transfer(ref self, recipient, amount)
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            ERC20::transfer_from(ref self, sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            ERC20::approve(ref self, spender, amount)
        }
    }
}
