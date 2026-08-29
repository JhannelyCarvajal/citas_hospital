/* ============================================================
   Módulo de Emergencias · Atenciones y triaje
   ============================================================ */

const EMER_TIPOS = ["Urgencias", "Consulta_Externa"];
const EMER_PRIORIDADES = [
  { key: "Rojo", label: "Rojo", badge: "badge-danger" },
  { key: "Naranja", label: "Naranja", badge: "badge-warning" },
  { key: "Amarillo", label: "Amarillo", badge: "badge-warning" },
  { key: "Verde", label: "Verde", badge: "badge-success" },
];
const EMER_ESTADOS = [
  { key: "Admisión", label: "Admisión", badge: "badge-warning" },
  { key: "Triaje", label: "Triaje", badge: "badge-info" },
  { key: "Atención", label: "Atención", badge: "badge-info" },
  { key: "Observación", label: "Observación", badge: "badge-warning" },
  { key: "Finalizado", label: "Finalizado", badge: "badge-success" },
];

let emeSel = null;
let emeVencido = false;
let emeWired = false;

function emeNombreCompleto(p) {
  return p ? `${p.nombres} ${p.apellidos}`.trim() : "—";
}

function empreoMedico(e) {
  return e ? emeNombreCompleto(store.personaById[e.id_persona]) : "—";
}

function empreoNombre(e) {
  const n = empreoMedico(e);
  const tipo = (e.tipo_empleado || "").toLowerCase();
  return tipo ? `${n} (${tipo})` : n;
}

function emePersonaMedico(idPersona) {
  return (store.empleados || []).some(
    (e) => e.id_persona === idPersona && (e.tipo_empleado || "").toLowerCase() === "medico"
  );
}

function emePriBadge(p) {
  const p2 = EMER_PRIORIDADES.find((x) => x.key === p);
  return `<span class="badge ${p2 ? p2.badge : "badge-gray"}">${esc(p)}</span>`;
}

function emeEstadoBadge(e) {
  const e2 = EMER_ESTADOS.find((x) => x.key === e);
  return `<span class="badge ${e2 ? e2.badge : "badge-gray"}">${esc(e)}</span>`;
}

function emeFecha(raw) {
  return raw ? fmtFechaCorta(String(raw).slice(0, 10)) : "—";
}

function emeHora(raw) {
  return raw ? fmtHora(String(raw).slice(11, 16)) : "—";
}

function llenarSel(id, options, vacio) {
  const sel = document.getElementById(id);
  const base = (vacio ? [["", vacio]] : []).concat(options);
  sel.innerHTML = base.map((o) => `<option value="${o[0]}">${esc(o[1])}</option>`).join("");
}

/* ---------- Datos filtrados ---------- */

function emerFiltrados() {
  const desde = document.getElementById("emeDesde").value;
  const hasta = document.getElementById("emeHasta").value;
  const tipo = document.getElementById("emeTipoF").value;
  const pri = document.getElementById("emePriF").value;
  const est = document.getElementById("emeEstadoF").value;
  const med = document.getElementById("emeMedicoF").value;

  return (store.emergencias || []).filter((e) => {
    const fecha = String(e.fecha_apertura || "").slice(0, 10);
    if (desde && fecha < desde) return false;
    if (hasta && fecha > hasta) return false;
    if (tipo && e.tipo_ingreso !== tipo) return false;
    if (pri && e.prioridad_color !== pri) return false;
    if (est && e.estado !== est) return false;
    if (med && String(e.id_medico) !== med) return false;
    return true;
  });
}

/* ---------- Render ---------- */

