export function createRouter(controller) {
  return [
    { method: "GET", pattern: /^\/api\/v1\/marketplace\/tenants$/, handler: (req, res) => controller.listTenants(req, res) },
    { method: "GET", pattern: /^\/api\/v1\/me\/profile$/, handler: (req, res) => controller.myProfile(req, res) },
    { method: "GET", pattern: /^\/api\/v1\/marketplace\/tenants\/([^/]+)$/, handler: (req, res, p) => controller.getTenant(req, res, { tenantId: decodeURIComponent(p[1]) }) },
    { method: "GET", pattern: /^\/api\/v1\/marketplace\/tenants\/([^/]+)\/services$/, handler: (req, res, p) => controller.listServices(req, res, { tenantId: decodeURIComponent(p[1]) }) },
    { method: "GET", pattern: /^\/api\/v1\/marketplace\/tenants\/([^/]+)\/staff$/, handler: (req, res, p) => controller.listStaff(req, res, { tenantId: decodeURIComponent(p[1]) }) },
    { method: "GET", pattern: /^\/api\/v1\/availability$/, handler: (req, res, match, query) => controller.getAvailability(req, res, query) },
    { method: "POST", pattern: /^\/api\/v1\/appointments$/, handler: (req, res, match, query, body) => controller.createAppointment(req, res, body) },
    { method: "GET", pattern: /^\/api\/v1\/me\/appointments$/, handler: (req, res) => controller.myAppointments(req, res) },
    { method: "GET", pattern: /^\/api\/v1\/merchant\/appointments$/, handler: (req, res, match, query) => controller.merchantAppointments(req, res, query) },
    { method: "PATCH", pattern: /^\/api\/v1\/merchant\/appointments\/([^/]+)\/accept$/, handler: (req, res, p, query) => controller.accept(req, res, { appointmentId: decodeURIComponent(p[1]) }, query.tenantId) },
    { method: "PATCH", pattern: /^\/api\/v1\/merchant\/appointments\/([^/]+)\/decline$/, handler: (req, res, p, query) => controller.decline(req, res, { appointmentId: decodeURIComponent(p[1]) }, query.tenantId) },
    { method: "PATCH", pattern: /^\/api\/v1\/merchant\/appointments\/([^/]+)\/start$/, handler: (req, res, p, query) => controller.start(req, res, { appointmentId: decodeURIComponent(p[1]) }, query.tenantId) },
    { method: "PATCH", pattern: /^\/api\/v1\/merchant\/appointments\/([^/]+)\/complete$/, handler: (req, res, p, query) => controller.complete(req, res, { appointmentId: decodeURIComponent(p[1]) }, query.tenantId) },
    { method: "PATCH", pattern: /^\/api\/v1\/merchant\/appointments\/([^/]+)\/no-show$/, handler: (req, res, p, query) => controller.noShow(req, res, { appointmentId: decodeURIComponent(p[1]) }, query.tenantId) },
    { method: "POST", pattern: /^\/api\/v1\/appointments\/([^/]+)\/cancel$/, handler: (req, res, p) => controller.cancel(req, res, { appointmentId: decodeURIComponent(p[1]) }) },
    { method: "PATCH", pattern: /^\/api\/v1\/appointments\/([^/]+)\/reschedule$/, handler: (req, res, p, query, body) => controller.reschedule(req, res, { appointmentId: decodeURIComponent(p[1]) }, body) }
  ];
}
