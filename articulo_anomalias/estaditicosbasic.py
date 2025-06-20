import pandas as pd
import numpy as np
from scipy import stats
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

class EstadisticasDataset:
    def __init__(self, archivo_csv):
        """
        Inicializa la clase con el archivo CSV
        
        Args:
            archivo_csv (str): Ruta al archivo CSV
        """
        self.archivo = archivo_csv
        self.df = None
        self.estadisticas = {}
        
    def cargar_datos(self):
        """Carga los datos del archivo CSV"""
        try:
            # Intentar diferentes encodings
            encodings = ['utf-8', 'latin-1', 'iso-8859-1', 'cp1252']
            
            for encoding in encodings:
                try:
                    self.df = pd.read_csv(self.archivo, encoding=encoding)
                    print(f"✅ Archivo cargado exitosamente con encoding: {encoding}")
                    break
                except UnicodeDecodeError:
                    continue
            
            if self.df is None:
                raise Exception("No se pudo cargar el archivo con ningún encoding")
                
            print(f"📊 Dimensiones del dataset: {self.df.shape[0]} filas x {self.df.shape[1]} columnas")
            print(f"📋 Columnas disponibles: {list(self.df.columns)}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error al cargar el archivo: {e}")
            return False
    
    def identificar_columnas(self):
        """Identifica las columnas de CONSUMO y FACTURACIÓN"""
        columnas = {}
        
        # Buscar columnas que contengan 'CONSUMO' o 'FACTURACIÓN'
        for col in self.df.columns:
            col_upper = col.upper()
            if 'CONSUMO' in col_upper:
                columnas['consumo'] = col
            elif 'FACTURACIÓN' in col_upper or 'FACTURACION' in col_upper:
                columnas['facturacion'] = col
        
        return columnas
    
    def calcular_estadisticas(self, columna, nombre_columna):
        """
        Calcula estadísticas descriptivas para una columna
        
        Args:
            columna (pd.Series): Serie de datos
            nombre_columna (str): Nombre de la columna
            
        Returns:
            dict: Diccionario con las estadísticas
        """
        # Convertir a numérico y eliminar valores nulos
        datos = pd.to_numeric(columna, errors='coerce').dropna()
        
        if len(datos) == 0:
            return {"error": "No hay datos numéricos válidos"}
        
        estadisticas = {
            'nombre': nombre_columna,
            'cantidad_datos': len(datos),
            'datos_validos': len(datos),
            'datos_nulos': len(columna) - len(datos),
            
            # Medidas de tendencia central
            'media': datos.mean(),
            'mediana': datos.median(),
            'moda': datos.mode().iloc[0] if not datos.mode().empty else None,
            
            # Medidas de dispersión
            'desviacion_estandar': datos.std(),
            'varianza': datos.var(),
            'rango': datos.max() - datos.min(),
            'rango_intercuartil': datos.quantile(0.75) - datos.quantile(0.25),
            'coeficiente_variacion': (datos.std() / datos.mean()) * 100 if datos.mean() != 0 else 0,
            
            # Valores extremos
            'minimo': datos.min(),
            'maximo': datos.max(),
            
            # Percentiles
            'percentil_25': datos.quantile(0.25),
            'percentil_50': datos.quantile(0.50),
            'percentil_75': datos.quantile(0.75),
            'percentil_90': datos.quantile(0.90),
            'percentil_95': datos.quantile(0.95),
            'percentil_99': datos.quantile(0.99),
            
            # Medidas de forma
            'asimetria': stats.skew(datos),
            'curtosis': stats.kurtosis(datos),
            
            # Errores estándar
            'error_estandar_media': datos.std() / np.sqrt(len(datos)),
            
            # Intervalo de confianza de la media (95%)
            'ic_95_inferior': datos.mean() - 1.96 * (datos.std() / np.sqrt(len(datos))),
            'ic_95_superior': datos.mean() + 1.96 * (datos.std() / np.sqrt(len(datos))),
        }
        
        return estadisticas
    
    def detectar_outliers(self, columna):
        """Detecta outliers usando el método IQR"""
        datos = pd.to_numeric(columna, errors='coerce').dropna()
        
        if len(datos) == 0:
            return []
        
        Q1 = datos.quantile(0.25)
        Q3 = datos.quantile(0.75)
        IQR = Q3 - Q1
        
        limite_inferior = Q1 - 1.5 * IQR
        limite_superior = Q3 + 1.5 * IQR
        
        outliers = datos[(datos < limite_inferior) | (datos > limite_superior)]
        
        return {
            'cantidad_outliers': len(outliers),
            'porcentaje_outliers': (len(outliers) / len(datos)) * 100,
            'limite_inferior': limite_inferior,
            'limite_superior': limite_superior,
            'outliers_valores': outliers.tolist()[:10]  # Solo primeros 10
        }
    
    def generar_reporte(self):
        """Genera el reporte completo de estadísticas"""
        if self.df is None:
            print("❌ Primero debes cargar los datos")
            return
        
        # Identificar columnas
        columnas = self.identificar_columnas()
        
        if not columnas:
            print("❌ No se encontraron columnas de CONSUMO o FACTURACIÓN")
            print("Columnas disponibles:", list(self.df.columns))
            return
        
        print("\n" + "="*80)
        print("📊 REPORTE DE ESTADÍSTICAS DESCRIPTIVAS")
        print("="*80)
        
        # Calcular estadísticas para cada columna encontrada
        for tipo, nombre_col in columnas.items():
            print(f"\n🔍 ANÁLISIS DE {tipo.upper()}: {nombre_col}")
            print("-" * 60)
            
            # Calcular estadísticas
            stats_col = self.calcular_estadisticas(self.df[nombre_col], nombre_col)
            
            if 'error' in stats_col:
                print(f"❌ {stats_col['error']}")
                continue
            
            # Mostrar estadísticas básicas
            print(f"📈 ESTADÍSTICAS BÁSICAS:")
            print(f"   Cantidad de datos: {stats_col['cantidad_datos']:,}")
            print(f"   Datos válidos: {stats_col['datos_validos']:,}")
            print(f"   Datos nulos: {stats_col['datos_nulos']:,}")
            
            print(f"\n📊 MEDIDAS DE TENDENCIA CENTRAL:")
            print(f"   Media: {stats_col['media']:,.2f}")
            print(f"   Mediana: {stats_col['mediana']:,.2f}")
            if stats_col['moda'] is not None:
                print(f"   Moda: {stats_col['moda']:,.2f}")
            
            print(f"\n📏 MEDIDAS DE DISPERSIÓN:")
            print(f"   Desviación estándar: {stats_col['desviacion_estandar']:,.2f}")
            print(f"   Varianza: {stats_col['varianza']:,.2f}")
            print(f"   Rango: {stats_col['rango']:,.2f}")
            print(f"   Rango intercuartil: {stats_col['rango_intercuartil']:,.2f}")
            print(f"   Coeficiente de variación: {stats_col['coeficiente_variacion']:.2f}%")
            
            print(f"\n🎯 VALORES EXTREMOS:")
            print(f"   Mínimo: {stats_col['minimo']:,.2f}")
            print(f"   Máximo: {stats_col['maximo']:,.2f}")
            
            print(f"\n📋 PERCENTILES:")
            print(f"   25%: {stats_col['percentil_25']:,.2f}")
            print(f"   50% (Mediana): {stats_col['percentil_50']:,.2f}")
            print(f"   75%: {stats_col['percentil_75']:,.2f}")
            print(f"   90%: {stats_col['percentil_90']:,.2f}")
            print(f"   95%: {stats_col['percentil_95']:,.2f}")
            print(f"   99%: {stats_col['percentil_99']:,.2f}")
            
            print(f"\n📐 MEDIDAS DE FORMA:")
            print(f"   Asimetría: {stats_col['asimetria']:.4f}")
            if stats_col['asimetria'] > 0:
                print("   → Distribución con sesgo hacia la derecha")
            elif stats_col['asimetria'] < 0:
                print("   → Distribución con sesgo hacia la izquierda")
            else:
                print("   → Distribución simétrica")
            
            print(f"   Curtosis: {stats_col['curtosis']:.4f}")
            if stats_col['curtosis'] > 0:
                print("   → Distribución leptocúrtica (más puntiaguda)")
            elif stats_col['curtosis'] < 0:
                print("   → Distribución platicúrtica (más aplanada)")
            else:
                print("   → Distribución mesocúrtica (normal)")
            
            print(f"\n🎯 INTERVALOS DE CONFIANZA:")
            print(f"   Error estándar de la media: {stats_col['error_estandar_media']:.4f}")
            print(f"   IC 95% de la media: [{stats_col['ic_95_inferior']:,.2f}, {stats_col['ic_95_superior']:,.2f}]")
            
            # Detectar outliers
            outliers_info = self.detectar_outliers(self.df[nombre_col])
            print(f"\n🚨 ANÁLISIS DE OUTLIERS:")
            print(f"   Cantidad de outliers: {outliers_info['cantidad_outliers']}")
            print(f"   Porcentaje de outliers: {outliers_info['porcentaje_outliers']:.2f}%")
            print(f"   Límite inferior: {outliers_info['limite_inferior']:,.2f}")
            print(f"   Límite superior: {outliers_info['limite_superior']:,.2f}")
            
            # Guardar estadísticas
            self.estadisticas[tipo] = stats_col
    
    def generar_graficos(self):
        """Genera gráficos descriptivos"""
        if not self.estadisticas:
            print("❌ Primero debes generar el reporte de estadísticas")
            return
        
        columnas = self.identificar_columnas()
        
        # Configurar el estilo de los gráficos
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")
        
        # Crear figura con subplots
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('Análisis Estadístico - Consumo y Facturación', fontsize=16, fontweight='bold')
        
        for i, (tipo, nombre_col) in enumerate(columnas.items()):
            datos = pd.to_numeric(self.df[nombre_col], errors='coerce').dropna()
            
            # Histograma
            ax1 = axes[i, 0]
            ax1.hist(datos, bins=30, alpha=0.7, color=f'C{i}', edgecolor='black')
            ax1.set_title(f'Distribución - {tipo.capitalize()}')
            ax1.set_xlabel('Valores')
            ax1.set_ylabel('Frecuencia')
            ax1.grid(True, alpha=0.3)
            
            # Box plot
            ax2 = axes[i, 1]
            ax2.boxplot(datos, patch_artist=True, 
                       boxprops=dict(facecolor=f'C{i}', alpha=0.7))
            ax2.set_title(f'Box Plot - {tipo.capitalize()}')
            ax2.set_ylabel('Valores')
            ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.show()
    
    def exportar_estadisticas(self, nombre_archivo="estadisticas_reporte.csv"):
        """Exporta las estadísticas a un archivo CSV"""
        if not self.estadisticas:
            print("❌ Primero debes generar el reporte de estadísticas")
            return
        
        # Convertir estadísticas a DataFrame
        df_stats = pd.DataFrame(self.estadisticas).T
        
        # Guardar en archivo CSV
        df_stats.to_csv(nombre_archivo, index=True)
        print(f"✅ Estadísticas exportadas a: {nombre_archivo}")

