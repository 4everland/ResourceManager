// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IStorageManager {

	function mintStorage(
		bytes2 gId_, 
		bytes2 serviceId_, 
		bytes28 uuid,
		uint256 amount,
		uint256 expiration_
	) external;

	function gId() external view returns(bytes2);

	function serviceId() external view returns(bytes2);

	event MintStorage(bytes2 indexed gId, bytes2 indexed serviceId, bytes28 indexed uuid, uint256 amount, uint256 expiration);

}