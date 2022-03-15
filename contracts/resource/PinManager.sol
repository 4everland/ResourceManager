// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import './ServiceStorageManager.sol';
import './ServiceManager.sol';

contract PinManager is ServiceStorageManager, ServiceManager {
	using SafeMath for uint256;

	mapping(bytes32 => mapping(string => uint256)) public cids;

	event FreeBalance(bytes32 indexed to, uint256 total, uint256 cost, uint256 expiration);

	event Insert(bytes32 indexed to, string cid, uint256 size, uint256 expiration);

	event Update(bytes32 indexed to, string cid, uint256 originalSize, uint256 size, uint256 expiration);

	event Remove(bytes32 indexed to, string cid, uint256 size, uint256 expiration);

	function freeBalance(
		bytes32 to,
		uint256 total,
		uint256 cost,
		uint256 expiration
	) external onlyManager {
		require(isExpired(to), 'PinManager: account is not expired.');
		balances[to] = Balance({
			to: to,
			total: total,
			cost: cost,
			expiration: expiration
		});

		emit FreeBalance(to, total, cost, expiration);
	}

	function insertAll(
		bytes32 to,
		string[] memory toCIDs,
		uint256[] memory toSizes
	) external onlyManager {
		require(toCIDs.length == toSizes.length, 'PinManager: Invalid parameters.');
		for (uint256 i = 0; i < toCIDs.length; i++) {
			insert(to, toCIDs[i], toSizes[i]);
		}
	}

	function updateAll(
		bytes32 to,
		string[] memory toCIDs,
		uint256[] memory toSizes
	) external onlyManager {
		require(toCIDs.length == toSizes.length, 'PinManager: Invalid parameters.');
		for (uint256 i = 0; i < toCIDs.length; i++) {
			update(to, toCIDs[i], toSizes[i]);
		}
	}

	function removeAll(
		bytes32 to,
		string[] memory toCIDs
	) external onlyManager {
		for (uint256 i = 0; i < toCIDs.length; i++) {
			remove(to, toCIDs[i]);
		}
	}
	
	function insert(
		bytes32 to,
		string memory cid,
		uint256 size
	) public validateallCIDsize(size) onlyManager {
		require(left(to) >= size, 'PinManager: Not enough storage to pin.');
		uint256 toExpiration = expiration(to);
		require(toExpiration > block.timestamp, 'PinManager: account expired.');
		require(!cidExists(to, cid), 'PinManager: cid exists.');
		cids[to][cid] = size;
		updateCost(to, cost(to).add(size));

		emit Insert(to, cid, size, toExpiration);
	}

	function update(
		bytes32 to,
		string memory cid,
		uint256 size
	) public validateallCIDsize(size) onlyManager {
		uint256 toExpiration = expiration(to);
		require(toExpiration > block.timestamp, 'PinManager: account expired.');
		require(cidExists(to, cid), 'PinManager: cid nonexistent.');
		// replace cid size, incase set wrong cid size;
		uint256 originalSize = cidSize(to, cid);
		require(originalSize != size, 'PinManager: equal cid size.');
		bool isOverflow = originalSize > size;
		uint256 diff = isOverflow ? originalSize.sub(size) : size.sub(originalSize);
		if (!isOverflow) {
			require(diff <= left(to), 'PinManager: not enough storage to pin.');
		}
		uint256 cost = isOverflow ? cost(to).sub(diff) : cost(to).add(diff);
		updateCost(to, cost);
		cids[to][cid] = size;

		emit Update(to, cid, originalSize, size, toExpiration);
	}

	function remove(bytes32 to, string memory cid) public onlyManager {
		require(cidExists(to, cid), 'PinManager: cid nonexistent.');
		uint256 size = cidSize(to, cid);
		updateCost(to, cost(to).sub(size));
		delete cids[to][cid];

		emit Remove(to, cid, size, expiration(to));
	}

	function cidExists(bytes32 to, string memory cid) public view returns (bool) {
		return cids[to][cid] != 0;
	}

	function cidSize(bytes32 to, string memory cid) public view returns (uint256) {
		return cids[to][cid];
	}

	modifier validateallCIDsize(uint256 size) {
		require(size > 0, 'PinManager: invalid cid size.');
		_;
	}
}
