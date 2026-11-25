// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title MerkleDistributor
/// @notice 单季 Merkle 领取合约。部署时不设根、不注资；
///         owner 在名单确定后调用 arm(root, deadline) 一次性设定根与截止期，
///         随后把当季额度转入本合约，用户自付 gas 领取。
///         截止期后 owner 可把未领部分转回奖励池（不销毁）。
contract MerkleDistributor {
    address public immutable token;
    bytes32 public merkleRoot;
    uint256 public deadline;
    address public owner;

    mapping(uint256 => uint256) private claimedBitMap;

    event Armed(bytes32 root, uint256 deadline);
    event Claimed(uint256 index, address account, uint256 amount);
    event Swept(address to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _token) {
        require(_token != address(0), "token is zero");
        token = _token;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @notice 名单确定后一次性设定 Merkle 根与领取截止期
    function arm(bytes32 root, uint256 _deadline) external onlyOwner {
        require(merkleRoot == bytes32(0), "already armed");
        require(root != bytes32(0), "root is zero");
        require(_deadline > block.timestamp, "deadline passed");
        merkleRoot = root;
        deadline = _deadline;
        emit Armed(root, _deadline);
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = 1 << (index & 0xff);
        return (claimedBitMap[wordIndex] & bitIndex) != 0;
    }

    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = 1 << (index & 0xff);
        claimedBitMap[wordIndex] |= bitIndex;
    }

    /// @notice 领取。proof 由链下根据 Merkle 树生成。
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        require(merkleRoot != bytes32(0), "not armed");
        require(block.timestamp <= deadline, "window closed");
        require(!isClaimed(index), "already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(index, account, amount));
        require(_verify(proof, leaf), "invalid proof");

        _setClaimed(index);
        require(IERC20(token).transfer(account, amount), "transfer failed");
        emit Claimed(index, account, amount);
    }

    function _verify(bytes32[] calldata proof, bytes32 leaf) internal view returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 p = proof[i];
            computed = computed <= p
                ? keccak256(abi.encodePacked(computed, p))
                : keccak256(abi.encodePacked(p, computed));
        }
        return computed == merkleRoot;
    }

    /// @notice 窗口结束后，把未领取的部分转回奖励池
    function sweep(address to) external onlyOwner {
        require(merkleRoot != bytes32(0), "not armed");
        require(block.timestamp > deadline, "window not closed");
        require(to != address(0), "to is zero");
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, "nothing to sweep");
        require(IERC20(token).transfer(to, bal), "transfer failed");
        emit Swept(to, bal);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
