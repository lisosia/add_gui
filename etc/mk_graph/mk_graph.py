import sys
import numpy as np
import matplotlib.pyplot as plt


ls = sys.stdin.readlines()
assert len(ls) %3 == 0

ss = []
dep = []
dup = []
snv = []
indel = []

for i in range( len(ls)/3):
    ii = i*3
    sample = ls[i].split(',')[0]; ss.append(sample)

    dep.append( float( ls[ii].split(',')[-1] ) )
    dup.append( float( ls[ii+1].split(',')[-1] ))
    snv.append( int( ls[ii+2].split(',')[3] ))
    indel.append( int(ls[ii+2].split(',')[-1] ) )

dep = np.array(dep)
dup = np.array(dup)
ssnv = np.array(snv)
indel = np.array(indel)

X = np.arange( len(ss) )

plt.bar(X, dep) # koreha iede kaku

plt.savefig('tmp.png')

