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

sample_count = len(ls) / 3
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
margin = 1.

plt.figure( figsize=( 0.3 * sample_count  + 1.5 ,10) )
width = 0.5

plt.subplot(311)
plt.ylabel('depth')
plt.bar(X, dep, align='center', width=width)
plt.xticks(X, ss, rotation=90, fontsize='small')
ymax = 150
plt.yticks( np.arange(0, ymax  ,30) , fontsize='small')
plt.xlim( -margin , len(ss) -1 + width + margin)
plt.ylim(0, ymax )
plt.gca().yaxis.grid(True)
for x,y in zip(X, dep):
    plt.text(x, min(y ,ymax) +3,int(round(y)), ha='center', va='bottom', fontsize='x-small')

plt.subplot(312)
plt.ylabel('duplication rate')
plt.bar(X, dup, align='center', width=width)
plt.xlim( -margin, len(ss) -1 + width + margin)
plt.xticks(X, ss, rotation=90, fontsize='small')
ytick_step = int ( max(dup) / 10 )
ytick_step = max( ytick_step, 1 )
plt.yticks( np.arange(0, max(dup) + ytick_step * 3  ,ytick_step) , fontsize='small')
plt.gca().yaxis.grid(True)
for x,y in zip(X, dup):
    plt.text(x,y+0.5,int(round(y)), ha='center', va='bottom', fontsize='small')

plt.subplot(313)
plt.ylabel('# of rare variants')
w = 0.4
plt.bar(X, snv, width=w ,color='b' ,align='center', label='SNV(NS/SS)')
plt.bar(X + w , indel, width=w ,color='r',align='center', label='indel(coding)')
plt.xlim( -margin, len(ss) -1 + width + margin)
plt.legend(loc='best', prop={'size':9}, bbox_to_anchor=( 1, 1) )
plt.xticks(X +w/2, ss, rotation=90, fontsize='small')
plt.yticks( np.arange(0, max(max( snv ),max(indel ) ) + 200  ,100) , fontsize='small')
plt.gca().yaxis.grid(True)

plt.tight_layout()
plt.savefig('tmp.png')

