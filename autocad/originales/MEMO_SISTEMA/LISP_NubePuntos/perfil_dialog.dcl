perfil_dlg : dialog {
  label = "PERFIL - Secciones Transversales Batimetricas";

  : column {
    : boxed_column {
      label = "Parametros de Busqueda";
      : edit_box {
        label = "Ancho de busqueda perpendicular:";
        key = "ancho";
        edit_width = 12;
        value = "5.0";
      }
      : edit_box {
        label = "Radio de busqueda texto estacion:";
        key = "radio_texto";
        edit_width = 12;
        value = "15.0";
      }
    }
    : boxed_column {
      label = "Escala y Retricula";
      : edit_box {
        label = "Escala vertical:";
        key = "escala_v";
        edit_width = 12;
        value = "1.0";
      }
      : edit_box {
        label = "Espaciado de reticula:";
        key = "esp_reticula";
        edit_width = 12;
        value = "5.0";
      }
      : edit_box {
        label = "Elevacion de referencia:";
        key = "elev_ref";
        edit_width = 12;
        value = "0.0";
      }
    }
    : boxed_column {
      label = "Disposicion en Columnas";
      : edit_box {
        label = "Espacio entre secciones:";
        key = "esp_entre_sec";
        edit_width = 12;
        value = "40.0";
      }
      : edit_box {
        label = "Secciones por columna:";
        key = "sec_por_col";
        edit_width = 12;
        value = "5";
      }
    }
  }

  : row {
    : button {
      label = "Aceptar";
      key = "aceptar";
      width = 12;
      fixed_width = true;
      is_default = true;
    }
    : button {
      label = "Cancelar";
      key = "cancelar";
      width = 12;
      fixed_width = true;
      is_cancel = true;
    }
  }
}