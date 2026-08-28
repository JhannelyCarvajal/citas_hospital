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
  document.getElementById("btnExport").addEventListener("click", exportarCSV);

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

function exportarCSV() {
  const s = window.STORE;
  if (!s) return;
  const list = fichasReporte();
  if (list.length === 0) {
    toast("No hay fichas para exportar con el filtro actual", "warning");
    return;
  }

  const escCSV = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const head = ["Nro", "Fecha", "Hora", "Paciente", "CI", "Tipo", "Medico", "Especialidad", "Estado", "Observacion"];

  const rows = list.map((f) => {
    const med = s.empleadoById[f.id_medico];
    const esp = s.espById[f.id_especialidad];
    return [
      f.nro_ficha,
      f.fech_cita,
      f.hora_cita,
      nombreCompleto(s.personaById[f.id_persona]),
      f.ci_paciente,
      f.tipo_paciente,
      nombreMedico(med),
      esp ? esp.nombre_especialidad : f.id_especialidad,
      f.estado,
      f.observacion,
    ]
      .map(escCSV)
      .join(",");
  });

  const csv = "\uFEFF" + [head.map(escCSV).join(","), ...rows].join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `reporte_fichas_${document.getElementById("repDesde").value}_a_${document.getElementById(
    "repHasta"
  ).value}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}