/* Cliente HTTP genérico para la API del módulo de citas.
   Usa rutas relativas: el frontend se sirve desde la misma API (FastAPI). */

async function api(path, options = {}) {
  const conf = {
    method: options.method || "GET",
    headers: { "Content-Type": "application/json" },
  };

  if (options.body !== undefined) {
    conf.body = JSON.stringify(options.body);
  }

  const res = await fetch(path, conf);

  if (!res.ok) {
    let msg = `Error ${res.status}`;
    try {
      const data = await res.json();
      if (data && data.detail) {
        msg = typeof data.detail === "string" ? data.detail : JSON.stringify(data.detail);
      }
    } catch (_) {
      /* sin cuerpo JSON */
    }
    throw new Error(msg);
  }

  return res.status === 204 ? null : res.json();
}

const apiGet = (path) => api(path);
const apiPost = (path, body) => api(path, { method: "POST", body });
const apiPut = (path, body) => api(path, { method: "PUT", body });
const apiDelete = (path) => api(path, { method: "DELETE" });