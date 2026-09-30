/* Applies the theme before first paint, so dark-mode users never see a white
   flash. Loaded from <head> on every page; assets/theme.js (end of body) still
   owns the toggle button and writes the choice.

   Dark is the product default and the system preference is deliberately NOT
   consulted: the palette is built from Larry, who lives on black, and the site
   should look the same to a first-time visitor whatever their OS is set to.
   Only an explicit choice the visitor made here can select light. */
(function () {
  try {
    if (localStorage.getItem('fp-theme') !== 'light') {
      document.documentElement.setAttribute('data-theme', 'dark');
    }
  } catch (e) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();