function renderEmergencias() {
  const list = emerFiltrados();
  document.getElementById("emeCount").textContent = `(${list.length})`;
  document.getElementById("wrapEme").style.display = list.length ? "" : "none";
  document.getElementById("emptyEme").hidden = list.length > 0;

  const total = list.length;
  const rojo = list.filter((e) => e.prioridad_color === "Rojo").length;
  const admision = list.filter((e) => e.estado === "Admisión").length;
  const triaje = list.filter((e) => e.estado === "Triaje" || e.estado === "Atención").length;
  const observacion = list.filter((e) => e.estado === "Observación").length;
  const finalizadas = list.filter((e) => e.estado === "Finalizado").length;
  document.getElementById("emeResumen").innerHTML =
    `<div class="stat total"><div class="stat-value">${total}</div><div class="stat-label">Total</div></div>` +
    `<div class="stat"><div class="stat-value">${rojo}</div><div class="stat-label">Prioridad roja</div></div>` +
    `<div class="stat"><div class="stat-value">${admision}</div><div class="stat-label">Admisión</div></div>` +
    `<div class="stat"><div class="stat-value">${triaje}</div><div class="stat-label">En triaje</div></div>` +
    `<div class="stat"><div class="stat-value">${observacion}</div><div class="stat-label">Observación</div></div>` +
    `<div class="stat"><div class="stat-value">${finalizadas}</div><div class="stat-label">Finalizados</div></div>`;

  const accionesPorEst = {
    "Admisión": [
      { label: "Pasar a triaje", estado: "Triaje", clase: "btn-info" },
    ],
    "Triaje": [
      { label: "Iniciar atención", estado: "Atención", clase: "btn-success" },
    ],
    "Atención": [
      { label: "Pasar a observación", estado: "Observación", clase: "btn-warning" },
    ],
    "Observación": [
      { label: "Finalizar", estado: "Finalizado", clase: "btn-success" },
    ],
    "Finalizado": [],
  };

  const tbody = document.getElementById("emeTbody");
  tbody.innerHTML = list
    .map((e) => {
      const acciones = (accionesPorEst[e.estado] || [])
        .map(
          (a) =>
            `<button class="btn ${a.clase} btn-sm" data-em-id="${e.id}" data-em-estado="${a.estado}">${a.label}</button>`
        )
        .join("");
      return `<tr>
        <td>${e.id}</td>
        <td>${emeFecha(e.fecha_apertura)}</td>
        <td>${emeHora(e.fecha_apertura)}</td>
        <td>${esc(e.paciente)}</td>
        <td>${esc(e.ci_paciente)}</td>
        <td>${badgeTipo(e.tipo_seguro)}</td>
        <td>${esc(e.tipo_ingreso)}</td>
        <td>${emePriBadge(e.prioridad_color)}</td>
        <td>${esc(e.medico)}</td>
        <td>${esc(e.registrado_por)}</td>
        <td>${emeEstadoBadge(e.estado)}</td>
        <td class="acciones">${acciones || '<span class="muted">—</span>'}</td>
      </tr>`;
    })
    .join("");
}

/* ---------- Modal: nueva emergencia ---------- */

function abrirNuevaEmergencia() {
  emeSel = null;
  emeVencido = false;
  document.getElementById("emeCiBus").value = "";
  document.getElementById("emePacInfo").hidden = true;
  document.getElementById("emePacAlert").hidden = true;
  document.getElementById("emePacVence").hidden = true;

  llenarSel("emeMedico", store.medList.map((e) => [e.id_empleado, empreoNombre(e)]), "Selecciona el médico");
  llenarSel(
    "emeEnfermero",
    store.empleados.map((e) => [e.id_empleado, empreoNombre(e)]),
    "Selecciona quién registra"
  );
  llenarSel("emeTipo", EMER_TIPOS.map((t) => [t, t]), "");
  llenarSel("emePri", EMER_PRIORIDADES.map((p) => [p.key, p.label]), "Selecciona la prioridad");
  llenarSel("emeEstado", EMER_ESTADOS.map((s) => [s.key, s.label]), "");

  const ahora = new Date();
  document.getElementById("emeFecha").value = hoyISO();
  document.getElementById("emeHora").value = `${String(ahora.getHours()).padStart(2, "0")}:${String(
    ahora.getMinutes()
  ).padStart(2, "0")}`;

  ["emePas", "emePad", "emeFC", "emeFR", "emeO2", "emeTemp", "emeGlasgow", "emeDolor", "emeEspera"].forEach(
    (id) => (document.getElementById(id).value = "")
  );

  mostrarModal("modalEmergencia");
}

