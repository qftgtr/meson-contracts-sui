const fs = require('fs')
const path = require('path')
const { fromB64 } = require('@mysten/sui.js')
const { utils } = require('ethers')
const { adaptors } = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default

const networkId = 'sui-testnet'
presets.useTestnet(true)

mint('1000000')

async function mint(amount, to) {
  const keystore = fs.readFileSync(path.join(__dirname, '../.sui/sui.keystore'))
  const privateKey = utils.hexlify(fromB64(JSON.parse(keystore)[0])).replace('0x01', '0x')

  const network = presets.getNetwork(networkId)
  const client = presets.createNetworkClient(networkId, [network.url])
  const wallet = adaptors.getWallet(privateKey, client)
  const mesonClient = presets.createMesonClient(networkId, wallet)
  const mintTo = to || wallet.address

  let coinObjectList = {}
  for (const coin of network.tokens) {
    const coinContract = mesonClient.getTokenContract(coin.addr)

    const name = await coinContract.name()
    const symbol = await coinContract.symbol()
    const decimals = await coinContract.decimals()

    console.log(`Mint ${amount} ${symbol} to ${mintTo}...`)

    const tx = await mesonClient.mesonInstance.call(
      '0x2::coin::mint_and_transfer',
      ({ txBlock, metadata }) => ({
        arguments: [
          txBlock.object(metadata.treasuryCap[coin.tokenIndex.toString()]),
          txBlock.pure(utils.parseUnits(amount, decimals)),
          txBlock.pure(mintTo)
        ],
        typeArguments: [coin.addr],
      })
    )
    const minted = await tx.wait()
    
    const coinObject = minted.changes.find(obj => obj.type == 'created')?.objectId
    console.log(`Minted. Object created:`, coinObject)

    console.log(`Current balance:`, utils.formatUnits(await coinContract.balanceOf(mintTo), decimals), symbol)
    coinObjectList[symbol] = coinObject
  }

  return coinObjectList
}