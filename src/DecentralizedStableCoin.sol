// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";


/*
* @title DecentralizedStableCoin
* @author Jacob Blemaster
* Collateral: Exogenous (ETH & BTC)
* Minitng: Algorithmic
* Relative Stability: Pegged to USD
* 
* This is the contract meant to be governed by DSCEngine. This contract is just the ERC20
implementation of our tablecoin system
*
*/

contract DecentralizedStableCoin {
    constructor() {}
}