async function buscarPacienteEmergencia() {
  const ci = document.getElementById("emeCiBus").value.trim();
  if (!ci) {
    toast("Escribe el CI del paciente", "error");
    return;
  }
  const persona = (store.personas || []).find((p) => p.ci === ci);
  const info = document.getElementById("emePacInfo");
  const alert = document.getElementById("emePacAlert");

  if (!persona) {
    emeSel = null;
    info.hidden = true;
    toast("Persona no encontrada con ese CI", "error");
    return;
  }

  emeSel = persona;
  document.getElementById("emePacNombre").textContent = emeNombreCompleto(persona);
  document.getElementById("emePacCi").textContent = persona.ci;
  document.getElementById("emePacNac").textContent = persona.fecha_nacimiento ? fmtFechaCorta(persona.fecha_nacimiento) : "—";
  document.getElementById("emePacTel").textContent = persona.telefono || "—";
  document.getElementById("emePacMail").textContent = persona.email || "—";

  const badge = document.getElementById("emePacAseg");
  const venceEl = document.getElementById("emePacVence");
  badge.textContent = "Particular";
  badge.className = "badge badge-gray";
  emeVencido = false;
  venceEl.hidden = true;
  try {
    const asg = await apiGet(`/personas/${encodeURIComponent(ci)}/asegurado`);
    if (asg && asg.es_asegurado) {
      if (asg.vencido) {
        emeVencido = true;
        badge.textContent = "Asegurado vencido";
        badge.className = "badge badge-danger";
        venceEl.textContent = `La póliza venció el ${fmtFechaCorta(asg.fech_fin)}`;
        venceEl.hidden = false;
      } else {
        badge.textContent = "Asegurado";
        badge.className = "badge badge-info";
        if (asg.fech_fin) {
          venceEl.textContent = `Vence: ${fmtFechaCorta(asg.fech_fin)}`;
          venceEl.hidden = false;
        }
      }
    }
  } catch (_) {
    /* se mantiene como Particular */
  }

  if (emePersonaMedico(persona.id_persona)) {
    alert.textContent = "Esta persona es un médico: no puede registrarse como paciente.";
    alert.hidden = false;
  } else {
    alert.hidden = true;
  }
  info.hidden = false;
}

function numVal(id) {
  const v = Number(document.getElementById(id).value);
  return Number.isFinite(v) ? v : NaN;
}

async function guardarNuevaEmergencia() {
  if (!emeSel) {
    toast("Busca primero al paciente por CI", "error");
    return;
  }
  if (emePersonaMedico(emeSel.id_persona)) {
    toast("Un médico no puede ser paciente", "error");
    return;
  }

  const medico = Number(document.getElementById("emeMedico").value || 0);
  const enfermero = Number(document.getElementById("emeEnfermero").value || 0);
  const prioridad = document.getElementById("emePri").value;
  const fecha = document.getElementById("emeFecha").value;
  const hora = document.getElementById("emeHora").value;

  if (!medico) return toast("Selecciona el médico", "error");
  if (!enfermero) return toast("Selecciona quién registra la emergencia", "error");
  if (!prioridad) return toast("Selecciona la prioridad", "error");
  if (!fecha) return toast("Indica la fecha", "error");
  if (!hora) return toast("Indica la hora", "error");

  const campos = [
    ["emePas", "presion_sistolica", "presión sistólica", 40, 280],
    ["emePad", "presion_diastolica", "presión diastólica", 20, 180],
    ["emeFC", "frecuencia_cardiaca", "frecuencia cardíaca", 30, 220],
    ["emeFR", "frecuencia_respiratoria", "frecuencia respiratoria", 8, 60],
    ["emeO2", "saturacion_oxigeno", "saturación de oxígeno", 30, 100],
    ["emeTemp", "temperatura", "temperatura", 34, 43],
    ["emeGlasgow", "escala_glasgow", "escala de Glasgow", 3, 15],
    ["emeDolor", "nivel_dolor", "nivel de dolor", 0, 10],
  ];
  const body = {};
  for (const [id, campo, label, min, max] of campos) {
    const v = numVal(id);
    if (Number.isNaN(v)) return toast(`Indica la ${label}`, "error");
    if (v < min || v > max) return toast(`La ${label} debe estar entre ${min} y ${max}`, "error");
    body[campo] = v;
  }

  const espera = numVal("emeEspera");
  body.tiempo_espera_max_min = Number.isFinite(espera) ? espera : 0;

  const payload = {
    ci_paciente: emeSel.ci,
    id_medico: medico,
    id_enfermero: enfermero,
    tipo_ingreso: document.getElementById("emeTipo").value || "Urgencias",
    estado: document.getElementById("emeEstado").value || "Admisión",
    prioridad_color: prioridad,
    fecha,
    hora,
    ...body,
  };

  const btn = document.getElementById("emeSubmit");
  btn.disabled = true;
  try {
    await apiPost("/emergencias/", payload);
    toast("Emergencia registrada correctamente");
    cerrarModal("modalEmergencia");
    await loadData();
    initEmergencias();
    renderEmergencias();
  } catch (e) {
    toast(`No se pudo registrar: ${esc(e.message)}`, "error");
  } finally {
    btn.disabled = false;
  }
}

