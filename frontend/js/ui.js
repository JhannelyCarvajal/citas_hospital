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
  const clase = tipo === "Asegurado" ? "badge-info" : "badge-gray";
  return `<span class="badge ${clase}">${esc(tipo || "Particular")}</span>`;
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