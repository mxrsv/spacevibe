import { BandIcon } from "./band-icon";
import { MANIFESTO, type ChipKey } from "./content";

/** A bare app icon set inside the sentence, at the height of a letter; no disc and no border. */
function Chip({ chip }: { readonly chip: ChipKey }) {
  return (
    <span data-chip aria-hidden="true" className="mx-[0.1em] inline-block align-baseline text-ink-0">
      <BandIcon band={chip} size={14} className="size-[0.85em] translate-y-[0.08em]" />
    </span>
  );
}

/**
 * L26: a tiny pill label and one large paragraph, PRODUCT.md's Mechanism sentence, set in Inter (the body face).
 * The words start dim and light one by one as the page scrolls past (motion.tsx) and stay lit; the HTML already holds
 * the final state, so the sentence reads whole without script. The icon is decoration: the sentence carries the meaning.
 */
export function Manifesto() {
  return (
    <section aria-label="How SpaceVibe works" className="band">
      <div className="shell grid justify-items-center gap-9 text-center">
        <p className="inline-flex items-center rounded-full border border-edge-strong bg-glass px-3.5 py-1 text-label uppercase text-ink-1" data-slide>
          {MANIFESTO.label}
        </p>
        <p data-manifesto className="max-w-[980px] text-manifesto font-normal text-ink-0">
          {MANIFESTO.parts.map((part, index) =>
            typeof part === "string" ? (
              part.split(" ").map((word, i) => (
                <span key={`${index}-${i}`} data-w>
                  {word}{" "}
                </span>
              ))
            ) : (
              <Chip key={`${index}-${part.chip}`} chip={part.chip} />
            ),
          )}
        </p>
      </div>
    </section>
  );
}
