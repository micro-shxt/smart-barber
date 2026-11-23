import { AppointmentStatus } from "../domain/enums/appointmentStatus.js";

export class ApiController {
  constructor({ marketplace, availability, appointments, identityProvider }) {
    this.marketplace = marketplace;
    this.availability = availability;
    this.appointments = appointments;
    this.identityProvider = identityProvider;
  }

  success(res, data, message = "Operation completed successfully", status = 200) {
    res.statusCode = status;
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ success: true, data, message }));
  }

  async authenticate(req) { return this.identityProvider.authenticate(req); }

  async listTenants(req, res) { this.success(res, await this.marketplace.listTenants(), "Businesses retrieved successfully"); }
  async getTenant(req, res, params) { this.success(res, await this.marketplace.getTenant(params.tenantId)); }
  async listServices(req, res, params) { this.success(res, await this.marketplace.listServices(params.tenantId)); }
  async listStaff(req, res, params) { this.success(res, await this.marketplace.listStaff(params.tenantId)); }

  async getAvailability(req, res, query) {
    this.success(res, await this.availability.getSlots({
      tenantId: query.tenantId,
      locationId: query.locationId,
      staffId: query.staffId,
      serviceId: query.serviceId,
      date: query.date
    }));
  }

  async createAppointment(req, res, body) {
    const identity = await this.authenticate(req);
    const appointment = await this.appointments.createBooking(identity, body);
    this.success(res, appointment, "Booking request created successfully", 201);
  }

  async myAppointments(req, res) {
    const identity = await this.authenticate(req);
    this.success(res, await this.appointments.listMyAppointments(identity));
  }

  async merchantAppointments(req, res) {
    const identity = await this.authenticate(req);
    const tenantId = req.headers["x-tenant-id"];
    this.success(res, await this.appointments.listMerchantAppointments(identity, tenantId));
  }

  async merchantTransition(req, res, params, tenantId, nextStatus) {
    const identity = await this.authenticate(req);
    const resolvedTenantId = tenantId ?? req.headers["x-tenant-id"];
    const appointment = await this.appointments.merchantTransition(identity, resolvedTenantId, params.appointmentId, nextStatus);
    this.success(res, appointment, "Appointment updated successfully");
  }

  async accept(req, res, params) { await this.merchantTransition(req, res, params, null, AppointmentStatus.CONFIRMED); }
  async decline(req, res, params) { await this.merchantTransition(req, res, params, null, AppointmentStatus.DECLINED); }
  async start(req, res, params) { await this.merchantTransition(req, res, params, null, AppointmentStatus.IN_PROGRESS); }
  async complete(req, res, params) { await this.merchantTransition(req, res, params, null, AppointmentStatus.COMPLETED); }
  async noShow(req, res, params) { await this.merchantTransition(req, res, params, null, AppointmentStatus.NO_SHOW); }

  async cancel(req, res, params) {
    const identity = await this.authenticate(req);
    const appointment = await this.appointments.cancelAppointment(identity, params.appointmentId);
    this.success(res, appointment, "Appointment cancelled successfully");
  }
}
