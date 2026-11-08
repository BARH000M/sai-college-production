import { useEffect } from 'react';
import Navbar from '@/components/feature/Navbar';
import Footer from '@/components/feature/Footer';
import Hero from './components/Hero';
import About from './components/About';
import Programs from './components/Programs';
import Partnership from './components/Partnership';
import CampusNews from './components/CampusNews';
import Admissions from './components/Admissions';

export default function Home() {
  useEffect(() => {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) e.target.classList.add('in'); });
    }, { threshold: 0.12 });
    document.querySelectorAll('.reveal').forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  return (
    <div className="min-h-screen bg-background-50 text-foreground-950 font-sans">
      <Navbar />
      <main>
        <Hero />
        <About />
        <Programs />
        <Partnership />
        <CampusNews />
        <Admissions />
      </main>
      <Footer />
    </div>
  );
}