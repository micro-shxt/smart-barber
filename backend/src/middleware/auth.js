import { errors } from "../domain/errors/domainErrors.js";

export class MockIdentityProvider {
  constructor(repository) { this.repository = repository; }
  async authenticate(request) {
    const userId = request.headers["x-user-id"];
    if (!userId) throw errors.unauthorised();
    const user = await this.repository.findUserById(userId);
    if (!user) throw errors.unauthorised("Unknown mock identity");
    return { id: user.id, displayName: user.displayName, provider: "development-mock" };
  }
}

export async function requireAuth(request, identityProvider) {
  return identityProvider.authenticate(request);
}
