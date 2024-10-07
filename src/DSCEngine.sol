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
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__MintFailed();

     //////////////
    // State Variables //
    //////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100; 
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10; // Get assets at a 10% when liquidating

    mapping(address token => address priceFeeds) private s_priceFeeds;// tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))  private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////
    // Events   //
    //////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // If
        // redeemFrom != redeemedTo, then it was liquidated

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
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //////////////
    // External Functions //
    //////////////

    /*
    * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing 
    * @param amountCollateral: The amount of collateral you're depositing
    * @param amountDscToMint: The amount to DSC you want to mint
    * @notice This funciton will deposit your collateral to mint DSC in one transaction
    */ 
    function depositCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
    * @notice follows CEI
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to desposit
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) isAllowedToken (tokenCollateralAddress) {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address
        (this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /* 
    * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
    * @param amountCollateral: The amount of collateral you're redeeming 
    * @notice This funciton will redeem you collateral 
    * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
    */

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
    * @notice careful! You'll burn your DSC here! Make sure you want to do this...
    * @dev you might want to use this is you are nervous you might get liquidated and just want to burn
    * use DSC but keep your collateral in
    */ 

    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }
        // If covering $100 USD, we need $100 of collateral 
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And if we give them a 10% bonus 
        // we give the liquidator $110 of WETH for 100 DSC
        // we should impliment a feature to liquidate in the event the protocol is insolvent 
        // We should sweep extra amount into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn DSC equal to debtToCover
        // Figure out how much collateral to recover based on how much is burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case 
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        } 
        revertIfHealthFactorIsBroken(msg.sender);
    }

    // check collateral amount > DSC amount
    /*
    * @notice follows CEI
    * @param amountDSCToMint the amount of decentralized stable coin to mint
    * @notice they must have more collateral value than the minimum threshold 
    */
   
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint){
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they mint to much ($150 DSC, $100 ETH)
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }
    }

    /*
    * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming 
    * @param amountCollateral: The amount of collateral you're redeeming
    * @notice This function will redeem your collateral 
    * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
    */

    function getHealthFactor() external view {}

     /////////////////////
    // Private Function //
    //////////////////////

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This position is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    //////////////////////////////////////
    // Private & Internal View Function //
    /////////////////////////////////////
    function _getAccountInformation (address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
    * Returns how close a user gets to liquidation 
    * If a user goes below 1, then they can get liquidated
    */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // return (collateralValueInUsd / totalDscMinted);
    }

    function _getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $4000
        // the returned value from CL will be 4000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function revertIfHealthFactorIsBroken(address user) internal view{
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if they don't
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////////////
    // Private & Internal View Function //
    /////////////////////////////////////

        // loop through each collateral token, get the amount they have deposited, and map it to 
        // the price, to get USD value
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // $100e18 USD Debt 
        // 1 ETH = $2000 USD
        // The return value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we just predent they all do
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }
}