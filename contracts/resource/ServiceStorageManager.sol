// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import '../interfaces/IServiceStorageManager.sol';
import '../access/Permitable.sol';

contract ServiceStorageManager is Permitable, IServiceStorageManager {
	using SafeMath for uint256;

	struct Balance {
		bytes32 to;
		uint256 total;
		uint256 cost;
		uint256 expiration;
	}

	mapping(bytes32 => Balance) public balances;

	function syncStorage(
		bytes2 gId, 
		bytes2 serviceId, 
		bytes28 uuid,
		uint256 amount,
		uint256 expiration_
	) external override onlyPermit {
		bytes32 to = guid(gId, serviceId, uuid);
		if (accountExists(to)) {
			updateExpiration(to, expiration_);
			updateTotal(to, amount);
		} else {
			balances[to] = Balance({
				to: to,
				total: amount,
				cost: 0,
				expiration: expiration_
			});
		}
		emit SyncStorage(to, amount, expiration_);
	}

	function updateTotal(bytes32 to, uint256 total_) internal {
		if (total(to) != total_) {
			balances[to].total = total_;
		}
	}

	function updateCost(bytes32 to, uint256 cost_) internal {
		if (cost(to) != cost_) {
			balances[to].cost = cost_;
		}
	}

	function updateExpiration(bytes32 to, uint256 expiration_) internal {
		if (expiration(to) != expiration_) {
			balances[to].expiration = expiration_;
		}
	}

	function accountExists(bytes32 to) public view override returns (bool) {
		return balances[to].expiration != 0;
	}

	function guid(bytes2 gId, bytes2 serviceId, bytes28 uuid) public pure override returns (bytes32) {
		uint256 i = 0;
		i = i.add(type(uint256).max & (uint256(uint16(gId)) << (30 * 8)));
		i = i.add(type(uint256).max & (uint256(uint16(serviceId)) << (28 * 8)));
		i = i.add(type(uint256).max & uint256((uint224(uuid))));
		return bytes32(i);
	}

	function total(bytes32 to) public view override returns (uint256) {
		return balances[to].total;
	}

	function cost(bytes32 to) public view override returns (uint256) {
		return balances[to].cost;
	}

	function left(bytes32 to) public view override returns(uint256) {
		return total(to).sub(cost(to));
	}

	function expiration(bytes32 to) public view override returns (uint256) {
		return balances[to].expiration;
	}

	function isExpired(bytes32 to) public view returns (bool) {
		return block.timestamp > expiration(to);
	}

}
