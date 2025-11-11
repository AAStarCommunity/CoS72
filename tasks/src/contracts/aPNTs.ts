// Import from shared-config instead of hardcoding
import { CONTRACTS, xPNTsTokenABI } from "@aastar/shared-config";

// Get the aPNTs contract address from shared-config
// Using sepolia testnet configuration
const APNTS_ADDRESS = CONTRACTS.sepolia.testTokens.aPNTs;

export const APNTS_CONTRACT_ADDRESS = APNTS_ADDRESS;
export const APNTS_ABI = xPNTsTokenABI;
