// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {KITAToken} from "./Erc20Token.sol";
import {Test} from "forge-std/Test.sol";

contract KITATokenTest is Test {
    KITAToken token;
    address owner = address(0xDEAD);
    address user = address(0xBEEF);

    function setUp() public {
        // deploy the token with owner=msg.sender
        vm.prank(owner);
        token = new KITAToken();
    }

    function test_InitialOwnerIsCorrect() public view {
        assertEq(token.owner(), owner, "Owner should be a deployer");
    }

    function test_InitialSupplyAssignedToOwner() public view {
        uint256 expectedSupply = 99000000000000 * 10 ** token.decimals();
        assertEq(token.totalSupply(), expectedSupply, "Total supply mismatch");
        assertEq(token.balanceOf(owner), expectedSupply, "Owner balance mismatch");
    }

    function test_OnlyOwnerCanMint() public {
        uint256 mintAmount = 1000;

        // A non-owner should revert
        vm.prank(user);
        vm.expectRevert();
        token.mintToOwner(mintAmount);
    }

    function test_OwnerCanMintAndSupplyUpdates() public {
        uint256 mintAmount = 1_000 ether;

        uint256 beforeSupply = token.totalSupply();
        uint256 beforeBalance = token.balanceOf(owner);

        vm.prank(owner);
        token.mintToOwner(mintAmount);

        assertEq(
            token.totalSupply(),
            beforeSupply + mintAmount,
            "Total supply did not increase correctly"
        );

        assertEq(
            token.balanceOf(owner),
            beforeBalance + mintAmount,
            "Owner balance did not increase correctly"
        );
    }

    function test_MintMultipleTimes() public {
        vm.startPrank(owner);

        token.mintToOwner(500);
        token.mintToOwner(700);

        assertEq(token.balanceOf(owner), token.totalSupply());
        assertEq(token.balanceOf(owner) > 0, true);

        vm.stopPrank();
    }
}
