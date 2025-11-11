// Registry contract integration using shared-config
import { CONTRACTS, RegistryABI } from "@aastar/shared-config";
import { ethers } from "ethers";

// Get the registry contract address from shared-config
const REGISTRY_ADDRESS = CONTRACTS.sepolia.core.registry;

// Create a contract instance for the registry
export const createRegistryContract = (provider: ethers.Provider | ethers.Signer) => {
  return new ethers.Contract(REGISTRY_ADDRESS, RegistryABI, provider);
};

// Get community profile from registry
export const getCommunityProfile = async (communityAddress: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.getCommunityProfile(communityAddress);
};

// Check if a community is registered
export const isRegisteredCommunity = async (communityAddress: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.isRegisteredCommunity(communityAddress);
};

// Get community by ENS name
export const getCommunityByENS = async (ensName: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.getCommunityByENS(ensName);
};

// Get community by name
export const getCommunityByName = async (name: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.getCommunityByName(name);
};

// Get all communities (paginated)
export const getCommunities = async (offset: number = 0, limit: number = 50, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.getCommunities(offset, limit);
};

// Get community status (registered and active)
export const getCommunityStatus = async (communityAddress: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.getCommunityStatus(communityAddress);
};

// Get the xPNTs token address for a community
export const getCommunityXPNTs = async (communityAddress: string, provider: ethers.Provider) => {
  const profile = await getCommunityProfile(communityAddress, provider);
  return profile.xPNTsToken;
};

// Check if permissionless mint is allowed for a community
export const isPermissionlessMintAllowed = async (communityAddress: string, provider: ethers.Provider) => {
  const registry = createRegistryContract(provider);
  return await registry.isPermissionlessMintAllowed(communityAddress);
};

// Constants
export const REGISTRY_CONTRACT_ADDRESS = REGISTRY_ADDRESS;
export const REGISTRY_CONTRACT_ABI = RegistryABI;
