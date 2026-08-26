// ==================== VARIABLES GLOBALES ====================
let especialidades = [];
let medicos = [];
let horarios = [];

// ==================== INICIALIZACION ====================

document.addEventListener('DOMContentLoaded', () => {
    loadEspecialidades();
    loadCitas();
    
    // Event listeners
    document.getElementById('citaForm').addEventListener('submit', handleCitaSubmit);
    document.getElementById('especialidad').addEventListener('change', handleEspecialidadChange);
    document.getElementById('medico').addEventListener('change', handleMedicoChange);
    document.getElementById('buscarBtn').addEventListener('click', loadCitas);
    
    // Fechas
    document.getElementById('fecha').valueAsDate = new Date();
});

// ==================== CARGAR DATOS ====================

async function loadEspecialidades() {
    try {
        especialidades = await apiGet('/api/catalogos/especialidades');
        const select = document.getElementById('especialidad');
        select.innerHTML = '<option value="">Seleccione especialidad...</option>';
        especialidades.forEach(esp => {
            select.innerHTML += `<option value="${esp.id_especialidad}">${esp.nombre_especialidad}</option>`;
        });
    } catch (error) {
        showAlert('Error al cargar especialidades', 'danger');
    }
}

async function loadCitas() {
    try {
        const fecha = document.getElementById('fecha').value;
        const estado = document.getElementById('filtroEstado').value;
        
        let endpoint = '/api/citas/fichas?';
        if (fecha) endpoint += `fecha=${fecha}&`;
        if (estado) endpoint += `estado=${estado}&`;
        
        const fichas = await apiGet(endpoint);
        renderCitasTable(fichas);
    } catch (error) {
        showAlert('Error al cargar citas', 'danger');
    }
}

function renderCitasTable(fichas) {
    const tbody = document.getElementById('citasTable');
    tbody.innerHTML = '';
    
    if (fichas.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" class="text-center">No hay citas para esta fecha</td>
            </tr>
        `;
        return;
    }
    
    fichas.forEach(ficha => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${ficha.nro_ficha}</td>
            <td>${ficha.paciente || ficha.ci_paciente}</td>
            <td>${ficha.medico}</td>
            <td>${ficha.especialidad}</td>
            <td>${formatDate(ficha.fech_cita)}</td>
            <td>${formatTime(ficha.hora_cita)}</td>
            <td>${getEstadoBadge(ficha.estado)}</td>
            <td>
                <button class="btn btn-sm btn-outline" onclick="verDetalle(${ficha.id_ficha})">Ver</button>
                ${ficha.estado === 'R' ? `
                    <button class="btn btn-sm btn-success" onclick="confirmarCita(${ficha.id_ficha})">Confirmar</button>
                    <button class="btn btn-sm btn-danger" onclick="cancelarCita(${ficha.id_ficha})">Cancelar</button>
                ` : ''}
                ${ficha.estado === 'C' ? `
                    <button class="btn btn-sm btn-secondary" onclick="atenderCita(${ficha.id_ficha})">Atender</button>
                ` : ''}
            </td>
        `;
        tbody.appendChild(row);
    });
}

// ==================== CREAR CITA ====================

async function handleEspecialidadChange(e) {
    const idEspecialidad = e.target.value;
    const medicoSelect = document.getElementById('medico');
    const horarioSelect = document.getElementById('horario');
    
    medicoSelect.innerHTML = '<option value="">Cargando medicos...</option>';
    horarioSelect.innerHTML = '<option value="">Primero seleccione un medico...</option>';
    
    if (!idEspecialidad) {
        medicoSelect.innerHTML = '<option value="">Seleccione especialidad primero...</option>';
        return;
    }
    
    try {
        medicos = await apiGet(`/api/catalogos/medicos/${idEspecialidad}`);
        medicoSelect.innerHTML = '<option value="">Seleccione medico...</option>';
        medicos.forEach(med => {
            medicoSelect.innerHTML += `<option value="${med.id_empleado}">${med.medico} (${med.nmp})</option>`;
        });
    } catch (error) {
        showAlert('Error al cargar medicos', 'danger');
    }
}