def main():
    """Función principal para ejecutar el programa"""
    print("🚀 CALCULADORA DE ESTADÍSTICAS PARA DATASET")
    print("=" * 50)
    
    # Usar directamente el archivo reporte.csv
    archivo = "reporte.csv"
    
    if not Path(archivo).exists():
        print(f"❌ El archivo '{archivo}' no existe en la carpeta actual.")
        print("💡 Asegúrate de que 'reporte.csv' esté en la misma carpeta que este script.")
        return
    
    # Crear instancia y procesar
    calc = EstadisticasDataset(archivo)
    
    if calc.cargar_datos():
        calc.generar_reporte()
        
        # Preguntar si quiere generar gráficos
        respuesta = input("\n📊 ¿Deseas generar gráficos? (s/n): ").lower().strip()
        if respuesta in ['s', 'si', 'sí', 'y', 'yes']:
            try:
                calc.generar_graficos()
            except Exception as e:
                print(f"⚠️ Error al generar gráficos: {e}")
        
        # Preguntar si quiere exportar
        respuesta = input("\n💾 ¿Deseas exportar las estadísticas a CSV? (s/n): ").lower().strip()
        if respuesta in ['s', 'si', 'sí', 'y', 'yes']:
            calc.exportar_estadisticas()

if __name__ == "__main__":
    main()