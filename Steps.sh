# Sui Client doc: https://docs.sui.io/devnet/build/cli-client

# 1 Create new package and a source file
sui move new my_first_package
touch my_first_package/sources/my_module.move

# 2 Build a package, test a package
sui move build --skip-fetch-latest-git-deps
sui move test --skip-fetch-latest-git-deps

# 3.1 Request faucet
sui client addresses            # 
sui client active-address       # show your using address
curl --location --request POST 'https://faucet.devnet.sui.io/gas' \
--header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "0x29e30b919b77fbc03fa3220c91acfbf95cf3c24e817eddd0685d45a443bceb9f"
    }
}'

# 3.2 Publish a module
sui client publish --gas-budget 1000    # or `sui console` to enter interactive shell