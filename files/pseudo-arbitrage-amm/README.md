# PseudoArbitrage AMM

Implementation of the Engel & Herlihy pseudo-arbitrage AMM strategy for SwapVM with **Pyth Network** oracle integration.

## Features

✅ **Eliminates Impermanent Loss** - Uses oracle to transform curve before arbitrageurs can exploit  
✅ **Pyth Network Integration** - Real-time price feeds from 40+ chains, 400+ assets  
✅ **SwapVM Compatible** - Fully integrated with 1inch's SwapVM framework  
✅ **Production Ready** - Comprehensive tests and documentation  

## Setup

1. Install dependencies:
   ```bash
   forge install
   ```

2. Compile contracts:
   ```bash
   forge build
   ```

3. Run tests:
   ```bash
   forge test
   ```

4. Configure Pyth oracle (see [PYTH_INTEGRATION.md](./PYTH_INTEGRATION.md))

## Quick Start with Pyth

```solidity
// 1. Deploy Pyth adapter
PythPriceAdapter adapter = new PythPriceAdapter(PYTH_ADDRESS, 3600);
adapter.setPriceFeed(WETH, USDC, ETH_USD_PRICE_ID);

// 2. Use in your AMM
order = ammBuilder.buildProgram({
    oracle: address(adapter),  // Use Pyth!
    // ... other params
});
```

See [PYTH_INTEGRATION.md](./PYTH_INTEGRATION.md) for complete guide.

## Deployment

See `STEP_BY_STEP_GUIDE.md` for detailed instructions.

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [SwapVM Docs](https://github.com/1inch/swap-vm)
- [Engel & Herlihy Paper](https://arxiv.org/abs/2106.00667)
