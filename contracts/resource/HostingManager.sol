// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../interfaces/IServiceStorageManager.sol';
import '../interfaces/IStorageManager.sol';
import './ChannelWrapper.sol';

contract HostingManager is ChannelWrapper, IStorageManager {

	IServiceStorageManager public serviceManager;

	constructor(IServiceStorageManager serviceManager_, address channel, address owner_) ChannelWrapper(channel) {
		serviceManager = serviceManager_;
		transferOwnership(owner_);
	}

	function mintStorage(
		bytes2 gId_, 
		bytes2 serviceId_, 
		bytes28 uuid,
		uint256 amount,
		uint256 expiration_
	) external override onlyChannel {
		require(gId_ == gId(), 'HostingManager: Invalid gid.');
		require(serviceId_ == serviceId(), 'HostingManager: Invalid serviceId.');

		serviceManager.syncStorage(gId_, serviceId_, uuid, amount, expiration_);
		emit MintStorage(gId_, serviceId_, uuid, amount, expiration_);
	}

	function gId() public pure override returns(bytes2) {
		return 0x0001;
	}

	function serviceId() public pure override returns(bytes2) {
		return 0x0001;
	}

}
