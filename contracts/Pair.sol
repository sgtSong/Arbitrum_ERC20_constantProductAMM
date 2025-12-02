// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Minimal UniswapV2-like pair. Acts as an ERC20 LP token.
/// @dev For initialization via Factory.createPair we call initialize()
contract Pair is ERC20, ReentrancyGuard {
    address public token0;
    address public token1;
    bool private initialized;

    uint112 private reserve0; // uses single storage slot, values fit in 112 bits (same style as Uniswap)
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    uint256 public constant FEE_NUM = 997; // 0.3% fee, uses 1000 denom convention (997/1000)
    uint256 public constant FEE_DEN = 1000;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier onlyInitialized() {
        require(initialized, "Pair: NOT_INITIALIZED");
        _;
    }

    constructor() ERC20("LP Token", "LP") {
        // empty - real initialization happens through initialize()
    }

    /// @notice Called once by Factory right after pair deployment
    function initialize(address _token0, address _token1) external {
        require(!initialized, "Pair: ALREADY_INITIALIZED");
        require(_token0 != _token1, "Pair: IDENTICAL_ADDRESSES");
        token0 = _token0;
        token1 = _token1;
        initialized = true;
    }

    /// @notice Return current reserves
    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    /// @notice Add liquidity by transferring tokens in and minting LP tokens proportionally.
    /// @dev Caller must approve this pair to transfer tokens on their behalf.
    function addLiquidity(uint256 amount0, uint256 amount1) external nonReentrant onlyInitialized returns (uint256 liquidityMinted) {
        require(amount0 > 0 && amount1 > 0, "Pair: ZERO_AMOUNT");

        // pull tokens from sender
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // initial liquidity
            liquidityMinted = sqrt(amount0 * amount1);
            require(liquidityMinted > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
            // lock a tiny MINIMUM liquidity to avoid dividing by zero in some implementations - optional here
            _mint(msg.sender, liquidityMinted);
        } else {
            // proportional mint
            uint256 liq0 = (amount0 * _totalSupply) / reserve0;
            uint256 liq1 = (amount1 * _totalSupply) / reserve1;
            liquidityMinted = liq0 < liq1 ? liq0 : liq1;
            require(liquidityMinted > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
            _mint(msg.sender, liquidityMinted);
        }

        _updateReserves(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice Remove liquidity by burning LP tokens and sending underlying tokens back to `to`.
    function removeLiquidity(uint256 liquidity, address to) external nonReentrant onlyInitialized returns (uint256 amount0, uint256 amount1) {
        require(liquidity > 0, "Pair: ZERO_LIQUIDITY");
        uint256 _totalSupply = totalSupply();
        require(_totalSupply > 0, "Pair: NO_LIQUIDITY");

        // calculate amounts to return
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "Pair: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(msg.sender, liquidity);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        _updateReserves(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice Swap tokenIn for the other token. Caller must have approved tokenIn to this contract.
    /// @param tokenIn address of token being sent into the pool (must be token0 or token1)
    /// @param amountIn amount of tokenIn sent by sender (caller)
    /// @param minAmountOut minimal amount of tokenOut expected (slippage protection)
    /// @param to address receiving tokenOut
    function swap( address tokenIn, uint256 amountIn, uint256 minAmountOut, address to ) external nonReentrant onlyInitialized returns (uint256 amountOut) {
        require(amountIn > 0, "Pair: ZERO_AMOUNT_IN");
        require(tokenIn == token0 || tokenIn == token1, "Pair: INVALID_TOKEN_IN");
        require(to != address(0), "Pair: INVALID_TO");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // --- PACK VARIABLES IN A SINGLE STRUCT (avoids stack too deep)
        SwapTemp memory t;

        (t.r0, t.r1,) = getReserves();

        if (tokenIn == token0) {
            t.reserveIn  = uint256(t.r0);
            t.reserveOut = uint256(t.r1);
            t.tokenOut   = token1;
        } else {
            t.reserveIn  = uint256(t.r1);
            t.reserveOut = uint256(t.r0);
            t.tokenOut   = token0;
        }

        t.amountInWithFee = amountIn * FEE_NUM;
        t.numerator = t.amountInWithFee * t.reserveOut;
        t.amountOut = t.numerator / (t.reserveIn * FEE_DEN + t.amountInWithFee);

        require(t.amountOut >= minAmountOut, "Pair: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(t.tokenOut).transfer(to, t.amountOut);

        _updateReserves(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );

        emit Swap(msg.sender, tokenIn, amountIn, t.amountOut, to);

        return t.amountOut;
    }

    // Temporary struct to compress stack variables
    struct SwapTemp {
        uint112 r0;
        uint112 r1;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 amountInWithFee;
        uint256 numerator;
        uint256 amountOut;
        address tokenOut;
    }


    /// @notice Force reserves to equal actual balances (useful in some edge cases or for oracles).
    function sync() external onlyInitialized {
        _updateReserves(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit Sync(reserve0, reserve1);
    }

    /// @dev internal helper to update reserves
    function _updateReserves(uint256 balance0, uint256 balance1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Pair: OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    /// @dev integer sqrt
    function sqrt(uint y) internal pure returns (uint z) {
        if (y == 0) return 0;
        uint x = y / 2 + 1;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
