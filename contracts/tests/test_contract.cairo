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

fn TOKEN_ZERO() -> ContractAddress {
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
    let event = contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
    assert(event.caller == owner, 'Caller address mismatch');
    assert(event.token == erc20_address, 'Token address mismatch');
    assert(event.amount == amount, 'Token amount mismatch');
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_insoficient_deposit_allowance() {
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
    let event = contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    assert(event.caller == owner, 'Caller address mismatch');
    assert(event.token == erc20_address, 'Token address mismatch');
    assert(event.amount == amount, 'Token amount mismatch');

        // deposit token 2
    let event = contract.deposit(erc20_address, amount2);
    assert(event.caller == owner, 'Caller address mismatch');
    assert(event.token == erc20_address, 'Token address mismatch');
    assert(event.amount == amount2, 'Token amount mismatch');

        // deposit token 3
    let event = contract.deposit(erc20_address, amount2);
    assert(event.caller == owner, 'Caller address mismatch');
    assert(event.token == erc20_address, 'Token address mismatch');
    assert(event.amount == amount2, 'Token amount mismatch');
    stop_cheat_caller_address(contract.contract_address);
}