// Persistence layer — localStorage on web, Capacitor.Preferences on device.
// Falls back gracefully if Capacitor isn't loaded.

const KEY = 'hearthkeep.save.v1';

export const Save = {
  load() {
    try {
      const raw = localStorage.getItem(KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      return {};
    }
  },
  save(state) {
    try {
      localStorage.setItem(KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('save failed', e);
    }
  },
  clear() {
    try { localStorage.removeItem(KEY); } catch (e) {}
  },
};
