/* ============================================================
   Módulo de Citas · Lógica principal (single page)
   ============================================================ */

window.STORE = null;

const VISTAS = {
  dashboard: { titulo: "Resumen", sub: "Resumen del día" },
  citas: { titulo: "Citas", sub: "Gestión de citas médicas" },
  reportes: { titulo: "Reportes", sub: "Fichas por rango de fechas" },
  catalogos: { titulo: "Listas", sub: "Todo lo que tenemos dentro del sistema" },
};

let store = null;

/* Estado del registro de cita (paciente seleccionado y fecha sugerida por horario) */
let pacSel = null;
let fechaSugerida = "";

function nombreCompleto(p) {
  return p ? `${p.nombres} ${p.apellidos}`.trim() : "—";
}

function nombreMedico(e) {
  return e ? nombreCompleto(store.personaById[e.id_persona]) : "—";
}

function esPersonaMedico(idPersona) {
  return (store.empleados || []).some(
    (e) => e.id_persona === idPersona && (e.tipo_empleado || "").toLowerCase() === "medico"
  );
}

/* ---------- Carga de datos ---------- */

async function loadData() {
  const [personas, empleados, fichas, especialidades, horarios, servicios, turnos] = await Promise.all([
    apiGet("/personas/"),
    apiGet("/empleados/"),
    apiGet("/fichas/"),
    apiGet("/especialidades/"),
    apiGet("/horarios/"),
    apiGet("/servicios/"),
    apiGet("/turnos/"),
  ]);

  store = {
    personas,
    empleados,
    fichas,
    especialidades,
    horarios,
    servicios,
    turnos,
    personaById: {},
    empleadoById: {},
    espById: {},
    horById: {},
    servById: {},
    turnoById: {},
    fichaById: {},
    medList: [],
  };

  (personas || []).forEach((p) => (store.personaById[p.id_persona] = p));
  (empleados || []).forEach((e) => (store.empleadoById[e.id_empleado] = e));
  (especialidades || []).forEach((e) => (store.espById[e.id_especialidad] = e));
  (horarios || []).forEach((h) => (store.horById[h.id_horario] = h));
  (servicios || []).forEach((s) => (store.servById[s.id_servicio] = s));
  (turnos || []).forEach((t) => (store.turnoById[t.id_turno] = t));
  (fichas || []).forEach((f) => (store.fichaById[f.id_ficha] = f));

  store.medList = (empleados || []).filter((e) => (e.tipo_empleado || "").toLowerCase() === "medico");

  window.STORE = store;
}

function fichasDeFecha(fecha) {
  return (store.fichas || [])
    .filter((f) => f.fech_cita === fecha)
    .sort((a, b) => String(a.hora_cita).localeCompare(String(b.hora_cita)) || (a.nro_ficha - b.nro_ficha));
}

function fichasMedicoDia(medId, fecha) {
  return (store.fichas || []).filter((f) => f.id_medico === medId && f.fech_cita === fecha);
}

/* ---------- Resumen / Dashboard ---------- */

function renderResumen(fecha) {
  const list = fichasDeFecha(fecha);
  const total = list.length;
  const cards = document.getElementById("resumenCards");

  const stats = ESTADOS.map((e) => {
    const n = list.filter((f) => f.estado === e.key).length;
    return `<div class="stat"><div class="stat-value">${n}</div><div class="stat-label">${esc(
      e.label
    )}</div></div>`;
  }).join("");

  cards.innerHTML =
    `<div class="stat total"><div class="stat-value">${total}</div><div class="stat-label">Total</div></div>` + stats;
}

function renderDashTable(fecha) {
  const tbody = document.getElementById("dashTbody");
  const list = fichasDeFecha(fecha).slice(0, 8);
  tbody.innerHTML =
    list.length === 0
      ? `<tr><td colspan="6" class="muted" style="text-align:center">Sin citas para esta fecha.</td></tr>`
      : list
          .map((f) => {
            const med = store.empleadoById[f.id_medico];
            const esp = store.espById[f.id_especialidad];
            return `<tr>
              <td>${f.nro_ficha}</td>
              <td>${esc(nombreCompleto(store.personaById[f.id_persona]))}</td>
              <td>${esc(nombreMedico(med))}</td>
              <td>${esc(esp ? esp.nombre_especialidad : f.id_especialidad)}</td>
              <td>${esc(fmtHora(f.hora_cita))}</td>
              <td>${badgeEstado(f.estado)}</td>
            </tr>`;
          })
          .join("");
}

/* ---------- Tabla de citas ---------- */

