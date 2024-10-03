1. (Relatively Stabillity) Pegged or Ancored -> $1.00; only pegged because we are not scalling the stable coin. (Would use a float to scale).
    - Chainlink price feed. (that is how we chain coin to a dollar)
    - Set a funciton to exchange BTC and ETH -> $$$(or whatever the dollar equivalent is)
2. Stability mechanism (minting): Algorithmic (NO centralized entity); on chain and algorithmic 
    - people can only mint Bitzona stablecoin with enough collateral (coded directly into the protocol)
3. Collateral: Exogenous (Crypto); use crypto as collateral
    - (only allow these two crypto currencies to be deposited)
        - wBTC (wrapped BTC/ ERC20 version of BTC)
        - wETH (wrapped ETH/ ERC20 version of ETH)
4. 

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
