import type { Metadata } from 'next';
import {
  Archivo,
  Figtree,
  IBM_Plex_Sans,
  Instrument_Sans,
  Manrope,
  Plus_Jakarta_Sans,
  Schibsted_Grotesk,
  Sora,
  Space_Grotesk,
  Syne,
} from 'next/font/google';

const instrumentSans = Instrument_Sans({ subsets: ['latin'], display: 'swap', preload: false });
const spaceGrotesk = Space_Grotesk({ subsets: ['latin'], display: 'swap', preload: false });
const manrope = Manrope({ subsets: ['latin'], display: 'swap', preload: false });
const sora = Sora({ subsets: ['latin'], display: 'swap', preload: false });
const syne = Syne({ subsets: ['latin'], display: 'swap', preload: false });
const archivo = Archivo({ subsets: ['latin'], display: 'swap', preload: false });
const schibsted = Schibsted_Grotesk({ subsets: ['latin'], display: 'swap', preload: false });
const jakarta = Plus_Jakarta_Sans({ subsets: ['latin'], display: 'swap', preload: false });
const plex = IBM_Plex_Sans({ subsets: ['latin'], display: 'swap', preload: false });
const figtree = Figtree({ subsets: ['latin'], display: 'swap', preload: false });

export const metadata: Metadata = {
  title: 'Kiki typeface comparison',
  description: 'Ten live display typeface options for Kiki.',
  openGraph: { images: [] },
  twitter: { images: [] },
};

const options = [
  { name: 'Instrument Sans', font: instrumentSans.className, note: 'Sophisticated and clean', badge: 'Recommended' },
  { name: 'Space Grotesk', font: spaceGrotesk.className, note: 'Technical with more personality', badge: 'Expressive' },
  { name: 'Manrope', font: manrope.className, note: 'Polished, warm, and highly readable' },
  { name: 'Sora', font: sora.className, note: 'Geometric and distinctly digital' },
  { name: 'Syne', font: syne.className, note: 'Bold, unusual, and editorial' },
  { name: 'Archivo', font: archivo.className, note: 'Confident and restrained' },
  { name: 'Schibsted Grotesk', font: schibsted.className, note: 'Refined with stronger character' },
  { name: 'Plus Jakarta Sans', font: jakarta.className, note: 'Friendly and premium' },
  { name: 'IBM Plex Sans', font: plex.className, note: 'Technical and trustworthy' },
  { name: 'Figtree', font: figtree.className, note: 'Clean, relaxed, and contemporary' },
];

export default function FontComparison() {
  return (
    <main className="font-showcase">
      <header className="font-showcase-nav">
        <a href="/" aria-label="Back to Kiki">
          <img src="/kiki-icon.png" alt="" />
          <span>Kiki</span>
        </a>
        <a className="font-back-link" href="/">Back to the site</a>
      </header>

      <section className="font-showcase-intro">
        <p>Live type study</p>
        <h1>Choose Kiki’s voice.</h1>
        <span>Each option uses the exact hero and section copy from the site. Compare shape, rhythm, width, and personality at realistic display sizes.</span>
      </section>

      <section className="font-option-grid" aria-label="Kiki display typeface options">
        {options.map((option, index) => (
          <article className="font-option" key={option.name}>
            <div className="font-option-meta">
              <span>{String(index + 1).padStart(2, '0')}</span>
              <div><strong>{option.name}</strong><small>{option.note}</small></div>
              {option.badge && <em>{option.badge}</em>}
            </div>
            <div className={option.font}>
              <h2 className="font-hero-sample">Your voice.<br />Your words.<br /><i>Your Mac.</i></h2>
              <p className="font-section-sample">Everything your voice can do,<br />without leaving your Mac.</p>
            </div>
          </article>
        ))}
      </section>

      <footer className="font-showcase-footer">
        <p>Pick a number and I’ll apply it throughout the live Kiki site.</p>
        <a href="/">Return to Kiki</a>
      </footer>
    </main>
  );
}
