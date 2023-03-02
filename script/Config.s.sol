// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/PenelopesKey.sol";

contract Config is Script {
    // Deployments
    PenelopesKey public pkey;
    address signer = 0x5b8F11C2c1E33f0857c12Da896bF7c86A8101023;
    address withdraw = 0x5b8F11C2c1E33f0857c12Da896bF7c86A8101023;
    uint256 totalTickets = 6000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        // pkey = new PenelopesKey(signer);
        // // initialize bins
        // pkey.addTickets(totalTickets);
        // //set active session
        // pkey.setSession(1);

        vm.stopBroadcast();
    }
}
