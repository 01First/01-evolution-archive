// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 01 进化档案馆 · 链上存证
/// @notice 链上只保存记录指纹（SHA-256）、内容地址、发布时间与发布者。
///         发布权归 owner（档案馆多签/团队地址），防止垃圾记录。
contract EvolutionArchive {
    struct Record {
        bytes32 digest;      // SHA-256(canonical JSON) 的 32 字节指纹
        string uri;          // 内容地址：https:// 或 ipfs://
        uint64 publishedAt;  // 上链时间
        address publisher;   // 发布者
    }

    address public owner;
    uint256 public recordCount;

    mapping(bytes32 => bool) public published;
    Record[] private _records;

    event RecordPublished(uint256 indexed id, bytes32 indexed digest, string uri, address indexed publisher);
    event OwnershipTransferred(address indexed from, address indexed to);

    error NotOwner();
    error AlreadyPublished(bytes32 digest);
    error ZeroDigest();
    error ZeroAddress();

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice 发布一条记录；digest 重复会被拒绝。
    function publish(bytes32 digest, string calldata uri) external onlyOwner returns (uint256 id) {
        if (digest == bytes32(0)) revert ZeroDigest();
        if (published[digest]) revert AlreadyPublished(digest);

        published[digest] = true;
        id = recordCount;
        _records.push(Record({
            digest: digest,
            uri: uri,
            publishedAt: uint64(block.timestamp),
            publisher: msg.sender
        }));
        recordCount = id + 1;

        emit RecordPublished(id, digest, uri, msg.sender);
    }

    /// @notice 读取第 id 条记录；越界会 revert。
    function recordAt(uint256 id)
        external
        view
        returns (bytes32 digest, string memory uri, uint64 publishedAt, address publisher)
    {
        Record storage r = _records[id];
        return (r.digest, r.uri, r.publishedAt, r.publisher);
    }

    function transferOwnership(address next) external onlyOwner {
        if (next == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, next);
        owner = next;
    }
}
