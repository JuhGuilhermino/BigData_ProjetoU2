"""Testes funcionais da exportação opcional. Requer main compilado e MPI."""
import csv
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
BIN=Path(os.environ.get('KMEANS_BIN',ROOT/'main')).resolve()
MPI=os.environ.get('MPIRUN','mpirun')

def read(path):
    with path.open() as f:return list(csv.DictReader(f))

class Exportacao(unittest.TestCase):
    def run_mpi(self,source,k,p,folder=None,iterations=100):
        env=os.environ.copy();env.pop('KMEANS_EXPORT_DIR',None)
        if folder is not None:env['KMEANS_EXPORT_DIR']=str(folder)
        return subprocess.run([MPI,'-np',str(p),str(BIN),str(source),str(k),str(iterations),'42'],env=env,text=True,capture_output=True,timeout=40)

    def test_fixtures_com_e_sem_exportacao(self):
        cases=[('media',1,4,[4]),('dimensao_constante',1,4,[4]),('dois_grupos',2,6,[3,3])]
        with tempfile.TemporaryDirectory() as d:
            for name,k,n,counts in cases:
                for p in [1,2,4]:
                    with self.subTest(caso=name,processos=p):
                        source=ROOT/f'tests/fixtures/{name}.csv';folder=Path(d)/f'{name}_{p}'
                        baseline=self.run_mpi(source,k,p);exported=self.run_mpi(source,k,p,folder)
                        self.assertEqual(baseline.returncode,0,baseline.stderr)
                        self.assertEqual(exported.returncode,0,exported.stderr)
                        select=lambda s:[l for l in s.splitlines() if l.startswith(('Cluster ','Convergiu'))]
                        self.assertEqual(select(baseline.stdout),select(exported.stdout))
                        pts=[r for rank in range(p) for r in read(folder/f'pontos_rank{rank}.csv')]
                        centers=read(folder/'centroides.csv')
                        self.assertEqual(len(pts),n)
                        self.assertEqual({int(r['global_index']) for r in pts},set(range(n)))
                        self.assertEqual(sorted(int(c['tweets']) for c in centers),counts)
                        original=read(source)
                        first=min(float(r['timestamp_seconds']) for r in original)
                        for r in pts:
                            src=original[int(r['global_index'])]
                            self.assertAlmostEqual(float(r['x_m']),float(src['x_m']))
                            self.assertAlmostEqual(float(r['y_m']),float(src['y_m']))
                            self.assertAlmostEqual(float(r['t_h']),(float(src['timestamp_seconds'])-first)/3600)
                        for center in centers:
                            assigned=[r for r in pts if r['cluster']==center['cluster']]
                            self.assertEqual(len(assigned),int(center['tweets']))
                            for field in ['x_m','y_m','t_h']:
                                self.assertAlmostEqual(sum(float(r[field]) for r in assigned)/len(assigned),float(center[field]))

    def test_pasta_existente_nao_sobrescrita(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d);sentinel=folder/'preservar.txt';sentinel.write_text('original')
            run=self.run_mpi(ROOT/'tests/fixtures/media.csv',1,2,folder)
            self.assertNotEqual(run.returncode,0)
            self.assertEqual(sentinel.read_text(),'original')
            self.assertFalse((folder/'centroides.csv').exists())

    def test_execucao_sem_convergencia_rejeitada_pelo_grafico(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d)/'export';run=self.run_mpi(ROOT/'tests/fixtures/dois_grupos.csv',2,1,folder,iterations=1)
            self.assertEqual(run.returncode,0,run.stderr)
            self.assertIn('convergiu=0',(folder/'metadados.txt').read_text())
            plot=subprocess.run([sys.executable,str(ROOT/'scripts/visualizar_clusters.py'),str(folder)],capture_output=True,text=True,timeout=30)
            self.assertNotEqual(plot.returncode,0)
            self.assertIn('não convergiu',plot.stderr)

    def test_limite_amostra_e_repetibilidade(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d);source=folder/'pontos.csv'
            source.write_text('x_m,y_m,timestamp_seconds,timezone\n'+''.join(f'{i},5,{i},1\n' for i in range(10020)))
            for suffix in ['a','b']:
                run=self.run_mpi(source,1,1,folder/suffix)
                self.assertEqual(run.returncode,0,run.stderr)
            sample=read(folder/'a/pontos_rank0.csv')
            self.assertEqual(len(sample),10000)
            self.assertEqual(len({p['global_index'] for p in sample}),10000)
            self.assertEqual(sample,read(folder/'b/pontos_rank0.csv'))
            self.assertEqual(int(read(folder/'a/centroides.csv')[0]['tweets']),10020)

    def test_processos_sem_pontos_locais(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d);source=folder/'unico.csv';source.write_text('x_m,y_m,timestamp_seconds,timezone\n1,2,0,1\n')
            run=self.run_mpi(source,1,4,folder/'export')
            self.assertEqual(run.returncode,0,run.stderr)
            parts=[read(folder/f'export/pontos_rank{i}.csv') for i in range(4)]
            self.assertEqual(sum(map(len,parts)),1)
            self.assertTrue(any(not p for p in parts))

if __name__=='__main__':unittest.main(verbosity=2)