function accionesPorEstado(estado) {
  const map = {
    Registrada: [
      { label: "Confirmar", estado: "Confirmada", clase: "btn-success" },
      { label: "Cancelar", estado: "Cancelada", clase: "btn-danger" },
    ],
    Confirmada: [
      { label: "Atender", estado: "Atendida", clase: "btn-success" },
      { label: "No asistió", estado: "No asistio", clase: "btn-warning" },
      { label: "Cancelar", estado: "Cancelada", clase: "btn-danger" },
    ],
    Atendida: [],
    "No asistio": [],
    Cancelada: [],
  };
  return map[estado] || [];
}

function renderCitas() {
  const fecha = document.getElementById("citasFecha").value;
  const list = fichasDeFecha(fecha);
  const totalEl = document.getElementById("citasTotal");
  totalEl.textContent = list.length;

  document.getElementById("citasFechaLabel").textContent = `· ${fmtFechaCorta(fecha)}`;
  document.getElementById("wrapCitas").style.display = list.length ? "" : "none";
  document.getElementById("emptyCitas").hidden = list.length > 0;

  const tbody = document.getElementById("citasTbody");
  tbody.innerHTML = list
    .map((f) => {
      const med = store.empleadoById[f.id_medico];
      const esp = store.espById[f.id_especialidad];
      const acciones = accionesPorEstado(f.estado)
        .map(
          (a) =>
            `<button class="btn ${a.clase} btn-sm" data-id="${f.id_ficha}" data-estado="${a.estado}">${a.label}</button>`
        )
        .join("");
      return `<tr>
        <td>${f.nro_ficha}</td>
        <td>${esc(nombreCompleto(store.personaById[f.id_persona]))}</td>
        <td>${badgeTipo(f.tipo_paciente)}</td>
        <td>${esc(nombreMedico(med))}</td>
        <td>${esc(esp ? esp.nombre_especialidad : f.id_especialidad)}</td>
        <td>${esc(fmtHora(f.hora_cita))}</td>
        <td>${badgeEstado(f.estado)}</td>
        <td class="acciones">${acciones || '<span class="muted">—</span>'}</td>
      </tr>`;
    })
    .join("");
}

/* ---------- Cambiar estado ---------- */

async function cambiarEstado(id, estado) {
  const ficha = store.fichaById[id];
  if (!ficha) return;
  const ok = confirm(`¿Marcar la cita #${ficha.nro_ficha} como "${estado}"?`);
  if (!ok) return;
  try {
    showLoader(true);
    await apiPut(`/fichas/${id}`, { estado });
    toast(`Cita #${ficha.nro_ficha} → ${estado}`);
    await recargarYRender();
  } catch (e) {
    toast(`No se pudo actualizar: ${esc(e.message)}`, "error");
  } finally {
    showLoader(false);
  }
}

async function recargarYRender() {
  const f = document.getElementById("citasFecha").value;
  await loadData();
  renderResumen(document.getElementById("dashFecha").value);
  renderDashTable(document.getElementById("dashFecha").value);
  document.getElementById("citasFecha").value = f;
  renderCitas();
}

/* ---------- Modal: nueva cita ---------- */

function llenarSelect(id, options, texto) {
  const sel = document.getElementById(id);
  sel.innerHTML = options.map((o) => `<option value="${o[0]}">${esc(o[1])}</option>`).join("");
}

function abrirNuevaCita() {
  pacSel = null;
  fechaSugerida = "";
  document.getElementById("ncCiBus").value = "";
  document.getElementById("ncPacInfo").hidden = true;
  document.getElementById("ncPacAlert").hidden = true;

  llenarSelect(
    "ncMedico",
    store.medList.map((e) => [e.id_empleado, `${nombreMedico(e)} (${e.nmp || "sin NMP"})`.trim()]),
    ""
  );
  llenarSelect("ncEsp", store.especialidades.map((e) => [e.id_especialidad, e.nombre_especialidad]), "");
  llenarSelect("ncServ", store.servicios.map((s) => [s.id_servicio, s.nombre_servicio]), "");

  document.getElementById("ncFecha").value = hoyISO();
  document.getElementById("ncHora").value = "";
  document.getElementById("ncObs").value = "";
  document.getElementById("ncHorInfo").textContent = "";

  fillHorarios();
  mostrarModal("modalNuevaCita");
}

function horarioTexto(h) {
  const t = store.turnoById[h.id_turno];
  return `${procesarDiaSemana(h.dia_semana)} · ${fmtHora(h.hora_inicio)}–${fmtHora(h.hora_fin)} · ${
    t ? t.nombre_turno : "turno " + h.id_turno
  }`;
}

