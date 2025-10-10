// Rendering and filtering
(() => {
  const App = (window.App = window.App || {});
  const { $, $$, esc, safeUrl, wireAvatarFallbacks } = App.utils;

  function trStudent(s) {
    const interests = esc(s.interests || '');
    const date = new Date(s.registrationDate).toLocaleDateString();
    const photo = safeUrl(s.photoUrl) || App.utils.phSm;
    return `<tr data-id="${esc(s.id)}">
            <td data-label="Photo"><img class="avatar avatar-sm" src="${photo}" alt=""/></td>
            <td data-label="Name">${esc(s.firstName)} ${esc(s.lastName)}</td>
            <td data-label="Email">${esc(s.email)}</td>
            <td data-label="Programme">${esc(s.programme)}</td>
            <td data-label="Year">${esc(s.yearOfStudy)}</td>
            <td data-label="Interests">${interests}</td>
            <td data-label="Date">${esc(date)}</td>
            <td data-label="Actions">
                <button class="btn btn-secondary action-edit" type="button" aria-label="Edit">
                    <img src="icons/edit-profile.svg" class="icon" alt="" aria-hidden="true" />
                    <span class="sr">Edit</span>
                </button>
                <button class="btn btn-danger action-delete" type="button" aria-label="Delete">
                    <img src="icons/trash.svg" class="icon" alt="" aria-hidden="true" />
                    <span class="sr">Delete</span>
                </button>
            </td>
        </tr>`;
  }
  function cardStudent(s) {
    const photo = safeUrl(s.photoUrl) || App.utils.phLg;
    return `<article class="card" data-id="${esc(s.id)}" aria-label="${esc(s.firstName)} ${esc(s.lastName)}">
            <div class="card-head">
                <img class="avatar" src="${photo}" alt=""/>
                <div>
                    <h3 class="title">${esc(s.firstName)} ${esc(s.lastName)}</h3>
                    <p class="muted">${esc(s.email)}</p>
                </div>
            </div>
            <div class="card-body">
                <span class="pill">${esc(s.programme)}</span>
                <span class="pill">Year ${esc(s.yearOfStudy)}</span>
            </div>
            <p class="muted">${esc(s.interests || '')}</p>
            <div class="card-actions">
                <button class="btn btn-secondary action-edit" type="button" aria-label="Edit">
                    <img src="icons/edit-profile.svg" class="icon" alt="" aria-hidden="true" />
                    <span class="sr">Edit</span>
                </button>
                <button class="btn btn-danger action-delete" type="button" aria-label="Delete">
                    <img src="icons/trash.svg" class="icon" alt="" aria-hidden="true" />
                    <span class="sr">Delete</span>
                </button>
            </div>
        </article>`;
  }

  function render(list) {
    const tbody = $('#summary tbody');
    const cards = $('#cards');
    const count = $('#studentCount');
    if (!list.length) {
      tbody.innerHTML = `<tr class="empty"><td colspan="8">
                <div class="table-empty">
                        <img class="empty-gif" src="gif/dogrunning.gif" alt="Nothing here yet" onerror="this.style.display='none'"/>
                    <div class="empty-text">No students yet. Add one above.</div>
                </div>
            </td></tr>`;
    } else {
      tbody.innerHTML = list.map(trStudent).join('');
    }
    cards.innerHTML = list.map(cardStudent).join('');
    wireAvatarFallbacks(document);
    if (count) count.textContent = String(list.length);
  }

  function applyFilter(list, q) {
    q = (q || '').trim().toLowerCase();
    if (!q) return list;
    return list.filter((s) =>
      [s.firstName, s.lastName, s.email, s.programme, s.yearOfStudy, s.interests]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q))
    );
  }

  App.render = { render, applyFilter };
})();
