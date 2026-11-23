/**
 * Repository contract for future D1 implementations.
 * Implementations must return domain-shaped plain objects.
 */
export class RepositoryInterface {
  async findTenantById() { throw new Error("Repository method not implemented"); }
  async listTenants() { throw new Error("Repository method not implemented"); }
  async listServicesByTenant() { throw new Error("Repository method not implemented"); }
  async listStaffByTenant() { throw new Error("Repository method not implemented"); }
  async findServiceById() { throw new Error("Repository method not implemented"); }
  async findStaffById() { throw new Error("Repository method not implemented"); }
  async findLocationById() { throw new Error("Repository method not implemented"); }
  async findMembership() { throw new Error("Repository method not implemented"); }
  async findUserById() { throw new Error("Repository method not implemented"); }
  async listAppointmentsByCustomer() { throw new Error("Repository method not implemented"); }
  async listAppointmentsByTenant() { throw new Error("Repository method not implemented"); }
  async findAppointmentById() { throw new Error("Repository method not implemented"); }
  /**
   * Atomic operation for production implementations:
   * validate relationships/conflicts and insert appointment transactionally.
   */
  async createAppointmentAtomically() { throw new Error("Repository method not implemented"); }
  async saveAppointment() { throw new Error("Repository method not implemented"); }
}
