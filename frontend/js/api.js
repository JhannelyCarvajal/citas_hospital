const API_BASE = 'http://localhost:8000';

// ==================== FUNCIONES GENERICAS ====================

async function apiGet(endpoint) {
    const response = await fetch(`${API_BASE}${endpoint}`);
    if (!response.ok) {
        throw new Error(`Error: ${response.statusText}`);
    }
    return response.json();
}

async function apiPost(endpoint, data) {
    const response = await fetch(`${API_BASE}${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    });
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Error al crear registro');
    }
    return response.json();
}

async function apiPut(endpoint, data) {
    const response = await fetch(`${API_BASE}${endpoint}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    });
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.detail || 'Error al actualizar registro');
    }
    return response.json();
}

async function apiDelete(endpoint) {
    const response = await fetch(`${API_BASE}${endpoint}`, {
        method: 'DELETE',
    });
    if (!response.ok) {
        throw new Error(`Error: ${response.statusText}`);
    }
    return response.json();
}

// ==================== UTILIDADES ====================

function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('es-BO');
}

function formatTime(timeStr) {
    if (!timeStr) return '-';
    return timeStr.substring(0, 5);
}

function getEstadoBadge(estado) {
    const badges = {
        'R': '<span class="badge badge-info">Registrada</span>',
        'C': '<span class="badge badge-success">Confirmada</span>',
        'A': '<span class="badge badge-secondary">Atendida</span>',
        'N': '<span class="badge badge-warning">No asistio</span>',
        'X': '<span class="badge badge-danger">Cancelada</span>',
    };
    return badges[estado] || estado;
}

function getTipoBadge(tipo) {
    return tipo === 'A' 
        ? '<span class="badge badge-info">Asegurado</span>'
        : '<span class="badge badge-secondary">Particular</span>';
}

function showModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function hideModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

function showAlert(message, type = 'success') {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type}`;
    alertDiv.textContent = message;
    
    const main = document.querySelector('.main');
    main.insertBefore(alertDiv, main.firstChild);
    
    setTimeout(() => {
        alertDiv.remove();
    }, 5000);
}

function clearForm(formId) {
    document.getElementById(formId).reset();
}