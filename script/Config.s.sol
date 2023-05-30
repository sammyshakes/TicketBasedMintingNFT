// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/PenelopesKey.sol";

contract Config is Script {
    // Deployments
    PenelopesKey public pkey;

    // address signer = 0x5b8F11C2c1E33f0857c12Da896bF7c86A8101023;
    // address withdraw = 0x5b8F11C2c1E33f0857c12Da896bF7c86A8101023;
    // uint256 totalTickets = 6000;

    address payable pkey_addy = payable(0xFc1C1356CA86498f4E4b8Eeab37CED171956C664);

    // address user1 = 0x73eE6527DBb475A718718882Ad53fcd953CB7803;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET_DEPLOYER");
        pkey = PenelopesKey(pkey_addy);

        PenelopesKey.ActiveSession session = pkey.activeSession();

        //Deploy Contracts
        vm.startBroadcast(deployerPrivateKey);

        // bytes32 ticket = pkey.getTicket(user1, 0, 1);

        // // initialize bins
        // pkey.addTickets(totalTickets);
        // //set active session
        // pkey.setSession(1);

        vm.stopBroadcast();
    }
}
