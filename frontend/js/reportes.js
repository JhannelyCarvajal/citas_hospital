/* ============================================================
   Sección Reportes: fichas por rango de fechas, con filtros
   y exportación a CSV.
   ============================================================ */

function initReportes() {
  document.getElementById("repEstado").innerHTML =
    '<option value="">Todos</option>' +
    ESTADOS.map((e) => `<option value="${e.key}">${e.label}</option>`).join("");

  document.getElementById("repMedico").innerHTML =
    '<option value="">Todos</option>' +
    window.STORE.medList
      .map((e) => [e.id_empleado, nombreMedico(e)])
      .sort((a, b) => a[1].localeCompare(b[1]))
      .map(([id, nombre]) => `<option value="${id}">${esc(nombre)}</option>`)
      .join("");

  const hoy = new Date();
  const hace30 = new Date();
  hace30.setDate(hace30.getDate() - 29);
  document.getElementById("repDesde").value = fechaISO(hace30);
  document.getElementById("repHasta").value = fechaISO(hoy);

  document.getElementById("btnGenerar").addEventListener("click", renderReportes);
  document.getElementById("btnImprimir").addEventListener("click", imprimirReporte);
  document.getElementById("btnRepExcel").addEventListener("click", exportarFichasExcel);

  document.getElementById("repDesde").addEventListener("change", () => {
    const desde = document.getElementById("repDesde").value;
    const hasta = document.getElementById("repHasta").value;
    if (desde && hasta && desde > hasta) {
      toast('"Desde" no puede ser mayor que "Hasta"', "error");
      document.getElementById("repDesde").value = hasta;
    }
  });

  document.getElementById("repHasta").addEventListener("change", () => {
    const desde = document.getElementById("repDesde").value;
    const hasta = document.getElementById("repHasta").value;
    if (desde && hasta && hasta < desde) {
      toast('"Hasta" no puede ser menor que "Desde"', "error");
      document.getElementById("repHasta").value = desde;
    }
  });

  renderReportes();
}

function fechaValida(desde, hasta) {
  return !(desde && hasta && desde > hasta);
}

function fichasReporte() {
  const s = window.STORE;
  if (!s) return [];
  const desde = document.getElementById("repDesde").value;
  const hasta = document.getElementById("repHasta").value;
  if (!fechaValida(desde, hasta)) return [];
  const estado = document.getElementById("repEstado").value;
  const medico = document.getElementById("repMedico").value;

  return (s.fichas || [])
    .filter((f) => {
      if (desde && f.fech_cita < desde) return false;
      if (hasta && f.fech_cita > hasta) return false;
      if (estado && f.estado !== estado) return false;
      if (medico && f.id_medico !== Number(medico)) return false;
      return true;
    })
    .sort(
      (a, b) =>
        String(a.fech_cita).localeCompare(String(b.fech_cita)) ||
        String(a.hora_cita).localeCompare(String(b.hora_cita)) ||
        a.nro_ficha - b.nro_ficha
    );
}

function renderReportes() {
  const s = window.STORE;
  if (!s) return;
  const list = fichasReporte();
  const total = list.length;

  const cards = [
    `<div class="stat total"><div class="stat-value">${total}</div><div class="stat-label">Total fichas</div></div>`,
  ];
  ESTADOS.forEach((e) => {
    const n = list.filter((f) => f.estado === e.key).length;
    cards.push(`<div class="stat"><div class="stat-value">${n}</div><div class="stat-label">${esc(e.label)}</div></div>`);
  });
  document.getElementById("repResumen").innerHTML = cards.join("");

  document.getElementById("repCount").textContent = `· ${total} ficha(s)`;
  const empty = total === 0;
  document.getElementById("emptyRep").hidden = !empty;
  document.getElementById("wrapRep").style.display = empty ? "none" : "";

  const tbody = document.getElementById("repTbody");
  tbody.innerHTML = list
    .map((f) => {
      const med = s.empleadoById[f.id_medico];
      const esp = s.espById[f.id_especialidad];
      return `<tr>
        <td>${f.nro_ficha}</td>
        <td>${esc(fmtFechaCorta(f.fech_cita))}</td>
        <td>${esc(fmtHora(f.hora_cita))}</td>
        <td>${esc(nombreCompleto(s.personaById[f.id_persona]))}</td>
        <td>${esc(f.ci_paciente)}</td>
        <td>${esc(nombreMedico(med))}</td>
        <td>${esc(esp ? esp.nombre_especialidad : f.id_especialidad)}</td>
        <td>${badgeEstado(f.estado)}</td>
      </tr>`;
    })
    .join("");
}

