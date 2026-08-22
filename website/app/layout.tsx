import type { Metadata } from 'next';
import { Bricolage_Grotesque, DM_Sans, IBM_Plex_Mono } from 'next/font/google';
import './globals.css';

const display = Bricolage_Grotesque({
  variable: '--font-display',
  subsets: ['latin'],
});

const body = DM_Sans({
  variable: '--font-body',
  subsets: ['latin'],
});

const mono = IBM_Plex_Mono({
  variable: '--font-mono',
  subsets: ['latin'],
  weight: ['400', '500'],
});

export const metadata: Metadata = {
  metadataBase: new URL('https://kiki-for-mac.tonyricciardi.chatgpt.site'),
  title: 'Kiki | Private voice intelligence for Mac',
  description: 'Dictate anywhere, capture meetings, transcribe recordings, and create audio in your own voice. Kiki runs fully locally on your Mac.',
  openGraph: {
    title: 'Kiki | Private voice intelligence for Mac',
    description: 'Dictate, capture meetings, transcribe recordings, and create audio without sending a word off your Mac.',
    images: [{ url: '/og.png', width: 1200, height: 630, alt: 'Kiki | Private voice intelligence for Mac' }],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Kiki | Private voice intelligence for Mac',
    description: 'Dictate, capture meetings, transcribe recordings, and create audio without sending a word off your Mac.',
    images: ['/og.png'],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={`${display.variable} ${body.variable} ${mono.variable}`}>
        {children}
      </body>
    </html>
  );
}
