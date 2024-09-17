type AssetType = '.png' | '.jpg' | '.gif' | '.svg' | '.json' | '.html' | '.htm' | '.css' | '.js' | '.xml' | '.txt' | string;

interface PinataConfig {
    apiKey: string;
    apiSecret: string;
    gateway: string;
}

interface WebContractConfig {
    buildFolder: string;
    fileTypes?: AssetType[];
    assetLimit?: number;
    deployChain?: string;
    pinata?: PinataConfig;
    ipfsPath?: string;
}

const config: WebContractConfig = {
    buildFolder: './build',
    fileTypes: ['.html', '.htm', '.css', '.js', '.xml', '.txt'],
    assetLimit: 5 * 1024 * 1024, // 5 MB
    deployChain: 'sepolia',
    pinata: {
        apiKey: process.env.PINATA_API_KEY || '',
        apiSecret: process.env.PINATA_API_SECRET || '',
        gateway: process.env.PINATA_GATEWAY || ''
    },
    ipfsPath: 'https://emerald-academic-heron-105.mypinata.cloud/ipfs/{cid}'
};

export default config;
