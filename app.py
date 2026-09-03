import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from fpdf import FPDF
import tempfile
import os
from datetime import datetime
import numpy as np

# ---------- CONFIGURACIÓN ----------
st.set_page_config(page_title="Sistema de Estimaciones", layout="wide")
st.title("🚧 Sistema de Estimaciones Inteligente")

# ---------- CARGA DE ARCHIVO EXCEL ----------
st.sidebar.header("📂 Cargar datos")
archivo = st.sidebar.file_uploader(
    "Sube tu archivo Excel con los grupos de trabajo",
    type=["xlsx", "xls"]
)

# Datos por defecto
DATOS_POR_DEFECTO = {
    "Grupo": [
        "TERRACERÍAS", "PILOTES Y CIMENTACIONES", "PILAS Y ESTRIBOS",
        "TRABES PREFABRICADAS", "LOSA SUPERIOR", "APARATOS DE APOYO",
        "BARRERAS Y PROTECCIONES", "DRENAJE Y PAVIMENTO", "SEÑALAMIENTO"
    ],
    "Ejecutado (MXN)": [
        801050.00, 6626640.00, 3526750.00, 3541102.50,
        0.00, 0.00, 0.00, 0.00, 0.00
    ],
    "Total (MXN)": [
        1055050.00, 8154550.00, 5745550.00, 23565500.00,
        6605010.00, 1715000.00, 2724290.00, 1083430.00, 199445.00
    ],
    "Avance Esperado %": [
        70.0, 75.0, 60.0, 25.0, 10.0, 5.0, 5.0, 5.0, 5.0
    ]
}

if archivo is None:
    st.info("👈 Sube un archivo Excel para ver tus datos reales. Mostrando datos de ejemplo...")
    df_grupos = pd.DataFrame(DATOS_POR_DEFECTO)
    nombre_proyecto = "Puente Carretero — Pilas y Trabes Prefabricadas"
else:
    try:
        df_grupos = pd.read_excel(archivo)
        st.sidebar.success("✅ Datos cargados correctamente")
        nombre_proyecto = st.sidebar.text_input("Nombre del proyecto", "Proyecto sin nombre")
    except Exception as e:
        st.sidebar.error(f"❌ Error al leer el archivo: {e}")
        st.stop()

# Calcular porcentajes
if "Avance %" not in df_grupos.columns:
    df_grupos["Avance %"] = (df_grupos["Ejecutado (MXN)"] / df_grupos["Total (MXN)"]) * 100
    df_grupos["Avance %"] = df_grupos["Avance %"].round(1)

if "Avance Esperado %" not in df_grupos.columns:
    df_grupos["Avance Esperado %"] = df_grupos["Avance %"]

# ---------- MÉTRICAS ----------
total_contrato = df_grupos["Total (MXN)"].sum()
total_ejecutado = df_grupos["Ejecutado (MXN)"].sum()
porcentaje_global = (total_ejecutado / total_contrato) * 100

col1, col2, col3, col4 = st.columns(4)
col1.metric("Monto del Contrato", f"${total_contrato:,.2f}")
col2.metric("Monto Ejecutado", f"${total_ejecutado:,.2f}", delta=f"{porcentaje_global:.1f}%")
col3.metric("Por Ejecutar", f"${total_contrato - total_ejecutado:,.2f}")
col4.metric("Grupos", len(df_grupos))

# ---------- TABLA ----------
st.subheader("📋 Avance por Grupo de Trabajo")

def color_avance(val):
    if val >= 50:
        return 'background-color: #90EE90'
    elif val >= 20:
        return 'background-color: #FFD700'
    else:
        return 'background-color: #FFB6C1'

df_mostrar = df_grupos.copy()
df_mostrar["Desviación"] = df_mostrar["Avance %"] - df_mostrar["Avance Esperado %"]
styled_df = df_mostrar.style.map(color_avance, subset=['Avance %'])
styled_df = styled_df.format({
    'Ejecutado (MXN)': '${:,.2f}',
    'Total (MXN)': '${:,.2f}',
    'Avance %': '{:.1f}%',
    'Avance Esperado %': '{:.1f}%',
    'Desviación': '{:+.1f}%'
})
st.dataframe(styled_df, width='stretch', height=400)

# ---------- GRÁFICOS ----------
st.subheader("📊 Comparativo de Monto Ejecutado vs Total por Grupo")
df_grafico = df_grupos.copy()
df_grafico["Ejecutado (Millones)"] = df_grafico["Ejecutado (MXN)"] / 1_000_000
df_grafico["Total (Millones)"] = df_grafico["Total (MXN)"] / 1_000_000

fig = px.bar(
    df_grafico,
    x="Grupo",
    y=["Ejecutado (Millones)", "Total (Millones)"],
    barmode="group",
    labels={"value": "Monto (Millones MXN)", "variable": "Concepto"},
    color_discrete_map={"Ejecutado (Millones)": "#1f77b4", "Total (Millones)": "#ff7f0e"}
)
fig.update_layout(xaxis_tickangle=-45, legend_title_text='', height=500, plot_bgcolor='rgba(0,0,0,0)')
st.plotly_chart(fig, width='stretch')

# ---------- DETECCIÓN DE ANOMALÍAS ----------
st.subheader("🚨 Detección de Anomalías")
df_grupos["Desviación"] = df_grupos["Avance %"] - df_grupos["Avance Esperado %"]
grupos_riesgo = df_grupos[df_grupos["Desviación"] < -10]

if len(grupos_riesgo) > 0:
    st.warning(f"⚠️ **{len(grupos_riesgo)} grupos** están retrasados:")
    for _, row in grupos_riesgo.iterrows():
        st.write(f"- **{row['Grupo']}**: {row['Avance %']:.1f}% vs {row['Avance Esperado %']:.1f}% esperado")
else:
    st.success("✅ Todos los grupos están en parámetros esperados.")

# ---------- PIE DE PÁGINA ----------
st.divider()
st.caption("Sistema de Estimaciones v2.0 — Con IA Predictiva")
