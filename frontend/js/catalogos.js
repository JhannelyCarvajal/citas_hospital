/* Sección Catálogos: listas de apoyo en modo lectura. */

function renderCatalogos() {
  const s = window.STORE;
  if (!s) return;
  const grid = document.getElementById("catalogoGrid");
  if (!grid) return;

  const nombrePersona = (pid) => {
    const p = s.personaById[pid];
    return p ? `${p.nombres} ${p.apellidos}`.trim() : `persona ${pid}`;
  };

  const nombreMedico = (eid) => {
    const e = s.empleadoById[eid];
    return e ? nombrePersona(e.id_persona) : `emp ${eid}`;
  };

  const tabla = (titulo, headers, rows, empty) => `
    <div class="card">
      <div class="card-header"><h3>${esc(titulo)}</h3></div>
      ${
        rows.length === 0
          ? `<p class="muted">${esc(empty || "Sin datos")}</p>`
          : `<div class="table-wrap"><table class="table">
              <thead><tr>${headers.map((h) => `<th>${esc(h)}</th>`).join("")}</tr></thead>
              <tbody>${rows.join("")}</tbody>
            </table></div>`
      }
    </div>`;

  const medicos = s.medList.map(
    (e) =>
      `<tr><td>${e.id_empleado}</td><td>${esc(nombrePersona(e.id_persona))}</td><td>${esc(
        e.id_persona
      )}</td><td>${esc(e.nmp || "—")}</td></tr>`
  );

  const especialidades = s.especialidades.map(
    (x) =>
      `<tr><td>${x.id_especialidad}</td><td>${esc(x.nombre_especialidad)}</td><td><span class="badge badge-info">${esc(
        x.tipo
      )}</span></td><td>${esc(x.descripcion || "")}</td></tr>`
  );

  const turnos = s.turnos.map(
    (t) =>
      `<tr><td>${t.id_turno}</td><td>${esc(t.nombre_turno)}</td><td>${esc(
        fmtHora(t.hora_inicio)
      )} – ${esc(fmtHora(t.hora_fin))}</td></tr>`
  );

  const servicios = s.servicios.map(
    (sv) => `<tr><td>${sv.id_servicio}</td><td>${esc(sv.nombre_servicio)}</td></tr>`
  );

  const horarios = s.horarios.map(
    (h) =>
      `<tr><td>${h.id_horario}</td><td>${esc(nombreMedico(h.id_empleado))}</td><td>${esc(
        procesarDiaSemana(h.dia_semana)
      )}</td><td>${esc((s.turnoById[h.id_turno] || {}).nombre_turno || h.id_turno)}</td><td>${esc(
        fmtHora(h.hora_inicio)
      )} – ${esc(fmtHora(h.hora_fin))}</td><td>${h.nro_fichas}</td></tr>`
  );

  grid.innerHTML = [
    tabla("Médicos", ["Id", "Nombre", "Id persona", "NMP"], medicos),
    tabla("Especialidades", ["Id", "Nombre", "Tipo", "Descripción"], especialidades),
    tabla("Turnos", ["Id", "Nombre", "Horario"], turnos),
    tabla("Servicios", ["Id", "Nombre"], servicios),
    tabla("Horarios", ["Id", "Médico", "Día", "Turno", "Horario", "Fichas"], horarios),
  ].join("\n");
}