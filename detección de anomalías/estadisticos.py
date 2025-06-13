import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Configurar matplotlib para mostrar caracteres especiales
plt.rcParams['font.size'] = 10
plt.rcParams['figure.figsize'] = (12, 8)

def analizar_datos_facturacion(archivo_csv):
    """
    Función para realizar análisis estadístico completo de datos de facturación
    """
    
    # Leer el archivo CSV
    try:
        df = pd.read_csv(archivo_csv)
        print("✅ Archivo CSV cargado exitosamente")
        print(f"📊 Dimensiones del dataset: {df.shape[0]} filas x {df.shape[1]} columnas")
    except Exception as e:
        print(f"❌ Error al cargar el archivo: {e}")
        return
    
    print("\n" + "="*80)
    print("📋 INFORMACIÓN GENERAL DEL DATASET")
    print("="*80)
    
    # Información básica del dataset
    print(f"Columnas: {list(df.columns)}")
    print(f"\nTipos de datos:")
    print(df.dtypes)
    
    print(f"\nPrimeras 5 filas:")
    print(df.head())
    
    print(f"\nÚltimas 5 filas:")
    print(df.tail())
    
    # Información sobre valores faltantes
    print(f"\n📊 VALORES FALTANTES:")
    valores_faltantes = df.isnull().sum()
    print(valores_faltantes[valores_faltantes > 0] if valores_faltantes.sum() > 0 else "No hay valores faltantes")
    
    print("\n" + "="*80)
    print("📈 ESTADÍSTICOS DESCRIPTIVOS - VARIABLES NUMÉRICAS")
    print("="*80)
    
    # Identificar columnas numéricas (excluyendo fechas)
    columnas_numericas = df.select_dtypes(include=[np.number]).columns.tolist()
    
    if columnas_numericas:
        print("Variables numéricas encontradas:", columnas_numericas)
        
        # Estadísticos descriptivos básicos
        estadisticos_desc = df[columnas_numericas].describe()
        print("\n📊 ESTADÍSTICOS DESCRIPTIVOS BÁSICOS:")
        print(estadisticos_desc.round(2))
        
        # Estadísticos adicionales
        print("\n📊 ESTADÍSTICOS ADICIONALES:")
        for col in columnas_numericas:
            print(f"\n--- {col} ---")
            serie = df[col].dropna()
            
            print(f"Moda: {serie.mode().iloc[0] if not serie.mode().empty else 'N/A'}")
            print(f"Varianza: {serie.var():.2f}")
            print(f"Desviación estándar: {serie.std():.2f}")
            print(f"Coeficiente de variación: {(serie.std()/serie.mean()*100):.2f}%")
            print(f"Asimetría (Skewness): {serie.skew():.2f}")
            print(f"Curtosis: {serie.kurtosis():.2f}")
            print(f"Rango: {serie.max() - serie.min():.2f}")
            print(f"Rango intercuartílico (IQR): {serie.quantile(0.75) - serie.quantile(0.25):.2f}")
            
            # Percentiles adicionales
            percentiles = [5, 10, 25, 50, 75, 90, 95]
            print("Percentiles:")
            for p in percentiles:
                print(f"  P{p}: {serie.quantile(p/100):.2f}")
    
    print("\n" + "="*80)
    print("📊 ESTADÍSTICOS DESCRIPTIVOS - VARIABLES CATEGÓRICAS")
    print("="*80)
    
    # Variables categóricas
    columnas_categoricas = df.select_dtypes(include=['object']).columns.tolist()
    
    if columnas_categoricas:
        print("Variables categóricas encontradas:", columnas_categoricas)
        
        for col in columnas_categoricas:
            print(f"\n--- {col} ---")
            conteos = df[col].value_counts()
            print(f"Valores únicos: {df[col].nunique()}")
            print(f"Valor más frecuente: {conteos.index[0]} (aparece {conteos.iloc[0]} veces)")
            print("Top 10 valores más frecuentes:")
            print(conteos.head(10))
            
            # Porcentajes
            porcentajes = df[col].value_counts(normalize=True) * 100
            print("\nPorcentajes (Top 5):")
            print(porcentajes.head().round(2))
    
    print("\n" + "="*80)
    print("🔍 ANÁLISIS DE CORRELACIONES")
    print("="*80)
    
    if len(columnas_numericas) > 1:
        correlaciones = df[columnas_numericas].corr()
        print("Matriz de correlaciones:")
        print(correlaciones.round(3))
        
        # Correlaciones más altas
        print("\n🔝 CORRELACIONES MÁS ALTAS (en valor absoluto):")
        correlaciones_flat = correlaciones.abs().unstack()
        correlaciones_flat = correlaciones_flat[correlaciones_flat < 1.0]  # Excluir autocorrelaciones
        correlaciones_ordenadas = correlaciones_flat.sort_values(ascending=False)
        
        for i, (variables, corr) in enumerate(correlaciones_ordenadas.head(10).items()):
            print(f"{i+1}. {variables[0]} vs {variables[1]}: {corr:.3f}")
    
    print("\n" + "="*80)
    print("📊 ANÁLISIS DE OUTLIERS (Método IQR)")
    print("="*80)
    
    for col in columnas_numericas:
        serie = df[col].dropna()
        Q1 = serie.quantile(0.25)
        Q3 = serie.quantile(0.75)
        IQR = Q3 - Q1
        limite_inferior = Q1 - 1.5 * IQR
        limite_superior = Q3 + 1.5 * IQR
        
        outliers = serie[(serie < limite_inferior) | (serie > limite_superior)]
        
        print(f"\n--- {col} ---")
        print(f"Límite inferior: {limite_inferior:.2f}")
        print(f"Límite superior: {limite_superior:.2f}")
        print(f"Número de outliers: {len(outliers)} ({len(outliers)/len(serie)*100:.2f}%)")
        
        if len(outliers) > 0:
            print(f"Outliers más extremos:")
            print(f"  Mínimo: {outliers.min():.2f}")
            print(f"  Máximo: {outliers.max():.2f}")
    
    print("\n" + "="*80)
    print("🎯 RESUMEN EJECUTIVO")
    print("="*80)
    
    print(f"📋 Dataset con {df.shape[0]:,} registros y {df.shape[1]} variables")
    print(f"📊 Variables numéricas: {len(columnas_numericas)}")
    print(f"📝 Variables categóricas: {len(columnas_categoricas)}")
    print(f"❌ Valores faltantes: {df.isnull().sum().sum()}")
    
    if columnas_numericas:
        # Variable con mayor variabilidad
        cv_max = 0
        var_max_cv = ""
        for col in columnas_numericas:
            cv = df[col].std() / df[col].mean() * 100
            if cv > cv_max:
                cv_max = cv
                var_max_cv = col
        
        print(f"🔥 Variable con mayor variabilidad: {var_max_cv} (CV: {cv_max:.2f}%)")
    
    return df

