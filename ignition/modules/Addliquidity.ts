import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("AddingLiquidityModule", (m) => {
  // 
  // You do not need to run this script if you succeed running "FactoryAndPair.ts"
  // This Script is only for adding liquidity separately from deploying Factory and getting approval
  //

  const PAIR_ADDRESS = "0x7FeDB8a2fb5b8Bf4C4a0B6414eb5E4362A03D290"; // Pair Contract Address
  const pair = m.contractAt("Pair", PAIR_ADDRESS);

  const amountKita = 5_000_000_000_000n * 10n ** 18n; // 5T KITA
  const amountUsdc = 50n * 10n ** 6n;                 // 50 USDC
  
  m.call(pair, "addLiquidity", [amountKita, amountUsdc]);

  return { pair };
});
