import { ethers } from "ethers";
import fs from "fs";

async function main() {
  // 1. Connect directly to your local Hardhat node
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

  // 2. Use the first Hardhat account (Private Key #0)
  const wallet = new ethers.Wallet(
    "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    provider,
  );

  console.log("🚀 Deploying with account:", wallet.address);

  // 3. Load the Compiled Contract Artifact
  // Hardhat saves these in the 'artifacts' folder after you run 'npx hardhat compile'
  const artifactPath =
    "./artifacts/contracts/EmergencyAudit.sol/EmergencyAudit.json";
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  // 4. Create Factory and Deploy
  const factory = new ethers.ContractFactory(
    artifact.abi,
    artifact.bytecode,
    wallet,
  );

  console.log("📡 Sending deployment transaction...");
  const contract = await factory.deploy();

  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log("---");
  console.log("✅ EmergencyAudit deployed to:", address);
  console.log("---");
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
});
