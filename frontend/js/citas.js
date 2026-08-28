/* ============================================================
   Módulo de Citas · Lógica principal (single page)
   ============================================================ */

window.STORE = null;

const VISTAS = {
  dashboard: { titulo: "Dashboard", sub: "Resumen del día" },
  citas: { titulo: "Citas", sub: "Gestión de citas médicas" },
  catalogos: { titulo: "Catálogos", sub: "Listas de apoyo (solo lectura)" },
};

let store = null;

function nombreCompleto(p) {
  return p ? `${p.nombres} ${p.apellidos}`.trim() : "—";
}

function nombreMedico(e) {
  return e ? nombreCompleto(store.personaById[e.id_persona]) : "—";
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

function personaOptions() {
  return (store.personas || [])
    .slice()
    .sort((a, b) => a.nombres.localeCompare(b.nombres))
    .map((p) => [p.id_persona, `${p.ci} · ${p.nombres} ${p.apellidos}`.trim()]);
}

function abrirNuevaCita() {
  llenarSelect("ncPersona", personaOptions(), "");
  llenarSelect(
    "ncMedico",
    store.medList.map((e) => [e.id_empleado, `${nombreMedico(e)} (${e.nmp || "sin NMP"})`.trim()]),
    ""
  );
  llenarSelect("ncEsp", store.especialidades.map((e) => [e.id_especialidad, e.nombre_especialidad]), "");
  llenarSelect("ncServ", [[ "", "Sin servicio" ], ...store.servicios.map((s) => [s.id_servicio, s.nombre_servicio])], "");

  const fecha = document.getElementById("citasFecha").value || hoyISO();
  document.getElementById("ncFecha").value = fecha;
  document.getElementById("ncHora").value = "";
  document.getElementById("ncCi").value = "";
  document.getElementById("ncObs").value = "";

  fillHorarios();
  sincronizarCi();
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
  const filtrados = (store.horarios || []).filter((h) => h.id_empleado === medId);
  llenarSelect("ncHor", filtrados.map((h) => [h.id_horario, horarioTexto(h)]), "");
}

function sincronizarCi() {
  const pid = Number(document.getElementById("ncPersona").value || 0);
  const p = store.personaById[pid];
  document.getElementById("ncCi").value = p ? p.ci : "";
}

async function guardarNuevaCita() {
  const body = {
    id_persona: Number(document.getElementById("ncPersona").value),
    ci_paciente: document.getElementById("ncCi").value.trim(),
    id_medico: Number(document.getElementById("ncMedico").value),
    id_especialidad: Number(document.getElementById("ncEsp").value),
    id_horario: Number(document.getElementById("ncHor").value),
    fech_cita: document.getElementById("ncFecha").value,
    hora_cita: document.getElementById("ncHora").value,
    observacion: document.getElementById("ncObs").value.trim(),
    usuario_reg: "admin",
  };

  const sv = document.getElementById("ncServ").value;
  if (sv) body.id_servicio = Number(sv);

  const faltantes = ["id_persona", "ci_paciente", "id_medico", "id_especialidad", "id_horario", "fech_cita", "hora_cita"].filter(
    (k) => !body[k] && body[k] !== 0
  );

  if (faltantes.length) {
    toast("Faltan campos: " + faltantes.join(", "), "error");
    return;
  }

  const btn = document.getElementById("ncSubmit");
  btn.disabled = true;
  try {
    await apiPost("/fichas/", body);
    toast("Cita registrada correctamente");
    cerrarModal("modalNuevaCita");
    document.getElementById("citasFecha").value = body.fech_cita;
    await recargarYRender();
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

  document.getElementById("ncPersona").addEventListener("change", sincronizarCi);
  document.getElementById("ncMedico").addEventListener("change", fillHorarios);

  document.getElementById("citasTbody").addEventListener("click", (ev) => {
    const btn = ev.target.closest("button[data-id]");
    if (btn) cambiarEstado(Number(btn.dataset.id), btn.dataset.estado);
  });

  try {
    showLoader(true);
    await loadData();
    renderResumen(hoyISO());
    renderDashTable(hoyISO());
    renderCitas();
  } catch (e) {
    toast(`Error cargando datos: ${esc(e.message)}`, "error");
  } finally {
    showLoader(false);
  }
});