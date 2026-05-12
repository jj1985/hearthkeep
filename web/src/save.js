// Persistence layer — localStorage on web, Capacitor.Preferences on device.
// 3-slot profiles; active slot persists separately.

const SLOT_KEY = 'hearthkeep.active_slot.v1';
const KEY_PREFIX = 'hearthkeep.save.v1.';

function activeSlot() {
  try {
    const s = parseInt(localStorage.getItem(SLOT_KEY) || '0', 10);
    return isNaN(s) ? 0 : Math.max(0, Math.min(2, s));
  } catch (e) { return 0; }
}

export const Save = {
  load() {
    try {
      const raw = localStorage.getItem(KEY_PREFIX + activeSlot());
      return raw ? JSON.parse(raw) : {};
    } catch (e) { return {}; }
  },
  save(state) {
    try {
      localStorage.setItem(KEY_PREFIX + activeSlot(), JSON.stringify(state));
    } catch (e) {
      console.warn('save failed', e);
    }
  },
  clear() {
    try { localStorage.removeItem(KEY_PREFIX + activeSlot()); } catch (e) {}
  },
  // Slot management
  activeSlot,
  setActiveSlot(i) {
    try { localStorage.setItem(SLOT_KEY, String(Math.max(0, Math.min(2, i)))); } catch (e) {}
  },
  slotSummary(i) {
    try {
      const raw = localStorage.getItem(KEY_PREFIX + i);
      if (!raw) return null;
      const obj = JSON.parse(raw);
      return {
        best_wave: obj.best_wave || 0,
        embers: obj.embers || 0,
        rebirths: obj.rebirths || 0,
        hero_level: obj.hero_level || 1,
      };
    } catch (e) { return null; }
  },
};
