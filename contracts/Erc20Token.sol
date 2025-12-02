// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract KITAToken is ERC20, ERC20Permit, Ownable {
  uint private _totalSupply;

  constructor() ERC20("Kessoku","KITA") Ownable(msg.sender) ERC20Permit("Kessoku") {
        _totalSupply = 99000000000000 * 10 ** decimals();
        _mint(msg.sender, _totalSupply);
    }

  function mintToOwner(uint256 amount) external onlyOwner {
        _mint(owner(), amount);
    }
}