function fillHorarios() {
  const medId = Number(document.getElementById("ncMedico").value || 0);
  const filtrados = (store.horarios || []).filter((h) => h.id_empleado === medId && h.activo !== false);
  llenarSelect("ncHor", filtrados.map((h) => [h.id_horario, horarioTexto(h)]), "");
  recalcularCita(true);
}

/* ---- Búsqueda de paciente por CI ---- */

async function buscarPaciente() {
  const ci = document.getElementById("ncCiBus").value.trim();
  if (!ci) {
    toast("Escribe el CI del paciente", "error");
    return;
  }
  const persona = (store.personas || []).find((p) => p.ci === ci);
  const info = document.getElementById("ncPacInfo");
  const alert = document.getElementById("ncPacAlert");

  if (!persona) {
    pacSel = null;
    info.hidden = true;
    toast("Persona no encontrada con ese CI", "error");
    return;
  }

  const esMedico = esPersonaMedico(persona.id_persona);
  pacSel = persona;

  document.getElementById("ncPacNombre").textContent = nombreCompleto(persona);
  document.getElementById("ncPacCi").textContent = persona.ci;
  document.getElementById("ncPacNac").textContent = persona.fecha_nacimiento ? fmtFechaCorta(persona.fecha_nacimiento) : "—";
  document.getElementById("ncPacTel").textContent = persona.telefono || "—";
  document.getElementById("ncPacMail").textContent = persona.email || "—";

  const badge = document.getElementById("ncPacAseg");
  badge.textContent = "Particular";
  badge.className = "badge badge-gray";
  try {
    const asg = await apiGet(`/personas/${encodeURIComponent(ci)}/asegurado`);
    if (asg && asg.es_asegurado) {
      badge.textContent = `Asegurado · ${asg.nro_poliza || "con póliza"}`;
      badge.className = "badge badge-info";
    }
  } catch (_) {
    /* se mantiene como Particular */
  }

  if (esMedico) {
    alert.textContent = "Esta persona es un médico: no puede registrarse como paciente.";
    alert.hidden = false;
  } else {
    alert.hidden = true;
  }
  info.hidden = false;
}

/* ---- Horario / fecha / hora automáticas ---- */

function nextDateWithWeekday(dow) {
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const objetivo = dow % 7;
  for (let i = 0; i < 8; i++) {
    const cand = new Date(hoy);
    cand.setDate(hoy.getDate() + i);
    if (cand.getDay() === objetivo) return fechaISO(cand);
  }
  return hoyISO();
}

