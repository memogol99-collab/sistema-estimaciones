import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from fpdf import FPDF
import tempfile
import os
from datetime import datetime
import numpy as np
from io import BytesIO
import base64

# ---------- CONFIGURACIÓN ----------
st.set_page_config(page_title="Sistema de Estimaciones", layout="wide")
st.title("🚧 Sistema de Estimaciones Inteligente")

# ---------- INICIALIZAR SESSION STATE ----------
if 'historial' not in st.session_state:
    st.session_state.historial = []
if 'df_catalogo' not in st.session_state:
    st.session_state.df_catalogo = None
if 'df_estimacion' not in st.session_state:
    st.session_state.df_estimacion = None
if 'comparativa' not in st.session_state:
    st.session_state.comparativa = None

# ---------- FUNCIONES AUXILIARES ----------
def calcular_volumen(row):
    """Calcula el volumen según las columnas disponibles."""
    try:
        if "RESULTADO" in row.index and pd.notna(row["RESULTADO"]):
            return row["RESULTADO"]
        if all(col in row.index for col in ["LARGO", "ANCHO", "ESPESOR"]):
            largo = float(row["LARGO"]) if pd.notna(row["LARGO"]) else 0
            ancho = float(row["ANCHO"]) if pd.notna(row["ANCHO"]) else 0
            espesor = float(row["ESPESOR"]) if pd.notna(row["ESPESOR"]) else 0
            return largo * ancho * espesor
        elif all(col in row.index for col in ["AREA", "ESPESOR"]):
            area = float(row["AREA"]) if pd.notna(row["AREA"]) else 0
            espesor = float(row["ESPESOR"]) if pd.notna(row["ESPESOR"]) else 0
            return area * espesor
        elif all(col in row.index for col in ["LARGO", "ANCHO"]):
            largo = float(row["LARGO"]) if pd.notna(row["LARGO"]) else 0
            ancho = float(row["ANCHO"]) if pd.notna(row["ANCHO"]) else 0
            return largo * ancho
        elif "VOLUMEN" in row.index and pd.notna(row["VOLUMEN"]):
            return row["VOLUMEN"]
        else:
            return 0
    except:
        return 0

def generar_informe_excel(df_errores):
    """Genera un archivo Excel con los errores encontrados."""
    output = BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        df_errores.to_excel(writer, sheet_name="Errores", index=False)
    return output.getvalue()

def generar_pdf_reporte(df_comparativa, nombre_proyecto):
    """Genera un PDF con el reporte de la comparativa."""
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
    
    # Tabla de resultados
    pdf.set_font("Arial", "B", 9)
    pdf.cell(40, 8, txt="Concepto", border=1)
    pdf.cell(35, 8, txt="Generador", border=1)
    pdf.cell(35, 8, txt="Estimado", border=1)
    pdf.cell(30, 8, txt="Diferencia %", border=1)
    pdf.cell(30, 8, txt="Estado", border=1)
    pdf.ln()
    
    pdf.set_font("Arial", "", 8)
    for _, row in df_comparativa.iterrows():
        concepto = str(row.get("Concepto", ""))[:15]
        pdf.cell(40, 6, txt=concepto, border=1)
        pdf.cell(35, 6, txt=f"{row.get('Volumen_Generador', 0):.2f}", border=1)
        pdf.cell(35, 6, txt=f"{row.get('Volumen_Estimado', 0):.2f}", border=1)
        pdf.cell(30, 6, txt=f"{row.get('Diferencia_%', 0):.1f}%", border=1)
        pdf.cell(30, 6, txt=row.get('Estado', ''), border=1)
        pdf.ln()
    
    return pdf.output(dest='S').encode('latin1')

# ---------- DATOS POR DEFECTO ----------
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

# ---------- BARRA LATERAL: NAVEGACIÓN ----------
st.sidebar.header("📋 Navegación")
seccion = st.sidebar.radio(
    "Ir a:",
    ["🏠 Inicio", "📐 Generadores", "📊 Comparativa", "📈 Historial"]
)

