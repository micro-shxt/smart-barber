import { errors } from "../domain/errors/domainErrors.js";

export class MockIdentityProvider {
  constructor(repository, { enabled = true } = {}) {
    this.repository = repository;
    this.enabled = enabled;
  }
  async authenticate(request) {
    if (!this.enabled) throw errors.unauthorised("Mock authentication is disabled");
    const userId = request.headers["x-user-id"];
    if (!userId) throw errors.unauthorised();
    const user = await this.repository.findUserById(userId);
    if (!user) throw errors.unauthorised("Unknown mock identity");
    const memberships = await this.repository.findMembershipsByUser(user.id);
    const requestedTenantId = request.headers["x-tenant-id"];
    let tenantId = requestedTenantId;
    if (!tenantId && memberships.length === 1) tenantId = memberships[0].tenantId;
    if (tenantId && !memberships.some((membership) => membership.tenantId === tenantId)) {
      throw errors.forbidden("User is not an active member of this tenant");
    }
    return { id: user.id, displayName: user.displayName, provider: "development-mock", tenantId };
  }
}

export async function requireAuth(request, identityProvider) {
  return identityProvider.authenticate(request);
}
