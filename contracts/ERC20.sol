// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    // Constructor: Define el nombre del token, el símbolo, y el suministro inicial
    constructor(string memory name, string memory symbol, uint256 initialSupply) 
        ERC20(name, symbol) 
        Ownable(msg.sender)  // Se pasa msg.sender como propietario inicial
    {
        // Acuñar el suministro inicial de tokens al creador del contrato
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }

    // Función para que solo el propietario pueda acuñar (mint) más tokens
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
