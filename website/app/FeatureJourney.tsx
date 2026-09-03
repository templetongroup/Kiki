'use client';

import { useEffect, useRef, useState } from 'react';

const features = [
  {
    id: 'dictation',
    label: 'Dictation',
    title: 'Speak where you already write.',
    copy: 'Hold your shortcut in any text field. Kiki listens, shows a live preview, and inserts the finished words when you release.',
    proof: 'Undo, retry, custom vocabulary, and private sessions are built in.',
    image: '/product/kiki-home.png',
    alt: 'Kiki Workbench ready for local dictation',
  },
  {
    id: 'meetings',
    label: 'Meetings',
    title: 'Capture the room. Keep it private.',
    copy: 'Record your microphone and Mac audio on separate tracks, then review a local brief with a summary, decisions, action items, and next steps.',
    proof: 'Export Markdown, text, SRT, or WebVTT without uploading the meeting.',
    image: '/product/kiki-meeting.png',
    alt: 'Kiki Meeting Intelligence with a local transcript and action item',
  },
  {
    id: 'recordings',
    label: 'Recordings',
    title: 'Turn old audio into useful text.',
    copy: 'Drop in a recording and get an editable local transcript. Copy it, refine it, or export it in the format you need.',
    proof: 'Your selected local model does the work. No network transcription service.',
    image: '/product/kiki-file-transcription.png',
    alt: 'Kiki converting a local audio recording into editable text',
  },
  {
    id: 'voice',
    label: 'Voice Studio',
    title: 'Write it. Hear it in your voice.',
    copy: 'Record one private reference passage, type your script, and create polished speech with Kiki’s optional on-device voice engine.',
    proof: 'Your reference voice, text, and generated audio stay on your Mac.',
    image: '/product/kiki-voice-studio.png',
    alt: 'Kiki Voice Studio with local voice recording and audio creation controls',
  },
];

export default function FeatureJourney() {
  const [active, setActive] = useState(0);
  const steps = useRef<Array<HTMLElement | null>>([]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (!visible) return;
        const index = Number((visible.target as HTMLElement).dataset.index);
        if (!Number.isNaN(index)) setActive(index);
      },
      { rootMargin: '-30% 0px -42% 0px', threshold: [0.15, 0.4, 0.7] },
    );

    steps.current.forEach((step) => step && observer.observe(step));
    return () => observer.disconnect();
  }, []);

  return (
    <section className="feature-journey" aria-label="Kiki features">
      <div className="journey-visual">
        <div className="journey-screen">
          {features.map((feature, index) => (
            <img
              key={feature.id}
              className={index === active ? 'is-active' : ''}
              src={feature.image}
              alt={index === active ? feature.alt : ''}
              aria-hidden={index !== active}
            />
          ))}
          <div className="screen-label">
            <span>{String(active + 1).padStart(2, '0')}</span>
            {features[active].label}
          </div>
        </div>
        <div className="journey-dots" aria-hidden="true">
          {features.map((feature, index) => (
            <i key={feature.id} className={index === active ? 'is-active' : ''} />
          ))}
        </div>
      </div>

      <div className="journey-steps">
        {features.map((feature, index) => (
          <article
            key={feature.id}
            data-index={index}
            ref={(node) => { steps.current[index] = node; }}
            className={index === active ? 'is-active' : ''}
            onMouseEnter={() => setActive(index)}
          >
            <p className="feature-index">{String(index + 1).padStart(2, '0')} / {feature.label}</p>
            <h3>{feature.title}</h3>
            <p className="feature-copy">{feature.copy}</p>
            <p className="feature-proof"><span>✓</span>{feature.proof}</p>
            <img className="mobile-feature-image" src={feature.image} alt={feature.alt} />
          </article>
        ))}
      </div>
    </section>
  );
}
