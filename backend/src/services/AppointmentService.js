import { AppointmentStatus } from "../domain/enums/appointmentStatus.js";
import { MembershipStatus } from "../domain/enums/membership.js";
import { errors } from "../domain/errors/domainErrors.js";
import { assertValidTransition, appointmentsOverlap } from "../domain/rules/appointmentRules.js";

export class AppointmentService {
  constructor(repository) { this.repository = repository; }

  async createBooking(identity, input) {
    if (!input || typeof input !== "object") throw errors.validation("Request body is required");
    const required = ["tenantId", "locationId", "staffId", "serviceId", "startAt"];
    for (const field of required) {
      if (!input[field] || typeof input[field] !== "string") throw errors.validation(`${field} is required`);
    }
    if (!/(Z|[+-]\d{2}:\d{2})$/.test(input.startAt)) throw errors.validation("startAt must include ISO 8601 timezone information");
    const start = new Date(input.startAt);
    if (Number.isNaN(start.getTime())) throw errors.validation("startAt is not a valid ISO 8601 timestamp");

    const tenant = await this.repository.findTenantById(input.tenantId);
    const location = await this.repository.findLocationById(input.locationId);
    const service = await this.repository.findServiceById(input.serviceId);
    const staff = await this.repository.findStaffById(input.staffId);
    if (!tenant || tenant.businessStatus !== "active") throw errors.notFound("Business not found");
    if (!location || location.tenantId !== input.tenantId) throw errors.validation("Invalid location selection");
    if (!service || service.tenantId !== input.tenantId || service.serviceStatus !== "active") throw errors.validation("Invalid service selection");
    if (!staff || staff.tenantId !== input.tenantId || staff.locationId !== input.locationId || staff.staffStatus !== "active") {
      throw errors.validation("Invalid staff selection");
    }
    if (!staff.assignedServiceIds.includes(service.id)) throw errors.validation("The selected staff member cannot perform this service");

    const totalMinutes = service.durationMinutes + service.bufferMinutes;
    const end = new Date(start.getTime() + totalMinutes * 60000);
    const endAt = end.toISOString();

    const johannesburgParts = new Intl.DateTimeFormat("en-ZA", {
      timeZone: "Africa/Johannesburg", weekday: "short"
    }).formatToParts(start);
    const weekdayName = johannesburgParts.find((part) => part.type === "weekday")?.value;
    const dayMap = { Sun: 7, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
    const dayOfWeek = dayMap[weekdayName];
    const tenantHours = await this.repository.getOperatingHours(input.tenantId, dayOfWeek);
    const staffHours = await this.repository.getStaffHours(staff.id, dayOfWeek);
    if (!tenantHours || !staffHours) throw errors.conflict("The business or staff member is unavailable at this time");

    const dateKey = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Africa/Johannesburg", year: "numeric", month: "2-digit", day: "2-digit"
    }).format(start);
    const localTime = (date) => {
      const parts = new Intl.DateTimeFormat("en-GB", {
        timeZone: "Africa/Johannesburg", hour: "2-digit", minute: "2-digit", hourCycle: "h23"
      }).formatToParts(date);
      return `${parts.find((x) => x.type === "hour").value}:${parts.find((x) => x.type === "minute").value}`;
    };
    const toMinutes = (value) => { const [h, m] = value.split(":").map(Number); return h * 60 + m; };
    const startMinutes = toMinutes(localTime(start));
    const endMinutes = toMinutes(localTime(end));
    if (startMinutes < toMinutes(tenantHours.openTime) || endMinutes > toMinutes(tenantHours.closeTime) ||
        startMinutes < toMinutes(staffHours.startTime) || endMinutes > toMinutes(staffHours.endTime)) {
      throw errors.conflict("The appointment is outside operating or staff working hours");
    }

    const timeOff = await this.repository.listTimeOff(staff.id);
    if (timeOff.some((period) => appointmentsOverlap(start, end, period.startAt, period.endAt))) {
      throw errors.conflict("The staff member is unavailable at this time");
    }

    return this.repository.createAppointmentAtomically({
      tenantId: tenant.id,
      locationId: location.id,
      customerId: identity.id,
      staffId: staff.id,
      serviceId: service.id,
      startAt: start.toISOString(),
      endAt,
      priceSnapshot: service.price,
      durationSnapshot: service.durationMinutes,
      customerNotes: typeof input.customerNotes === "string" ? input.customerNotes.trim().slice(0, 1000) : ""
    });
  }

  async listMyAppointments(identity) {
    return this.repository.listAppointmentsByCustomer(identity.id);
  }

  async assertMerchant(identity, tenantId) {
    const membership = await this.repository.findMembership(identity.id, tenantId);
    if (!membership || membership.membershipStatus !== MembershipStatus.ACTIVE) {
      throw errors.forbidden("User is not an active member of this tenant");
    }
    return membership;
  }

  async listMerchantAppointments(identity, tenantId) {
    await this.assertMerchant(identity, tenantId);
    return this.repository.listAppointmentsByTenant(tenantId);
  }

  async merchantTransition(identity, tenantId, appointmentId, nextStatus) {
    await this.assertMerchant(identity, tenantId);
    const appointment = await this.repository.findAppointmentById(appointmentId);
    if (!appointment) throw errors.notFound("Appointment not found");
    if (appointment.tenantId !== tenantId) throw errors.forbidden("Appointment belongs to another tenant");
    assertValidTransition(appointment.status, nextStatus);
    appointment.status = nextStatus;
    return this.repository.saveAppointment(appointment);
  }

  async cancelAppointment(identity, appointmentId) {
    const appointment = await this.repository.findAppointmentById(appointmentId);
    if (!appointment) throw errors.notFound("Appointment not found");
    if (appointment.customerId !== identity.id) throw errors.forbidden("Cannot cancel another customer's appointment");
    assertValidTransition(appointment.status, AppointmentStatus.CANCELLED);
    appointment.status = AppointmentStatus.CANCELLED;
    return this.repository.saveAppointment(appointment);
  }
}
