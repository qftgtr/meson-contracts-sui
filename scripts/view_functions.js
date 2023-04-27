const dotenv = require('dotenv')
const { Connection, JsonRpcProvider } = require('@mysten/sui.js')

const { get_metadata } = require('./get_metadata')
dotenv.config()

const {
  SUI_NODE_URL,
  SUI_FAUCET_URL,
  DEPLOY_DIGEST,
} = process.env

main()

async function main() {
  const connection = new Connection({ fullnode: SUI_NODE_URL, faucet: SUI_FAUCET_URL })
  const provider = new JsonRpcProvider(connection)

  const metadata = {
    ...await get_metadata(DEPLOY_DIGEST),
    storeC: {
      USDC: '0x009bc7a4d710535342c3549d6e74ca7313b7a92b99f42ffb87b3fe83efece30d',
      USDT: '0xef41108ef7c8832bee9898dbecbd17d83e25e31d4985f646661e350b1f3afc86',
    }
  }

  console.log("\ngetPostedSwap (Specified, expected failed): ")
  console.log(await getPostedSwap(
    provider, metadata, '0x00004c4b408000000000008308cf870000000000006447518003100103100200'
  ))
}


function arrayToHex(u8ar) {
  return '0x' + u8ar.map(byte => byte.toString(16).padStart(2, '0')).join('')
}



async function getLockedSwap(provider, metadata, swapId) {
  const locked_swaps_raw = (await provider.getDynamicFields({
    parentId: metadata.storeG_content.locked_swaps.fields.id.id
  })).data

  try {
    const locked_key = locked_swaps_raw.filter(
      locked_raw => arrayToHex(locked_raw.name.value.slice(1)) == swapId
    )[0]
    const locked_value = (await provider.getObject(
      { id: locked_key.objectId, options: { showContent: true } }
    )).data.content.fields.value.fields
    return locked_value
  }
  catch (err) {
    console.log(`SwapId ${swapId} value not exists!`)
  }
}     // Haven't test!