function sumarMinutos(t, mins) {
  const [hh, mm] = String(t).split(":").map(Number);
  const total = hh * 60 + (mm || 0) + mins;
  return `${String(Math.floor(total / 60) % 24).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}

function recalcularCita(resetFecha = true) {
  const medId = Number(document.getElementById("ncMedico").value || 0);
  const horId = Number(document.getElementById("ncHor").value || 0);
  const hor = store.horById[horId];
  const fechaEl = document.getElementById("ncFecha");
  const horaEl = document.getElementById("ncHora");

  const infoHor = document.getElementById("ncHorInfo");
  infoHor.classList.remove("hint-danger");

  if (!hor) {
    infoHor.textContent = "";
    return;
  }

  let fecha = fechaEl.value;
  if (resetFecha || !fecha) {
    fecha = nextDateWithWeekday(hor.dia_semana);
    fechaEl.value = fecha;
  }
  fechaSugerida = fecha;

  const usadas = fichasMedicoDia(medId, fecha).length;
  const cupoTotal = usadas + 1;
  const lleno = usadas >= hor.nro_fichas;

  const turno = (store.turnoById[hor.id_turno] || {}).nombre_turno || "";
  const base = `${procesarDiaSemana(hor.dia_semana)} · ${fmtHora(hor.hora_inicio)}–${fmtHora(hor.hora_fin)}${
    turno ? " · " + turno : ""
  }`;

  infoHor.textContent = lleno
    ? `${base} · ficha ${cupoTotal} de ${hor.nro_fichas} — horario lleno`
    : `Ficha ${cupoTotal} de ${hor.nro_fichas} — ${base}`;
  if (lleno) infoHor.classList.add("hint-danger");

  if (lleno) {
    horaEl.value = "";
    return;
  }

  horaEl.value = sumarMinutos(hor.hora_inicio, usadas * 15);
}

/* ---- Guardar nueva cita ---- */

async function guardarNuevaCita() {
  if (!pacSel) {
    toast("Busca primero al paciente por CI", "error");
    return;
  }
  if (esPersonaMedico(pacSel.id_persona)) {
    toast("Un médico no puede ser paciente", "error");
    return;
  }

  const medId = Number(document.getElementById("ncMedico").value || 0);
  const espId = Number(document.getElementById("ncEsp").value || 0);
  const horId = Number(document.getElementById("ncHor").value || 0);
  const fecha = document.getElementById("ncFecha").value;
  const hora = document.getElementById("ncHora").value;

  if (!medId) return toast("Selecciona el médico", "error");
  if (!espId) return toast("Selecciona la especialidad", "error");
  if (!horId) return toast("Selecciona el horario del médico", "error");
  if (!fecha) return toast("Selecciona o confirma la fecha", "error");
  if (!hora) return toast("Indica la hora de la cita", "error");

  const body = {
    id_persona: pacSel.id_persona,
    ci_paciente: pacSel.ci,
    id_medico: medId,
    id_especialidad: espId,
    id_horario: horId,
    fech_cita: fecha,
    hora_cita: hora,
    observacion: document.getElementById("ncObs").value.trim(),
    usuario_reg: "admin",
  };

  const sv = Number(document.getElementById("ncServ").value || 0);
  if (!sv) return toast("Selecciona el servicio", "error");
  body.id_servicio = sv;

  const btn = document.getElementById("ncSubmit");
  btn.disabled = true;
  try {
    await apiPost("/fichas/", body);
    toast("Cita registrada correctamente");
    cerrarModal("modalNuevaCita");
    document.getElementById("repDesde").value = fecha;
    document.getElementById("repHasta").value = fecha;
    document.getElementById("citasFecha").value = fecha;
    await recargarYRender();
    irA("reportes");
  } catch (e) {
    toast(`No se pudo registrar: ${esc(e.message)}`, "error");
  } finally {
    btn.disabled = false;
  }
}

/* ---------- Navegación ---------- */

function irA(vista) {
  document.querySelectorAll(".nav-item").forEach((b) => b.classList.toggle("active", b.dataset.view === vista));
  const info = VISTAS[vista] || VISTAS.dashboard;
  document.getElementById("pageTitle").textContent = info.titulo;
  document.getElementById("pageSubtitle").textContent = info.sub;
  document.querySelectorAll(".view").forEach((s) => s.classList.toggle("active", s.id === `view-${vista}`));
  if (vista === "catalogos") renderCatalogos();
  if (vista === "reportes") renderReportes();
  if (vista === "dashboard") {
    renderResumen(document.getElementById("dashFecha").value);
    renderDashTable(document.getElementById("dashFecha").value);
  }
}

function showLoader(show) {
  document.getElementById("loader").hidden = !show;
}

/* ---------- Init ---------- */

document.addEventListener("DOMContentLoaded", async () => {
  document.getElementById("headerDate").textContent = fmtFecha(hoyISO());

  document.querySelectorAll(".nav-item").forEach((btn) =>
    btn.addEventListener("click", () => irA(btn.dataset.view))
  );

  document.querySelectorAll("[data-goto]").forEach((btn) =>
    btn.addEventListener("click", () => irA(btn.dataset.goto))
  );

  document.querySelectorAll("[data-close-modal]").forEach((btn) =>
    btn.addEventListener("click", () => cerrarModal(btn.dataset.closeModal))
  );

  document.getElementById("dashFecha").value = hoyISO();
  document.getElementById("citasFecha").value = hoyISO();
  document.getElementById("citasFecha").addEventListener("change", renderCitas);
  document.getElementById("dashFecha").addEventListener("change", () => {
    renderResumen(document.getElementById("dashFecha").value);
    renderDashTable(document.getElementById("dashFecha").value);
  });

  document.getElementById("btnNuevaCita").addEventListener("click", abrirNuevaCita);
  document.getElementById("btnNuevaCitaEmpty").addEventListener("click", abrirNuevaCita);
  document.getElementById("ncSubmit").addEventListener("click", guardarNuevaCita);

  document.getElementById("btnBuscarPac").addEventListener("click", buscarPaciente);
  document.getElementById("ncCiBus").addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      buscarPaciente();
    }
  });
  document.getElementById("ncMedico").addEventListener("change", fillHorarios);
  document.getElementById("ncHor").addEventListener("change", () => recalcularCita(true));
  document.getElementById("ncServ").addEventListener("change", () => recalcularCita(false));

  document.getElementById("citasTbody").addEventListener("click", (ev) => {
    const btn = ev.target.closest("button[data-id]");
    if (btn) cambiarEstado(Number(btn.dataset.id), btn.dataset.estado);
  });

  try {
    showLoader(true);
    await loadData();
    initReportes();
    renderResumen(hoyISO());
    renderDashTable(hoyISO());
    renderCitas();
  } catch (e) {
    toast(`Error cargando datos: ${esc(e.message)}`, "error");
  } finally {
    showLoader(false);
  }
});