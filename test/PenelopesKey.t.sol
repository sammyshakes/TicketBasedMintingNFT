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
    uint256 testMax =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 totalTickets = 4000;

    // Cheatcodes
    HEVM public hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Users
    address public owner;
    address public user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public user2 = address(0x1338);
    // address public user3 = address(0x1339);
    address public withdrawAddress = address(0x1340);
    address public signer;

    uint256 internal signerPrivateKey =
        0x0123456789012345678901234567890123456789012345678901234567890123;

    // uint256 internal signerPrivateKey = 0xA11CE;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        pk = new PenelopesKey(signer);
        console.log("signer", signer);

        // initialize bins
        pk.addTickets(totalTickets);
        //set active session
        pk.setSession(1);

        //setWithdrawAddress
        pk.setWithdrawAddress(withdrawAddress);
        uint256 bal = withdrawAddress.balance;
        console.log("starting_bal withdrawAddress", bal / 1e18);

        //deal some ether
        hevm.deal(user1, 1 ether);
        hevm.deal(user2, 1 ether);
        // hevm.deal(user3, 1 ether);
    }

    function testPublicMint() public {
        //set active session to public mint
        pk.setSession(3);
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
        pk.addTickets(2000);
        uint256 tickets = pk.totalTickets();

        assertEq(pk.ticketMap(0), type(uint256).max);
        assertEq(pk.ticketMap(1), type(uint256).max);
        assertEq(pk.ticketMap(2), type(uint256).max);
        assertEq(pk.ticketMap(tickets / 256), type(uint256).max);
        assertEq(pk.ticketMap(tickets / 256 + 1), 0);
    }

    function testHashing() public {
        //signature that will be provided by back end for user 1
        uint256 ticketNumber = 5;
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        user1,
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
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to WAITLIST
        pk.setSession(2);
        hevm.expectRevert();
        hevm.prank(user1);
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);

        //set active session to ALLOWLIST
        pk.setSession(1);

        //revert "not allowed" if wrong user tries to use it
        hevm.expectRevert();
        hevm.prank(user2);
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);

        hevm.prank(user1);
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);

        //revert "already minted" if user tries to use it to mint again
        hevm.expectRevert();
        hevm.prank(user1);
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);

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

    function testGetTicket() public {
        //first get using solidity function
        uint256 ticketNumber = 5;

        bytes32 tick = pk.getTicket(user1, ticketNumber, 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)
            )
        );
        address _signer = ecrecover(
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", tick)
            ),
            v,
            r,
            s
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signer, _signer); // [PASS]

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = ticketNumber;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = signature;

        hevm.prank(user1);
        pk.mintWithTicket{value: .01 ether}(tickets, sigs);
    }

    function testMintForTeam() public {
        pk.mintForTeam(user2, 5);
        assertEq(pk.balanceOf(user2), 5);

        // also check totalSupply()
        assertEq(pk.totalSupply(), 5);
    }

    function testSetMintPrice() public {
        assertEq(pk.mintPrice(), .01 ether);
        pk.setMintPrice(1 ether);
        assertEq(pk.mintPrice(), 1 ether);
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
