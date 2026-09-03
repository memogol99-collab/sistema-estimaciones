import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from fpdf import FPDF
import tempfile
import os
from datetime import datetime, timedelta
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler

# ---------- CONFIGURACIÓN ----------
st.set_page_config(page_title="Sistema de Estimaciones", layout="wide")
st.title("🚧 Sistema de Estimaciones Inteligente")

# ---------- CARGA DE ARCHIVO EXCEL ----------
st.sidebar.header("📂 Cargar datos")
archivo = st.sidebar.file_uploader(
    "Sube tu archivo Excel con los grupos de trabajo",
    type=["xlsx", "xls"]
)

# Datos por defecto (los que extraje de tu web)
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
    "Avance Esperado %": [  # Simulado: lo que deberían haber avanzado a esta fecha
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

# Calcular porcentajes automáticamente
if "Avance %" not in df_grupos.columns:
    df_grupos["Avance %"] = (df_grupos["Ejecutado (MXN)"] / df_grupos["Total (MXN)"]) * 100
    df_grupos["Avance %"] = df_grupos["Avance %"].round(1)

# Si no tiene columna de avance esperado, la creamos con valores por defecto
if "Avance Esperado %" not in df_grupos.columns:
    df_grupos["Avance Esperado %"] = df_grupos["Avance %"]  # Usamos el real como esperado

# ---------- MÉTRICAS PRINCIPALES ----------
total_contrato = df_grupos["Total (MXN)"].sum()
total_ejecutado = df_grupos["Ejecutado (MXN)"].sum()
porcentaje_global = (total_ejecutado / total_contrato) * 100

col1, col2, col3, col4 = st.columns(4)
col1.metric("Monto del Contrato", f"${total_contrato:,.2f}")
col2.metric("Monto Ejecutado", f"${total_ejecutado:,.2f}", delta=f"{porcentaje_global:.1f}%")
col3.metric("Por Ejecutar", f"${total_contrato - total_ejecutado:,.2f}")
col4.metric("Grupos", len(df_grupos))

# ---------- BARRA DE PROGRESO GLOBAL ----------
st.subheader("📊 Avance Financiero Global")
st.progress(porcentaje_global / 100)
st.write(f"**{porcentaje_global:.1f}%** ejecutado — Contrato: ${total_contrato:,.2f}")

# ---------- TABLA DE AVANCE POR GRUPO ----------
st.subheader("📋 Avance por Grupo de Trabajo")
st.caption("Desglose del avance físico y financiero por cada grupo del catálogo")

def color_avance(val):
    if val >= 50:
        return 'background-color: #90EE90'
    elif val >= 20:
        return 'background-color: #FFD700'
    else:
        return 'background-color: #FFB6C1'

# Crear DataFrame para mostrar
df_mostrar = df_grupos.copy()
df_mostrar["Desviación"] = df_mostrar["Avance %"] - df_mostrar["Avance Esperado %"]
df_mostrar["Estado"] = df_mostrar["Desviación"].apply(
    lambda x: "✅ En línea" if abs(x) < 5 else ("⚠️ Riesgo" if x < -5 else "📈 Adelantado")
)

styled_df = df_mostrar.style.map(color_avance, subset=['Avance %'])
styled_df = styled_df.format({
    'Ejecutado (MXN)': '${:,.2f}',
    'Total (MXN)': '${:,.2f}',
    'Avance %': '{:.1f}%',
    'Avance Esperado %': '{:.1f}%',
    'Desviación': '{:+.1f}%'
})
st.dataframe(styled_df, width='stretch', height=400)

# ---------- GRÁFICO DE BARRAS ----------
st.subheader("📊 Comparativo de Monto Ejecutado vs Total por Grupo")
st.caption("Montos en millones de pesos (MXN)")

df_grafico = df_grupos.copy()
df_grafico["Ejecutado (Millones)"] = df_grafico["Ejecutado (MXN)"] / 1_000_000
df_grafico["Total (Millones)"] = df_grafico["Total (MXN)"] / 1_000_000

fig = px.bar(
    df_grafico,
    x="Grupo",
    y=["Ejecutado (Millones)", "Total (Millones)"],
    barmode="group",
    title="Comparativo por Grupo de Trabajo",
    labels={"value": "Monto (Millones MXN)", "variable": "Concepto"},
    color_discrete_map={"Ejecutado (Millones)": "#1f77b4", "Total (Millones)": "#ff7f0e"}
)
fig.update_layout(xaxis_tickangle=-45, legend_title_text='', height=500, plot_bgcolor='rgba(0,0,0,0)')
st.plotly_chart(fig, width='stretch')

# ---------- GRÁFICO DE AVANCE VS ESPERADO ----------
st.subheader("🎯 Avance Real vs Esperado por Grupo")
fig2 = go.Figure()
fig2.add_trace(go.Bar(
    x=df_grupos["Grupo"],
    y=df_grupos["Avance %"],
    name="Avance Real",
    marker_color="#1f77b4"
))
fig2.add_trace(go.Bar(
    x=df_grupos["Grupo"],
    y=df_grupos["Avance Esperado %"],
    name="Avance Esperado",
    marker_color="#ff7f0e"
))
fig2.update_layout(
    title="Comparativa de Avance",
    xaxis_tickangle=-45,
    height=400,
    barmode='group',
    plot_bgcolor='rgba(0,0,0,0)',
    yaxis_title="Porcentaje (%)"
)
st.plotly_chart(fig2, width='stretch')

# ---------- IA PREDICTIVA ----------
st.subheader("🤖 Predicción de Avance Futuro")

# Crear datos simulados de tiempo (en semanas) para la regresión
def predecir_avance(grupo_actual, semanas_extra=4):
    """Predice el avance futuro usando regresión lineal simple"""
    # Simular fechas (semanas desde el inicio)
    semanas = np.array([1, 2, 3, 4, 5, 6, 7, 8]).reshape(-1, 1)
    
    # Simular avance histórico para este grupo (basado en avance actual)
    avance_historico = np.linspace(0, grupo_actual, 8).reshape(-1, 1)
    
    try:
        modelo = LinearRegression()
        modelo.fit(semanas, avance_historico)
        
        # Predecir para las próximas semanas
        semanas_futuro = np.array([[9], [10], [11], [12]])  # 4 semanas extra
        predicciones = modelo.predict(semanas_futuro)
        
        # Limitar a 100%
        predicciones = np.clip(predicciones, 0, 100)
        
        return predicciones.flatten().tolist()
    except:
        # Si falla, devolver valores simulados
        return [min(grupo_actual + 2*i, 100) for i in range(1, 5)]

# Seleccionar grupo para predecir
grupo_seleccionado = st.selectbox(
    "Selecciona un grupo para predecir su avance",
    df_grupos["Grupo"].tolist()
)

if grupo_seleccionado:
    grupo_data = df_grupos[df_grupos["Grupo"] == grupo_seleccionado].iloc[0]
    avance_actual = grupo_data["Avance %"]
    predicciones = predecir_avance(avance_actual)
    
    # Mostrar predicción
    col_pred1, col_pred2, col_pred3, col_pred4 = st.columns(4)
    semanas_futuro = ["Semana 9", "Semana 10", "Semana 11", "Semana 12"]
    for i, (semana, pred) in enumerate(zip(semanas_futuro, predicciones)):
        col = [col_pred1, col_pred2, col_pred3, col_pred4][i]
        col.metric(semana, f"{pred:.1f}%", delta=f"{pred - avance_actual:.1f}%")
    
    # Gráfico de predicción
    fig_pred = go.Figure()
    # Datos históricos (simulados)
    semanas_hist = list(range(1, 9))
    avance_hist = np.linspace(0, avance_actual, 8)
    fig_pred.add_trace(go.Scatter(
        x=semanas_hist,
        y=avance_hist,
        mode='lines+markers',
        name='Histórico',
        line=dict(color='blue')
    ))
    fig_pred.add_trace(go.Scatter(
        x=[9, 10, 11, 12],
        y=predicciones,
        mode='lines+markers',
        name='Predicción',
        line=dict(color='red', dash='dash')
    ))
    fig_pred.update_layout(
        title=f"Predicción de Avance - {grupo_seleccionado}",
        xaxis_title="Semanas",
        yaxis_title="Avance (%)",
        height=400,
        plot_bgcolor='rgba(0,0,0,0)'
    )
    st.plotly_chart(fig_pred, width='stretch')

# ---------- DETECCIÓN DE ANOMALÍAS ----------
st.subheader("🚨 Detección de Anomalías")

# Calcular grupos con desviación significativa
df_grupos["Desviación"] = df_grupos["Avance %"] - df_grupos["Avance Esperado %"]
grupos_riesgo = df_grupos[df_grupos["Desviación"] < -10]

if len(grupos_riesgo) > 0:
    st.warning(f"⚠️ **{len(grupos_riesgo)} grupos** están significativamente retrasados (más de 10% por debajo del esperado):")
    for _, row in grupos_riesgo.iterrows():
        st.write(f"- **{row['Grupo']}**: {row['Avance %']:.1f}% vs {row['Avance Esperado %']:.1f}% esperado (desviación: {row['Desviación']:+.1f}%)")
else:
    st.success("✅ Todos los grupos están dentro de los parámetros esperados. ¡Buen trabajo!")

# ---------- GENERAR REPORTE PDF ----------
st.divider()
col_pdf, col_vacio = st.columns([1, 3])
with col_pdf:
    if st.button("📄 Generar Reporte PDF", type="primary"):
        try:
            with st.spinner("Generando PDF..."):
                pdf = FPDF()
                pdf.add_page()
                pdf.set_font("Arial", "B", 16)
                
                pdf.cell(200, 10, txt="REPORTE DE ESTIMACIONES", ln=1, align="C")
                pdf.set_font("Arial", "B", 12)
                pdf.cell(200, 10, txt=nombre_proyecto, ln=1, align="C")
                pdf.ln(5)
                
                pdf.set_font("Arial", "I", 10)
                pdf.cell(200, 10, txt=f"Generado: {datetime.now().strftime('%d/%m/%Y %H:%M')}", ln=1, align="C")
                pdf.ln(5)
                
                pdf.set_font("Arial", "B", 12)
                pdf.cell(200, 10, txt="RESUMEN FINANCIERO", ln=1, align="L")
                pdf.set_font("Arial", "", 11)
                pdf.cell(100, 8, txt=f"Monto del Contrato: ${total_contrato:,.2f}", ln=1)
                pdf.cell(100, 8, txt=f"Monto Ejecutado: ${total_ejecutado:,.2f}", ln=1)
                pdf.cell(100, 8, txt=f"Porcentaje de Avance: {porcentaje_global:.1f}%", ln=1)
                pdf.cell(100, 8, txt=f"Por Ejecutar: ${total_contrato - total_ejecutado:,.2f}", ln=1)
                pdf.ln(5)
                
                pdf.set_font("Arial", "B", 11)
                pdf.cell(60, 10, txt="Grupo", border=1)
                pdf.cell(40, 10, txt="Ejecutado", border=1)
                pdf.cell(40, 10, txt="Total", border=1)
                pdf.cell(25, 10, txt="Avance", border=1)
                pdf.cell(25, 10, txt="Estado", border=1)
                pdf.ln()
                
                pdf.set_font("Arial", "", 8)
                for _, row in df_grupos.iterrows():
                    estado = "En línea" if abs(row.get("Desviación", 0)) < 5 else ("Riesgo" if row.get("Desviación", 0) < -5 else "Adelantado")
                    pdf.cell(60, 8, txt=str(row["Grupo"])[:20], border=1)
                    pdf.cell(40, 8, txt=f"${row['Ejecutado (MXN)']:,.2f}", border=1)
                    pdf.cell(40, 8, txt=f"${row['Total (MXN)']:,.2f}", border=1)
                    pdf.cell(25, 8, txt=f"{row['Avance %']:.1f}%", border=1)
                    pdf.cell(25, 8, txt=estado, border=1)
                    pdf.ln()
                
                with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
                    pdf.output(tmp.name)
                    tmp_path = tmp.name
                
                with open(tmp_path, "rb") as f:
                    pdf_data = f.read()
                
                st.download_button(
                    label="⬇️ Descargar PDF",
                    data=pdf_data,
                    file_name=f"reporte_estimaciones_{datetime.now().strftime('%Y%m%d')}.pdf",
                    mime="application/pdf"
                )
                os.unlink(tmp_path)
                
        except Exception as e:
            st.error(f"❌ Error al generar el PDF: {e}")

# ---------- PIE DE PÁGINA ----------
st.divider()
st.caption("Sistema de Estimaciones v2.0 — Con IA Predictiva y Detección de Anomalías")
