export class AvailabilityService {
  constructor(repository) { this.repository = repository; }

  async getSlots({ tenantId, locationId, staffId, serviceId, date }) {
    if (!tenantId || !staffId || !serviceId || !date) {
      const { errors } = await import("../domain/errors/domainErrors.js");
      throw errors.validation("tenantId, staffId, serviceId and date are required");
    }
    const tenant = await this.repository.findTenantById(tenantId);
    const staff = await this.repository.findStaffById(staffId);
    const service = await this.repository.findServiceById(serviceId);
    if (!tenant || !staff || staff.tenantId !== tenantId) {
      const { errors } = await import("../domain/errors/domainErrors.js");
      throw errors.notFound("Tenant or staff member not found");
    }
    if (!service || service.tenantId !== tenantId || !staff.assignedServiceIds.includes(serviceId)) {
      const { errors } = await import("../domain/errors/domainErrors.js");
      throw errors.validation("The selected service is not provided by this staff member");
    }
    if (locationId) {
      const location = await this.repository.findLocationById(locationId);
      if (!location || location.tenantId !== tenantId || location.id !== staff.locationId) {
        const { errors } = await import("../domain/errors/domainErrors.js");
        throw errors.validation("The location and staff member do not belong to this tenant");
      }
    }
    const dateValue = new Date(`${date}T12:00:00+02:00`);
    if (Number.isNaN(dateValue.getTime())) {
      const { errors } = await import("../domain/errors/domainErrors.js");
      throw errors.validation("date must be a valid YYYY-MM-DD value");
    }
    const day = dateValue.getUTCDay() === 0 ? 7 : dateValue.getUTCDay();
    const hours = await this.repository.getStaffHours(staffId, day);
    if (!hours) return [];
    const slots = [];
    const [startHour, startMinute] = hours.startTime.split(":").map(Number);
    const [endHour, endMinute] = hours.endTime.split(":").map(Number);
    let minutes = startHour * 60 + startMinute;
    const endMinutes = endHour * 60 + endMinute;
    const appointments = await this.repository.listAppointmentsByStaff(staffId);
    while (minutes + service.durationMinutes + service.bufferMinutes <= endMinutes) {
      const hour = String(Math.floor(minutes / 60)).padStart(2, "0");
      const minute = String(minutes % 60).padStart(2, "0");
      const iso = new Date(`${date}T${hour}:${minute}:00+02:00`).toISOString();
      const end = new Date(new Date(iso).getTime() + (service.durationMinutes + service.bufferMinutes) * 60000).toISOString();
      const busy = appointments.some((appointment) => appointment.status !== "cancelled" &&
        appointment.status !== "declined" && appointment.status !== "expired" &&
        new Date(iso) < new Date(appointment.endAt) && new Date(appointment.startAt) < new Date(end));
      if (!busy) slots.push({ startAt: iso, endAt: end, durationMinutes: service.durationMinutes });
      minutes += 30;
    }
    return slots;
  }
}
