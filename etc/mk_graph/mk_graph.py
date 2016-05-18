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
    sample = ls[ii].split(',')[0]; ss.append(sample)

    dep.append( float( ls[ii].split(',')[-1] ) )
    dup.append( float( ls[ii+1].split(',')[-1] ))
    snv.append( int( ls[ii+2].split(',')[3] ))
    indel.append( int(ls[ii+2].split(',')[8] ) )

dep = np.array(dep)
dup = np.array(dup)
ssnv = np.array(snv)
indel = np.array(indel)

X = np.arange( len(ss) )

plt.subplot(311)
plt.bar(X, dep, align='center')
plt.xticks(X, ss, rotation=90, fontsize='small')

plt.subplot(312)
plt.bar(X, dup, align='center')
plt.xticks(X, ss, rotation=90, fontsize='small')

plt.subplot(313)
w = 0.4
plt.bar(X, snv, width=w ,color='b' ,align='center')
plt.bar(X + w , indel, width=w ,color='r',align='center')
plt.xticks(X +w/2, ss, rotation=90, fontsize='small')

plt.tight_layout()
plt.savefig('tmp.png')

