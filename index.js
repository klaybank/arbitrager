const Caver = require('caver-js')
const BigNumber = require("bignumber.js");

const IKIP7ABI = require('./build/contracts/IKIP7.json');
const IKlayswapProtocolABI = require('./build/contracts/IKlaySwapProtocol.json');
const IKlayswapExchangeABI = require('./build/contracts/IKlaySwapExchange.json');
const IClaimSwapRouterABI = require('./build/contracts/IClaimSwapRouter.json');
const ArbitragerABI = require('./build/contracts/Arbitrager.json')

const KETHAddress = "0x34d21b1e550d73cee41151c77f3c73359527a396"
const KUSDTAddress = "0xcee8faf64bb97a73bb51e115aa89c17ffa8dd167"
const KlayswapFactoryAddress = "0xc6a2ad8cc6e4a7e08fc37cc5954be07d499e7654"
const ClaimSwapRouterAddress = "0xEf71750C100f7918d6Ded239Ff1CF09E81dEA92D"
const Klayswap_KUSDT_KETH_ExchangeAddress = "0x029e2a1b2bb91b66bd25027e1c211e5628dbcb93"
const ArbitragerAddress = "0x029e2a1b2bb91b66bd25027e1c211e5628dbcb93"

const tryKUSDTAmount = new BigNumber("10000" + "000000") // 10000 KUSDT

const caver = new Caver(new Caver.providers.WebsocketProvider("wss://public-node-api.klaytnapi.com/v1/cypress/ws"));
const KUSDTContract = new caver.klay.Contract(IKIP7ABI, KUSDTAddress)
const KETHContract = new caver.klay.Contract(IKIP7ABI, KETHAddress)
const klayswapFactoryContract = new caver.klay.Contract(IKlayswapProtocolABI, KlayswapFactoryAddress)
const klayswap_USDT_ETH_ExchangeContract = new caver.klay.Contract(IKlayswapExchangeABI, Klayswap_KUSDT_KETH_ExchangeAddress)
const claimSwapRouterContract = new caver.klay.Contract(IClaimSwapRouterABI, ClaimSwapRouterAddress)
const arbitragerContract = new caver.klay.Contract(ArbitragerABI, ArbitragerAddress)

const keyring = caver.wallet.keyring.createFromPrivateKey('Input your private key here')
caver.wallet.add(keyring)
caver.klay.accounts.wallet.add(
    caver.klay.accounts.createWithAccountKey(keyring.address, keyring.key.privateKey))


const subscription = caver.rpc.klay.subscribe(
    'newBlockHeaders',
    async (error, result) => {
        if (error) {
            console.error(error);
            return;
        }

        let estimateUsdtToETHKlayswap = await klayswap_USDT_ETH_ExchangeContract.methods.estimatePos(KUSDTAddress, tryKUSDTAmount).call();
        let estimateETHToUsdtClaimSwap = (await claimSwapRouterContract.methods.getAmountsOut(estimateUsdtToETHKlayswap, [KETHAddress, KUSDTAddress]).call())[1]
        let KlayswapToClaimRes = new BigNumber(estimateETHToUsdtClaimSwap)
        console.log(`diff1 : ${KlayswapToClaimRes.toString()}`)
        if (KlayswapToClaimRes.isGreaterThan(tryKUSDTAmount)) {
            let txRes = await arbitragerContract.methods.swapKlaySwapToClaimSwap(KUSDTAddress, KETHAddress, tryKUSDTAmount).send(
                {
                    from: keyring.address,
                    gas: 5000000
                }
            )
            console.log(`try arbitrage klayswap -> claimSwap tx : ` + txRes.hash)
        }


        let estimateUsdtToETHClaimSwap = (await claimSwapRouterContract.methods.getAmountsOut(tryKUSDTAmount, [KUSDTAddress, KETHAddress]).call())[1];
        let estimateETHToUsdtKlayswap = await klayswap_USDT_ETH_ExchangeContract.methods.estimatePos(KETHAddress, estimateUsdtToETHClaimSwap).call()
        let ClaimSwapToKlayswapRes = new BigNumber(estimateETHToUsdtKlayswap)
        console.log(`diff2 : ${ClaimSwapToKlayswapRes.toString()}`)
        if (ClaimSwapToKlayswapRes.isGreaterThan(tryKUSDTAmount)) {
            let txRes = await arbitragerContract.methods.swapClaimSwapToKlaySwap(KUSDTAddress, KETHAddress, tryKUSDTAmount).send(
                {
                    from: keyring.address,
                    gas: 5000000
                }
            )
            console.log(`try arbitrage claimSwap -> klayswap tx : ` + txRes.hash)
        }


    })
    .on('connected', console.log)
    .on('error', console.error);





