#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""verify_merkle.py —— 独立核验 01 进化档案馆的 30 条记录与链上 Merkle 根。

默认离线核验：
  1) 从 index.html 重新计算每条记录的 SHA-256 指纹
  2) 用 merkle.json 的证明逐条重建根
  3) 与 merkle.json 记录的根比对
加 --chain 再查 Polygon 上的 recordAt(0)，确认链上根一致。

用法：
  python3 verify_merkle.py
  python3 verify_merkle.py --chain
"""
import hashlib, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ARCHIVE = os.path.dirname(HERE)
MERKLE_F = os.path.join(HERE, 'merkle.json')
CONTRACT = '0xb5f365df38247cb0d49e5e5d3237ed597019e5d9'


def sha(b):
    return hashlib.sha256(b).digest()


def hpair(a, b):
    return sha(a + b) if a.hex() < b.hex() else sha(b + a)


def rebuild():
    html = open(os.path.join(ARCHIVE, 'index.html'), encoding='utf-8').read()
    recs = json.loads(re.search(r'const RECORDS = (\[.*?\]);', html, re.S).group(1))
    leaves = []
    for r in recs:
        canon = json.dumps({k: r[k] for k in ('date', 'title', 'summary', 'impact', 'source', 'cat', 'era')},
                           ensure_ascii=False, separators=(',', ':'))
        d = sha(canon.encode()).hex()
        if d != r['digest']:
            raise SystemExit('记录 #%s 指纹不一致' % r['id'])
        leaves.append(bytes.fromhex(d))
    lvl = leaves[:]
    while len(lvl) > 1:
        nxt = [hpair(lvl[i], lvl[i + 1]) for i in range(0, len(lvl) - 1, 2)]
        if len(lvl) % 2:
            nxt.append(lvl[-1])
        lvl = nxt
    return recs, leaves, lvl[0]


def verify_proof(leaf, proof, root):
    cur = leaf
    for p in proof:
        other = bytes.fromhex(p['hash'])
        cur = hpair(cur, other) if p['pos'] == 'L' else hpair(other, cur)
    return cur == root


def main():
    mk = json.load(open(MERKLE_F))
    root = bytes.fromhex(mk['root'][2:])
    recs, leaves, rebuilt = rebuild()
    print('记录数: %d' % len(recs))
    print('重建根: 0x%s' % rebuilt.hex())
    print('档案根: %s  %s' % (mk['root'], '一致' if rebuilt == root else '不一致'))
    bad = sum(1 for lf in mk['leaves'] if not verify_proof(bytes.fromhex(lf['digest']), lf['proof'], root))
    print('Merkle 证明: %d/%d 通过' % (len(mk['leaves']) - bad, len(mk['leaves'])))
    ok = rebuilt == root and bad == 0 and len(recs) == mk['count'] == 30

    if '--chain' in sys.argv:
        sys.path.insert(0, '/Users/qlyp/Desktop/TA/TALAMASKA/scan/abandoned')
        import mint_sweep as ms
        from Crypto.Hash import keccak
        k = keccak.new(digest_bits=256); k.update(b'recordAt(uint256)'); sel = '0x' + k.hexdigest()[:8]
        good, r, _ = ms.rpc2('polygon', 'eth_call',
                             [{'to': CONTRACT, 'data': sel + format(0, '064x')}, 'latest'], timeout=20)
        if not good:
            raise SystemExit('链上查询失败: %s' % str(r)[:120])
        onchain = '0x' + r[2:66]
        print('链上记录: %s  %s' % (onchain, '一致' if onchain == mk['root'] else '不一致'))
        ok = ok and onchain == mk['root']

    print('结果:', 'PASS' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
