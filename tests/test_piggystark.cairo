use piggystark::interfaces::ipiggystark::{IPiggyStarkDispatcher, IPiggyStarkDispatcherTrait};
use core::traits::{Into, TryInto};

use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

fn setup(owner: ContractAddress) -> (IPiggyStarkDispatcher, ContractAddress) {
    // Deploy mock ERC20
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 18];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    let contract_class = declare("PiggyStark").unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![owner.into(), erc20_address.into()])
        .unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address };
    (dispatcher, erc20_address)
}

// Utility functions
fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn NON_OWNER() -> ContractAddress {
    contract_address_const::<'NON_OWNER'>()
}

fn USER1() -> ContractAddress {
    contract_address_const::<'USER1'>()
}

fn TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<'TOKEN_ADRESS'>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ERRORS() -> piggystark::errors::piggystark_errors::Errors::Errors {
    piggystark::errors::piggystark_errors::Errors::new()
}

#[test]
fn test_successful_create_asset() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, amount, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_zero_token_address_create_asset() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(zero_address, amount, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_zero_amount_create_asset() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 0, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Asset already exists')]
fn test_asset_existance_create_asset() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, token_name);
    contract.create_asset(erc20_address, 100, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_none_existing_token_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_zero_token_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_insufficient_deposit_allowance() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let amount2: u256 = 200_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.deposit(erc20_address, amount2);
    contract.deposit(erc20_address, amount2);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, amount, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.withdraw(erc20_address, amount + 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.withdraw(erc20_address, 345);
    contract.withdraw(erc20_address, 500_000);
    contract.withdraw(erc20_address, 100_000_000);
    contract.withdraw(erc20_address, 400);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount overflows balance')]
fn test_balance_overflow_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.withdraw(erc20_address, amount);
    contract.withdraw(erc20_address, 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Asset does not exist')]
fn test_withdraw_from_non_existing_user_token() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_withdraw_from_Zero_caller_address() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_token_balance() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, amount);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
    assert(token_balance >= amount, ERRORS().INCORRECT_BALANCE);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_get_token_balance_for_none_exixt_user_token() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_get_token_balance_from_Zero_caller_address() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_target_test_successful_create_target() {
    let owner = OWNER();
    let (contract, _) = setup(owner);

    let deadline = 0x2137_u64;
    start_cheat_caller_address(contract.contract_address, USER1().into());
    let new_target = contract.create_target(200, deadline);
    stop_cheat_caller_address(contract.contract_address);
    let target_count: u64 = contract.get_target_count();
    let target = contract.get_target(new_target);
    assert(new_target == 1, 'New target not created');
    assert(target_count == 1, 'Incorrect target count');
    assert(target.is_some(), 'target not added');
}
#[test]
#[should_panic(expected: 'user already has a target')]
fn test_target_test_user_already_has_target_create_target() {
    let owner = OWNER();
    let (contract, _) = setup(owner);

    let deadline = 0x2137_u64;
    let user1 = USER1().into();

    start_cheat_caller_address(contract.contract_address, user1);
    let _ = contract.create_target(200, deadline);
    // Attempt to create a second target for the same user, should panic
    let _ = contract.create_target(300, deadline + 1000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_target_contribute_to_target_function() {
    let owner = OWNER();
    let (contract, token_addr) = setup(owner);
    let dispatcher = IERC20Dispatcher { contract_address: token_addr };

    let deadline = 0x2137_u64;
    let user1: ContractAddress = USER1().into();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    // Print balances before transfer
    let owner_balance_before = dispatcher.balance_of(owner);
    let user1_balance_before = dispatcher.balance_of(user1);
    println!("Owner balance before: {}", owner_balance_before);
    println!("User1 balance before: {}", user1_balance_before);

    // cheat caller address and send tokens to user 1
    start_cheat_caller_address(token_addr, owner);
    dispatcher.transfer(user1, 200);
    stop_cheat_caller_address(token_addr);

    // Print balances after transfer
    let owner_balance_after = dispatcher.balance_of(owner);
    let user1_balance_after = dispatcher.balance_of(user1);
    println!("Owner balance after: {}", owner_balance_after);
    println!("User1 balance after: {}", user1_balance_after);

    start_cheat_caller_address(contract.contract_address, user1);
    let new_target = contract.create_target(200, deadline);
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(token_addr, owner);
    dispatcher.transfer(user1, 200);
    stop_cheat_caller_address(token_addr);

    start_cheat_caller_address(token_addr, user1);
    dispatcher.approve(contract.contract_address, amount);
    stop_cheat_caller_address(token_addr);

    start_cheat_caller_address(contract.contract_address, user1);
    contract.contribute_to_target(new_target, 20);
    stop_cheat_caller_address(contract.contract_address);

    let target_after = contract.get_target(new_target);
    let user1_token_balance = dispatcher.balance_of(user1);
    
    // Check that the target exists and was updated
    assert(target_after.is_some(), 'Target should exist');
    let target_data = target_after.unwrap();
    assert(target_data.current_amount == 20, 'Target contribution not updated');
    assert(target_data.last_updated == deadline, 'last_updated not correct');

    // Check that the user's ERC20 balance decreased by the contributed amount
    let expected_balance = user1_balance_after - 20;
    assert(user1_token_balance == expected_balance, 'User1 token balance not updated');
}

// #[test]
// fn test_get_user_assets() {
//     let owner = OWNER();
//     let amount: u256 = 200_000_000_000_000_000_000_000;

//     let (contract, erc20_address) = setup(owner);
//     let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

//     start_cheat_caller_address(erc20_address, owner);
//     token_dispatcher.approve(contract.contract_address, amount);
//     token_dispatcher.allowance(owner, contract.contract_address);
//     stop_cheat_caller_address(erc20_address);

//     start_cheat_caller_address(contract.contract_address, owner);
//     contract.create_asset(erc20_address, 300, 'STRK');
//     let user_assets = contract.get_user_assets();
//     stop_cheat_caller_address(contract.contract_address);
//     assert(user_assets.len() > 0, ERRORS().NO_TOKENS_AVAILABLE);
// }

// #[test]
// fn test_get_user_assets_no_token() {
//     let owner = OWNER();
//     let amount: u256 = 200_000_000_000_000_000_000_000;

//     let (contract, erc20_address) = setup(owner);
//     let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

//     start_cheat_caller_address(erc20_address, owner);
//     token_dispatcher.approve(contract.contract_address, amount);
//     token_dispatcher.allowance(owner, contract.contract_address);
//     stop_cheat_caller_address(erc20_address);

//     start_cheat_caller_address(contract.contract_address, owner);
//     let user_assets = contract.get_user_assets();
//     stop_cheat_caller_address(contract.contract_address);
//     assert(user_assets.len() == 0, ERRORS().SHOULD_HAVE_NO_TOKENS);
// }


