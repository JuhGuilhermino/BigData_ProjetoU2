"""Gera tabelas e figuras a partir das evidências já registradas, sem executar MPI/CUDA."""
from pathlib import Path
import csv
import statistics as st
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'resultados' / 'relatorio'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with (ROOT / 'resultados/medicoes.csv').open() as f:
        rows = list(csv.DictReader(f))
    groups = ['1', '2', '4', '8', '16', 'gpu']
    if len(rows) != 18 or any(sum(r['processos'] == g for r in rows) != 3 for g in groups):
        raise ValueError('Este relatório requer as 18 medições originais: três por configuração.')
    series = {g: [float(r['kmeans_s']) for r in rows if r['processos'] == g] for g in groups}
    totals = {g: [float(r['kmeans_s']) + float(r['leitura_s']) for r in rows if r['processos'] == g] for g in groups}
    labels = [f'MPI {g}' if g != 'gpu' else 'CUDA' for g in groups]
    table = ['| Configuração | Mínimo (s) | Mediana (s) | Máximo (s) |', '|---|---:|---:|---:|']
    for g, label in zip(groups, labels):
        table.append(f'| {label} | {min(series[g]):.3f} | {st.median(series[g]):.3f} | {max(series[g]):.3f} |')
    (OUT/'variacao_tempos.md').write_text('\n'.join(table)+'\n',encoding='utf-8')

    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'savefig.dpi':180})
    fig, ax = plt.subplots(figsize=(9.8,3.8),layout='constrained')
    pos = list(range(6)); a=[st.median(series[g]) for g in groups]; b=[st.median(totals[g]) for g in groups]
    ax.bar([x-.19 for x in pos],a,width=.36,label='K-means',color='#126d91')
    ax.bar([x+.19 for x in pos],b,width=.36,label='Leitura + K-means',color='#71b6a1')
    for x,y in zip(pos,a):ax.text(x-.19,y+.6,f'{y:.2f}',ha='center',fontsize=9)
    for x,y in zip(pos,b):ax.text(x+.19,y+.6,f'{y:.2f}',ha='center',fontsize=9)
    ax.set(xticks=pos,xticklabels=labels,ylabel='Tempo mediano (s)',ylim=(0,53))
    ax.legend(frameon=False,loc='upper right');ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
    fig.savefig(OUT/'tempos.png');plt.close(fig)

    clusters=[]
    for line in (ROOT/'resultados/resultados_gpu.md').read_text().splitlines():
        cells=[s.strip() for s in line.strip().strip('|').split('|')]
        if len(cells)==5 and cells[0].isdigit() and '.' in cells[1]:
            conv=lambda v:float(v.replace('.','').replace(',','.'))
            clusters.append([int(cells[0]),int(conv(cells[1])),conv(cells[2]),conv(cells[3]),conv(cells[4])])
    if len(clusters)!=8 or sum(c[1] for c in clusters)!=14262517:
        raise ValueError('Resumo GPU diferente do esperado; revise a fonte antes de gerar o relatório.')
    with (OUT/'clusters_resumo.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['cluster','tweets','x_m','y_m','t_h']);w.writerows(clusters)
    tab=['| Cluster | Tweets | Participação | t do centroide (h) |','|---|---:|---:|---:|']
    for c in clusters:tab.append(f'| {c[0]} | {c[1]:,}'.replace(',','.')+f' | {100*c[1]/14262517:.2f}% | {c[4]:.1f} |')
    (OUT/'clusters_resumo.md').write_text('\n'.join(tab)+'\n',encoding='utf-8')
    colors=plt.get_cmap('tab10').colors
    fig,axes=plt.subplots(1,2,figsize=(9.8,3),layout='constrained')
    ids=[c[0] for c in clusters]
    axes[0].bar(ids,[c[1]/1e6 for c in clusters],color=colors[:8])
    axes[0].set(xlabel='Cluster',ylabel='Tweets (milhões)',xticks=ids,ylim=(0,2.9),title='Tamanho dos grupos')
    axes[1].scatter([c[4] for c in clusters],ids,c=colors[:8],s=65)
    axes[1].set(xlabel='Tempo do centroide (h após o início)',ylabel='Cluster',yticks=ids,xlim=(0,168),title='Centro temporal de cada grupo')
    for ax in axes:ax.grid(alpha=.18);ax.set_axisbelow(True)
    fig.savefig(OUT/'grupos_tempo.png');plt.close(fig)

    fig,ax=plt.subplots(figsize=(9.8,3.8),layout='constrained')
    offsets={0:(-80,24),1:(24,-8),4:(-55,55),2:(-80,-5),6:(-50,-35),7:(35,-22),3:(-75,25),5:(30,-25)}
    for i,n,x,y,t in clusters:
        ax.scatter(x/1e6,y/1e6,s=n/10000,c=[colors[i]],edgecolors='white',linewidth=.8,zorder=3)
        ax.annotate(f'C{i} / {t:.1f} h',(x/1e6,y/1e6),xytext=offsets[i],textcoords='offset points',fontsize=9,
                    arrowprops={'arrowstyle':'-','color':colors[i],'lw':1},color='#263747')
    ax.set(xlim=(-2.4,1.9),ylim=(.6,2.65),xlabel='x projetado (milhões de metros)',ylabel='y projetado (milhões de metros)')
    ax.set_aspect('equal',adjustable='box');ax.grid(alpha=.2)
    fig.savefig(OUT/'centroides_espaciais.png');plt.close(fig)
    print('Gerados: variação dos tempos, resumo dos clusters e três figuras em resultados/relatorio/.')

if __name__ == '__main__':
    main()
