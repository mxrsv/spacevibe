import { FOOTER, FOOTER_COLUMNS } from "./content";
import { SpaceVibeMark } from "./spacevibe-mark";

/** The reference's footer: the brand and its disclaimer on the left, then columns of links; one line under them. */
export function SiteFooter() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-edge pt-16 pb-8">
      <div className="shell grid gap-x-12 gap-y-12 md:grid-cols-[minmax(0,2fr)_repeat(2,minmax(0,1fr))]">
        <div className="grid max-w-[360px] content-start gap-5">
          <span translate="no" className="inline-flex items-center gap-2.5 text-sec font-medium text-ink-0">
            <SpaceVibeMark className="size-[22px]" />
            {FOOTER.brand}
          </span>
          <p className="text-sec text-ink-2">{FOOTER.disclaimer}</p>
        </div>
        {FOOTER_COLUMNS.map((column) => (
          <nav key={column.title} aria-label={column.title} className="grid content-start gap-3">
            <p className="text-label uppercase text-ink-2">{column.title}</p>
            <ul className="grid gap-2.5">
              {column.links.map((link) => {
                const external = link.href.startsWith("http");
                return (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      className="inline-flex min-h-6 items-center text-sec text-ink-1 no-underline transition-colors duration-150 hover:text-ink-0"
                      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
                    >
                      {link.label}
                      {external ? <span className="sr-only">(opens in a new tab)</span> : null}
                    </a>
                  </li>
                );
              })}
            </ul>
          </nav>
        ))}
      </div>
      <div className="shell mt-14 flex flex-wrap items-center justify-between gap-x-8 gap-y-2 border-t border-edge pt-6 text-tiny text-ink-2">
        <span>
          © {year} {FOOTER.by}
        </span>
      </div>
    </footer>
  );
}
