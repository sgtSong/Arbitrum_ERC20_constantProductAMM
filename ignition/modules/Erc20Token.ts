import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Erc20Module", (m) => {
  const kitatoken = m.contract("KITAToken");

  m.call(kitatoken, "mintToOwner", [1000n * 10n ** 18n]);

  return { kitatoken };
});
