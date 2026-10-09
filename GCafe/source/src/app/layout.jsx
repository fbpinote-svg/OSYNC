import './globals.css';

export const metadata = {
  title: '0JAYSHOP',
  description: '0JAYSHOP Cyber Client & Game Launcher',
};

export default function RootLayout({ children }) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
