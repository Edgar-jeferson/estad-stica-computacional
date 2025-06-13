import pandas as pd
import numpy as np
import optuna
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

class FastAnomalyDetector:
    def __init__(self, csv_file='reporte.csv'):
   
        self.data = None
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
        self.best_params = None
        self.patterns_found = {}
        
        print("🔍 Iniciando sistema de detección de anomalías...")
        self.load_and_preprocess_data(csv_file)
        
    def load_and_preprocess_data(self, csv_file):
    
        try:
            print("📂 Cargando dataset...")
            # Cargar con optimizaciones para datasets grandes
            self.data = pd.read_csv(csv_file, dtype={'CONSUMO': 'float32', 'FACTURACIÓN': 'float32'})
            print(f"✅ Datos cargados: {self.data.shape[0]:,} registros")
            
            # Preprocesamiento rápido
            self.data['FECHA_ALTA'] = pd.to_datetime(self.data['FECHA_ALTA'], format='%d/%m/%Y', errors='coerce')
            self.data['MES'] = self.data['FECHA_ALTA'].dt.month
            self.data['AÑO'] = self.data['FECHA_ALTA'].dt.year
            self.data['TRIMESTRE'] = self.data['FECHA_ALTA'].dt.quarter
            
            # Codificar distrito para patrones geográficos
            self.data['DISTRITO_ENCODED'] = self.label_encoder.fit_transform(self.data['DISTRITO'].astype(str))
            
            # Crear ratios para detectar patrones
            self.data['RATIO_CONSUMO_FACTURA'] = self.data['CONSUMO'] / (self.data['FACTURACIÓN'] + 0.01)
            self.data['CONSUMO_LOG'] = np.log1p(self.data['CONSUMO'])
            
            # Características optimizadas
            self.features = ['CONSUMO', 'FACTURACIÓN', 'RATIO_CONSUMO_FACTURA', 
                           'MES', 'TRIMESTRE', 'DISTRITO_ENCODED']
            
            # Eliminar outliers extremos (valores imposibles)
            self.data = self.data[(self.data['CONSUMO'] >= 0) & (self.data['FACTURACIÓN'] >= 0)]
            
            print("🔧 Preprocesamiento completado")
            
        except Exception as e:
            print(f"❌ Error al cargar datos: {e}")
            
    def detect_patterns_fast(self):
        """Detección rápida de patrones en el dataset"""
        print("🧠 Analizando patrones en el dataset...")
        
        patterns = {}
        
        # Patrón 1: Consumo vs Facturación
        correlation = self.data['CONSUMO'].corr(self.data['FACTURACIÓN'])
        patterns['correlacion_consumo_factura'] = correlation
        
        # Patrón 2: Estacionalidad por mes
        monthly_avg = self.data.groupby('MES')['CONSUMO'].mean()
        patterns['mes_mayor_consumo'] = monthly_avg.idxmax()
        patterns['mes_menor_consumo'] = monthly_avg.idxmin()
        patterns['variacion_estacional'] = (monthly_avg.max() - monthly_avg.min()) / monthly_avg.mean()
        
        # Patrón 3: Distribución por distrito
        district_stats = self.data.groupby('DISTRITO')['CONSUMO'].agg(['mean', 'std', 'count'])
        patterns['distrito_mayor_consumo'] = district_stats['mean'].idxmax()
        patterns['distrito_menor_consumo'] = district_stats['mean'].idxmin()
        
        # Patrón 4: Detección de clustering rápido
        sample_data = self.data.sample(n=min(5000, len(self.data)), random_state=42)
        kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
        sample_features = sample_data[['CONSUMO', 'FACTURACIÓN']].fillna(0)
        clusters = kmeans.fit_predict(sample_features)
        
        cluster_means = []
        for i in range(3):
            cluster_data = sample_data[clusters == i]
            cluster_means.append(cluster_data['CONSUMO'].mean())
        
        patterns['clusters_consumo'] = {
            'bajo': min(cluster_means),
            'medio': sorted(cluster_means)[1],
            'alto': max(cluster_means)
        }
        
        self.patterns_found = patterns
        print("✅ Patrones detectados exitosamente")
        return patterns
    
    def objective_fast(self, trial):
        """Función objetivo optimizada para datasets grandes"""
        # Hiperparámetros con rangos optimizados
        n_estimators = trial.suggest_int('n_estimators', 50, 150)  # Reducido para velocidad
        contamination = trial.suggest_float('contamination', 0.005, 0.05)  # Más específico
        max_samples = trial.suggest_categorical('max_samples', [0.3, 0.5, 0.7])  # Discreto
        
        # Usar muestra para optimización rápida
        sample_size = min(10000, len(self.data))
        sample_data = self.data.sample(n=sample_size, random_state=42)
        
        X = sample_data[self.features].fillna(0)
        X_scaled = StandardScaler().fit_transform(X)
        
        # Modelo optimizado
        model = IsolationForest(
            n_estimators=n_estimators,
            contamination=contamination,
            max_samples=max_samples,
            random_state=42,
            n_jobs=-1  # Paralelización
        )
        
        predictions = model.fit_predict(X_scaled)
        anomaly_scores = model.decision_function(X_scaled)
        
        # Métrica: balance entre detección y estabilidad
        score = np.mean(anomaly_scores) + np.std(anomaly_scores) * 0.1
        
        return score
    
    def optimize_fast(self, n_trials=20):
        """Optimización rápida con menos trials"""
        print("⚡ Optimizando hiperparámetros (modo rápido)...")
        
        study = optuna.create_study(direction='maximize')
        study.optimize(self.objective_fast, n_trials=n_trials, show_progress_bar=True)
        
        self.best_params = study.best_params
        print(f"🎯 Mejores parámetros encontrados")
        return study
    
    def detect_anomalies_fast(self):
        """Detección rápida de anomalías en todo el dataset"""
        print("🚀 Ejecutando detección de anomalías...")
        
        if self.best_params is None:
            # Usar parámetros por defecto optimizados
            self.best_params = {
                'n_estimators': 100,
                'contamination': 0.02,
                'max_samples': 0.5
            }
        
        # Preparar datos completos
        X = self.data[self.features].fillna(0)
        X_scaled = self.scaler.fit_transform(X)
        
        # Modelo final optimizado
        self.model = IsolationForest(
            n_estimators=self.best_params['n_estimators'],
            contamination=self.best_params['contamination'],
            max_samples=self.best_params['max_samples'],
            random_state=42,
            n_jobs=-1
        )
        
        # Entrenar y predecir
        predictions = self.model.fit_predict(X_scaled)
        scores = self.model.decision_function(X_scaled)
        
        # Agregar resultados
        self.data['ES_ANOMALIA'] = predictions == -1
        self.data['SCORE_ANOMALIA'] = scores
        
        anomalies_count = np.sum(predictions == -1)
        print(f"✅ Detección completada: {anomalies_count:,} anomalías encontradas")
        
        return anomalies_count > 0
    
    def quick_report(self):
        """Reporte rápido de anomalías detectadas"""
        if 'ES_ANOMALIA' not in self.data.columns:
            print("❌ Primero ejecuta la detección de anomalías")
            return
        
        anomalies = self.data[self.data['ES_ANOMALIA'] == True]
        normal = self.data[self.data['ES_ANOMALIA'] == False]
        
        print("\n" + "="*60)
        print("📊 REPORTE RÁPIDO DE ANOMALÍAS")
        print("="*60)
        
        print(f"📈 Total de registros analizados: {len(self.data):,}")
        print(f"🔴 Anomalías detectadas: {len(anomalies):,} ({len(anomalies)/len(self.data)*100:.2f}%)")
        
        if len(anomalies) > 0:
            print(f"⚡ Consumo promedio normal: {normal['CONSUMO'].mean():.2f} kWh")
            print(f"⚠️  Consumo promedio anómalo: {anomalies['CONSUMO'].mean():.2f} kWh")
            print(f"📊 Diferencia: {abs(anomalies['CONSUMO'].mean() - normal['CONSUMO'].mean()):.2f} kWh")
            
            # Top 3 anomalías más extremas
            print("\n🔍 TOP 3 ANOMALÍAS MÁS EXTREMAS:")
            top_anomalies = anomalies.nsmallest(3, 'SCORE_ANOMALIA')
            for i, (_, row) in enumerate(top_anomalies.iterrows(), 1):
                print(f"  {i}. Cliente {row['CORRELATIVO']}: {row['CONSUMO']:.2f} kWh (Score: {row['SCORE_ANOMALIA']:.3f})")
            
            # Distribución por distrito
            if len(anomalies) > 0:
                distrito_anomalias = anomalies['DISTRITO'].value_counts().head(3)
                print(f"\n🏘️  Distritos con más anomalías:")
                for distrito, count in distrito_anomalias.items():
                    print(f"  • {distrito}: {count} casos")
        else:
            print("✅ No se encontraron anomalías significativas")
        
        print("="*60)
    
    def show_pattern_summary(self):
        """Mostrar resumen de patrones encontrados"""
        if not self.patterns_found:
            print("❌ Primero ejecuta detect_patterns_fast()")
            return
        
        patterns = self.patterns_found
        
        print("\n" + "="*60)
        print("🧠 PATRONES IDENTIFICADOS EN EL DATASET")
        print("="*60)
        
        print(f"📈 Correlación Consumo-Facturación: {patterns['correlacion_consumo_factura']:.3f}")
        if patterns['correlacion_consumo_factura'] > 0.7:
            print("  ✅ Correlación fuerte - Datos consistentes")
        elif patterns['correlacion_consumo_factura'] < 0.3:
            print("  ⚠️  Correlación débil - Posibles inconsistencias")
        
        print(f"\n📅 Estacionalidad:")
        print(f"  • Mes de mayor consumo: {patterns['mes_mayor_consumo']}")
        print(f"  • Mes de menor consumo: {patterns['mes_menor_consumo']}")
        print(f"  • Variación estacional: {patterns['variacion_estacional']:.2f}")
        
        print(f"\n🏘️  Distribución Geográfica:")
        print(f"  • Distrito mayor consumo: {patterns['distrito_mayor_consumo']}")
        print(f"  • Distrito menor consumo: {patterns['distrito_menor_consumo']}")
        
        clusters = patterns['clusters_consumo']
        print(f"\n🎯 Clusters de Consumo Identificados:")
        print(f"  • Consumo Bajo: {clusters['bajo']:.2f} kWh")
        print(f"  • Consumo Medio: {clusters['medio']:.2f} kWh")
        print(f"  • Consumo Alto: {clusters['alto']:.2f} kWh")
        
        print("="*60)
    
    def run_complete_analysis(self):
        """Ejecutar análisis completo de forma rápida"""
        print("🚀 INICIANDO ANÁLISIS COMPLETO...")
        
        # 1. Detectar patrones
        self.detect_patterns_fast()
        
        # 2. Optimizar modelo
        self.optimize_fast(n_trials=15)
        
        # 3. Detectar anomalías
        has_anomalies = self.detect_anomalies_fast()
        
        # 4. Mostrar resultados
        self.show_pattern_summary()
        self.quick_report()
        
        # 5. Respuesta rápida
        print(f"\n🎯 RESULTADO FINAL:")
        if has_anomalies:
            print("🔴 SÍ SE ENCONTRARON ANOMALÍAS en el consumo eléctrico")
            print("📋 Revisar el reporte detallado arriba")
        else:
            print("✅ NO se encontraron anomalías significativas")
            print("📊 El patrón de consumo parece normal")
        
        return has_anomalies

# Ejecución rápida
if __name__ == "__main__":
    # Crear detector optimizado
    detector = FastAnomalyDetector('reporte.csv')
    
    # Ejecutar análisis completo
    detector.run_complete_analysis()
    
    # Opcional: Exportar anomalías encontradas
    if 'ES_ANOMALIA' in detector.data.columns:
        anomalies = detector.data[detector.data['ES_ANOMALIA'] == True]
        if len(anomalies) > 0:
            anomalies.to_csv('anomalias_detectadas.csv', index=False)
            print(f"\n💾 Anomalías exportadas a 'anomalias_detectadas.csv'")