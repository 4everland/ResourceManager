// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import './PinManager.sol';

contract ResourceManager is PinManager {
	constructor(address owner) {
		transferOwnership(owner);
	}
}