function imprimirReporte() {
  const s = window.STORE;
  if (!s) return;
  const list = fichasReporte();
  if (list.length === 0) {
    toast("No hay fichas para imprimir con el filtro actual", "warning");
    return;
  }

  const desde = document.getElementById("repDesde").value;
  const hasta = document.getElementById("repHasta").value;
  const estadoLabel = document.getElementById("repEstado").selectedOptions[0].textContent;
  const medicoLabel = document.getElementById("repMedico").selectedOptions[0].textContent;

  const resumen = ESTADOS.map((e) => {
    const n = list.filter((f) => f.estado === e.key).length;
    return `${e.label}: ${n}`;
  }).join("  |  ");

  const filas = list
    .map((f) => {
      const med = s.empleadoById[f.id_medico];
      const esp = s.espById[f.id_especialidad];
      const serv = s.servById[f.id_servicio];
      return `<tr>
        <td>${f.nro_ficha}</td>
        <td>${esc(fmtFechaCorta(f.fech_cita))}</td>
        <td>${esc(fmtHora(f.hora_cita))}</td>
        <td>${esc(nombreCompleto(s.personaById[f.id_persona]))}</td>
        <td>${esc(f.ci_paciente)}</td>
        <td>${esc(f.tipo_paciente)}</td>
        <td>${esc(nombreMedico(med))}</td>
        <td>${esc(esp ? esp.nombre_especialidad : f.id_especialidad)}</td>
        <td>${esc(serv ? serv.nombre_servicio : "—")}</td>
        <td>${esc(f.estado)}</td>
        <td>${esc(f.observacion)}</td>
      </tr>`;
    })
    .join("");

  const html = `
    <div class="rep-print-head">
      <h1>Hospital Prototipo · Módulo de Citas</h1>
      <div class="rep-print-sub">Reporte de fichas · Generado el ${fmtFechaCorta(hoyISO())}</div>
    </div>
    <div class="rep-print-filtros">Periodo: ${fmtFechaCorta(desde)} – ${fmtFechaCorta(hasta)} · Estado: ${esc(
    estadoLabel
  )} · Médico: ${esc(medicoLabel)}</div>
    <div class="rep-print-resumen"><b>Resumen (${list.length} fichas):</b> ${esc(resumen)}</div>
    <table class="rep-print-table">
      <thead>
        <tr>
          <th>Nº</th><th>Fecha</th><th>Hora</th><th>Paciente</th><th>CI</th><th>Tipo</th>
          <th>Médico</th><th>Especialidad</th><th>Servicio</th><th>Estado</th><th>Observación</th>
        </tr>
      </thead>
      <tbody>${filas}</tbody>
    </table>`;

  document.getElementById("printArea").innerHTML = html;
  document.getElementById("btnImprimir").blur();
  window.print();
}

/* ---------- Descargar Excel (con previsualización) ---------- */

function exportarFichasExcel() {
  const s = window.STORE;
  if (!s) return;
  const list = fichasReporte();
  if (list.length === 0) {
    toast("No hay fichas para exportar con el filtro actual", "warning");
    return;
  }

  const desde = document.getElementById("repDesde").value;
  const hasta = document.getElementById("repHasta").value;
  const estadoLabel = document.getElementById("repEstado").selectedOptions[0].textContent;
  const medicoLabel = document.getElementById("repMedico").selectedOptions[0].textContent;

  const columnas = [
    { label: "Nº", type: "number" },
    { label: "Fecha" },
    { label: "Hora" },
    { label: "Paciente" },
    { label: "CI" },
    { label: "Tipo" },
    { label: "Médico" },
    { label: "Especialidad" },
    { label: "Servicio" },
    { label: "Estado" },
    { label: "Observación" },
  ];

  const filas = list.map((f) => {
    const med = s.empleadoById[f.id_medico];
    const esp = s.espById[f.id_especialidad];
    const serv = s.servById[f.id_servicio];
    return [
      f.nro_ficha,
      fmtFechaCorta(f.fech_cita),
      fmtHora(f.hora_cita),
      nombreCompleto(s.personaById[f.id_persona]),
      f.ci_paciente,
      f.tipo_paciente,
      nombreMedico(med),
      esp ? esp.nombre_especialidad : f.id_especialidad,
      serv ? serv.nombre_servicio : "—",
      f.estado,
      f.observacion,
    ];
  });

  abrirPrevisualizacionExcel({
    titulo: "Reporte de fichas",
    info: `Periodo ${fmtFechaCorta(desde)} – ${fmtFechaCorta(hasta)} · Estado: ${estadoLabel} · Médico: ${medicoLabel}`,
    nombreArchivo: `reporte_fichas_${desde}_a_${hasta}`,
    nombreHoja: "Fichas",
    columnas,
    filas,
  });
}