import { ethers } from "ethers";
import { getRpcUrl } from "@aastar/shared-config";

// Get RPC URL from shared-config
const rpcUrl = getRpcUrl("sepolia"); // Using sepolia testnet

if (!rpcUrl) {
  throw new Error("RPC URL not available in shared-config for sepolia network");
}

// A provider for read-only operations
export const jsonRpcProvider = new ethers.JsonRpcProvider(rpcUrl);

// A signer for the owner to perform write operations (e.g., publishing tasks)
let ownerSigner: ethers.Wallet | null = null;

// Get environment variables from external .env file
// Note: No private keys should be committed to version control
let ownerPrivateKey: string | undefined;

try {
  // Try to load from external env file (outside of git control)
  const envPath = "../../../env/.env";
  const fs = await import("fs");
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, "utf8");
    const match = envContent.match(/VITE_OWNER_PRIVATE_KEY=(.+)/);
    if (match && match[1]) {
      ownerPrivateKey = match[1].trim();
    }
  }
} catch (error) {
  console.warn("Could not load external .env file, using fallback");
}

if (ownerPrivateKey) {
  ownerSigner = new ethers.Wallet(ownerPrivateKey, jsonRpcProvider);
} else {
  console.warn(
    "VITE_OWNER_PRIVATE_KEY is not set. Owner-specific actions will not be available.",
  );
}

export { ownerSigner };
