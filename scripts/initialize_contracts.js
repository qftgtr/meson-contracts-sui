const dotenv = require('dotenv')
const fs = require('fs')
const path = require('path')
const { fromB64 } = require('@mysten/sui.js')
const { utils } = require('ethers')
const { adaptors } = require('@mesonfi/sdk')
const presets = require('@mesonfi/presets').default

const testnetMode = true
const networkId = testnetMode ? 'sui-testnet' : 'sui'
presets.useTestnet(testnetMode)

dotenv.config()

initialize()

async function initialize() {
  const keystore = fs.readFileSync(path.join(__dirname, '../.sui/sui.keystore'))
  const privateKey = utils.hexlify(fromB64(JSON.parse(keystore)[0])).replace('0x01', '0x')

  const network = presets.getNetwork(networkId)
  const client = presets.createNetworkClient(networkId, [network.url])
  const wallet = adaptors.getWallet(privateKey, client)
  const mesonClient = presets.createMesonClient(networkId, wallet)

  // add supported tokens
  const storeC = {}
  for (const coin of network.tokens) {
    console.log(`addSupportToken (${coin.symbol})`)
    const tx = await mesonClient.mesonInstance.addSupportToken(coin.addr, coin.tokenIndex)
    const addTx = await tx.wait()

    storeC[coin.tokenIndex.toString()] = addTx.changes.find(obj => obj.objectType.includes('StoreForCoin'))?.objectId
  }
  console.log('storeC', storeC)

  // const premiumRecipient = ''
  // const txBlock = new TransactionBlock()
  // const payload = {
  //   function: `0x2::transfer::transfer`,
  //   typeArguments: [`${mesonAddress}::MesonStates::AdminCap`],
  //   arguments: [
  //     txBlock.object(metadata.adminCap),
  //     txBlock.txn(premiumRecipient),
  //   ],
  // }
  // txBlock.moveCall(payload)
  // const tx = await wallet.sendTransaction(txBlock)
  // console.log(`TransferPremiumManager: ${tx.hash}`)
  // await tx.wait()
}
