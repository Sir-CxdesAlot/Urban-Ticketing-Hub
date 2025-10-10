// Storage abstraction for students list
(() => {
  const App = (window.App = window.App || {});
  const LS_KEY = 'students';

  function loadStudents() {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (!raw) return [];
      return JSON.parse(raw);
    } catch {
      return [];
    }
  }
  function saveStudents(list) {
    localStorage.setItem(LS_KEY, JSON.stringify(list));
  }
  function upsert(students, payload) {
    const idx = students.findIndex((s) => s.id === payload.id);
    if (idx >= 0) students[idx] = payload;
    else students.unshift(payload);
    saveStudents(students);
    return students;
  }
  function removeById(students, id) {
    const next = students.filter((s) => s.id !== id);
    saveStudents(next);
    return next;
  }

  App.storage = { loadStudents, saveStudents, upsert, removeById };
})();
