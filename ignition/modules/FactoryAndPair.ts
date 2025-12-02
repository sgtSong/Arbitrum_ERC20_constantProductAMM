import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FactoryPairModule", (m) => {
  const KITA_ADDRESS = "0x46920Db850342931A759c138c4CA920ac2B63DB7";  //KITA token deployed on Arbitrum Sepolia
  const USDC_ADDRESS = "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d";  //USDC token deployed on Arbitrum Sepolia

  const factory = m.contract("Factory");
  const createPairTx = m.call(factory, "createPair", [KITA_ADDRESS, USDC_ADDRESS]);

  const pairAddress = m.readEventArgument(createPairTx, "PairCreated", "pair");
  const pair = m.contractAt("Pair", pairAddress);

  const KITA = m.contractAt("KITAToken", KITA_ADDRESS);
  const USDC = m.contractAt("IERC20", USDC_ADDRESS);

  const amountKita = 10_000_000_000_000n * 10n ** 18n; // 10T KITA
  const amountUsdc = 100n * 10n ** 6n;                 // 100 USDC

  m.call(KITA, "approve", [pairAddress, amountKita]);
  m.call(USDC, "approve", [pairAddress, amountUsdc]);
  
  m.call(pair, "addLiquidity", [amountKita, amountUsdc]);

  return {
    factory,
    pair,
  };
});
