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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DSCEngine
 * @author Jacob Blemaster
 * 
 * The system is designed to be as minimal as possiblem and have the tokens maintain a 1
 token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 * 
 * It is similar to DAI if DAI has no governance, no fees, and was only backed by wETH and wBTC
 * 
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 all collateral <= the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the DSC System. It handles all the logic for mining
 and redeeming DSC, as well as depositing & withdraling collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) System.
 */
 
contract DSCEngine{
    //////////////
    // Errors //
    //////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();

     //////////////
    // State Variables //
    //////////////
    mapping(address token => address priceFeeds) private s_priceFeeds;// tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////
    // Events   //
    //////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    //////////////
    // Modifiers //
    //////////////
    modifier moreThanZero(uint256 amount) {
        if(amount == 0){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token){
        if(s_priceFeeds[token] == address(0)) {
                revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    //////////////
    // Funnctions //
    //////////////
    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        // USD Price Feeds
        if(tokenAddresses.length != priceFeedAddresses.length){
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint i = 0; i< tokenAddresses.length; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //////////////
    // External Functions //
    //////////////
    function depositCollateralAndMintDsc() external {}

    /*
    * @notice follows CEI
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to desposit
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) 
        external 
        moreThanZero(amountCollateral) 
        isAllowedToken (tokenCollateralAddress) 
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address
        (this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDSC() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}


}