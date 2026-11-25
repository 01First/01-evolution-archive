// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title PaymentRouter
/// @notice 服务收款路由：稳定币从付款方直接转入金库，合约不留存任何资金。
///         每笔付款带 invoiceId，链上留下可对账的事件；合约无 owner、无提款权限。
///         误转到本合约的代币只能由任何人触发 sweep 转回金库。
contract PaymentRouter {
    address public immutable treasury;
    mapping(address => bool) public isAllowedToken;

    event PaymentReceived(
        bytes32 indexed invoiceId,
        address indexed payer,
        address indexed token,
        uint256 amount
    );
    event Swept(address indexed token, address indexed to, uint256 amount);

    constructor(address _treasury, address[] memory _tokens) {
        require(_treasury != address(0), "treasury is zero");
        treasury = _treasury;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "token is zero");
            isAllowedToken[_tokens[i]] = true;
        }
    }

    /// @notice 支付服务费。amount 为代币最小单位（USDT/USDC 均为 6 位小数）。
    function pay(address token, uint256 amount, bytes32 invoiceId) external {
        require(isAllowedToken[token], "token not allowed");
        require(amount > 0, "amount is zero");
        require(invoiceId != bytes32(0), "invoiceId is zero");
        require(IERC20(token).transferFrom(msg.sender, treasury, amount), "transferFrom failed");
        emit PaymentReceived(invoiceId, msg.sender, token, amount);
    }

    /// @notice 误转代币的兜底：只能转给金库，任何人都可触发
    function sweep(address token) external {
        require(isAllowedToken[token], "token not allowed");
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, "nothing to sweep");
        require(IERC20(token).transfer(treasury, bal), "transfer failed");
        emit Swept(token, treasury, bal);
    }
}
