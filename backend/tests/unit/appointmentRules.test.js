import test from "node:test";
import assert from "node:assert/strict";
import { AppointmentStatus } from "../../src/domain/enums/appointmentStatus.js";
import { assertValidTransition, appointmentsOverlap } from "../../src/domain/rules/appointmentRules.js";
import { InMemoryRepository } from "../../src/repositories/memory/inMemoryRepository.js";
import { AppointmentService } from "../../src/services/AppointmentService.js";

test("accepts a pending to confirmed transition", () => {
  assert.doesNotThrow(() => assertValidTransition(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED));
});

test("rejects an invalid status transition", () => {
  assert.throws(() => assertValidTransition(AppointmentStatus.COMPLETED, AppointmentStatus.PENDING),
    (error) => error.code === "INVALID_STATUS_TRANSITION");
});

test("detects overlapping appointments", () => {
  assert.equal(appointmentsOverlap("2026-11-24T08:00:00Z", "2026-11-24T09:00:00Z",
    "2026-11-24T08:30:00Z", "2026-11-24T10:00:00Z"), true);
  assert.equal(appointmentsOverlap("2026-11-24T08:00:00Z", "2026-11-24T09:00:00Z",
    "2026-11-24T09:00:00Z", "2026-11-24T10:00:00Z"), false);
});

test("snapshots service price and duration during booking", async () => {
  const repository = new InMemoryRepository();
  const service = await repository.createAppointmentAtomically({
    tenantId: "tenant-crown",
    locationId: "location-crown-1",
    customerId: "customer-1",
    staffId: "staff-crown-1",
    serviceId: "service-crown-cut",
    startAt: "2026-11-24T08:00:00Z",
    endAt: "2026-11-24T08:55:00Z",
    priceSnapshot: 18000,
    durationSnapshot: 45,
    customerNotes: ""
  });
  assert.equal(service.priceSnapshot, 18000);
  assert.equal(service.durationSnapshot, 45);
});

test("tenant membership prevents cross-tenant merchant access", async () => {
  const repository = new InMemoryRepository();
  const service = new AppointmentService(repository);
  await assert.rejects(
    () => service.listMerchantAppointments({ id: "merchant-owner-1" }, "tenant-studio"),
    (error) => error.code === "FORBIDDEN"
  );
});
