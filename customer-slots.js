// Slot validity is calculated and rechecked by Supabase; this module only
// requests the current choices and formats them in the studio's local time.
(() => {
  function dateKey(date) {
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
  }

  function format(slot, timeZone) {
    return {
      ...slot,
      label: new Intl.DateTimeFormat("en-ZA", {
        hour: "2-digit",
        minute: "2-digit",
        timeZone,
      }).format(new Date(slot.starts_at)),
    };
  }

  window.customerSlots = {
    dateKey,
    format,
    async forBooking(booking) {
      const slots = await window.customerAuth.getAvailableSlots({
        providerId: booking.providerId,
        serviceId: booking.serviceId,
        date: booking.date,
        employee: booking.employee,
      });
      return slots.filter((slot) => slot.employee);
    },
  };
})();
