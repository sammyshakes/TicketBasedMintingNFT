// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/PenelopesKey.sol";

contract Deploy is Script {
    // Deployments
    PenelopesKey public pkey;
    address signer = vm.envAddress("PKEY_SIGNER_ADDRESS");
    address withdraw = vm.envAddress("PUBLIC_KEY_TESTNET_DEPLOYER");
    uint256 totalTickets = 6000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        pkey = new PenelopesKey(signer);
        //set active session
        // pkey.setSession(1);

        vm.stopBroadcast();
    }
}
