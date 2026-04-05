const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting deployment...");
  const EmergencyAudit = await hre.ethers.getContractFactory("EmergencyAudit");
  const contract = await EmergencyAudit.deploy();
  await contract.waitForDeployment();
  console.log("✅ Deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
