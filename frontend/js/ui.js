/* Helpers de DOM y formato reutilizables. */

const ESTADOS = [
  { key: "Registrada", label: "Registrada", badge: "badge-warning" },
  { key: "Confirmada", label: "Confirmada", badge: "badge-info" },
  { key: "Atendida", label: "Atendida", badge: "badge-success" },
  { key: "No asistio", label: "No asistió", badge: "badge-gray" },
  { key: "Cancelada", label: "Cancelada", badge: "badge-danger" },
];

const DIA_NOMBRES = { 1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo" };

function esc(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function hoyISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate()
  ).padStart(2, "0")}`;
}

function fechaISO(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate()
  ).padStart(2, "0")}`;
}

function fmtFecha(iso) {
  if (!iso) return "";
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("es-ES", {
    weekday: "short",
    day: "2-digit",
    month: "short",
  });
}

function fmtFechaCorta(iso) {
  if (!iso) return "";
  const [y, m, d] = iso.split("-").map(Number);
  return `${String(d).padStart(2, "0")}/${String(m).padStart(2, "0")}/${y}`;
}

function fmtHora(t) {
  if (!t) return "";
  return String(t).slice(0, 5);
}

function badgeEstado(estado) {
  const e = ESTADOS.find((x) => x.key === estado) || ESTADOS[0];
  return `<span class="badge ${e.badge}">${esc(e.label)}</span>`;
}

function badgeTipo(tipo) {
  if (tipo === "Asegurado") return `<span class="badge badge-info">Asegurado</span>`;
  if (tipo === "Asegurado vencido") return `<span class="badge badge-danger">Asegurado vencido</span>`;
  return `<span class="badge badge-gray">${esc(tipo || "Particular")}</span>`;
}

function toast(message, type = "success") {
  const cont = document.getElementById("toastContainer");
  const el = document.createElement("div");
  el.className = `toast ${type}`;
  el.textContent = message;
  cont.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

function mostrarModal(id) {
  const m = document.getElementById(id);
  if (m) m.hidden = false;
}

function cerrarModal(id) {
  const m = document.getElementById(id);
  if (m) m.hidden = true;
}

function procesarDiaSemana(n) {
  return DIA_NOMBRES[n] || String(n);
}

function fillFechaInput(id, iso) {
  const el = document.getElementById(id);
  if (el && el.value === "") el.value = iso;
}

/* ============================================================
   Exportación a Excel (.xls nativo, sin librerías) con
   previsualización previa en un modal.
   ============================================================ */

function _xlsEscapeXML(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function _xlsCell(value, isNumber) {
  if (isNumber && Number.isFinite(value)) {
    return `<Cell><Data ss:Type="Number">${value}</Data></Cell>`;
  }
  return `<Cell><Data ss:Type="String">${_xlsEscapeXML(value)}</Data></Cell>`;
}

function _filenamizar(nombre) {
  const limpio = String(nombre || "reporte").replace(/[\\/:*?"<>|]/g, "_").trim();
  return limpio ? limpio : "reporte";
}

function _xlsBlob(nombreHoja, columnas, filas, titulo) {
  const nCols = columnas.length;
  let filasXml = "";

  if (titulo) {
    filasXml += `<Row><Cell ss:MergeAcross="${nCols - 1}"><Data ss:Type="String">${_xlsEscapeXML(
      titulo
    )}</Data></Cell></Row>`;
  }

  filasXml += "<Row>" + columnas.map((c) => `<Cell><Data ss:Type="String">${_xlsEscapeXML(c.label)}</Data></Cell>`).join("") + "</Row>";

  filas.forEach((fila) => {
    filasXml +=
      "<Row>" +
      columnas
        .map((c, i) => {
          const raw = fila[i];
          return _xlsCell(raw, c.type === "number" && typeof raw === "number");
        })
        .join("") +
      "</Row>";
  });

  const xml = `<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Bottom"/>
   <Font ss:FontName="Calibri" ss:Size="11"/>
  </Style>
  <Style ss:ID="Titulo">
   <Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/>
  </Style>
  <Style ss:ID="Encabezado">
   <Font ss:Bold="1"/>
   <Interior ss:Color="#D9E1F2" ss:Pattern="Solid"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="${_xlsEscapeXML(nombreHoja)}">
  <Table>
   ${filasXml}
  </Table>
 </Worksheet>
</Workbook>`;

  return new Blob(["\uFEFF" + xml], {
    type: "application/vnd.ms-excel;charset=utf-8",
  });
}

function descargarBlob(blob, nombreArchivo) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nombreArchivo;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

let _xlsDescargarHandler = null;

function cerrarPrevisualizacionExcel() {
  _xlsDescargarHandler = null;
  cerrarModal("modalExcelPrev");
}

/**
 * Abre el modal de previsualización y (tras confirmar) descarga el .xls.
 * @param {Object} opt
 *  - titulo: string (encabezado dentro de la hoja)
 *  - info:   string (texto explicativo bajo el título del modal)
 *  - nombreArchivo: string
 *  - nombreHoja: string (nombre de la pestaña de Excel)
 *  - columnas: [{label, type?}]
 *  - filas:   array de arrays
 */
function abrirPrevisualizacionExcel(opt) {
  const columnas = opt.columnas || [];
  const filas = opt.filas || [];
  const nombreArchivo = _filenamizar(opt.nombreArchivo);
  const nombreHoja = _filenamizar(opt.nombreHoja || "Datos");

  document.getElementById("xlsPrevTitulo").textContent = opt.titulo || "Previsualización";
  document.getElementById("xlsPrevInfo").textContent =
    `${filas.length} fila(s) · ${columnas.length} columna(s) · ${opt.info || ""}`.trim();

  document.getElementById("xlsPrevHead").innerHTML =
    "<tr>" + columnas.map((c) => `<th>${esc(c.label)}</th>`).join("") + "</tr>";
  document.getElementById("xlsPrevBody").innerHTML = filas
    .map(
      (fila) =>
        "<tr>" +
        columnas.map((c, i) => `<td>${esc(fila[i])}</td>`).join("") +
        "</tr>"
    )
    .join("");

  _xlsDescargarHandler = () => {
    const blob = _xlsBlob(nombreHoja, columnas, filas, opt.titulo);
    descargarBlob(blob, nombreArchivo + ".xls");
    cerrarPrevisualizacionExcel();
  };

  mostrarModal("modalExcelPrev");
}

document.addEventListener("DOMContentLoaded", () => {
  const btn = document.getElementById("xlsPrevDescargar");
  const closeBtns = document.querySelectorAll('[data-close-modal="modalExcelPrev"]');
  if (btn) btn.addEventListener("click", () => _xlsDescargarHandler && _xlsDescargarHandler());
  closeBtns.forEach((b) => b.addEventListener("click", cerrarPrevisualizacionExcel));
});