# 01 Evolution Archive · 01 进化档案馆

把“区块链的进化史”做成一个由社区共建、链上存证的公开档案。

- 在线站点：https://01first.github.io/01-evolution-archive/
- 存证网络：Polygon PoS
- 代币：01 Evolution（进化币）`0x095d3d6e62c8e2e845a38d239601b10c71fff1b7`
- DEX 交易对：`0x0b202ad83212b460bc2b26913b3727662383575b`
- 第一季：2026-11-23 至 2027-01-31（进行中）
- 发奖合约：`0x781b218941d59ca613b292baff5b2c5638309d50`

## 链上存证

| 项目 | 值 |
|---|---|
| 存证合约 | `0xb5f365df38247cb0d49e5e5d3237ed597019e5d9` |
| owner | `0x8AF1619Ec9E7dcf4976ad0264F857aFcE3666666` |
| Merkle 根 | `0xbdff8289ef60fb345a8109b2151aa7adf2d445ecc83d03c38906c98e1c73b905` |
| 覆盖记录 | 30 / 30 |
| 存证交易 | `0x019726d029721d482c198f7ba0180fee2fc9cc278d772b1d53ce282b35a2d7c3` |

指纹算法：`leaf = SHA-256(canonical JSON)`，`parent = SHA-256(min||max)`，奇数节点上提。
每条记录的独立 Merkle 证明见 [`contracts/merkle.json`](contracts/merkle.json)。

## 独立核验

```bash
python3 contracts/verify_merkle.py           # 离线核验 30 条记录与证明
python3 contracts/verify_merkle.py --chain   # 再与 Polygon 链上 recordAt(0) 比对
```

预期输出：`Merkle 证明: 30/30 通过`、`结果: PASS`。

## 目录

```
index.html                     站点（单文件，无外部依赖）
01_logo.png                    Logo
POINTS.md                      第一季贡献积分规则
contracts/EvolutionArchive.sol 存证合约源码
contracts/merkle.json          30 条叶子、证明与根
contracts/verify_merkle.py     独立核验脚本
.github/ISSUE_TEMPLATE/        贡献登记 / 纠错模板
contributions.json             贡献台账（第一季）
```

## 贡献与积分

- 完整规则：[`POINTS.md`](POINTS.md)
- 登记入口：[提交贡献 Issue](https://github.com/01First/01-evolution-archive/issues/new?template=contribution.yml)
- 纠错入口：[提交纠错 Issue](https://github.com/01First/01-evolution-archive/issues/new?template=correction.yml)

执行流程：

1. 贡献者提交 Issue，附作品链接、账号和说明。
2. 两名复核人独立评分，质量系数取平均。
3. 复核结果写入 `contributions.json`，每周公示积分榜。
4. 季末快照、公示 7 天，冻结名单并生成 Merkle 兑换名单。
5. 兑换由参与者自行发起并支付网络费用；不承诺具体日期。

积分只记录贡献，不可转让，不构成任何收益承诺。奖励来自团队预留份额，不新增发行、不动池子流动性。

## 安全说明

- 本仓库不包含任何私钥、助记词或环境变量文件。
- 档案不募资、不承诺收益、不提供投资建议。
- 所有记录附公开来源；无法核验的内容不收。
- 合约写入权限归 owner，防止垃圾记录。

## 本地预览

```bash
python3 -m http.server 8080
# 打开 http://localhost:8080
```
