const deployed = require('../deployed.json')

const mesonAddress = deployed.objectChanges.find(obj => obj.type == 'published')?.packageId
const metadata = {
  mesonAddress,
  storeG: deployed.objectChanges.find(obj => obj.objectType == `${mesonAddress}::MesonStates::GeneralStore`)?.objectId,
  adminCap: deployed.objectChanges.find(obj => obj.objectType == `${mesonAddress}::MesonStates::AdminCap`)?.objectId,
  treasuryCap: {},
}

const coins = deployed.objectChanges.filter(obj => obj.objectType?.startsWith('0x2::coin::TreasuryCap'))
  .map(obj => {
    const [_, addr] = /0x2::coin::TreasuryCap<(.*)>/.exec(obj.objectType)
    const [p, module, symbol] = addr.split('::')
    return { addr, symbol }
  })

for (const coin of coins) {
  metadata.treasuryCap[coin.symbol] = deployed.objectChanges.find(obj => obj.objectType == `0x2::coin::TreasuryCap<${coin.addr}>`)?.objectId
}

console.log(metadata)