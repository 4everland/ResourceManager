// SPDX-License-Identifier: UNLICENSE

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

abstract contract Permitable is Ownable {
	mapping(address => bool) public permits;

	function permit(address permitter, bool isPermit) public onlyOwner {
		permits[permitter] = isPermit;
	}

	modifier onlyPermit() {
		require(permits[msg.sender], 'Permitable: caller is not permitted.');
		_;
	}
}
