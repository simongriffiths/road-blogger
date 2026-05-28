const sections = [
  'Dashboard',
  'Subscribers',
  'Newsletter Composer',
  'Send History'
];

export function App() {
  return (
    <main className="app-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">ROAD Blogger</p>
          <h1>Admin Workspace</h1>
        </div>
        <span className="status-pill">M5 scaffold</span>
      </header>

      <nav className="tabs" aria-label="Admin sections">
        {sections.map((section) => (
          <button key={section} className="tab" type="button">
            {section}
          </button>
        ))}
      </nav>

      <section className="workspace">
        <h2>Build Surface</h2>
        <p>
          This placeholder marks the React admin application that will be served from ORDS through the
          ROAD UI asset pipeline. The backing admin endpoints should be designed before this surface is
          connected to live data.
        </p>
      </section>
    </main>
  );
}
