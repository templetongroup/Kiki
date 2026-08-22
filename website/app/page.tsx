import FeatureJourney from './FeatureJourney';

const downloadUrl =
  'https://templetongroup.dev/kiki/kiki.dmg';

const waveform = [18, 34, 52, 26, 70, 42, 88, 54, 32, 66, 92, 48, 76, 38, 58, 24, 46, 20];
const privacyWaveform = [24, 42, 68, 36, 82, 50, 92, 58, 32, 74, 46, 88, 54, 70, 38, 62, 28, 48, 76, 44, 84, 52, 66, 34, 58, 26, 42];

export default function Home() {
  return (
    <main>
      <header className="site-nav">
        <a className="developer-brand" href="#top" aria-label="Templeton Group Development, Kiki home">
          <img src="/templeton-group-development.png" alt="Templeton Group Development" />
        </a>
        <nav aria-label="Primary navigation">
          <a href="#features">Features</a>
          <a href="#privacy">Privacy</a>
          <a href="#download">Download</a>
        </nav>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="eyebrow">Voice intelligence, on your Mac</p>
          <h1>Kiki<br /><em>Private Voice<br />Intelligence.</em></h1>
          <p className="hero-intro">
            Dictate anywhere, capture meetings, transcribe recordings, and create audio in your own voice without sending a word off your Mac.
          </p>
          <div className="hero-actions">
            <a className="primary-button" href={downloadUrl}>
              <span className="download-mark" aria-hidden="true">↓</span>
              Download Kiki
              <span className="button-arrow" aria-hidden="true">↘</span>
            </a>
            <a className="text-link" href="#features">See what Kiki can do <span>↓</span></a>
          </div>
          <p className="compatibility">Version 0.6.34 · macOS 14+ · Apple silicon</p>
        </div>

        <div className="hero-stage" aria-label="Kiki turns speech into private local text">
          <div className="stage-glow" />
          <img className="hero-kiki" src="/kiki-studio-hero.png" alt="Kiki wearing headphones beside a studio microphone" />
          <div className="voice-orbit voice-orbit-one" />
          <div className="voice-orbit voice-orbit-two" />
          <div className="live-card">
            <div className="live-meta"><span className="live-dot" /> Listening locally</div>
            <div className="waveform" aria-hidden="true">
              {waveform.map((height, index) => (
                <i key={index} style={{ '--bar-height': `${height}%`, '--delay': `${index * -0.07}s` } as React.CSSProperties} />
              ))}
            </div>
            <p>“Send the revised proposal tomorrow morning.”</p>
            <div className="local-proof"><span>✓</span> Processed on this Mac</div>
          </div>
        </div>
      </section>

      <section className="proof-strip" aria-label="Kiki privacy and platform details">
        <p><span>01</span> Fully local processing</p>
        <p><span>02</span> No account required</p>
        <p><span>03</span> One Mac app, every workflow</p>
      </section>

      <section className="product-reveal" id="features">
        <div className="section-heading">
          <p className="eyebrow">One quiet command center</p>
          <h2 className="product-heading">Everything your voice can do,<br />without leaving your Mac.</h2>
        </div>
        <div className="app-window">
          <img src="/product/kiki-home.png" alt="Kiki Workbench showing dictation, meetings, Voice Studio, transcription, and setup readiness" />
        </div>
      </section>

      <FeatureJourney />

      <section className="privacy-section" id="privacy">
        <div className="privacy-copy">
          <p className="eyebrow">Privacy is the architecture</p>
          <h2>No cloud<br />to trust.</h2>
          <p>Kiki’s normal workflow happens on the Mac in front of you. Recordings, transcripts, learned spellings, and voice references don’t need a round trip through someone else’s server.</p>
          <ul>
            <li><span>✓</span> Local speech recognition</li>
            <li><span>✓</span> Private-app and secure-field protection</li>
            <li><span>✓</span> Text-only history you control</li>
            <li><span>✓</span> Sanitized support bundles</li>
          </ul>
        </div>
        <div className="privacy-diagram" aria-label="Audio is processed locally and becomes text without leaving the Mac">
          <div className="privacy-signal" aria-hidden="true">
            {privacyWaveform.map((height, index) => (
              <i key={index} style={{ '--signal-height': `${height}%`, '--signal-delay': `${index * -0.055}s` } as React.CSSProperties} />
            ))}
          </div>
          <div className="privacy-node input-node"><small>Input</small><strong>Your voice</strong><div className="mini-wave">|||||||||</div></div>
          <div className="privacy-node mac-node"><img src="/kiki-icon.png" alt="" /><small>Local intelligence</small><strong>This Mac</strong></div>
          <div className="privacy-node output-node"><small>Output</small><strong>Your words</strong><p>Notes from today’s meeting…</p></div>
          <div className="cloud-blocked"><span>×</span><p>Cloud upload</p><strong>Not in the path</strong></div>
        </div>
      </section>

      <section className="details-section">
        <div className="section-heading compact-heading">
          <p className="eyebrow">Thoughtful by default</p>
          <h2>Power when you need it.<br />Quiet when you don’t.</h2>
        </div>
        <div className="detail-grid">
          <article><p>Personalization</p><h3>Kiki learns the words that matter to you.</h3><span>Approve corrections, teach exact spellings, and import context from sources you choose.</span></article>
          <article><p>Live feedback</p><h3>See what Kiki hears while you speak.</h3><span>A lightweight transcript follows your caret, then disappears after insertion.</span></article>
          <article><p>Private session</p><h3>Leave no trail when the work is sensitive.</h3><span>Pause history, learning, confidence review, and usage totals with one action.</span></article>
          <article><p>Recovery</p><h3>Undo or retry your exact last dictation.</h3><span>Recover quickly without Kiki saving the underlying recording to disk.</span></article>
          <article><p>Model choice</p><h3>Choose the local engine that fits your Mac.</h3><span>Fast Parakeet models and compatible Whisper options are managed inside Kiki.</span></article>
          <article><p>Checkup</p><h3>Know what’s ready before you start.</h3><span>Test your microphone, permissions, model, shortcut, and first insertion in one place.</span></article>
        </div>
      </section>

      <section className="setup-section">
        <div className="setup-title">
          <p className="eyebrow">From download to first words</p>
          <h2>Ready in three<br />clear steps.</h2>
        </div>
        <ol>
          <li><span>1</span><div><h3>Move Kiki to Applications</h3><p>Open the download, then launch Kiki from your Applications folder.</p></div></li>
          <li><span>2</span><div><h3>Choose a local model</h3><p>Kiki recommends the best balance of speed and accuracy for your Mac.</p></div></li>
          <li><span>3</span><div><h3>Run Kiki Checkup</h3><p>Grant microphone and accessibility access, test your shortcut, and dictate.</p></div></li>
        </ol>
      </section>

      <section className="download-section" id="download">
        <div className="download-glow" />
        <div className="download-copy">
          <p className="eyebrow">Ready when you are</p>
          <h2>Say it once.<br /><em>Keep it yours.</em></h2>
          <p>Private voice intelligence for Apple silicon Macs running macOS 14 or later.</p>
          <a className="primary-button download-button" href={downloadUrl}>
            Download Kiki 0.6.34 <span className="button-arrow" aria-hidden="true">↘</span>
          </a>
          <small>62.8 MB · Developer ID signed · Notarized by Apple · Signed automatic updates</small>
        </div>
        <img src="/kiki-studio-hero.png" alt="Kiki wearing headphones beside a studio microphone" />
      </section>

      <footer>
        <a className="brand" href="#top"><img src="/kiki-icon.png" alt="" /><span>Kiki</span></a>
        <div className="footer-product">
          <strong>Kiki is a Templeton Technologies product.</strong>
          <a href="https://templetontech.com" aria-label="Visit Templeton Technologies">
            <img src="/templeton-technologies.png" alt="Templeton Technologies" />
          </a>
        </div>
        <div className="footer-links"><a href="https://github.com/templetongroup/Kiki">GitHub</a><a href="https://github.com/templetongroup/Kiki/releases">Releases</a><a href="#privacy">Privacy</a></div>
      </footer>
    </main>
  );
}
