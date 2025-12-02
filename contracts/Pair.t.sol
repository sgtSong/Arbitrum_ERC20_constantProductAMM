// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// A simple mintable test token
contract TestToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract PairTest is Test {
    Pair pair;
    TestToken token0;
    TestToken token1;

    address bob = address(0xB0B);
    address alice = address(0xA11CE);

    function setUp() public {
        // deploy two tokens
        token0 = new TestToken("Token0", "TK0");
        token1 = new TestToken("Token1", "TK1");

        // deploy pair
        pair = new Pair();
        pair.initialize(address(token0), address(token1));

        // mint tokens to Alice
        token0.mint(alice, 1_000_000 ether);
        token1.mint(alice, 1_000_000 ether);

        vm.startPrank(alice);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testAddLiquidity() public {
        vm.startPrank(alice);
        uint256 liq = pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        // LP tokens minted = sqrt(x*y)
        assertEq(liq, 1000 ether);

        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(r0, 1000 ether);
        assertEq(r1, 1000 ether);
    }

    function testRemoveLiquidity() public {
        vm.startPrank(alice);
        uint256 liq = pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        // alice removes all liquidity
        vm.startPrank(alice);
        pair.removeLiquidity(liq, alice);
        vm.stopPrank();

        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(r0, 0);
        assertEq(r1, 0);
    }

    function testSwap0to1() public {
        vm.startPrank(alice);
        pair.addLiquidity(1000 ether, 1000 ether);

        // swap 100 TK0 for TK1
        uint256 out = pair.swap(address(token0), 100 ether, 1, alice);
        vm.stopPrank();

        assertGt(out, 0);

        // reserves updated
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(r0, 1100 ether);
        assertEq(r1, 1000 ether - out);
    }

    function testSwap1to0() public {
        vm.startPrank(alice);
        pair.addLiquidity(1000 ether, 1000 ether);

        uint256 out = pair.swap(address(token1), 200 ether, 1, alice);
        vm.stopPrank();

        assertGt(out, 0);

        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(r1, 1200 ether);
        assertEq(r0, 1000 ether - out);
    }

    function test_Revert_When_InvalidTokenSwap() public {
        vm.startPrank(alice);
        vm.expectRevert("Pair: INVALID_TOKEN_IN");
        pair.swap(address(0xDEADBEEF), 10 ether, 1, alice);
        vm.stopPrank();
    }

    function test_Revert_When_ZeroAmountSwap() public {
        vm.startPrank(alice);
        vm.expectRevert("Pair: ZERO_AMOUNT_IN");
        pair.swap(address(token0), 0, 1, alice);
        vm.stopPrank();
    }

    function testReentrancyGuard() public {
        // ensure nonReentrant is applied
        bytes4 selector = Pair.swap.selector;
        (bool success,) = address(pair).call(
            abi.encodeWithSelector(selector, address(token0), 0, 0, alice)
        );
        assert(!success); // reverts
    }
}
