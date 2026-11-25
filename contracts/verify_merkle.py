#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""verify_merkle.py —— 独立核验 01 进化档案馆的 30 条记录与链上 Merkle 根。

默认离线核验：
  1) 从 index.html 重新计算每条记录的 SHA-256 指纹
  2) 用 merkle.json 的证明逐条重建根
  3) 与 merkle.json 记录的根比对
加 --chain 再查 Polygon 上的 anchors(0)，确认链上根与记录数一致。

用法：
  python3 verify_merkle.py
  python3 verify_merkle.py --chain
"""
import hashlib, json, os, re, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ARCHIVE = os.path.dirname(HERE)
MERKLE_F = os.path.join(HERE, 'merkle.json')
CONTRACT = '0x38bE675BD7E04AF650b1383EfF57124068d01F45'
RPCS = [
    'https://polygon-rpc.com',
    'https://1rpc.io/matic',
    'https://polygon-bor-rpc.publicnode.com',
]
SEL = '368b733e'  # anchors(uint256)


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


def chain_anchor():
    payload = {'jsonrpc': '2.0', 'id': 1, 'method': 'eth_call',
               'params': [{'to': CONTRACT, 'data': '0x' + SEL + format(0, '064x')}, 'latest']}
    err = None
    for rpc in RPCS:
        try:
            req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                         headers={'Content-Type': 'application/json'})
            with urllib.request.urlopen(req, timeout=20) as resp:
                out = json.load(resp)
            data = out['result']
            if not data or data == '0x':
                raise RuntimeError('empty result')
            root = '0x' + data[2:66]
            count = int(data[66:130], 16)
            return root, count
        except Exception as e:
            err = '%s: %s' % (rpc, str(e)[:100])
    raise SystemExit('链上查询失败: %s' % err)


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
        onchain, count = chain_anchor()
        print('链上批次 0: %s  recordCount=%d  %s' % (
            onchain, count, '一致' if onchain == mk['root'] and count == mk['count'] else '不一致'))
        ok = ok and onchain == mk['root'] and count == mk['count']

    print('结果:', 'PASS' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