# ---------- SECCIÓN 1: INICIO ----------
if seccion == "🏠 Inicio":
    st.subheader("🏠 Bienvenido al Sistema de Estimaciones")
    st.write("""
    Este sistema te permite:
    - 📐 **Cargar tus generadores de volumen** y calcular volúmenes automáticamente.
    - 📊 **Comparar estimaciones** de contratistas contra tus generadores.
    - 📄 **Generar informes** de errores o faltantes.
    - 📈 **Llevar un historial** de avance y ver curvas S.
    """)
    
    if st.session_state.df_catalogo is not None:
        st.success(f"✅ Catálogo cargado: {len(st.session_state.df_catalogo)} conceptos")
    else:
        st.info("📂 Ve a la sección 'Generadores' para cargar tu catálogo.")
    
    if st.session_state.df_estimacion is not None:
        st.success(f"✅ Estimación cargada: {len(st.session_state.df_estimacion)} conceptos")
    else:
        st.info("📂 Ve a la sección 'Comparativa' para cargar una estimación.")

# ---------- SECCIÓN 2: GENERADORES ----------
elif seccion == "📐 Generadores":
    st.subheader("📐 Generadores de Volumen - Catálogo Base")
    
    archivo_catalogo = st.file_uploader(
        "Sube tu archivo Excel con los generadores",
        type=["xlsx", "xls"],
        key="catalogo"
    )
    
    if archivo_catalogo:
        try:
            excel_file = pd.ExcelFile(archivo_catalogo)
            hojas = excel_file.sheet_names
            hoja_catalogo = st.selectbox(
                "Selecciona la hoja con los generadores",
                hojas
            )
            
            df_catalogo = pd.read_excel(archivo_catalogo, sheet_name=hoja_catalogo)
            
            # Normalizar columnas
            columnas_originales = df_catalogo.columns.tolist()
            columnas_normalizadas = {
                col: col.strip().upper().replace(" ", "_") for col in columnas_originales
            }
            df_catalogo = df_catalogo.rename(columns=columnas_normalizadas)
            
            # Calcular volúmenes
            df_catalogo["VOLUMEN_CALCULADO"] = df_catalogo.apply(calcular_volumen, axis=1)
            if "RESULTADO" not in df_catalogo.columns:
                df_catalogo["RESULTADO"] = df_catalogo["VOLUMEN_CALCULADO"]
            
            # Guardar en session_state
            st.session_state.df_catalogo = df_catalogo
            
            st.success(f"✅ Catálogo cargado: {len(df_catalogo)} conceptos")
            
            # Mostrar datos
            st.subheader("📊 Generadores con Volúmenes Calculados")
            columnas_mostrar = [col for col in df_catalogo.columns if col in [
                "EJE", "LARGO", "ANCHO", "AREA", "ESPESOR", "VOLUMEN", "VOLUMEN_CALCULADO", "RESULTADO", "UNIDAD"
            ]]
            if columnas_mostrar:
                st.dataframe(df_catalogo[columnas_mostrar], width='stretch', height=400)
            else:
                st.dataframe(df_catalogo, width='stretch', height=400)
            
            # Resumen por EJE
            if "EJE" in df_catalogo.columns:
                st.subheader("📊 Resumen por Eje")
                resumen_eje = df_catalogo.groupby("EJE")["RESULTADO"].sum().reset_index()
                resumen_eje.columns = ["EJE", "VOLUMEN_TOTAL"]
                st.dataframe(resumen_eje)
            
            # Descargar
            output = BytesIO()
            with pd.ExcelWriter(output, engine='openpyxl') as writer:
                df_catalogo.to_excel(writer, sheet_name="Generadores_Procesados", index=False)
            st.download_button(
                label="📥 Descargar catálogo procesado",
                data=output.getvalue(),
                file_name="catalogo_generadores_procesado.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
            
        except Exception as e:
            st.error(f"❌ Error al leer el archivo: {e}")

# ---------- SECCIÓN 3: COMPARATIVA ----------
elif seccion == "📊 Comparativa":
    st.subheader("📊 Comparativa: Catálogo vs Estimación")
    
    # Verificar si hay catálogo cargado
    if st.session_state.df_catalogo is None:
        st.warning("⚠️ No hay catálogo cargado. Carga uno en la sección 'Generadores'.")
        st.info("💡 Si no tienes un catálogo, sube un archivo Excel con tus generadores.")
        # No usamos datos por defecto para evitar errores
        st.stop()
    
    df_catalogo = st.session_state.df_catalogo
    st.success(f"✅ Catálogo cargado: {len(df_catalogo)} conceptos")
    
    # Cargar estimación
    archivo_estimacion = st.file_uploader(
        "Sube la estimación del contratista (Excel)",
        type=["xlsx", "xls"],
        key="estimacion"
    )
    
    if not archivo_estimacion:
        st.info("👈 Sube un archivo Excel para comenzar la comparativa.")
        st.stop()
    
    try:
        excel_est = pd.ExcelFile(archivo_estimacion)
        hojas_est = excel_est.sheet_names
        hoja_est = st.selectbox(
            "Selecciona la hoja con la estimación",
            hojas_est,
            key="hoja_est"
        )
        df_estimacion = pd.read_excel(archivo_estimacion, sheet_name=hoja_est)
        st.session_state.df_estimacion = df_estimacion
        
        st.success(f"✅ Estimación cargada: {len(df_estimacion)} conceptos")
        
        # Mostrar vista previa
        st.subheader("📋 Vista previa de la estimación")
        st.dataframe(df_estimacion.head(10), width='stretch')
        
        # ---------- COMPARATIVA ----------
        st.subheader("📊 Comparativa vs Generadores")
        
        # Identificar columnas clave en la estimación
        columnas_est = df_estimacion.columns.tolist()
        columna_concepto = None
        for col in columnas_est:
            if any(palabra in col.upper() for palabra in ["CONCEPTO", "CODIGO", "EJE", "CLAVE", "DESCRIPCION"]):
                columna_concepto = col
                break
        
        columna_cantidad = None
        for col in columnas_est:
            if any(palabra in col.upper() for palabra in ["CANTIDAD", "VOLUMEN", "RESULTADO", "IMPORTE"]):
                columna_cantidad = col
                break
        
        if columna_concepto is None or columna_cantidad is None:
            st.warning(f"No se pudieron identificar columnas clave. Concepto: {columna_concepto}, Cantidad: {columna_cantidad}")
            st.write("Columnas disponibles en la estimación:", columnas_est)
            st.stop()
        
        # Verificar que el catálogo tenga la columna EJE
        if "EJE" not in df_catalogo.columns:
            st.warning("El catálogo no tiene la columna 'EJE'. No se puede hacer la comparativa.")
            st.stop()
        
        # Hacer la comparativa
        try:
            # Seleccionar columnas del catálogo
            columnas_catalogo = ["EJE", "RESULTADO"]
            if "UNIDAD" in df_catalogo.columns:
                columnas_catalogo.append("UNIDAD")
            
            comparativa = pd.merge(
                df_catalogo[columnas_catalogo],
                df_estimacion[[columna_concepto, columna_cantidad]],
                left_on="EJE",
                right_on=columna_concepto,
                how="outer"
            )
            
            comparativa.rename(columns={
                "RESULTADO": "Volumen_Generador",
                columna_cantidad: "Volumen_Estimado"
            }, inplace=True)
            
            # Calcular diferencias
            comparativa["Diferencia_%"] = (
                (comparativa["Volumen_Estimado"] - comparativa["Volumen_Generador"]) 
                / comparativa["Volumen_Generador"] * 100
            ).round(1)
            comparativa["Diferencia_%"] = comparativa["Diferencia_%"].fillna(0)
            
            comparativa["Estado"] = comparativa["Diferencia_%"].apply(
                lambda x: "⚠️ Revisar" if abs(x) > 10 else "✅ OK"
            )
            
            # Guardar en session_state
            st.session_state.comparativa = comparativa
            
            # Mostrar
            st.dataframe(comparativa, width='stretch', height=400)
            
            # Resumen de errores
            errores = comparativa[comparativa["Estado"] == "⚠️ Revisar"]
            if len(errores) > 0:
                st.warning(f"⚠️ {len(errores)} conceptos con diferencias > 10%")
            else:
                st.success("✅ Todos los conceptos están dentro del rango aceptable (±10%)")
            
            # ---------- GENERAR INFORME ----------
            if len(errores) > 0:
                st.subheader("📄 Generar Informe de Errores")
                
                # Excel
                excel_data = generar_informe_excel(errores)
                st.download_button(
                    label="📥 Descargar informe de errores (Excel)",
                    data=excel_data,
                    file_name="informe_errores.xlsx",
                    mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                )
                
                # PDF
                if st.button("📄 Generar PDF"):
                    try:
                        pdf_data = generar_pdf_reporte(comparativa, "Proyecto")
                        st.download_button(
                            label="📥 Descargar informe (PDF)",
                            data=pdf_data,
                            file_name="informe_estimacion.pdf",
                            mime="application/pdf"
                        )
                    except Exception as e:
                        st.error(f"Error al generar PDF: {e}")
            
            # ---------- APROBAR ----------
            if st.button("✅ Aprobar Estimación"):
                # Agregar al historial
                st.session_state.historial.append({
                    "fecha": datetime.now(),
                    "monto": df_estimacion[columna_cantidad].sum() if columna_cantidad else 0,
                    "conceptos": len(df_estimacion)
                })
                st.success("🎉 Estimación aprobada. Avance actualizado.")
                
                # Mostrar avance acumulado
                total_acumulado = sum([h["monto"] for h in st.session_state.historial])
                st.metric("💰 Avance Acumulado", f"${total_acumulado:,.2f}")
                
        except Exception as e:
            st.error(f"❌ Error al hacer la comparativa: {e}")
            st.write("Detalles del error:", str(e))
            
    except Exception as e:
        st.error(f"❌ Error al leer la estimación: {e}")
        
# ---------- SECCIÓN 4: HISTORIAL ----------
elif seccion == "📈 Historial":
    st.subheader("📈 Historial de Avance")
    
    if len(st.session_state.historial) == 0:
        st.info("Aún no hay estimaciones aprobadas. Ve a 'Comparativa' y aprueba una estimación.")
    else:
        # Mostrar historial
        df_historial = pd.DataFrame(st.session_state.historial)
        st.dataframe(df_historial, width='stretch')
        
        # Curva S
        st.subheader("📈 Curva S de Avance")
        if len(df_historial) > 1:
            fig_curva = go.Figure()
            fig_curva.add_trace(go.Scatter(
                x=df_historial["fecha"],
                y=df_historial["monto"].cumsum(),
                mode='lines+markers',
                name='Avance Acumulado',
                line=dict(color='blue', width=3)
            ))
            fig_curva.update_layout(
                title="Evolución del Avance Financiero",
                xaxis_title="Fecha",
                yaxis_title="Monto Acumulado (MXN)",
                height=400
            )
            st.plotly_chart(fig_curva, width='stretch')
        else:
            st.info("Se necesitan al menos 2 estimaciones aprobadas para ver la curva S.")
        
        # Métricas
        total = sum([h["monto"] for h in st.session_state.historial])
        st.metric("💰 Total Acumulado", f"${total:,.2f}")

# ---------- PIE DE PÁGINA ----------
st.divider()
st.caption("Sistema de Estimaciones v3.1 — Versión robusta con manejo de errores")
