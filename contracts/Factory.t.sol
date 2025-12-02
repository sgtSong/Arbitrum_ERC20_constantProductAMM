// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/Factory.sol";

contract FactoryTest is Test {
    Factory factory;
    address tokenA = address(0xAAA1);
    address tokenB = address(0xBBB1);

    function setUp() public {
        factory = new Factory();
    }

    function test_Revert_When_IdenticalTokens() public {
        vm.expectRevert("Factory: IDENTICAL_ADDRESSES");
        factory.createPair(tokenA, tokenA);
    }

    function test_Revert_When_ZeroAddress() public {
        vm.expectRevert("Factory: ZERO_ADDRESS");
        factory.createPair(address(0), tokenA);
    }

    function test_Revert_When_PairExists() public {
        factory.createPair(tokenA, tokenB);
        vm.expectRevert("Factory: PAIR_EXISTS");
        factory.createPair(tokenA, tokenB);
    }

    function test_CreatePair_Works() public {
        address pair = factory.createPair(tokenA, tokenB);
        assertEq(factory.getPair(tokenA, tokenB), pair);
        assertEq(factory.getPair(tokenB, tokenA), pair);
        assertEq(factory.allPairsLength(), 1);
    }
}
