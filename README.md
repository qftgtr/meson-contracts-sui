# meson-contracts-sui

### Steps for deployment

1. Run `yarn`.
2. Copy and paste a private key to `.env` after `PRIVATE_KEY=`.
3. Run `yarn wallet` to prepare a wallet. Uncomment `SUI_FAUCET_URL` if wish to use the faucet.
4. Run `yarn build` or `yarn test` to build or test.
5. Run `yarn deploy` for deployment. Metadata will be printed.
6. Update metadata in `@mesonfi/presets`.

### Steps for initialization

1. Run `yarn initialize` to add supported tokens to Meson's contract.
2. (Testnet only) Run `yarn mint` to mint tokens.
3. Register a pool or add tokens to the pool using the script in `meson-contracts-solidity`

### Perform a swap

1. Just run `yarn swap`.
