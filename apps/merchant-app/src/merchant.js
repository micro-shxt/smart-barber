import { createApiClient } from "../../../packages/shared-utils/apiClient.js";
import { developmentAuth } from "../../../packages/shared-utils/devAuth.js";

const api = createApiClient({ headers: developmentAuth.merchant });

export function getAppointments() {
  return api.get("/merchant/appointments");
}

export function transitionAppointment(id, action) {
  return api.patch(`/merchant/appointments/${id}/${action}`);
}
