"""Desenha a amostra rotulada exportada pelo MPI; nunca recalcula os rótulos."""
import argparse
import csv
import math
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def read_csv(path):
    with path.open() as f:return list(csv.DictReader(f))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pasta',type=Path)
    args=parser.parse_args();root=args.pasta
    meta=dict(line.split('=',1) for line in (root/'metadados.txt').read_text().splitlines())
    if meta['convergiu']!='1':parser.error('A execução não convergiu; não apresentar essa amostra como resultado final.')
    centers=read_csv(root/'centroides.csv')
    ids={int(c['cluster']) for c in centers}
    if len(centers)!=int(meta['k']) or sum(int(c['tweets']) for c in centers)!=int(meta['tweets']):
        parser.error('Centroides/contagens incompatíveis com os metadados.')
    points=[]
    for rank in range(int(meta['processos'])):points.extend(read_csv(root/f'pontos_rank{rank}.csv'))
    if not points:parser.error('A amostra está vazia.')
    if len({r['global_index'] for r in points})!=len(points):parser.error('Índices de amostra repetidos.')
    for row in points+centers:
        if int(row['cluster']) not in ids or not all(math.isfinite(float(row[c])) for c in ['x_m','y_m','t_h']):
            parser.error('Rótulo ou coordenada inválida na exportação.')
    fig=plt.figure(figsize=(12,8),layout='constrained')
    ax=fig.add_subplot(221); space=fig.add_subplot(222,projection='3d'); bars=fig.add_subplot(223);time=fig.add_subplot(224)
    for c in sorted(ids):
        pts=[r for r in points if int(r['cluster'])==c];color=plt.get_cmap('tab10')(c%10)
        x=[float(r['x_m'])/1000 for r in pts];y=[float(r['y_m'])/1000 for r in pts];t=[float(r['t_h']) for r in pts]
        ax.scatter(x,y,s=2,alpha=.35,color=color,rasterized=True)
        space.scatter(x,y,t,s=2,alpha=.35,color=color,rasterized=True)
        center=next(r for r in centers if int(r['cluster'])==c)
        ax.scatter(float(center['x_m'])/1000,float(center['y_m'])/1000,marker='X',s=90,color=color,edgecolor='black',linewidth=.5,label=f'C{c}')
        bars.bar(c,int(center['tweets']),color=color)
        time.scatter([float(center['t_h'])],[c],s=60,color=color)
    ax.set(title='Pontos amostrados e centroides',xlabel='x projetado (km)',ylabel='y projetado (km)');ax.set_aspect('equal',adjustable='datalim');ax.legend(ncol=4,fontsize=8)
    space.set(title='Amostra no espaço e no tempo',xlabel='x (km)',ylabel='y (km)',zlabel='Tempo (h)')
    bars.set(title='Contagens do conjunto completo',xlabel='Cluster',ylabel='Número de tweets',xticks=sorted(ids))
    time.set(title='Tempo do centroide',xlabel='Horas após o início',ylabel='Cluster',yticks=sorted(ids))
    fig.suptitle(f'K-means MPI: {len(points):,} pontos amostrados de {int(meta["tweets"]):,} | k={meta["k"]}')
    fig.savefig(root/'clusters_amostra.png',dpi=180);plt.close(fig)
    print(root/'clusters_amostra.png')

if __name__=='__main__':main()
