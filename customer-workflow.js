// Replace the prototype's per-tab booking store with authenticated, per-user rows.
profile = function () {
  const currentUser = window.customerAuth.user;
  const account = currentUser
    ? '<section class="panel canva-panel"><h2>Your customer account</h2><p class="muted">' + esc(currentUser.email) + '</p><label class="field">Full name<input id="customer-profile-name" class="input" autocomplete="name" maxlength="160" value="' + esc(window.customerAuth.profile?.full_name || currentUser.user_metadata?.full_name || '') + '"></label><button class="btn secondary canva-button" data-action="customer-save-profile">Save profile</button><button class="text-btn canva-button" data-action="customer-signout">Sign out</button></section>'
    : '<section class="panel canva-panel"><h2>Welcome</h2><p class="muted">Explore studios without an account. Sign in or create a free customer account to manage your profile and appointments.</p><button class="btn canva-button" data-action="customer-signup">Create customer account</button><button class="text-btn canva-button" data-action="customer-signin">Sign in</button></section>';
  return '<div class="eyebrow">YOUR SPACE</div><h1 class="page-title">A little more you.</h1><p class="muted">Your account and saved customer information.</p><div class="detail-columns"><div>' + account + '<section class="panel canva-panel" style="margin-top:18px"><h2>Preferences</h2><p class="muted">Preferred city: ' + esc(city) + '</p><p class="muted">Saved places: ' + savedProviders.size + '</p></section></div></div>';
};

bookings = function () {
  if (!window.customerAuth.user) return '<div class="eyebrow">YOUR TIME</div><h1 class="page-title">My appointments.</h1><p class="muted">Sign in to view your private appointment history.</p><button class="btn canva-button" data-action="customer-signin">Sign in to continue</button>';
  const mine = records.filter((row) => row.record_type === 'customer_booking');
  return '<div class="eyebrow">YOUR TIME</div><h1 class="page-title">My appointments.</h1><p class="muted">Your private appointment history and requests.</p>' + (mine.length ? mine.map((row) => {
    const provider = window.customerProviders.find((item) => item.id === row.tenant_id);
    return '<article class="panel canva-card" style="margin-bottom:14px"><div class="booking-row"><div><span class="status ' + (row.status === 'Cancelled' ? 'cancelled' : '') + '">' + esc(row.status) + '</span><h3 style="margin:12px 0 3px">' + esc(provider?.name || 'Studio') + ' · ' + esc(row.service) + '</h3><p class="muted" style="margin:0">' + esc(new Date(row.starts_at).toLocaleString('en-ZA')) + ' · ' + esc(row.employee) + ' · ' + money(row.amount) + '</p></div>' + (row.status !== 'Cancelled' ? '<button class="btn small ghost canva-button" data-cancel="' + esc(row.item_id) + '">Cancel</button>' : '') + '</div></article>';
  }).join('') : '<div class="empty canva-panel"><h3>No appointments yet</h3><p>Your requests will appear here after you sign in.</p></div>') + '<button class="btn secondary canva-button" data-nav="Explore" style="margin-top:20px">Find an appointment</button>';
};

commitBooking = async function (button) {
  if (busy || !(await window.customerAuth.requireUser())) return;
  const value = recordForBooking();
  busy = true;
  button.disabled = true;
  button.textContent = 'Sending…';
  try {
    const saved = await window.customerAuth.saveBooking(value);
    if (!saved) return;
    records = [saved, ...records.filter((row) => row.item_id !== saved.item_id)];
    ownedIds.add(saved.item_id);
    modal = 'success';
    modalWrap('Request sent', '<div style="text-align:center;padding:20px 0"><h3>Your request is on its way.</h3><p class="muted">Status: Pending. The studio must confirm your appointment.</p><button class="btn canva-button" data-action="view-bookings">View my appointments</button></div>');
  } catch (error) {
    button.disabled = false;
    button.textContent = 'Try again';
    toast(error.message || 'Could not save the request.', true);
  } finally { busy = false; }
};

cancelBooking = async function (id, button) {
  if (busy || !(await window.customerAuth.requireUser())) return;
  busy = true;
  button.disabled = true;
  try {
    await window.customerAuth.cancelBooking(id);
    records = records.map((row) => row.item_id === id ? { ...row, status: 'Cancelled' } : row);
    render();
    toast('Appointment request cancelled.');
  } catch (error) {
    button.disabled = false;
    toast(error.message || 'Could not cancel the request.', true);
  } finally { busy = false; }
};

document.addEventListener('click', (event) => {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  const action = button.dataset.action;
  if (action === 'customer-signup' || action === 'customer-signin') {
    event.preventDefault(); event.stopImmediatePropagation();
    window.customerAuth.open(action === 'customer-signup' ? 'signup' : 'signin');
  } else if (action === 'customer-signout') {
    event.preventDefault(); event.stopImmediatePropagation();
    window.customerAuth.signOut().then(() => { records = []; render(); });
  } else if (action === 'customer-save-profile') {
    event.preventDefault(); event.stopImmediatePropagation();
    window.customerAuth.updateProfile(document.querySelector('#customer-profile-name').value)
      .then(() => toast('Profile saved.')).catch((error) => toast(error.message || 'Could not save profile.', true));
  }
}, true);

document.addEventListener('click', (event) => {
  if ((event.target.closest('[data-nav="Bookings"]') || event.target.closest('[data-action="submit-booking"]')) && !window.customerAuth.user) {
    event.preventDefault(); event.stopImmediatePropagation();
    window.customerAuth.requireUser().catch((error) => toast(error.message || 'Could not open sign-in.', true));
  }
}, true);

window.addEventListener('customer-auth-changed', async () => {
  try {
    records = await window.customerAuth.listBookings();
    ownedIds = new Set(records.map((row) => row.item_id));
  } catch (error) { toast(error.message || 'Could not load your appointments.', true); }
  ready = true;
  render();
});

(async () => {
  try {
    await window.customerAuth.initialize();
    if (window.customerAuth.user) {
      records = await window.customerAuth.listBookings();
      ownedIds = new Set(records.map((row) => row.item_id));
    }
  } catch (error) { toast(error.message || 'Customer accounts are temporarily unavailable.', true); }
  ready = true;
  render();
})();
