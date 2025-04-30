use contracts::contractss::piggystark;
use contracts::interfaces::ipiggystark::{IPiggyStarkDispatcher, IPiggyStarkDispatcherTrait};
use core::traits::{Into, TryInto};

use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address, CheatSpan,
};
use starknet::{ContractAddress, contract_address_const};

fn setup(owner: ContractAddress) -> (IPiggyStarkDispatcher, ContractAddress) {
    // token recipient address constant
    //let TOKEN_RECIEPIENT: ContractAddress = contract_address_const::<'123'>();
    // Deploy mock ERC20
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 18];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    let contract_class = declare("PiggyStark").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address };
    (dispatcher, erc20_address)
}

// Utility functions to create test contract addresses from a felt
fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn NON_OWNER() -> ContractAddress {
    contract_address_const::<'NON_OWNER'>()
}

fn TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<'TOKEN_ADRESS'>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

#[test]
fn test_successful_deposit() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // deposit token
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_zero_token_deposit() {
    // Setup addresses
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);
    // A zero amount deposit should panic
    start_cheat_caller_address(contract.contract_address, owner);
    contract.deposit(erc20_address, 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_insufficient_deposit_allowance() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, 100_000_000_000_000_000_000_000);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // shoulp panic with insufficient allowance
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_deposit() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let amount2: u256 = 200_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // deposit token 1
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);

    // deposit token 2
    contract.deposit(erc20_address, amount2);

    // deposit token 3
    contract.deposit(erc20_address, amount2);
    stop_cheat_caller_address(contract.contract_address);
}

// withdraw
#[test]
fn test_successful_withdraw() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // withdraw token
    contract.deposit(erc20_address, amount);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_multiple_withdraw() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // withdraw token
    contract.deposit(erc20_address, amount);
    contract.withdraw(erc20_address, 345);
    contract.withdraw(erc20_address, 500_000);
    contract.withdraw(erc20_address, 100_000_000);
    contract.withdraw(erc20_address, 400);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount overflows balance')]
fn test_balance_overflow_multiple_withdraw() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // withdraw token
    contract.deposit(erc20_address, amount);
    contract.withdraw(erc20_address, amount);
    contract.withdraw(erc20_address, 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Asset does not exist')]
fn test_withdraw_from_non_existing_user_token() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // withdraw token from non exiting assest
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_withdraw_from_Zero_caller_address() {
    // Setup addresses
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let zero_address = ZERO();

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    //zero aaddress caller will panic
    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

//get_token_balance
#[test]
fn test_get_token_balance() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // deposit token
    contract.deposit(erc20_address, amount);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
    assert(token_balance == amount, 'incorrect balance');
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_get_token_balance_for_none_exixt_user_token() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    //none existing token address will panic
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_get_token_balance_from_Zero_caller_address() {
    // Setup addresses
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let zero_address = ZERO();

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    //zero aaddress caller will panic
    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

//get_user_assets
#[test]
fn test_get_user_assets() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    //get caller tokens
    contract.deposit(erc20_address, amount);
    let user_assets = contract.get_user_assets();
    stop_cheat_caller_address(contract.contract_address);
    assert(user_assets.len() > 0, 'no token availabe')
}

#[test]
#[should_panic(expected: 'no token availabe')]
fn test_get_user_assets_no_token() {
    // Setup addresses
    let owner = OWNER();
    // let token_address = TOKEN_ADDRESS();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Deploy contract
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // A non zero address deposit tokens
    start_cheat_caller_address(erc20_address, owner);
    // allow contract to spend
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    // get tokens without any any availabe token should panic
    contract.get_user_assets();
    stop_cheat_caller_address(contract.contract_address);
}
