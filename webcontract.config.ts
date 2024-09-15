type AssetType = '.png' | '.jpg' | '.gif' | '.svg' | '.json' | string;

interface PinataConfig {
  apiKey: string;
  apiSecret: string;
  gateway: string;
}

interface WebContractConfig {
  deployedContractAddress?: string;
  buildFolder: string;
  assetTypes?: AssetType[];
  assetLimit?: number;
  pinata?: PinataConfig;
}

const config: WebContractConfig = {
  deployedContractAddress: '0x1234567890123456789012345678901234567890', // Replace with actual address
  buildFolder: './build',
  assetTypes: ['.png', '.jpg', '.gif', '.svg', '.json'], // Optional: list of asset types to store on IPFS
  assetLimit: 5 * 1024 * 1024, // Optional: 5MB limit for assets to store on IPFS
  pinata: {
    apiKey: process.env.PINATA_API_KEY || '',
    apiSecret: process.env.PINATA_API_SECRET || '',
    gateway: process.env.PINATA_GATEWAY || '',
  }
};

export default config;
