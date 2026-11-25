// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ArchiveAnchor
/// @notice 进化档案馆的存证合约。只存 Merkle 根，不存全文。
///         每条存证 = 一个批次（epoch）的全部记录指纹。
///         任何人可以离线重算 Merkle 根并与链上记录比对。
///         owner 初始为部署者，可移交给多签，也可 renounce 永久固定。
contract ArchiveAnchor {
    struct Anchor {
        bytes32 root;
        uint32 recordCount;
        uint64 timestamp;
        string uri;
    }

    address public owner;
    Anchor[] public anchors;

    event Anchored(
        uint256 indexed id,
        bytes32 root,
        uint32 recordCount,
        string uri,
        uint64 timestamp
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @notice 写入一批记录的 Merkle 根
    /// @param root 这一批记录的 Merkle 根
    /// @param recordCount 本批包含的记录条数
    /// @param uri 批次元数据地址（IPFS CID 或 https URL）
    function anchor(bytes32 root, uint32 recordCount, string calldata uri)
        external
        onlyOwner
        returns (uint256 id)
    {
        id = anchors.length;
        anchors.push(Anchor(root, recordCount, uint64(block.timestamp), uri));
        emit Anchored(id, root, recordCount, uri, uint64(block.timestamp));
    }

    function count() external view returns (uint256) {
        return anchors.length;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
