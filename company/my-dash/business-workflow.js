(async () => {
  try {
    const authorization = await window.businessAuth.guard();
    if (!authorization) return;
    window.businessMembership = authorization.membership;
    role = authorization.membership.role;
    const tenantSelect = document.querySelector('#tenant-select');
    const roleSelect = document.querySelector('#role-select');
    if (tenantSelect) tenantSelect.closest('label').hidden = true;
    if (roleSelect) roleSelect.closest('label').hidden = true;
    const demoNotice = document.querySelector('.demo-pill');
    if (demoNotice) demoNotice.textContent = '● AUTHENTICATED · PROTOTYPE DATA';
    const topbar = document.querySelector('#topbar');
    if (topbar) {
      const logout = document.createElement('button');
      logout.type = 'button';
      logout.className = 'btn small secondary canva-button';
      logout.textContent = 'Sign out';
      logout.addEventListener('click', async () => {
        await window.businessAuth.client.auth.signOut({ scope: 'local' });
        window.location.replace('./login.html');
      });
      topbar.append(logout);
    }
    render();
    document.querySelector('.app').style.visibility = 'visible';
  } catch (error) {
    window.location.replace('./login.html?denied=1');
  }
})();