/* ---------- Cambiar estado ---------- */

async function cambiarEstadoEmergencia(id, estado) {
  try {
    showLoader(true);
    await apiPut(`/emergencias/${id}`, { estado });
    toast(`Emergencia #${id} → ${estado}`);
    await loadData();
    initEmergencias();
    renderEmergencias();
  } catch (e) {
    toast(`No se pudo actualizar: ${esc(e.message)}`, "error");
  } finally {
    showLoader(false);
  }
}

/* ---------- Imprimir · PDF ---------- */

function imprimirEmergencias() {
  const list = emerFiltrados();
  const area = document.getElementById("printArea");
  const dia = document.getElementById("emeDesde").value;
  const hasta = document.getElementById("emeHasta").value;

  area.innerHTML = `
    <h2 class="rep-titulo">Emergencias del ${fmtFechaCorta(dia)} al ${fmtFechaCorta(hasta)}</h2>
    <p class="rep-sub">Unidad de Emergencias · ${list.length} atención(es)</p>
    <table class="rep-tabla">
      <thead><tr>
        <th>N°</th><th>Fecha</th><th>Hora</th><th>Paciente</th><th>CI</th><th>Tipo</th>
        <th>Prioridad</th><th>Médico</th><th>Estado</th>
      </tr></thead>
      <tbody>
        ${list
          .map(
            (e) => `<tr>
              <td>${e.id}</td><td>${emeFecha(e.fecha_apertura)}</td><td>${emeHora(e.fecha_apertura)}</td>
              <td>${esc(e.paciente)}</td><td>${esc(e.ci_paciente)}</td><td>${esc(e.tipo_ingreso)}</td>
              <td class="rep-pri rep-${e.prioridad_color.toLowerCase()}">${esc(e.prioridad_color)}</td>
              <td>${esc(e.medico)}</td><td>${esc(e.estado)}</td>
            </tr>`
          )
          .join("")}
      </tbody>
    </table>`;
  window.print();
}

/* ---------- Init ---------- */

function initEmergencias() {
  llenarSel("emeTipoF", [["", "Todos"]].concat(EMER_TIPOS.map((t) => [t, t])), "");
  llenarSel("emePriF", [["", "Todas"]].concat(EMER_PRIORIDADES.map((p) => [p.key, p.label])), "");
  llenarSel("emeEstadoF", [["", "Todos"]].concat(EMER_ESTADOS.map((s) => [s.key, s.label])), "");
  llenarSel(
    "emeMedicoF",
    store.medList.map((e) => [e.id_empleado, empreoNombre(e)]),
    "Todos"
  );
  fillFechaInput("emeDesde", hoyISO());
  fillFechaInput("emeHasta", hoyISO());

  if (!emeWired) {
    emeWired = true;
    document.getElementById("btnNuevaEmergencia").addEventListener("click", abrirNuevaEmergencia);
    document.getElementById("btnBuscarPacEme").addEventListener("click", buscarPacienteEmergencia);
    document.getElementById("emeCiBus").addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        buscarPacienteEmergencia();
      }
    });
    document.getElementById("emeSubmit").addEventListener("click", guardarNuevaEmergencia);
    document.getElementById("btnEmeFiltrar").addEventListener("click", renderEmergencias);
    ["emeDesde", "emeHasta", "emeTipoF", "emePriF", "emeEstadoF", "emeMedicoF"].forEach((id) =>
      document.getElementById(id).addEventListener("change", renderEmergencias)
    );
    document.getElementById("btnEmeImprimir").addEventListener("click", imprimirEmergencias);
    document.getElementById("emeTbody").addEventListener("click", (ev) => {
      const btn = ev.target.closest("button[data-em-id]");
      if (btn) cambiarEstadoEmergencia(Number(btn.dataset.emId), btn.dataset.emEstado);
    });
  }
}