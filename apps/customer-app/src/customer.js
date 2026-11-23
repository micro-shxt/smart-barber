import { createApiClient } from "../../../packages/shared-utils/apiClient.js";
import { developmentAuth } from "../../../packages/shared-utils/devAuth.js";

const api = createApiClient({ headers: developmentAuth.customer });

export async function loadMarketplace() {
  const tenants = await api.get("/marketplace/tenants");
  return Promise.all(tenants.map(async (tenant) => {
    const [services, staff] = await Promise.all([
      api.get(`/marketplace/tenants/${tenant.id}/services`),
      api.get(`/marketplace/tenants/${tenant.id}/staff`)
    ]);
    return {
      id: tenant.id,
      name: tenant.businessName,
      description: tenant.businessDescription,
      services: services.map((service) => [
        service.name,
        service.price,
        service.durationMinutes,
        service.description
      ]),
      tenantServices: services,
      staff,
      locationId: staff[0]?.locationId,
      tenant
    };
  }));
}

export function getAppointments() {
  return api.get("/me/appointments");
}

export function createAppointment(input) {
  return api.post("/appointments", input);
}

export function cancelAppointment(id) {
  return api.post(`/appointments/${id}/cancel`);
}
