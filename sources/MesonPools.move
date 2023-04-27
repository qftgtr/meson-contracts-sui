/// @title MesonPools
/// @notice The class to manage pools for LPs, and perform swap operations on the target 
/// chain side.
/// Methods in this class will be executed when a user wants to swap into this chain.
/// LP pool operations are also provided in this class.
module Meson::MesonPools {
    /* ---------------------------- Constant variables ---------------------------- */
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::tx_context::{Self, TxContext};
    use Meson::MesonHelpers;
    use Meson::MesonStates::{Self, GeneralStore, StoreForCoin};

    const EPOOL_INDEX_CANNOT_BE_ZERO: u64 = 16;
    const EPOOL_INDEX_MISMATCH: u64 = 17;
   
    const ESWAP_EXIPRE_TS_IS_SOON: u64 = 46;
    const ESWAP_STILL_IN_LOCK: u64 = 47;
    const ESWAP_PASSED_LOCK_PERIOD: u64 = 48;



    /* ---------------------------- LP functions ---------------------------- */
    // Named consistently with solidity contracts
    public entry fun depositAndRegister<CoinType>(
        amount: u64, 
        pool_index: u64,
        coin_from_sender: &mut Coin<CoinType>,
        storeG: &mut GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        ctx: &mut TxContext,
    ) {
        let sender_addr = tx_context::sender(ctx);
        MesonStates::register_pool_index(pool_index, sender_addr, storeG);
        let coins = coin::split(coin_from_sender, amount, ctx);
        MesonStates::coins_to_pool(pool_index, coins, storeC);
    }

    // Named consistently with solidity contracts
    public entry fun deposit<CoinType>(
        amount: u64, 
        pool_index: u64, 
        coin_from_sender: &mut Coin<CoinType>,
        storeG: &GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        ctx: &mut TxContext
    ) {
        let sender_addr = tx_context::sender(ctx);
        assert!(pool_index == MesonStates::pool_index_of(sender_addr, storeG), EPOOL_INDEX_MISMATCH);
        let coins = coin::split(coin_from_sender, amount, ctx);
        MesonStates::coins_to_pool(pool_index, coins, storeC);
    }

    // Named consistently with solidity contracts
    public entry fun withdraw<CoinType>(
        amount: u64, 
        pool_index: u64,
        storeG: &GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        ctx: &mut TxContext,
    ) {
        let sender_addr = tx_context::sender(ctx);
        assert!(pool_index == MesonStates::pool_index_if_owner(sender_addr, storeG), EPOOL_INDEX_MISMATCH);
        let coins = MesonStates::coins_from_pool(pool_index, amount, storeC, ctx);
        transfer::public_transfer(coins, sender_addr);
    }

    // Named consistently with solidity contracts
    public entry fun addAuthorizedAddr(
        addr: address,
        storeG: &mut GeneralStore,
        ctx: &mut TxContext,
    ) {
        let sender_addr = tx_context::sender(ctx);
        let pool_index = MesonStates::pool_index_if_owner(sender_addr, storeG);
        MesonStates::add_authorized(pool_index, addr, storeG);
    }

    // Named consistently with solidity contracts
    public entry fun removeAuthorizedAddr(
        addr: address,
        storeG: &mut GeneralStore,
        ctx: &mut TxContext,
    ) {
        let sender_addr = tx_context::sender(ctx);
        let pool_index = MesonStates::pool_index_if_owner(sender_addr, storeG);
        MesonStates::remove_authorized(pool_index, addr, storeG);
    }



    /* ---------------------------- Main functions ---------------------------- */
    // Step 2: Lock
    // Named consistently with solidity contracts
    public entry fun lock<CoinType>(
        encoded_swap: vector<u8>,
        signature: vector<u8>, // must be signed by `initiator`
        initiator: vector<u8>, // an eth address of (20 bytes), the signer to sign for release
        recipient: address,
        storeG: &mut GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        clock_object: &Clock,
        ctx: &mut TxContext,
    ) {
        MesonHelpers::is_encoded_valid(encoded_swap);
        MesonHelpers::for_target_chain(encoded_swap);
        MesonStates::match_coin_type<CoinType>(MesonHelpers::out_coin_index_from(encoded_swap), storeG);
        MesonHelpers::is_eth_addr(initiator);

        let now_seconds = clock::timestamp_ms(clock_object) / 1000;
        let until = now_seconds + MesonHelpers::get_LOCK_TIME_PERIOD();
        assert!(until < MesonHelpers::expire_ts_from(encoded_swap) - 300, ESWAP_EXIPRE_TS_IS_SOON);

        let pool_index = MesonStates::pool_index_of(tx_context::sender(ctx), storeG);
        assert!(pool_index != 0, EPOOL_INDEX_CANNOT_BE_ZERO);

        MesonHelpers::check_request_signature(encoded_swap, signature, initiator);

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let amount = MesonHelpers::amount_from(encoded_swap)- MesonHelpers::fee_for_lp(encoded_swap);

        let coins = MesonStates::coins_from_pool(pool_index, amount, storeC, ctx);
        MesonStates::coins_to_pending(swap_id, coins, storeC);

        MesonStates::add_locked_swap(swap_id, pool_index, until, recipient, storeG);
    }


    // Named consistently with solidity contracts
    public entry fun unlock<CoinType>(
        encoded_swap: vector<u8>,
        initiator: vector<u8>,
        storeG: &mut GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        clock_object: &Clock,
        // no ctx?
    ) {
        MesonHelpers::is_eth_addr(initiator);
        
        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (pool_index, until, _) = MesonStates::remove_locked_swap(swap_id, clock_object, storeG);
        let now_seconds = clock::timestamp_ms(clock_object) / 1000;
        assert!(until < now_seconds, ESWAP_STILL_IN_LOCK);

        let coins = MesonStates::coins_from_pending(swap_id, storeC);
        MesonStates::coins_to_pool(pool_index, coins, storeC);
    }


    // Step 3: Release
    // Named consistently with solidity contracts
    public entry fun release<CoinType>(
        encoded_swap: vector<u8>,
        signature: vector<u8>,
        initiator: vector<u8>,
        storeG: &mut GeneralStore,
        storeC: &mut StoreForCoin<CoinType>,
        clock_object: &Clock,
        ctx: &mut TxContext,
    ) {
        MesonHelpers::is_eth_addr(initiator);

        let waived = MesonHelpers::fee_waived(encoded_swap);
        if (waived) {
            // for fee waived swap, signer needs to be the premium manager
            MesonStates::assert_is_premium_manager(tx_context::sender(ctx), storeG);
        }; // otherwise, signer could be anyone

        let swap_id = MesonHelpers::get_swap_id(encoded_swap, initiator);
        let (_, until, recipient) = MesonStates::remove_locked_swap(swap_id, clock_object, storeG);
        let now_seconds = clock::timestamp_ms(clock_object) / 1000;
        assert!(until > now_seconds, ESWAP_PASSED_LOCK_PERIOD);

        MesonHelpers::check_release_signature(
            encoded_swap,
            MesonHelpers::eth_address_from_sui_address(recipient),
            signature,
            initiator
        );

        // Release to recipient
        let coins = MesonStates::coins_from_pending(swap_id, storeC);
        if (!waived) {
            let service_fee = coin::split(&mut coins, MesonHelpers::service_fee(encoded_swap), ctx);
            MesonStates::coins_to_pool(0, service_fee, storeC);
        };
        transfer::public_transfer(coins, recipient);
    }
}