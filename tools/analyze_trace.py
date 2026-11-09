#!/usr/bin/env python3
"""Summarize 16-byte real-mode squad trajectory snapshots from TANKS.COM /TRACE."""
from pathlib import Path
import argparse


def analyze(raw: bytes):
    if not raw or len(raw) % 16:
        raise ValueError(f"Expected N x 16 bytes, got {len(raw)}")
    result = []
    for ofs in range(0,len(raw),16):
        r=raw[ofs:ofs+16]
        result.append({
            'tick': r[0], 'player': (r[1],r[2]),
            'keys': r[3], 'phase': r[4],
            'enemies': tuple((r[5+i],r[9+i]) for i in range(4)),
            'spawned': r[13], 'state': r[14], 'killed': r[15],
        })
    return result


def report(states):
    print('XT Battle City tactical replay (8086 DOS /TRACE)')
    print('TICK | P1 x,y | TEAM phase | E0  x,y  | E1  x,y  | E2  x,y  | E3  x,y  | SPAWN KILLS STATE')
    for r in states:
        enemy = ' | '.join(f'{x:3},{y:3}' for x,y in r['enemies'])
        print(f"{r['tick']:4} | {r['player'][0]:3},{r['player'][1]:3} | {r['phase']:10} | {enemy} | {r['spawned']:5} {r['killed']:5} {r['state']:5}")
    print('Delta player:',states[-1]['player'][0]-states[0]['player'][0],states[-1]['player'][1]-states[0]['player'][1])
    for i in range(4):
        a=states[0]['enemies'][i];b=states[-1]['enemies'][i]
        print('Delta enemy',i,':',b[0]-a[0],b[1]-a[1])
    print('Squad assault reached:',any(r['phase'] for r in states))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('file',type=Path)
    args=p.parse_args()
    report(analyze(args.file.read_bytes()))
