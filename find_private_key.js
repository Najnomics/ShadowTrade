// Simple script to find the private key that corresponds to the SIGNER_ADDRESS
const { ethers } = require("ethers");

const SIGNER_ADDRESS = "0x6E12D8C87503D4287c294f2Fdef96ACd9DFf6bd2";

// Try some common test private keys
const testPrivateKeys = [
    "0x6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c",
    "0x0000000000000000000000000000000000000000000000000000000000000001",
    "0x0000000000000000000000000000000000000000000000000000000000000002",
    "0x0000000000000000000000000000000000000000000000000000000000000003",
    "0x0000000000000000000000000000000000000000000000000000000000000004",
    "0x0000000000000000000000000000000000000000000000000000000000000005",
];

for (const privateKey of testPrivateKeys) {
    try {
        const wallet = new ethers.Wallet(privateKey);
        const address = wallet.address;
        console.log(`Private key: ${privateKey}`);
        console.log(`Address: ${address}`);
        console.log(`Match: ${address.toLowerCase() === SIGNER_ADDRESS.toLowerCase()}`);
        console.log("---");
        
        if (address.toLowerCase() === SIGNER_ADDRESS.toLowerCase()) {
            console.log(`FOUND MATCHING PRIVATE KEY: ${privateKey}`);
            break;
        }
    } catch (error) {
        console.log(`Error with private key ${privateKey}:`, error.message);
    }
}
