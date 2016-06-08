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

plt.figure( figsize=(7,10) )

plt.subplot(311)
plt.ylabel('depth')
plt.bar(X, dep, align='center')
plt.xticks(X, ss, rotation=90, fontsize='small')
plt.yticks( np.arange(0, max(dep)+30  ,10) , fontsize='small')
plt.gca().yaxis.grid(True)
for x,y in zip(X, dep):
    plt.text(x,y+3,int(round(y)), ha='center', va='bottom', fontsize='x-small')

plt.subplot(312)
plt.ylabel('duplication rate')
plt.bar(X, dup, align='center')
plt.xticks(X, ss, rotation=90, fontsize='small')
plt.yticks( np.arange(0, max(dup) +3 ,1) , fontsize='small')
plt.gca().yaxis.grid(True)
for x,y in zip(X, dup):
    plt.text(x,y+0.5,int(round(y)), ha='center', va='bottom', fontsize='small')

plt.subplot(313)
plt.ylabel('# of rare variants')
w = 0.4
plt.bar(X, snv, width=w ,color='b' ,align='center', label='SNV(NS/SS)')
plt.bar(X + w , indel, width=w ,color='r',align='center', label='indel(coding)')
plt.legend(loc='upper right', prop={'size':10})
plt.xticks(X +w/2, ss, rotation=90, fontsize='small')
plt.yticks( np.arange(0, max(max( snv ),max(indel ) ) + 200  ,100) , fontsize='small')
plt.gca().yaxis.grid(True)

plt.tight_layout()
plt.savefig('tmp.png')