async function handleMedicoChange(e) {
    const idMedico = e.target.value;
    const horarioSelect = document.getElementById('horario');
    const fecha = document.getElementById('fecha').value;
    
    horarioSelect.innerHTML = '<option value="">Cargando horarios...</option>';
    
    if (!idMedico || !fecha) {
        horarioSelect.innerHTML = '<option value="">Seleccione medico y fecha...</option>';
        return;
    }
    
    try {
        const idEspecialidad = document.getElementById('especialidad').value;
        horarios = await apiGet(`/api/citas/horarios-disponibles/${idEspecialidad}?fecha=${fecha}`);
        
        // Filtrar por medico seleccionado
        horarios = horarios.filter(h => h.id_medico == idMedico);
        
        horarioSelect.innerHTML = '<option value="">Seleccione horario...</option>';
        horarios.forEach(h => {
            horarioSelect.innerHTML += `
                <option value="${h.id_horario}">
                    ${h.dia_semana} ${formatTime(h.hora_inicio)} - ${formatTime(h.hora_fin)} 
                    (${h.fichas_disponibles} cupos disponibles)
                </option>
            `;
        });
        
        if (horarios.length === 0) {
            horarioSelect.innerHTML = '<option value="">No hay horarios disponibles</option>';
        }
    } catch (error) {
        showAlert('Error al cargar horarios', 'danger');
    }
}

async function handleCitaSubmit(e) {
    e.preventDefault();
    
    const formData = {
        ci_paciente: document.getElementById('ciPaciente').value,
        id_persona: parseInt(document.getElementById('idPersona').value) || 0,
        id_especialidad: parseInt(document.getElementById('especialidad').value),
        id_medico: parseInt(document.getElementById('medico').value),
        id_horario: parseInt(document.getElementById('horario').value),
        fech_cita: document.getElementById('fecha').value,
        hora_cita: document.getElementById('horaCita').value,
        observacion: document.getElementById('observacion').value,
        usuario_reg: 'sistema'
    };
    
    try {
        const result = await apiPost('/api/citas/fichas', formData);
        showAlert('Cita registrada exitosamente');
        hideModal('nuevaCitaModal');
        clearForm('citaForm');
        loadCitas();
    } catch (error) {
        showAlert(error.message, 'danger');
    }
}

// ==================== ACCIONES SOBRE CITAS ====================

async function confirmarCita(idFicha) {
    if (!confirm('¿Confirmar esta cita?')) return;
    
    try {
        await apiPut(`/api/citas/fichas/${idFicha}/estado`, {
            estado: 'C'
        });
        showAlert('Cita confirmada');
        loadCitas();
    } catch (error) {
        showAlert('Error al confirmar cita', 'danger');
    }
}

async function cancelarCita(idFicha) {
    if (!confirm('¿Cancelar esta cita?')) return;
    
    const motivo = prompt('Motivo de cancelación:');
    if (motivo === null) return;
    
    try {
        await apiPut(`/api/citas/fichas/${idFicha}/estado`, {
            estado: 'X',
            observacion: motivo
        });
        showAlert('Cita cancelada');
        loadCitas();
    } catch (error) {
        showAlert('Error al cancelar cita', 'danger');
    }
}

async function atenderCita(idFicha) {
    if (!confirm('¿Marcar esta cita como atendida?')) return;
    
    try {
        await apiPut(`/api/citas/fichas/${idFicha}/estado`, {
            estado: 'A'
        });
        showAlert('Cita marcada como atendida');
        loadCitas();
    } catch (error) {
        showAlert('Error al actualizar cita', 'danger');
    }
}

async function verDetalle(idFicha) {
    try {
        const ficha = await apiGet(`/api/citas/fichas/${idFicha}`);
        alert(`
            DETALLE DE CITA #${ficha.nro_ficha}
            
            Paciente: ${ficha.paciente || ficha.ci_paciente}
            CI: ${ficha.ci_paciente}
            Tipo: ${ficha.tipo_desc}
            
            Medico: ${ficha.medico}
            Especialidad: ${ficha.especialidad}
            
            Fecha: ${formatDate(ficha.fech_cita)}
            Hora: ${formatTime(ficha.hora_cita)}
            
            Estado: ${ficha.estado_desc}
            Observacion: ${ficha.observacion || 'Sin observaciones'}
            
            Registrado: ${formatDate(ficha.fech_reg)}
            Por: ${ficha.usuario_reg || 'Sistema'}
        `);
    } catch (error) {
        showAlert('Error al cargar detalle', 'danger');
    }
}