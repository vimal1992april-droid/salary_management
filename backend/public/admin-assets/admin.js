/* The administrator's panel: the small amount of behaviour it has. No library, and every page works without it
   (the sidebar simply stays open, the theme follows the system). Loaded with `defer`. */
(function () {
  'use strict';

  var root = document.documentElement;
  var body = document.body;

  /* ---- Theme: light or dark, remembered. The page already has the right one (a script in the head applied it
     before drawing); this makes the switch work and keeps it in step with the system while the user has no choice saved. */
  var THEME_KEY = 'admin-theme';

  function currentTheme() {
    return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
  }

  function paintToggles() {
    var dark = currentTheme() === 'dark';
    document.querySelectorAll('[data-theme-toggle]').forEach(function (button) {
      button.setAttribute('aria-pressed', dark ? 'true' : 'false');
      button.setAttribute('aria-label', dark ? 'Use the light theme' : 'Use the dark theme');
    });
  }

  function applyTheme(theme) {
    root.setAttribute('data-theme', theme);
    paintToggles();
  }

  document.querySelectorAll('[data-theme-toggle]').forEach(function (button) {
    button.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      try { localStorage.setItem(THEME_KEY, next); } catch (error) { /* not saved, still applied */ }
      applyTheme(next);
    });
  });

  if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (event) {
      var saved = null;
      try { saved = localStorage.getItem(THEME_KEY); } catch (error) { /* ignore */ }
      if (saved !== 'light' && saved !== 'dark') applyTheme(event.matches ? 'dark' : 'light');
    });
  }
  paintToggles();

  /* ---- Sidebar: a drawer on small screens. ------------------------------------------------------------------------ */
  var sidebarButton = document.querySelector('[data-sidebar-toggle]');
  var backdrop = document.querySelector('[data-sidebar-backdrop]');

  function setSidebar(open) {
    body.classList.toggle('sidebar-open', open);
    if (sidebarButton) {
      sidebarButton.setAttribute('aria-expanded', open ? 'true' : 'false');
      sidebarButton.setAttribute('aria-label', open ? 'Close the menu' : 'Open the menu');
    }
  }

  if (sidebarButton) {
    sidebarButton.addEventListener('click', function () {
      setSidebar(!body.classList.contains('sidebar-open'));
    });
  }
  if (backdrop) backdrop.addEventListener('click', function () { setSidebar(false); });
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && body.classList.contains('sidebar-open')) {
      setSidebar(false);
      if (sidebarButton) sidebarButton.focus();
    }
  });
  document.querySelectorAll('#sidebar a').forEach(function (link) {
    link.addEventListener('click', function () { setSidebar(false); });
  });
})();