def crear_visualizaciones(df):
    """
    Crear visualizaciones básicas de los datos
    """
    columnas_numericas = df.select_dtypes(include=[np.number]).columns.tolist()
    
    if not columnas_numericas:
        print("No hay variables numéricas para visualizar")
        return
    
    # Configurar el estilo
    plt.style.use('default')
    
    # Crear subplots
    n_cols = min(3, len(columnas_numericas))
    n_rows = (len(columnas_numericas) + n_cols - 1) // n_cols
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(15, 5*n_rows))
    axes = axes.flatten() if n_rows > 1 else [axes] if n_rows == 1 else axes
    
    # Histogramas
    for i, col in enumerate(columnas_numericas):
        if i < len(axes):
            axes[i].hist(df[col].dropna(), bins=30, alpha=0.7, edgecolor='black')
            axes[i].set_title(f'Distribución de {col}')
            axes[i].set_xlabel(col)
            axes[i].set_ylabel('Frecuencia')
    
    # Ocultar axes vacíos
    for i in range(len(columnas_numericas), len(axes)):
        axes[i].set_visible(False)
    
    plt.tight_layout()
    plt.show()
    
    # Boxplots
    if len(columnas_numericas) > 1:
        fig, ax = plt.subplots(figsize=(12, 6))
        df[columnas_numericas].boxplot(ax=ax)
        ax.set_title('Boxplots de Variables Numéricas')
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.show()

# Ejemplo de uso
if __name__ == "__main__":
    # Cambia 'tu_archivo.csv' por la ruta de tu archivo
    archivo = 'reporte.csv'  # Reemplaza con la ruta de tu archivo
    
    print("🚀 INICIANDO ANÁLISIS ESTADÍSTICO")
    print("="*80)
    
    # Realizar análisis
    df = analizar_datos_facturacion(archivo)
    
    if df is not None:
        # Crear visualizaciones (opcional)
        respuesta = input("\n¿Deseas crear visualizaciones? (s/n): ")
        if respuesta.lower() in ['s', 'si', 'sí', 'y', 'yes']:
            crear_visualizaciones(df)
    
    print("\n✅ ANÁLISIS COMPLETADO")