// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/PenelopesKey.sol";

interface HEVM {
    function warp(uint256 time) external;

    function roll(uint256) external;

    function prank(address) external;

    function prank(address, address) external;

    function startPrank(address) external;

    function startPrank(address, address) external;

    function stopPrank() external;

    function deal(address, uint256) external;

    function expectRevert(bytes calldata) external;

    function expectRevert() external;
}

contract PenelopesKeyTest is Test {
    PenelopesKey pk;
    uint256 testMax = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 totalTickets = 6000;

    // Cheatcodes
    HEVM public hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public user2 = address(0x1338);
    address public user3 = address(0x1339);
    address public withdrawAddress = address(0x1340);
    address public signer;

    uint256 internal signerPrivateKey = 0x14fc04d5e0773603731ffc332f3a784ad12f01b685ce8fee476406105c010596;

    address pkey_addy = 0xD241d917e5b8ac86aa3e9EcB0556D0C47094504D;
    address user5 = 0x73eE6527DBb475A718718882Ad53fcd953CB7803;

    // uint256 internal signerPrivateKey = 0xA11CE;
    bytes testTicket;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        pk = new PenelopesKey(signer);
        console.log("signer", signer);

        //set admin
        pk.addAdmin(address(0x5555));

        //set active session
        pk.setSession(1);

        //setWithdrawAddress
        pk.setWithdrawAddress(withdrawAddress);
        uint256 bal = withdrawAddress.balance;
        console.log("starting_bal withdrawAddress", bal / 1e18);

        //deal some ether
        hevm.deal(user1, 1 ether);
        hevm.deal(user2, 1 ether);
        hevm.deal(user5, 1 ether);
        hevm.deal(user3, 1 ether);

        ///----------------------//
        //for testAllowlistMint()
        bytes32 tick = pk.getTicket(user3, 1, 1);
        bytes32 hash = hashGetTicket(tick);

        // // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(hash);
        testTicket = abi.encodePacked(r, s, v);
        ///----------------------//
    }

    function testLevelUp() public {
        //mint one
        pk.mintForTeam(user2, 1);

        //try to level up without setting admin address
        hevm.expectRevert();
        pk.levelUp(1);

        //try to set with zero address
        hevm.expectRevert();
        pk.addAdmin(address(0x00));

        hevm.prank(address(0x5555));
        pk.levelUp(1);

        // remove admin
        pk.removeAdmin(address(0x5555));

        // try to level up without after removing admin address
        hevm.expectRevert();
        pk.levelUp(1);
    }

    function testAllowlistMint() public {
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 1;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = testTicket;
        //mint from allowlist
        hevm.prank(user3);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);
    }

    function testTotalTickets() public {
        assertEq(pk.totalTickets(), 6000);
    }

    function testClaimTickets() public {
        pk.claimTicket(0);
    }

    function testInitialMap() public {
        assertEq(pk.name(), "PenelopesKey");
        assertEq(testMax, type(uint256).max);

        assertEq(pk.ticketMap(0), type(uint256).max);
        assertEq(pk.ticketMap(1), type(uint256).max);
        assertEq(pk.ticketMap(2), type(uint256).max);
        assertEq(pk.ticketMap(3), type(uint256).max);
        assertEq(pk.ticketMap(4), type(uint256).max);
        assertEq(pk.ticketMap(totalTickets / 256), type(uint256).max);
        assertEq(pk.ticketMap(totalTickets / 256 + 1), 0);
    }

    function testAddTickets() public {
        uint256 tickets = pk.maxSupply();

        assertEq(pk.ticketMap(0), type(uint256).max);
        assertEq(pk.ticketMap(1), type(uint256).max);
        assertEq(pk.ticketMap(2), type(uint256).max);
        assertEq(pk.ticketMap(tickets / 256), type(uint256).max);
        assertEq(pk.ticketMap(tickets / 256 + 1), 0);
    }

    function testAllowlist() public {
        // vm.assume(ticketNumber <= pogs.totalTickets());
        //signature that will be provided by back end for user 1
        uint256 ticketNumber = 2;
        address user = 0x1d07A15DafdD46247C4Aea1C77d1F2c08F4544A2;
        //deal some ether
        hevm.deal(user, 1 ether);

        // //hash ticket
        bytes32 hash = hashTicket(user, ticketNumber, uint8(1));
        // // sign ticket
        (uint8 v, bytes32 r, bytes32 s) = signTicket(hash);
        bytes memory signedTicket = abi.encodePacked(r, s, v);

        // recover signer
        address _signer = ecrecover(hash, v, r, s);
        assertEq(signer, _signer); // [PASS]

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signedTicket;

        //try to use before allowlist has started
        //set active session to NONE
        pk.setSession(0);
        hevm.expectRevert();
        hevm.prank(user1);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //set active session to WAITLIST
        pk.setSession(2);
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //set active session to ALLOWLIST
        pk.setSession(1);

        //revert "not allowed" if wrong user tries to use it
        hevm.expectRevert();
        hevm.prank(user2, user2);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        hevm.prank(user, user);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //revert "already minted" if user tries to use it to mint again
        hevm.expectRevert();
        hevm.prank(user3, user3);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //check user 1 balance
        pk.balanceOf(user1);
        pk.tokensOfOwner(user1);

        // test withdraw function
        // try to withdraw from non authorized account
        hevm.expectRevert();
        hevm.prank(user2);
        pk.withdraw();

        // now from proper address
        uint256 bal = withdrawAddress.balance;
        console.log("bal withdrawAddress before = ", bal);
        uint256 ctxBal = address(pk).balance;
        console.log("bal contract Address before = ", ctxBal);
        hevm.prank(withdrawAddress);
        pk.withdraw();
        assertTrue(withdrawAddress.balance > bal);
        bal = withdrawAddress.balance;
        console.log("bal withdrawAddress after = ", bal);
        assertEq(withdrawAddress.balance, pk.mintPrice());
        ctxBal = address(pk).balance;
        console.log("bal contract Address after = ", ctxBal);

        // try to mint with four tickets
        tickets = new uint256[](4);
        tickets[0] = 1;
        tickets[1] = 2;
        tickets[2] = 3;
        tickets[3] = 4;
        sigs = new bytes[](4);
        sigs[0] = testTicket;
        for (uint256 i = 1; i < 4; i++) {
            bytes32 tick = pk.getTicket(user2, i, 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: 4 * 0.075 ether}(tickets, sigs);

        // try to mint with mismatched arrays
        tickets = new uint256[](2);
        tickets[0] = 1;
        tickets[1] = 2;
        sigs = new bytes[](3);
        sigs[0] = testTicket;
        for (uint256 i = 1; i < 3; i++) {
            bytes32 tick = pk.getTicket(user2, i, 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: 0.02 ether}(tickets, sigs);

        tickets = new uint256[](2);
        tickets[0] = 4;
        tickets[1] = 5;
        sigs = new bytes[](2);
        sigs[0] = testTicket;
        for (uint256 i; i < 2; i++) {
            bytes32 tick = pk.getTicket(user2, tickets[i], 1);
            bytes32 _hash = hashGetTicket(tick);
            // sign ticket
            (uint8 v, bytes32 r, bytes32 s) = signTicket(_hash);
            sigs[i] = abi.encodePacked(r, s, v);
        }
        //try to mint without sending enough ether
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: 0}(tickets, sigs);

        //try to mint more than max supply
        pk.mintForTeam(user3, 5999);
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: 0.15 ether}(tickets, sigs);
    }

    function hashTicket(address user, uint256 ticketNumber, uint8 session) private pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(user, ticketNumber, session))
            )
        );
    }

    function hashGetTicket(bytes32 _tick) private pure returns (bytes32 _hash) {
        _hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _tick));
    }

    function signTicket(bytes32 _hash) private view returns (uint8 v, bytes32 r, bytes32 s) {
        (v, r, s) = vm.sign(signerPrivateKey, _hash);
    }

    // function testHash() public {
    //     bytes32 hash = keccak256("hello");
    //     bytes32 hash = keccak256(
    //         abi.encodePacked(
    //             "\x19Ethereum Signed Message:\n32",
    //             keccak256("hello")
    //         )
    //     );

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
    //     address _signer = ecrecover(hash, v, r, s);
    //     bytes memory signature = abi.encodePacked(r, s, v);
    //     uint256[] memory tickets = new uint256[](1);
    //     tickets[0] = 0;

    //     bytes[] memory sigs = new bytes[](1);
    //     sigs[0] = signature;

    //     pk.mintWithTicket{value: .01 ether}(tickets, sigs);
    // }

    function testHashing() public {
        //signature that will be provided by back end for user 1
        uint256 ticketNumber = 85;
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        user5,
                        // bytes32(uint256(uint160(user1))),
                        ticketNumber,
                        uint8(1)
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        address _signer = ecrecover(hash, v, r, s);
        assertEq(signer, _signer); // [PASS]
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signature;

        //try to use before allowlist has started
        //set active session to NONE
        pk.setSession(0);
        hevm.expectRevert();
        hevm.prank(user1);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //set active session to WAITLIST
        pk.setSession(2);
        hevm.expectRevert();
        hevm.prank(user1);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //set active session to ALLOWLIST
        pk.setSession(1);

        //revert "not allowed" if wrong user tries to use it
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        hevm.prank(user5);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //revert "already minted" if user tries to use it to mint again
        hevm.expectRevert();
        hevm.prank(user5);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);

        //check user 1 balance
        pk.balanceOf(user1);
        pk.tokensOfOwner(user1);

        // test withdraw function
        // try to withdraw from non authorized account
        hevm.expectRevert();
        hevm.prank(user2);
        pk.withdraw();

        // now from proper address
        hevm.prank(withdrawAddress);
        pk.withdraw();
        uint256 bal = withdrawAddress.balance;
        console.log("bal withdrawAddress", bal);
        assertEq(withdrawAddress.balance, pk.mintPrice());
    }

    function testReduceMaxSupply() public {
        console.log("current supply", pk.maxSupply());
        pk.reduceMaxSupplyBy(2000);
        console.log("current supply after", pk.maxSupply());

        //try to reduce by tooo much
        hevm.expectRevert();
        pk.reduceMaxSupplyBy(7000);
    }

    function testGetTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 0;

        bytes32 tick = pk.getTicket(user5, ticketNumber, 1);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerPrivateKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)));
        address _signer = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)), v, r, s);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signer, _signer); // [PASS]

        //test verify sig
        assertEq(true, pk.verifyTicket(user5, ticketNumber, 1, signature));

        // test minting with ticket
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signature;

        hevm.prank(user5);
        pk.mintWithTicket{value: 0.075 ether}(tickets, sigs);
    }

    function testVerifyTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 1;
        uint8 session = 1;

        bytes32 tick = pk.getTicket(user5, ticketNumber, session);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerPrivateKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)));
        address _signer = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)), v, r, s);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signer, _signer); // [PASS]

        //test verify sig
        assertEq(true, pk.verifyTicket(user5, ticketNumber, session, signature));
    }

    function testMaxSupply() public {
        hevm.expectRevert();
        pk.mintForTeam(user2, 6001);

        pk.mintForTeam(user2, 6000);

        hevm.expectRevert();
        pk.mintForTeam(user2, 1);
    }

    function testSetMintPrice() public {
        assertEq(pk.mintPrice(), 0.075 ether);
        pk.setMintPrice(1 ether);
        assertEq(pk.mintPrice(), 1 ether);
    }

    function testPublicMint() public {
        uint256 amount = 1;
        uint256 mintPrice = pk.mintPrice();

        //try to mint before setting active session
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pk.mint{value: amount * mintPrice}(amount);

        //try to mint from contract
        pk.setSession(3);
        hevm.expectRevert();
        //this is equivalent to sending from contract
        hevm.prank(user1);
        pk.mint{value: amount * mintPrice}(amount);

        //set active session to public mint
        pk.setSession(3);
        hevm.prank(user1, user1);
        pk.mint{value: amount * mintPrice}(amount);

        //try to mint without sending enough value
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pk.mint{value: 1 * mintPrice}(2);

        //try to mint more than max supply
        pk.mintForTeam(user3, 5995);
        hevm.expectRevert();
        hevm.prank(user1, user1);
        pk.mint{value: 10 * mintPrice}(10);
    }

    function testMintForTeam() public {
        uint16 amount = 664;
        uint256 currentSupply = pk.totalSupply();
        pk.mintForTeam(user2, amount);
        assertEq(pk.balanceOf(user2), amount);

        // also check totalSupply()
        assertEq(pk.totalSupply(), currentSupply + amount);

        //try to exceed maxsupply
        hevm.expectRevert();
        pk.mintForTeam(user2, 6000);
    }

    function testUnrevealed() public {
        //mint one
        pk.mintForTeam(user2, 1);

        // set unrevealed uri
        string memory setUnrevealedUrl = "https://unrevealed.com";
        pk.setUnrevealedURI(setUnrevealedUrl);

        // set base uri
        string memory baseUrl = "ipfs://bafybeibewadqajwgmka7357h7k7v2fw4jgekmv5di3vryr6lyfanzv3ioq/";
        pk.setBaseURI(baseUrl);

        //get uri before revealed
        string memory retrievedURI = pk.tokenURI(1);
        console.log("retrieved url for token 1 before reveal", retrievedURI);

        bool isRevealed = pk.isRevealed();
        assertEq(isRevealed, false);
        pk.setIsRevealed(true);
        isRevealed = pk.isRevealed();
        assertEq(isRevealed, true);

        // hevm.prank(user1);
        pk.mintForTeam(user1, 1);
        retrievedURI = pk.tokenURI(1);
        console.log(retrievedURI);

        //retrieve uri for token that does not exist
        hevm.expectRevert();
        pk.tokenURI(7000);
    }

    function testSetWithdrawAddress() public {
        //try to set with zero address
        hevm.expectRevert();
        pk.setWithdrawAddress(address(0x00));

        pk.setWithdrawAddress(address(0x5555));
        assertEq(address(0x5555), pk.withdrawAddress());
    }

    function testAllowListSigner() public {
        //try to set with address zero
        hevm.expectRevert();
        pk.setAllowListSigner(address(0x00));
        // assertEq(address(0x5555), pk.allowListSigner());

        pk.setAllowListSigner(address(0x5555));
        assertEq(address(0x5555), pk.allowListSigner());
    }

    function testAdmins() public {
        //mint one
        pk.mintForTeam(user2, 1);

        // try to burn without setting admin address
        // assertEq(pk.isAdmin(address(this)), false);
        hevm.expectRevert();
        pk.burn(1);

        //try to set with zero address
        hevm.expectRevert();
        pk.addAdmin(address(0x00));

        pk.addAdmin(address(0x5555));
        // assertEq(pk.isAdmin(address(0x5555)), true);

        hevm.prank(address(0x5555));
        pk.burn(1);

        // remove admin
        pk.removeAdmin(address(0x5555));
        // assertEq(pk.isAdmin(address(0x5555)), false);

        // try to burn without after removing admin address
        hevm.expectRevert();
        pk.burn(1);
    }

    function testInterface() public {
        assertTrue(pk.supportsInterface(0x80ac58cd));
    }

    // These tests no longer needed as the visibility of "claimTicket"
    // has now been changed to private
    //
    // function testClaimTicket() public {
    //     //claim ticket 1
    //     pk.claimTicket(1);
    //     //expect tx to fail when trying to claim ticket 1 again
    //     hevm.expectRevert();
    //     pk.claimTicket(1);

    //     //claim ticket 0
    //     pk.claimTicket(0);
    //     //expect tx to fail when trying to claim ticket 0 again
    //     hevm.expectRevert();
    //     pk.claimTicket(0);

    //     //claim ticket totalTickets
    //     pk.claimTicket(totalTickets - 1);

    //     //claim ticket totalTickets + 1 (expect revert)
    //     hevm.expectRevert();
    //     pk.claimTicket(totalTickets + 1);

    //     // assertEq(pk.ticketMap(0), type(uint256).max);
    //     // assertEq(pk.ticketMap(1), type(uint256).max);
    // }
}
