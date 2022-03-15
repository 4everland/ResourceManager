// SPDX-License-Identifier: UNLICENSE

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

abstract contract ServiceManager is Ownable {

	mapping(address => bool) public isManagers;

	event AddManager(address indexed manager);
	event RemoveManager(address indexed manager);

	function addManager(address manager) external onlyOwner {
		require(!isManagers[manager], 'ServiceManager: manager exists.');
		isManagers[manager] = true;
		emit AddManager(manager);
	}

	function removeManager(address manager) external onlyOwner {
		require(isManagers[manager], 'ServiceManager: nonexistent manager.');
		delete isManagers[manager];
		emit RemoveManager(manager);
	}

	modifier onlyManager() {
		require(isManagers[msg.sender], 'ServiceManager: nonexistent manager.');
		_;
	}

}
